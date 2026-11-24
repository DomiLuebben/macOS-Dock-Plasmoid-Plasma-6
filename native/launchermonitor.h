#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>

// Watches the system and user application directories and KSycoca so the Dock
// can drop launchers whose .desktop files were removed by package uninstalls.
//
// Directory bursts during package upgrades are debounced, and active package
// manager lock files defer the notification until the transaction finishes so a
// package replacement never briefly unpins an application.
class LauncherMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit LauncherMonitor(QObject *parent = nullptr);

    bool enabled() const;
    void setEnabled(bool enabled);

    Q_INVOKABLE bool isLauncherInstalled(const QString &launcherUrl) const;
    Q_INVOKABLE QStringList missingLaunchers(const QStringList &launcherUrls) const;

    // Test hooks so unit tests run against isolated temporary directories
    // without touching host application databases or package locks.
    void setApplicationDirectories(const QStringList &directories, bool useSystemServiceLookup = false);
    void setLockFilePaths(const QStringList &lockFiles);
    void setDebounceInterval(int milliseconds);
    void setValidateTryExec(bool validate);

Q_SIGNALS:
    void enabledChanged();
    void applicationsChanged();

private:
    void scheduleChangeNotification();
    void emitWhenSettled();
    void refreshWatchedDirectories();
    QStringList effectiveApplicationDirectories() const;
    bool isStorageIdInstalled(const QString &storageId) const;
    bool isDesktopEntryUsable(const QString &filePath, bool *explicitlyHidden = nullptr) const;
    bool isPackageManagerBusy() const;

    bool m_enabled = true;
    bool m_useCustomDirectories = false;
    bool m_useSystemServiceLookup = true;
    bool m_validateTryExec = true;
    int m_lockWaitCount = 0;
    QStringList m_customDirectories;
    QStringList m_lockFilePaths;
    QFileSystemWatcher m_watcher;
    QTimer m_debounceTimer;
};
