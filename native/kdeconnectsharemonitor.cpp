#include "kdeconnectsharemonitor.h"

#include "desktopidutils.h"

#include <QDateTime>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMetaType>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDesktopServices>
#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>
#include <QTimer>

#include <KApplicationTrader>
#include <KService>

#include <utility>

namespace
{
constexpr auto s_service = "org.kde.kdeconnect";
constexpr auto s_daemonPath = "/modules/kdeconnect";
constexpr auto s_daemonInterface = "org.kde.kdeconnect.daemon";
constexpr auto s_devicePathPrefix = "/modules/kdeconnect/devices/";
constexpr auto s_shareInterface = "org.kde.kdeconnect.device.share";
constexpr auto s_shareSuffix = "/share";
constexpr qint64 s_shareLifetimeMs = 15LL * 60 * 1000;
constexpr qint64 s_duplicateWindowMs = 5000;
constexpr qsizetype s_maxShares = 10;
}

KdeConnectShareMonitor::KdeConnectShareMonitor(QObject *parent)
    : QObject(parent)
    , m_refreshTimer(new QTimer(this))
    , m_expirationTimer(new QTimer(this))
{
    qDBusRegisterMetaType<QMap<QString, QString>>();

    m_refreshTimer->setSingleShot(true);
    connect(m_refreshTimer, &QTimer::timeout, this, &KdeConnectShareMonitor::refreshDevices);

    m_expirationTimer->setSingleShot(true);
    m_expirationTimer->setInterval(60000);
    connect(m_expirationTimer, &QTimer::timeout, this, &KdeConnectShareMonitor::cleanExpiredShares);

    setupDBusWatcher();
}

KdeConnectShareMonitor::~KdeConnectShareMonitor()
{
    disconnectAllDevices();
    disconnectDaemonSignals();
}

bool KdeConnectShareMonitor::isEnabled() const
{
    return m_enabled;
}

void KdeConnectShareMonitor::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }

    m_enabled = enabled;
    ++m_generation;
    Q_EMIT enabledChanged();

    if (m_enabled && m_active) {
        connectDaemonSignals();
        scheduleDeviceRefresh();
    } else {
        m_refreshTimer->stop();
        m_expirationTimer->stop();
        disconnectAllDevices();
        disconnectDaemonSignals();
        m_deviceNames.clear();
        clearRecentShares();
    }
}

bool KdeConnectShareMonitor::isActive() const
{
    return m_active;
}

void KdeConnectShareMonitor::setupDBusWatcher()
{
    auto bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        return;
    }

    m_serviceWatcher = new QDBusServiceWatcher(QString::fromLatin1(s_service),
                                               bus,
                                               QDBusServiceWatcher::WatchForRegistration
                                                   | QDBusServiceWatcher::WatchForUnregistration,
                                               this);
    connect(m_serviceWatcher,
            &QDBusServiceWatcher::serviceRegistered,
            this,
            &KdeConnectShareMonitor::onServiceRegistered);
    connect(m_serviceWatcher,
            &QDBusServiceWatcher::serviceUnregistered,
            this,
            &KdeConnectShareMonitor::onServiceUnregistered);

    if (bus.interface()
            && bus.interface()->isServiceRegistered(QString::fromLatin1(s_service))) {
        onServiceRegistered(QString::fromLatin1(s_service));
    }
}

void KdeConnectShareMonitor::onServiceRegistered(const QString &service)
{
    if (service != QLatin1String(s_service)) {
        return;
    }

    setActive(true);
    if (m_enabled) {
        connectDaemonSignals();
        scheduleDeviceRefresh();
    }
}

void KdeConnectShareMonitor::onServiceUnregistered(const QString &service)
{
    if (service != QLatin1String(s_service)) {
        return;
    }

    ++m_generation;
    m_refreshTimer->stop();
    m_expirationTimer->stop();
    disconnectAllDevices();
    disconnectDaemonSignals();
    m_deviceNames.clear();
    clearRecentShares();
    setActive(false);
}

bool KdeConnectShareMonitor::connectDaemonSignals()
{
    if (m_daemonSignalsConnected) {
        return true;
    }

    auto bus = QDBusConnection::sessionBus();
    const bool added = bus.connect(QString::fromLatin1(s_service),
                                   QString::fromLatin1(s_daemonPath),
                                   QString::fromLatin1(s_daemonInterface),
                                   QStringLiteral("deviceAdded"),
                                   this,
                                   SLOT(onDeviceAdded(QString)));
    const bool removed = bus.connect(QString::fromLatin1(s_service),
                                     QString::fromLatin1(s_daemonPath),
                                     QString::fromLatin1(s_daemonInterface),
                                     QStringLiteral("deviceRemoved"),
                                     this,
                                     SLOT(onDeviceRemoved(QString)));
    const bool visibility = bus.connect(QString::fromLatin1(s_service),
                                        QString::fromLatin1(s_daemonPath),
                                        QString::fromLatin1(s_daemonInterface),
                                        QStringLiteral("deviceVisibilityChanged"),
                                        this,
                                        SLOT(onDeviceVisibilityChanged(QString,bool)));
    m_daemonSignalsConnected = added && removed && visibility;
    if (!m_daemonSignalsConnected) {
        disconnectDaemonSignals();
    }
    return m_daemonSignalsConnected;
}

