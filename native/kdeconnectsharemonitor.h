#ifndef KDECONNECTSHAREMONITOR_H
#define KDECONNECTSHAREMONITOR_H

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVariantList>
#include <QList>
#include <QDateTime>
#include <QTimer>
#include <QDBusConnection>
#include <QDBusServiceWatcher>
#include <QDBusPendingCallWatcher>

#include <QDBusContext>

struct ShareEntry {
    QString deviceId;
    QString deviceName;
    QString url;
    QString type; // "url" or "file"
    qint64 timestamp;
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

    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool enabled);

    bool isActive() const { return m_active; }
    QVariantList recentShares() const;

    Q_INVOKABLE QVariantMap getLatestShareForApp(const QString &appId, const QString &appName) const;
    Q_INVOKABLE bool openShareUrl(const QString &urlStr);

Q_SIGNALS:
    void enabledChanged();
    void activeChanged();
    void recentSharesChanged();
    void shareReceived(const QString &deviceId, const QString &deviceName, const QString &url);

private Q_SLOTS:
    void onServiceRegistered(const QString &service);
    void onServiceUnregistered(const QString &service);
    void refreshDevices();
    void onDeviceAdded(const QString &deviceId);
    void onDeviceRemoved(const QString &deviceId);
    void onDeviceVisibilityChanged(const QString &deviceId, bool isVisible);
    void onShareReceived(const QString &url);
    void cleanExpiredShares();

private:
    void setupDBusWatcher();
    void setupDeviceSignals(const QString &deviceId);
    void checkDeviceDetails(const QString &deviceId);
    void addShareEntry(const QString &deviceId, const QString &deviceName, const QString &url);
    static bool isValidUrl(const QString &urlStr);

    bool m_enabled = true;
    bool m_active = false;
    QDBusServiceWatcher *m_serviceWatcher = nullptr;
    QHash<QString, QString> m_deviceNames; // deviceId -> deviceName
    QList<ShareEntry> m_shares;
    QTimer *m_expirationTimer = nullptr;
};

#endif // KDECONNECTSHAREMONITOR_H
