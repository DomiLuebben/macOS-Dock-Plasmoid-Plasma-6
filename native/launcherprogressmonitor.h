#pragma once

#include <QDBusContext>
#include <QHash>
#include <QObject>
#include <QSet>
#include <QVariantMap>

class QDBusServiceWatcher;

class LauncherProgressMonitor : public QObject, protected QDBusContext
{
    Q_OBJECT

public:
    explicit LauncherProgressMonitor(QObject *parent = nullptr);
    ~LauncherProgressMonitor() override;

    static QString normalizeDesktopId(const QString &rawId);

Q_SIGNALS:
    void progressUpdated(const QString &desktopId, double progress, bool visible);
    // Unity "count"/"count-visible": the unread number an application publishes
    // for its launcher (chat and mail clients). Hidden counts are reported with
    // visible == false so QML can drop the badge.
    void countUpdated(const QString &desktopId, qlonglong count, bool visible);

private Q_SLOTS:
    void update(const QString &appUri, const QVariantMap &properties);
    void onPublisherUnregistered(const QString &service);

private:
    struct Entry {
        double progress = 0.0;
        bool visible = false;
        qlonglong count = 0;
        bool countVisible = false;
        QString publisher;
    };

    void setupDBus();
    void tryClaimUnityEndpoint();
    void associatePublisher(const QString &publisher, const QString &desktopId);

    bool m_registeredObject = false;
    bool m_registeredService = false;
    QDBusServiceWatcher *m_unityServiceWatcher = nullptr;
    QDBusServiceWatcher *m_publisherWatcher = nullptr;
    QHash<QString, Entry> m_entries;
    QHash<QString, QSet<QString>> m_publisherEntries;
};