void KdeConnectShareMonitor::disconnectDaemonSignals()
{
    auto bus = QDBusConnection::sessionBus();
    bus.disconnect(QString::fromLatin1(s_service),
                   QString::fromLatin1(s_daemonPath),
                   QString::fromLatin1(s_daemonInterface),
                   QStringLiteral("deviceAdded"),
                   this,
                   SLOT(onDeviceAdded(QString)));
    bus.disconnect(QString::fromLatin1(s_service),
                   QString::fromLatin1(s_daemonPath),
                   QString::fromLatin1(s_daemonInterface),
                   QStringLiteral("deviceRemoved"),
                   this,
                   SLOT(onDeviceRemoved(QString)));
    bus.disconnect(QString::fromLatin1(s_service),
                   QString::fromLatin1(s_daemonPath),
                   QString::fromLatin1(s_daemonInterface),
                   QStringLiteral("deviceVisibilityChanged"),
                   this,
                   SLOT(onDeviceVisibilityChanged(QString,bool)));
    m_daemonSignalsConnected = false;
}

void KdeConnectShareMonitor::scheduleDeviceRefresh()
{
    if (m_enabled && m_active && !m_refreshTimer->isActive()) {
        m_refreshTimer->start(0);
    }
}

void KdeConnectShareMonitor::refreshDevices()
{
    if (!m_enabled || !m_active) {
        return;
    }

    const quint64 generation = ++m_generation;
    QDBusMessage message = QDBusMessage::createMethodCall(
        QString::fromLatin1(s_service),
        QString::fromLatin1(s_daemonPath),
        QString::fromLatin1(s_daemonInterface),
        QStringLiteral("deviceNames"));
    message.setArguments({true, true});

    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher,
            &QDBusPendingCallWatcher::finished,
            this,
            [this, generation](QDBusPendingCallWatcher *finishedWatcher) {
                const QDBusPendingReply<QMap<QString, QString>> reply =
                    *finishedWatcher;
                finishedWatcher->deleteLater();
                if (!reply.isValid() || generation != m_generation
                        || !m_enabled || !m_active) {
                    return;
                }

                const QMap<QString, QString> deviceNames = reply.value();
                QSet<QString> currentDevices;
                for (auto it = deviceNames.cbegin();
                     it != deviceNames.cend(); ++it) {
                    if (!devicePath(it.key()).isEmpty()) {
                        currentDevices.insert(it.key());
                    }
                }
                const QSet<QString> removedDevices = m_connectedDevices
                    - currentDevices;
                for (const QString &deviceId : removedDevices) {
                    disconnectDevice(deviceId);
                    m_deviceNames.remove(deviceId);
                }

                bool sharesChanged = false;
                for (const QString &deviceId : currentDevices) {
                    const QString reportedName =
                        deviceNames.value(deviceId).trimmed();
                    const QString name = reportedName.isEmpty()
                        ? deviceId : reportedName;
                    m_deviceNames[deviceId] = name;
                    for (ShareEntry &entry : m_shares) {
                        if (entry.deviceId == deviceId
                                && entry.deviceName != name) {
                            entry.deviceName = name;
                            sharesChanged = true;
                        }
                    }
                    connectDevice(deviceId);
                }
                if (sharesChanged) {
                    Q_EMIT recentSharesChanged();
                }
            });
}

QString KdeConnectShareMonitor::devicePath(const QString &deviceId)
{
    static const QRegularExpression validId(
        QStringLiteral("^[A-Za-z0-9_]+$"));
    if (!validId.match(deviceId).hasMatch()) {
        return {};
    }
    return QString::fromLatin1(s_devicePathPrefix) + deviceId;
}

void KdeConnectShareMonitor::connectDevice(const QString &deviceId)
{
    if (m_connectedDevices.contains(deviceId)) {
        return;
    }

    const QString path = devicePath(deviceId);
    if (path.isEmpty()) {
        return;
    }

    const bool connected = QDBusConnection::sessionBus().connect(
        QString::fromLatin1(s_service),
        path + QString::fromLatin1(s_shareSuffix),
        QString::fromLatin1(s_shareInterface),
        QStringLiteral("shareReceived"),
        this,
        SLOT(onShareReceived(QString)));
    if (connected) {
        m_connectedDevices.insert(deviceId);
    }
}

