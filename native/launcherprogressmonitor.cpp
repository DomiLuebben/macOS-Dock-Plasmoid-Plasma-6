#include "launcherprogressmonitor.h"

#include <QDBusConnectionInterface>
#include <QDBusMetaType>
#include <QDebug>

LauncherProgressMonitor::LauncherProgressMonitor(QObject *parent)
    : QObject(parent)
{
    qDBusRegisterMetaType<QVariantMap>();
    setupDBus();
}

LauncherProgressMonitor::~LauncherProgressMonitor()
{
    if (m_registeredService) {
        QDBusConnection::sessionBus().unregisterService(QStringLiteral("com.canonical.Unity"));
    }
}

QString LauncherProgressMonitor::normalizeDesktopId(const QString &rawId)
{
    QString id = rawId.trimmed();
    if (id.startsWith(QLatin1String("application://"))) {
        id.remove(0, 14);
    } else if (id.startsWith(QLatin1String("applications:"))) {
        id.remove(0, 13);
    }
    int queryIndex = id.indexOf(QLatin1Char('?'));
    if (queryIndex != -1) {
        id = id.left(queryIndex);
    }
    if (id.endsWith(QLatin1String(".desktop"), Qt::CaseInsensitive)) {
        id.chop(8);
    }
    return id.toLower();
}

void LauncherProgressMonitor::setupDBus()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        return;
    }

    tryRegisterService();

    bus.connect(QString(), QString(), QStringLiteral("com.canonical.Unity.LauncherEntry"),
                QStringLiteral("Update"), this, SLOT(Update(QString,QVariantMap)));

    bus.registerObject(QStringLiteral("/com/canonical/unity/launcherentry"), this, QDBusConnection::ExportAllSlots);
    bus.registerObject(QStringLiteral("/com/canonical/Unity/LauncherEntry"), this, QDBusConnection::ExportAllSlots);

    m_serviceWatcher = new QDBusServiceWatcher(QStringLiteral("com.canonical.Unity"), bus,
                                                 QDBusServiceWatcher::WatchForUnregistration, this);
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceUnregistered, this, [this](const QString &service) {
        Q_UNUSED(service);
        tryRegisterService();
    });

    m_active = true;
    Q_EMIT activeChanged();
}

void LauncherProgressMonitor::tryRegisterService()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        return;
    }
    if (!bus.interface()->isServiceRegistered(QStringLiteral("com.canonical.Unity"))) {
        if (bus.registerService(QStringLiteral("com.canonical.Unity"))) {
            m_registeredService = true;
        }
    }
}

void LauncherProgressMonitor::Update(const QString &appUri, const QVariantMap &properties)
{
    QString normalizedId = normalizeDesktopId(appUri);
    if (normalizedId.isEmpty()) {
        return;
    }

    bool visible = false;
    if (properties.contains(QStringLiteral("progress-visible"))) {
        visible = properties.value(QStringLiteral("progress-visible")).toBool();
    } else if (properties.contains(QStringLiteral("progress_visible"))) {
        visible = properties.value(QStringLiteral("progress_visible")).toBool();
    }

    double progress = 0.0;
    if (properties.contains(QStringLiteral("progress"))) {
        bool ok = false;
        double val = properties.value(QStringLiteral("progress")).toDouble(&ok);
        if (ok) {
            if (val > 1.0) {
                progress = val / 100.0;
            } else {
                progress = val;
            }
        }
    }

    if (progress < 0.0) progress = 0.0;
    if (progress > 1.0) progress = 1.0;

    m_progressMap[normalizedId] = progress;
    m_visibleMap[normalizedId] = visible;

    Q_EMIT progressUpdated(normalizedId, progress, visible);
}
