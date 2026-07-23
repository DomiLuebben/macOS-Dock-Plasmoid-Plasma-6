#include "kdeconnectsharemonitor.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusPendingReply>
#include <QUrl>
#include <QDesktopServices>
#include <QDebug>

KdeConnectShareMonitor::KdeConnectShareMonitor(QObject *parent)
    : QObject(parent)
{
    m_expirationTimer = new QTimer(this);
    m_expirationTimer->setInterval(60000); // Clean every minute
    connect(m_expirationTimer, &QTimer::timeout, this, &KdeConnectShareMonitor::cleanExpiredShares);
    m_expirationTimer->start();

    setupDBusWatcher();
}

KdeConnectShareMonitor::~KdeConnectShareMonitor()
{
}

void KdeConnectShareMonitor::setEnabled(bool enabled)
{
    if (m_enabled != enabled) {
        m_enabled = enabled;
        Q_EMIT enabledChanged();
        if (m_enabled) {
            refreshDevices();
        } else {
            m_shares.clear();
            Q_EMIT recentSharesChanged();
        }
    }
}

void KdeConnectShareMonitor::setupDBusWatcher()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        return;
    }

    m_serviceWatcher = new QDBusServiceWatcher(QStringLiteral("org.kde.kdeconnect"), bus,
                                                 QDBusServiceWatcher::WatchForRegistration | QDBusServiceWatcher::WatchForUnregistration,
                                                 this);

    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceRegistered, this, &KdeConnectShareMonitor::onServiceRegistered);
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceUnregistered, this, &KdeConnectShareMonitor::onServiceUnregistered);

    if (bus.interface()->isServiceRegistered(QStringLiteral("org.kde.kdeconnect"))) {
        onServiceRegistered(QStringLiteral("org.kde.kdeconnect"));
    }
}

void KdeConnectShareMonitor::onServiceRegistered(const QString &service)
{
    Q_UNUSED(service);
    m_active = true;
    Q_EMIT activeChanged();

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(QStringLiteral("org.kde.kdeconnect"), QStringLiteral("/modules/kdeconnect"),
                QStringLiteral("org.kde.kdeconnect.daemon"), QStringLiteral("deviceAdded"),
                this, SLOT(onDeviceAdded(QString)));

    bus.connect(QStringLiteral("org.kde.kdeconnect"), QStringLiteral("/modules/kdeconnect"),
                QStringLiteral("org.kde.kdeconnect.daemon"), QStringLiteral("deviceRemoved"),
                this, SLOT(onDeviceRemoved(QString)));

    bus.connect(QStringLiteral("org.kde.kdeconnect"), QStringLiteral("/modules/kdeconnect"),
                QStringLiteral("org.kde.kdeconnect.daemon"), QStringLiteral("deviceVisibilityChanged"),
                this, SLOT(onDeviceVisibilityChanged(QString,bool)));

    refreshDevices();
}

void KdeConnectShareMonitor::onServiceUnregistered(const QString &service)
{
    Q_UNUSED(service);
    m_active = false;
    m_deviceNames.clear();
    m_shares.clear();
    Q_EMIT activeChanged();
    Q_EMIT recentSharesChanged();
}

void KdeConnectShareMonitor::refreshDevices()
{
    if (!m_active || !m_enabled) {
        return;
    }

    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.kdeconnect"),
        QStringLiteral("/modules/kdeconnect"),
        QStringLiteral("org.kde.kdeconnect.daemon"),
        QStringLiteral("devices")
    );
    msg << true << true; // onlyReachable = true, onlyPaired = true

    QDBusPendingCall pcall = QDBusConnection::sessionBus().asyncCall(msg);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(pcall, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusPendingReply<QStringList> reply = *w;
        if (reply.isValid()) {
            QStringList deviceIds = reply.value();
            for (const QString &id : deviceIds) {
                checkDeviceDetails(id);
            }
        }
    });
}

void KdeConnectShareMonitor::checkDeviceDetails(const QString &deviceId)
{
    if (deviceId.isEmpty()) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.kdeconnect"),
        QString(QStringLiteral("/modules/kdeconnect/devices/") + deviceId),
        QStringLiteral("org.freedesktop.DBus.Properties"),
        QStringLiteral("Get")
    );
    msg << QStringLiteral("org.kde.kdeconnect.device") << QStringLiteral("name");

    QDBusPendingCall pcall = QDBusConnection::sessionBus().asyncCall(msg);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(pcall, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, deviceId](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusPendingReply<QVariant> reply = *w;
        if (reply.isValid()) {
            QString name = reply.value().toString();
            if (name.isEmpty()) name = deviceId;
            m_deviceNames[deviceId] = name;
            setupDeviceSignals(deviceId);
        }
    });
}

void KdeConnectShareMonitor::setupDeviceSignals(const QString &deviceId)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    QString path = QString(QStringLiteral("/modules/kdeconnect/devices/") + deviceId + QStringLiteral("/share"));

    bus.connect(QStringLiteral("org.kde.kdeconnect"), path,
                QStringLiteral("org.kde.kdeconnect.device.share"), QStringLiteral("shareReceived"),
                this, SLOT(onShareReceived(QString)));

    // Also connect to parent device object if shareReceived is emitted there
    QString devPath = QString(QStringLiteral("/modules/kdeconnect/devices/") + deviceId);
    bus.connect(QStringLiteral("org.kde.kdeconnect"), devPath,
                QStringLiteral("org.kde.kdeconnect.device.share"), QStringLiteral("shareReceived"),
                this, SLOT(onShareReceived(QString)));
}