void KdeConnectShareMonitor::disconnectDevice(const QString &deviceId)
{
    const QString path = devicePath(deviceId);
    if (!path.isEmpty()) {
        QDBusConnection::sessionBus().disconnect(
            QString::fromLatin1(s_service),
            path + QString::fromLatin1(s_shareSuffix),
            QString::fromLatin1(s_shareInterface),
            QStringLiteral("shareReceived"),
            this,
            SLOT(onShareReceived(QString)));
    }
    m_connectedDevices.remove(deviceId);
}

void KdeConnectShareMonitor::disconnectAllDevices()
{
    const QSet<QString> devices = m_connectedDevices;
    for (const QString &deviceId : devices) {
        disconnectDevice(deviceId);
    }
}

void KdeConnectShareMonitor::onDeviceAdded(const QString &)
{
    scheduleDeviceRefresh();
}

void KdeConnectShareMonitor::onDeviceRemoved(const QString &deviceId)
{
    disconnectDevice(deviceId);
    m_deviceNames.remove(deviceId);
    scheduleDeviceRefresh();
}

void KdeConnectShareMonitor::onDeviceVisibilityChanged(const QString &deviceId,
                                                       bool visible)
{
    if (!visible) {
        disconnectDevice(deviceId);
        m_deviceNames.remove(deviceId);
    }
    scheduleDeviceRefresh();
}

void KdeConnectShareMonitor::onShareReceived(const QString &urlString)
{
    if (!m_enabled || !m_active || !calledFromDBus()) {
        return;
    }

    const QString path = message().path();
    const QString prefix = QString::fromLatin1(s_devicePathPrefix);
    if (!path.startsWith(prefix)) {
        return;
    }

    const QString remainder = path.mid(prefix.size());
    const qsizetype slashIndex = remainder.indexOf(QLatin1Char('/'));
    const QString deviceId = slashIndex >= 0
        ? remainder.left(slashIndex) : remainder;
    if (!m_connectedDevices.contains(deviceId)) {
        return;
    }

    const QUrl url(urlString, QUrl::StrictMode);
    if (!isValidShareUrl(url)) {
        return;
    }
    addShareEntry(deviceId, url);
}

bool KdeConnectShareMonitor::isValidShareUrl(const QUrl &url)
{
    if (!url.isValid() || url.isEmpty()) {
        return false;
    }

    const QString scheme = url.scheme().toLower();
    if (scheme == QLatin1String("http") || scheme == QLatin1String("https")) {
        return !url.host().isEmpty();
    }
    if (scheme == QLatin1String("file") && url.isLocalFile()) {
        const QFileInfo file(url.toLocalFile());
        return file.isAbsolute() && file.exists();
    }
    return false;
}

QStringList KdeConnectShareMonitor::preferredBrowserDesktopIds()
{
    KService::Ptr service = KApplicationTrader::preferredService(
        QStringLiteral("x-scheme-handler/http"));
    if (!service) {
        service = KApplicationTrader::preferredService(QStringLiteral("text/html"));
    }
    if (!service) {
        return {};
    }

    QStringList ids;
    const QString storageId = DesktopIdUtils::normalize(service->storageId());
    const QString desktopEntry =
        DesktopIdUtils::normalize(service->desktopEntryName());
    if (!storageId.isEmpty()) {
        ids.append(storageId);
    }
    if (!desktopEntry.isEmpty() && !ids.contains(desktopEntry)) {
        ids.append(desktopEntry);
    }
    return ids;
}

QString KdeConnectShareMonitor::previewForUrl(const QUrl &url)
{
    if (url.isLocalFile()) {
        return QFileInfo(url.toLocalFile()).fileName();
    }
    return url.host();
}

