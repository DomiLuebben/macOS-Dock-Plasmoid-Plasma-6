#include "folderwatcher.h"

#include <QDir>
#include <QFileInfo>
#include <QSet>
#include <QUrl>

namespace
{
constexpr int kDefaultFolderDebounceMs = 120;

QString existingAncestorDirectory(const QString &targetPath)
{
    QString current = QDir::cleanPath(targetPath);
    while (!current.isEmpty()) {
        const QFileInfo info(current);
        if (info.exists() && info.isDir()) {
            return info.absoluteFilePath();
        }
        const QString parent = QFileInfo(current).dir().absolutePath();
        if (parent.isEmpty() || parent == current) {
            break;
        }
        current = parent;
    }
    return {};
}
} // namespace

FolderWatcher::FolderWatcher(QObject *parent)
    : QObject(parent)
{
    m_debounceTimer.setSingleShot(true);
    m_debounceTimer.setInterval(kDefaultFolderDebounceMs);
    connect(&m_debounceTimer, &QTimer::timeout, this, &FolderWatcher::refreshState);

    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
        m_debounceTimer.start();
    });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this]() {
        m_debounceTimer.start();
    });
}

QStringList FolderWatcher::watchedUrls() const
{
    return m_watchedUrls;
}

void FolderWatcher::setWatchedUrls(const QStringList &urls)
{
    if (m_watchedUrls == urls) {
        return;
    }
    m_watchedUrls = urls;
    Q_EMIT watchedUrlsChanged();
    refreshState();
}

QStringList FolderWatcher::existingUrls() const
{
    return m_existingUrls;
}

bool FolderWatcher::directoryExists(const QString &folderUrl) const
{
    const QString trimmed = folderUrl.trimmed();
    if (trimmed.isEmpty()) {
        return false;
    }

    bool isLocal = false;
    const QString localPath = localPathForFolderUrl(trimmed, &isLocal);
    if (!isLocal) {
        // Non-local KIO schemes (e.g. smb://, sftp://) cannot be probed
        // synchronously on the GUI thread without risking network stalls.
        return true;
    }
    if (localPath.isEmpty()) {
        return false;
    }

    const QFileInfo info(localPath);
    return info.exists() && info.isDir();
}

QStringList FolderWatcher::filterExisting(const QStringList &folderUrls) const
{
    QStringList result;
    result.reserve(folderUrls.size());
    for (const QString &url : folderUrls) {
        if (directoryExists(url)) {
            result.append(url);
        }
    }
    return result;
}

void FolderWatcher::setDebounceInterval(int milliseconds)
{
    m_debounceTimer.setInterval(qMax(0, milliseconds));
}

void FolderWatcher::refreshState()
{
    updateWatchPaths();

    const QStringList nextExisting = filterExisting(m_watchedUrls);
    if (nextExisting != m_existingUrls) {
        m_existingUrls = nextExisting;
        Q_EMIT existingUrlsChanged();
    }
}

void FolderWatcher::updateWatchPaths()
{
    QSet<QString> desired;
    for (const QString &rawUrl : std::as_const(m_watchedUrls)) {
        bool isLocal = false;
        const QString localPath = localPathForFolderUrl(rawUrl, &isLocal);
        if (!isLocal || localPath.isEmpty()) {
            continue;
        }

        const QString cleanTarget = QDir::cleanPath(QFileInfo(localPath).absoluteFilePath());
        const QFileInfo targetInfo(cleanTarget);
        if (targetInfo.exists() && targetInfo.isDir()) {
            desired.insert(cleanTarget);
            const QString parentPath = QDir::cleanPath(targetInfo.dir().absolutePath());
            if (!parentPath.isEmpty() && QFileInfo(parentPath).isDir()) {
                desired.insert(parentPath);
            }
        } else {
            const QString ancestor = existingAncestorDirectory(cleanTarget);
            if (!ancestor.isEmpty()) {
                desired.insert(QDir::cleanPath(ancestor));
            }
        }
    }

    const QStringList currentDirs = m_watcher.directories();
    const QSet<QString> current(currentDirs.cbegin(), currentDirs.cend());

    const QSet<QString> toRemove = current - desired;
    if (!toRemove.isEmpty()) {
        m_watcher.removePaths(QStringList(toRemove.cbegin(), toRemove.cend()));
    }

    const QSet<QString> toAdd = desired - current;
    if (!toAdd.isEmpty()) {
        m_watcher.addPaths(QStringList(toAdd.cbegin(), toAdd.cend()));
    }
}

QString FolderWatcher::localPathForFolderUrl(const QString &folderUrl, bool *isLocalOut)
{
    const QString trimmed = folderUrl.trimmed();
    if (trimmed.startsWith(QLatin1Char('/'))) {
        if (isLocalOut) {
            *isLocalOut = true;
        }
        return trimmed;
    }

    const QUrl url(trimmed);
    if (url.isLocalFile()) {
        if (isLocalOut) {
            *isLocalOut = true;
        }
        return url.toLocalFile();
    }
    if (url.scheme().isEmpty() && !trimmed.isEmpty()) {
        if (isLocalOut) {
            *isLocalOut = true;
        }
        return trimmed;
    }

    if (isLocalOut) {
        *isLocalOut = false;
    }
    return {};
}
