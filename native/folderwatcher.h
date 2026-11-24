#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>

// Tracks a list of configured Dock folder URLs and reports which ones currently
// exist as directories on disk.
//
// Missing local paths watch their closest existing ancestor directory (e.g. "/"
// for "/OneTouch/Nextcloud" or "/home/user" for "/home/user/Temp") so creating
// or mounting the folder makes it appear in the Dock without polling, and
// deleting or unmounting an existing folder hides it immediately.
class FolderWatcher : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList watchedUrls READ watchedUrls WRITE setWatchedUrls NOTIFY watchedUrlsChanged)
    Q_PROPERTY(QStringList existingUrls READ existingUrls NOTIFY existingUrlsChanged)

public:
    explicit FolderWatcher(QObject *parent = nullptr);

    QStringList watchedUrls() const;
    void setWatchedUrls(const QStringList &urls);

    QStringList existingUrls() const;

    Q_INVOKABLE bool directoryExists(const QString &folderUrl) const;
    Q_INVOKABLE QStringList filterExisting(const QStringList &folderUrls) const;

    // Test hook to shorten debounce timing in unit tests.
    void setDebounceInterval(int milliseconds);

Q_SIGNALS:
    void watchedUrlsChanged();
    void existingUrlsChanged();

private:
    void refreshState();
    void updateWatchPaths();
    static QString localPathForFolderUrl(const QString &folderUrl, bool *isLocalOut = nullptr);

    QStringList m_watchedUrls;
    QStringList m_existingUrls;
    QFileSystemWatcher m_watcher;
    QTimer m_debounceTimer;
};