void KdeConnectShareMonitor::addShareEntry(const QString &deviceId,
                                           const QUrl &url)
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    for (const ShareEntry &existing : std::as_const(m_shares)) {
        if (existing.deviceId == deviceId && existing.url == url
                && now - existing.timestamp < s_duplicateWindowMs) {
            return;
        }
    }

    ShareEntry entry;
    entry.deviceId = deviceId;
    const QString deviceName =
        m_deviceNames.value(deviceId, QStringLiteral("KDE Connect"));
    entry.deviceName = deviceName.trimmed().isEmpty()
        ? QStringLiteral("KDE Connect") : deviceName.trimmed();
    entry.url = url;
    entry.isFile = url.isLocalFile();
    entry.preview = previewForUrl(url);
    if (!entry.isFile) {
        entry.targetDesktopIds = preferredBrowserDesktopIds();
    }
    entry.timestamp = now;

    m_shares.prepend(entry);
    while (m_shares.size() > s_maxShares) {
        m_shares.removeLast();
    }

    // Nur starten, wenn der Timer nicht ohnehin schon laeuft. QTimer::start()
    // setzt einen aktiven Einmal-Timer zurueck: Treffen Freigaben haeufiger als
    // im 60-Sekunden-Takt ein, wurde die Aufraeumrunde dadurch immer weiter
    // verschoben und abgelaufene Eintraege blieben ueber ihre 15 Minuten hinaus
    // in der Liste stehen.
    if (!m_expirationTimer->isActive()) {
        m_expirationTimer->start();
    }
    Q_EMIT recentSharesChanged();
}

void KdeConnectShareMonitor::cleanExpiredShares()
{
    const qint64 cutoff = QDateTime::currentMSecsSinceEpoch()
        - s_shareLifetimeMs;
    const qsizetype oldSize = m_shares.size();
    m_shares.removeIf([cutoff](const ShareEntry &entry) {
        return entry.timestamp < cutoff;
    });

    if (m_shares.size() != oldSize) {
        Q_EMIT recentSharesChanged();
    }
    if (!m_shares.isEmpty()) {
        m_expirationTimer->start();
    }
}

QVariantMap KdeConnectShareMonitor::entryToVariantMap(const ShareEntry &entry)
{
    return {
        {QStringLiteral("deviceId"), entry.deviceId},
        {QStringLiteral("deviceName"), entry.deviceName},
        {QStringLiteral("url"), entry.url.toString()},
        {QStringLiteral("type"), entry.isFile
            ? QStringLiteral("file") : QStringLiteral("url")},
        {QStringLiteral("preview"), entry.preview},
        {QStringLiteral("timestamp"), entry.timestamp},
    };
}

QVariantList KdeConnectShareMonitor::recentShares() const
{
    QVariantList shares;
    shares.reserve(m_shares.size());
    for (const ShareEntry &entry : m_shares) {
        shares.append(entryToVariantMap(entry));
    }
    return shares;
}

QVariantMap KdeConnectShareMonitor::getLatestShareForApp(
    const QString &appId,
    const QString &launcherUrl) const
{
    const QString normalizedAppId = DesktopIdUtils::normalize(appId);
    const QString normalizedLauncher = DesktopIdUtils::normalize(launcherUrl);
    if (normalizedAppId.isEmpty() && normalizedLauncher.isEmpty()) {
        return {};
    }

    for (const ShareEntry &entry : m_shares) {
        if (entry.isFile) {
            continue;
        }
        if ((!normalizedAppId.isEmpty()
             && entry.targetDesktopIds.contains(normalizedAppId))
                || (!normalizedLauncher.isEmpty()
                    && entry.targetDesktopIds.contains(normalizedLauncher))) {
            return entryToVariantMap(entry);
        }
    }
    return {};
}

QVariantMap KdeConnectShareMonitor::getLatestShareForFolder(
    const QUrl &folderUrl) const
{
    if (!folderUrl.isLocalFile()) {
        return {};
    }

    const QFileInfo folderInfo(folderUrl.toLocalFile());
    const QString folderPath = folderInfo.canonicalFilePath();
    if (folderPath.isEmpty() || !folderInfo.isDir()) {
        return {};
    }

    const QDir folder(folderPath);
    for (const ShareEntry &entry : m_shares) {
        if (!entry.isFile || !entry.url.isLocalFile()) {
            continue;
        }
        const QString filePath = QFileInfo(entry.url.toLocalFile())
                                     .canonicalFilePath();
        if (filePath.isEmpty()) {
            continue;
        }
        const QString relativePath = folder.relativeFilePath(filePath);
        if (relativePath != QLatin1String("..")
                && !relativePath.startsWith(QLatin1String("../"))
                && !QDir::isAbsolutePath(relativePath)) {
            return entryToVariantMap(entry);
        }
    }
    return {};
}

bool KdeConnectShareMonitor::openShareUrl(const QString &urlString) const
{
    const QUrl url(urlString, QUrl::StrictMode);
    return isValidShareUrl(url) && QDesktopServices::openUrl(url);
}

void KdeConnectShareMonitor::clearRecentShares()
{
    if (m_shares.isEmpty()) {
        return;
    }
    m_shares.clear();
    Q_EMIT recentSharesChanged();
}

void KdeConnectShareMonitor::setActive(bool active)
{
    if (m_active == active) {
        return;
    }
    m_active = active;
    Q_EMIT activeChanged();
}