void KdeConnectShareMonitor::onShareReceived(const QString &url)
{
    QString deviceId = QStringLiteral("KDE Connect");
    QString senderPath = message().path();
    if (senderPath.startsWith(QLatin1String("/modules/kdeconnect/devices/"))) {
        QString rest = senderPath.mid(29);
        int slashIdx = rest.indexOf(QLatin1Char('/'));
        if (slashIdx != -1) {
            deviceId = rest.left(slashIdx);
        } else {
            deviceId = rest;
        }
    }
    QString deviceName = m_deviceNames.value(deviceId, QStringLiteral("KDE Connect"));
    addShareEntry(deviceId, deviceName, url);
}

void KdeConnectShareMonitor::onDeviceAdded(const QString &deviceId)
{
    checkDeviceDetails(deviceId);
}

void KdeConnectShareMonitor::onDeviceRemoved(const QString &deviceId)
{
    m_deviceNames.remove(deviceId);
}

void KdeConnectShareMonitor::onDeviceVisibilityChanged(const QString &deviceId, bool isVisible)
{
    if (isVisible) {
        checkDeviceDetails(deviceId);
    } else {
        m_deviceNames.remove(deviceId);
    }
}

bool KdeConnectShareMonitor::isValidUrl(const QString &urlStr)
{
    if (urlStr.isEmpty()) return false;
    QUrl url(urlStr);
    if (!url.isValid()) return false;
    QString scheme = url.scheme().toLower();
    return (scheme == QLatin1String("http") || scheme == QLatin1String("https") || scheme == QLatin1String("file"));
}

void KdeConnectShareMonitor::addShareEntry(const QString &deviceId, const QString &deviceName, const QString &url)
{
    if (!isValidUrl(url)) return;

    ShareEntry entry;
    entry.deviceId = deviceId;
    entry.deviceName = deviceName.isEmpty() ? QStringLiteral("KDE Connect") : deviceName;
    entry.url = url;
    QUrl qurl(url);
    entry.type = (qurl.scheme() == QLatin1String("file")) ? QStringLiteral("file") : QStringLiteral("url");
    entry.timestamp = QDateTime::currentMSecsSinceEpoch();

    m_shares.prepend(entry);
    if (m_shares.size() > 10) {
        m_shares.removeLast();
    }

    Q_EMIT shareReceived(entry.deviceId, entry.deviceName, entry.url);
    Q_EMIT recentSharesChanged();
}

void KdeConnectShareMonitor::cleanExpiredShares()
{
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    qint64 expireMs = 15 * 60 * 1000; // 15 minutes timeout

    bool changed = false;
    for (int i = m_shares.size() - 1; i >= 0; --i) {
        if ((now - m_shares[i].timestamp) > expireMs) {
            m_shares.removeAt(i);
            changed = true;
        }
    }

    if (changed) {
        Q_EMIT recentSharesChanged();
    }
}

QVariantList KdeConnectShareMonitor::recentShares() const
{
    QVariantList list;
    for (const auto &entry : m_shares) {
        QVariantMap map;
        map[QStringLiteral("deviceId")] = entry.deviceId;
        map[QStringLiteral("deviceName")] = entry.deviceName;
        map[QStringLiteral("url")] = entry.url;
        map[QStringLiteral("type")] = entry.type;
        map[QStringLiteral("timestamp")] = entry.timestamp;
        list.append(map);
    }
    return list;
}

QVariantMap KdeConnectShareMonitor::getLatestShareForApp(const QString &appId, const QString &appName) const
{
    if (m_shares.isEmpty()) {
        return QVariantMap();
    }

    QString normApp = appId.toLower();
    QString normName = appName.toLower();

    bool isBrowser = (normApp.contains(QLatin1String("firefox")) || normApp.contains(QLatin1String("chrome")) ||
                      normApp.contains(QLatin1String("chromium")) || normApp.contains(QLatin1String("falkon")) ||
                      normApp.contains(QLatin1String("brave")) || normApp.contains(QLatin1String("opera")) ||
                      normApp.contains(QLatin1String("edge")) || normName.contains(QLatin1String("firefox")) ||
                      normName.contains(QLatin1String("browser")));

    for (const auto &entry : m_shares) {
        if (entry.type == QLatin1String("url") && isBrowser) {
            QVariantMap map;
            map[QStringLiteral("url")] = entry.url;
            map[QStringLiteral("deviceName")] = entry.deviceName;
            map[QStringLiteral("deviceId")] = entry.deviceId;
            map[QStringLiteral("timestamp")] = entry.timestamp;
            return map;
        }
    }

    return QVariantMap();
}

bool KdeConnectShareMonitor::openShareUrl(const QString &urlStr)
{
    if (!isValidUrl(urlStr)) return false;
    return QDesktopServices::openUrl(QUrl(urlStr));
}
