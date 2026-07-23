#ifndef LAUNCHERPROGRESSMONITOR_H
#define LAUNCHERPROGRESSMONITOR_H

#include <QObject>
#include <QVariantMap>
#include <QString>
#include <QHash>
#include <QDBusConnection>
#include <QDBusServiceWatcher>

class LauncherProgressMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active READ isActive NOTIFY activeChanged)

public:
    explicit LauncherProgressMonitor(QObject *parent = nullptr);
    ~LauncherProgressMonitor() override;

    bool isActive() const { return m_active; }

    static QString normalizeDesktopId(const QString &rawId);

public Q_SLOTS:
    void Update(const QString &appUri, const QVariantMap &properties);

Q_SIGNALS:
    void activeChanged();
    void progressUpdated(const QString &desktopId, double progress, bool visible);

private:
    void tryRegisterService();
    void setupDBus();

    bool m_active = false;
    bool m_registeredService = false;
    QDBusServiceWatcher *m_serviceWatcher = nullptr;
    QHash<QString, double> m_progressMap;
    QHash<QString, bool> m_visibleMap;
};

#endif // LAUNCHERPROGRESSMONITOR_H
