#include "launcherprogressmonitor.h"

#include "desktopidutils.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusServiceWatcher>
#include <QDBusMetaType>

#include <KService>

#include <algorithm>
#include <cmath>

namespace
{
constexpr auto s_unityService = "com.canonical.Unity";
constexpr auto s_unityPath = "/Unity";
constexpr auto s_launcherInterface = "com.canonical.Unity.LauncherEntry";
}

LauncherProgressMonitor::LauncherProgressMonitor(QObject *parent)
    : QObject(parent)
{
    qDBusRegisterMetaType<QVariantMap>();
    setupDBus();
}

LauncherProgressMonitor::~LauncherProgressMonitor()
{
    auto bus = QDBusConnection::sessionBus();
    if (m_unityServiceWatcher) {
        m_unityServiceWatcher->blockSignals(true);
    }
    if (m_registeredService) {
        bus.unregisterService(QString::fromLatin1(s_unityService));
    }
    if (m_registeredObject) {
        bus.unregisterObject(QString::fromLatin1(s_unityPath));
    }
}

QString LauncherProgressMonitor::normalizeDesktopId(const QString &rawId)
{
    return DesktopIdUtils::normalize(rawId);
}

void LauncherProgressMonitor::setupDBus()
{
    auto bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        return;
    }

    const bool connected = bus.connect({},
                                       {},
                                       QString::fromLatin1(s_launcherInterface),
                                       QStringLiteral("Update"),
                                       this,
                                       SLOT(update(QString,QVariantMap)));
    if (!connected) {
        return;
    }

    m_unityServiceWatcher = new QDBusServiceWatcher(QString::fromLatin1(s_unityService),
                                                     bus,
                                                     QDBusServiceWatcher::WatchForUnregistration,
                                                     this);
    connect(m_unityServiceWatcher,
            &QDBusServiceWatcher::serviceUnregistered,
            this,
            [this](const QString &) {
                m_registeredService = false;
                tryClaimUnityEndpoint();
            });

    m_publisherWatcher = new QDBusServiceWatcher(this);
    m_publisherWatcher->setConnection(bus);
    m_publisherWatcher->setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
    connect(m_publisherWatcher,
            &QDBusServiceWatcher::serviceUnregistered,
            this,
            &LauncherProgressMonitor::onPublisherUnregistered);

    tryClaimUnityEndpoint();
}

void LauncherProgressMonitor::tryClaimUnityEndpoint()
{
    if (m_registeredService) {
        return;
    }

    auto bus = QDBusConnection::sessionBus();
    if (!bus.isConnected() || !bus.interface()) {
        return;
    }
    if (bus.interface()->isServiceRegistered(QString::fromLatin1(s_unityService))) {
        return;
    }

    if (!m_registeredObject) {
        m_registeredObject = bus.registerObject(QString::fromLatin1(s_unityPath), this);
    }
    if (!m_registeredObject) {
        return;
    }

    m_registeredService = bus.registerService(QString::fromLatin1(s_unityService));
    if (!m_registeredService) {
        bus.unregisterObject(QString::fromLatin1(s_unityPath));
        m_registeredObject = false;
    }
}

void LauncherProgressMonitor::associatePublisher(const QString &publisher,
                                                 const QString &desktopId)
{
    if (publisher.isEmpty()) {
        return;
    }

    auto entry = m_entries.find(desktopId);
    if (entry != m_entries.end() && !entry->publisher.isEmpty()
            && entry->publisher != publisher) {
        auto previous = m_publisherEntries.find(entry->publisher);
        if (previous != m_publisherEntries.end()) {
            previous->remove(desktopId);
            if (previous->isEmpty()) {
                m_publisherWatcher->removeWatchedService(entry->publisher);
                m_publisherEntries.erase(previous);
            }
        }
    }

    const bool newPublisher = !m_publisherEntries.contains(publisher);
    m_publisherEntries[publisher].insert(desktopId);
    if (newPublisher) {
        m_publisherWatcher->addWatchedService(publisher);
        auto *interface = QDBusConnection::sessionBus().interface();
        if (interface && !interface->isServiceRegistered(publisher)) {
            // Very short-lived publishers can disappear while their final
            // signal is still queued for delivery.
            QMetaObject::invokeMethod(
                this,
                [this, publisher] {
                    onPublisherUnregistered(publisher);
                },
                Qt::QueuedConnection);
        }
    }
    m_entries[desktopId].publisher = publisher;
}

void LauncherProgressMonitor::update(const QString &appUri,
                                     const QVariantMap &properties)
{
    QString desktopId = normalizeDesktopId(appUri);
    if (desktopId.isEmpty()) {
        return;
    }

    // Resolve aliases to the storage ID TaskManager uses whenever possible.
    QString serviceId = appUri;
    if (serviceId.startsWith(QLatin1String("application://"))) {
        serviceId.remove(0, 14);
    }
    if (const KService::Ptr service = KService::serviceByStorageId(serviceId)) {
        desktopId = normalizeDesktopId(service->storageId());
    }

    const bool hasProgress = properties.contains(QStringLiteral("progress"));
    const bool hasVisibility = properties.contains(QStringLiteral("progress-visible"))
        || properties.contains(QStringLiteral("progress_visible"));
    if (!hasProgress && !hasVisibility) {
        return;
    }

    Entry &entry = m_entries[desktopId];
    const double oldProgress = entry.progress;
    const bool oldVisible = entry.visible;

    if (hasProgress) {
        bool ok = false;
        double progress = properties.value(QStringLiteral("progress")).toDouble(&ok);
        if (!ok || !std::isfinite(progress)) {
            progress = 0.0;
        } else if (progress > 1.0 && progress <= 100.0) {
            // A few Unity API clients publish percentages despite the 0..1 spec.
            progress /= 100.0;
        }
        progress = std::clamp(progress, 0.0, 1.0);
        entry.progress = std::round(progress * 1000.0) / 1000.0;
    }

    if (properties.contains(QStringLiteral("progress-visible"))) {
        entry.visible = properties.value(QStringLiteral("progress-visible")).toBool();
    } else if (properties.contains(QStringLiteral("progress_visible"))) {
        entry.visible = properties.value(QStringLiteral("progress_visible")).toBool();
    }

    if (calledFromDBus()) {
        associatePublisher(message().service(), desktopId);
    }

    if (!qFuzzyCompare(oldProgress + 1.0, entry.progress + 1.0)
            || oldVisible != entry.visible) {
        Q_EMIT progressUpdated(desktopId, entry.progress, entry.visible);
    }
}

void LauncherProgressMonitor::onPublisherUnregistered(const QString &service)
{
    m_publisherWatcher->removeWatchedService(service);
    const QSet<QString> desktopIds = m_publisherEntries.take(service);
    for (const QString &desktopId : desktopIds) {
        auto entry = m_entries.find(desktopId);
        if (entry == m_entries.end() || entry->publisher != service) {
            continue;
        }
        const double progress = entry->progress;
        m_entries.erase(entry);
        Q_EMIT progressUpdated(desktopId, progress, false);
    }
}
