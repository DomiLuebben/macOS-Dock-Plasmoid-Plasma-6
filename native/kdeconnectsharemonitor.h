#pragma once

#include <QDBusContext>
#include <QHash>
#include <QList>
#include <QMap>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

class QDBusServiceWatcher;
class QTimer;

struct ShareEntry {
    QString deviceId;
    QString deviceName;
    QUrl url;
    QString preview;
    QStringList targetDesktopIds;
    qint64 timestamp = 0;
    bool isFile = false;
};

class KdeConnectShareMonitor : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool active READ isActive NOTIFY activeChanged)
    Q_PROPERTY(QVariantList recentShares READ recentShares NOTIFY recentSharesChanged)

public:
    explicit KdeConnectShareMonitor(QObject *parent = nullptr);
    ~KdeConnectShareMonitor() override;

    bool isEnabled() const;
    void setEnabled(bool enabled);

    bool isActive() const;
    QVariantList recentShares() const;

    Q_INVOKABLE QVariantMap getLatestShareForApp(const QString &appId,
                                                 const QString &launcherUrl) const;
    Q_INVOKABLE QVariantMap getLatestShareForFolder(const QUrl &folderUrl) const;
    Q_INVOKABLE bool openShareUrl(const QString &urlString) const;

Q_SIGNALS:
    void enabledChanged();
    void activeChanged();
    void recentSharesChanged();

private Q_SLOTS:
    void onServiceRegistered(const QString &service);
    void onServiceUnregistered(const QString &service);
    void refreshDevices();
    void onDeviceAdded(const QString &deviceId);
    void onDeviceRemoved(const QString &deviceId);
    void onDeviceVisibilityChanged(const QString &deviceId, bool visible);
    void onShareReceived(const QString &url);
    void cleanExpiredShares();

private:
    void setupDBusWatcher();
    bool connectDaemonSignals();
    void disconnectDaemonSignals();
    void connectDevice(const QString &deviceId);
    void disconnectDevice(const QString &deviceId);
    void disconnectAllDevices();
    void scheduleDeviceRefresh();
    void addShareEntry(const QString &deviceId, const QUrl &url);
    void clearRecentShares();
    void setActive(bool active);

    static QString devicePath(const QString &deviceId);
    static bool isValidShareUrl(const QUrl &url);
    static QString previewForUrl(const QUrl &url);
    static QVariantMap entryToVariantMap(const ShareEntry &entry);
    static QStringList preferredBrowserDesktopIds();

    bool m_enabled = false;
    bool m_active = false;
    bool m_daemonSignalsConnected = false;
    quint64 m_generation = 0;
    QDBusServiceWatcher *m_serviceWatcher = nullptr;
    QTimer *m_refreshTimer = nullptr;
    QTimer *m_expirationTimer = nullptr;
    QHash<QString, QString> m_deviceNames;
    QSet<QString> m_connectedDevices;
    QList<ShareEntry> m_shares;
};
