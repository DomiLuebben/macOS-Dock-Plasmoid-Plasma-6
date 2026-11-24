#include "launchermonitor.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QSet>
#include <QStandardPaths>
#include <QUrl>

#include <KService>
#include <KSycoca>

namespace
{
constexpr int kDefaultDebounceMs = 1500;
constexpr int kMaxLockWaitRetries = 20;

QString stripQueryAndFragment(const QString &url)
{
    QString cleaned = url.trimmed();
    const qsizetype queryIndex = cleaned.indexOf(QLatin1Char('?'));
    if (queryIndex >= 0) {
        cleaned.truncate(queryIndex);
    }
    const qsizetype fragmentIndex = cleaned.indexOf(QLatin1Char('#'));
    if (fragmentIndex >= 0) {
        cleaned.truncate(fragmentIndex);
    }
    return cleaned.trimmed();
}

QString unquoteDesktopValue(const QString &value)
{
    QString trimmed = value.trimmed();
    if (trimmed.size() >= 2 && trimmed.startsWith(QLatin1Char('"')) && trimmed.endsWith(QLatin1Char('"'))) {
        trimmed = trimmed.mid(1, trimmed.size() - 2);
    }
    return trimmed;
}

bool isMountedSystemOrHomeAncestor(const QString &filePath)
{
    const QString absolutePath = QFileInfo(filePath).absoluteFilePath();
    const QString homePath = QDir::cleanPath(QDir::homePath());
    if (!homePath.isEmpty()
        && (absolutePath == homePath || absolutePath.startsWith(homePath + QLatin1Char('/')))) {
        return true;
    }

    static const QStringList systemPrefixes = {
        QStringLiteral("/usr/"),
        QStringLiteral("/opt/"),
        QStringLiteral("/var/"),
        QStringLiteral("/etc/"),
        QStringLiteral("/snap/"),
    };
    for (const QString &prefix : systemPrefixes) {
        if (absolutePath.startsWith(prefix)) {
            return true;
        }
    }
    return false;
}
} // namespace

LauncherMonitor::LauncherMonitor(QObject *parent)
    : QObject(parent)
    , m_lockFilePaths({
          QStringLiteral("/var/lib/pacman/db.lck"),
          QStringLiteral("/var/lib/dpkg/lock-frontend"),
      })
{
    m_debounceTimer.setSingleShot(true);
    m_debounceTimer.setInterval(kDefaultDebounceMs);
    connect(&m_debounceTimer, &QTimer::timeout, this, &LauncherMonitor::emitWhenSettled);

    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
        refreshWatchedDirectories();
        scheduleChangeNotification();
    });
    connect(KSycoca::self(), &KSycoca::databaseChanged, this, &LauncherMonitor::scheduleChangeNotification);

    refreshWatchedDirectories();
}

bool LauncherMonitor::enabled() const
{
    return m_enabled;
}

void LauncherMonitor::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    if (!m_enabled) {
        m_debounceTimer.stop();
        m_lockWaitCount = 0;
    } else {
        refreshWatchedDirectories();
    }
    Q_EMIT enabledChanged();
}

bool LauncherMonitor::isLauncherInstalled(const QString &launcherUrl) const
{
    const QString cleaned = stripQueryAndFragment(launcherUrl);
    if (cleaned.isEmpty()) {
        return true;
    }

    if (cleaned.startsWith(QLatin1String("preferred://"), Qt::CaseInsensitive)) {
        return true;
    }

    QString storageId;
    if (cleaned.startsWith(QLatin1String("application://"), Qt::CaseInsensitive)) {
        storageId = cleaned.mid(14);
    } else if (cleaned.startsWith(QLatin1String("applications:"), Qt::CaseInsensitive)) {
        storageId = cleaned.mid(13);
    }

    if (!storageId.isEmpty()) {
        storageId = QUrl::fromPercentEncoding(storageId.toUtf8()).trimmed();
        while (storageId.startsWith(QLatin1Char('/'))) {
            storageId.remove(0, 1);
        }
        if (storageId.isEmpty()) {
            return false;
        }
        // Runtime Wine window identifiers (application://foo.exe) are not
        // desktop files; leave them untouched unless pinned as .desktop.
        if (storageId.endsWith(QLatin1String(".exe"), Qt::CaseInsensitive)
            && !storageId.endsWith(QLatin1String(".exe.desktop"), Qt::CaseInsensitive)) {
            return true;
        }
        return isStorageIdInstalled(storageId);
    }

    QString localPath;
    if (cleaned.startsWith(QLatin1Char('/'))) {
        localPath = cleaned;
    } else {
        const QUrl url(cleaned);
        if (url.isLocalFile()) {
            localPath = url.toLocalFile();
        } else {
            return true;
        }
    }

    if (localPath.isEmpty()) {
        return true;
    }

    const QFileInfo info(localPath);
    if (info.exists()) {
        if (localPath.endsWith(QLatin1String(".desktop"), Qt::CaseInsensitive)) {
            return isDesktopEntryUsable(info.filePath());
        }
        return true;
    }

    // Keep launchers pointing to an unmounted external drive so unplugging a
    // volume never drops pinned items; only prune paths under mounted system
    // or home prefixes.
    return !isMountedSystemOrHomeAncestor(localPath);
}

QStringList LauncherMonitor::missingLaunchers(const QStringList &launcherUrls) const
{
    QStringList missing;
    for (const QString &launcherUrl : launcherUrls) {
        if (!launcherUrl.trimmed().isEmpty() && !isLauncherInstalled(launcherUrl)) {
            missing.append(launcherUrl);
        }
    }
    return missing;
}

void LauncherMonitor::setApplicationDirectories(const QStringList &directories, bool useSystemServiceLookup)
{
    m_useCustomDirectories = true;
    m_useSystemServiceLookup = useSystemServiceLookup;
    m_customDirectories = directories;
    refreshWatchedDirectories();
}

void LauncherMonitor::setLockFilePaths(const QStringList &lockFiles)
{
    m_lockFilePaths = lockFiles;
}

void LauncherMonitor::setDebounceInterval(int milliseconds)
{
    m_debounceTimer.setInterval(qMax(0, milliseconds));
}

void LauncherMonitor::setValidateTryExec(bool validate)
{
    m_validateTryExec = validate;
}

void LauncherMonitor::scheduleChangeNotification()
{
    if (!m_enabled) {
        return;
    }
    m_lockWaitCount = 0;
    m_debounceTimer.start();
}

void LauncherMonitor::emitWhenSettled()
{
    if (!m_enabled) {
        return;
    }

    refreshWatchedDirectories();

    if (isPackageManagerBusy() && m_lockWaitCount < kMaxLockWaitRetries) {
        ++m_lockWaitCount;
        m_debounceTimer.start();
        return;
    }

    m_lockWaitCount = 0;
    Q_EMIT applicationsChanged();
}

void LauncherMonitor::refreshWatchedDirectories()
{
    QSet<QString> desired;
    const QStringList baseDirs = effectiveApplicationDirectories();
    for (const QString &rawDir : baseDirs) {
        if (rawDir.isEmpty()) {
            continue;
        }
        const QString cleanDir = QDir::cleanPath(rawDir);
        const QFileInfo info(cleanDir);
        if (info.exists() && info.isDir()) {
            desired.insert(cleanDir);
            QDirIterator subDirs(cleanDir, QDir::Dirs | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
            while (subDirs.hasNext()) {
                desired.insert(QDir::cleanPath(subDirs.next()));
            }
        } else {
            // Watch the closest existing parent so creating the applications
            // directory later immediately attaches a watcher to it.
            QFileInfo parentInfo(info.dir().absolutePath());
            while (!parentInfo.filePath().isEmpty() && !parentInfo.exists()) {
                const QString nextParent = parentInfo.dir().absolutePath();
                if (nextParent == parentInfo.filePath()) {
                    break;
                }
                parentInfo = QFileInfo(nextParent);
            }
            if (parentInfo.exists() && parentInfo.isDir()) {
                desired.insert(QDir::cleanPath(parentInfo.filePath()));
            }
        }
    }

    const QStringList currentList = m_watcher.directories();
    const QSet<QString> current(currentList.cbegin(), currentList.cend());

    const QSet<QString> toRemove = current - desired;
    if (!toRemove.isEmpty()) {
        m_watcher.removePaths(QStringList(toRemove.cbegin(), toRemove.cend()));
    }

    const QSet<QString> toAdd = desired - current;
    if (!toAdd.isEmpty()) {
        m_watcher.addPaths(QStringList(toAdd.cbegin(), toAdd.cend()));
    }
}

QStringList LauncherMonitor::effectiveApplicationDirectories() const
{
    if (m_useCustomDirectories) {
        return m_customDirectories;
    }

    QStringList dirs = QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);
    const QString home = QDir::homePath();
    if (!home.isEmpty()) {
        dirs.append(home + QStringLiteral("/.local/share/applications"));
        dirs.append(home + QStringLiteral("/.local/share/flatpak/exports/share/applications"));
    }
    dirs.append(QStringLiteral("/var/lib/flatpak/exports/share/applications"));
    dirs.append(QStringLiteral("/var/lib/snapd/desktop/applications"));
    dirs.append(QStringLiteral("/usr/local/share/applications"));
    dirs.append(QStringLiteral("/usr/share/applications"));

    QSet<QString> seen;
    QStringList unique;
    for (const QString &dir : std::as_const(dirs)) {
        const QString cleaned = QDir::cleanPath(dir);
        if (!cleaned.isEmpty() && !seen.contains(cleaned)) {
            seen.insert(cleaned);
            unique.append(cleaned);
        }
    }
    return unique;
}

bool LauncherMonitor::isStorageIdInstalled(const QString &storageId) const
{
    QStringList candidates = {storageId};
    if (!storageId.endsWith(QLatin1String(".desktop"), Qt::CaseInsensitive)) {
        candidates.append(storageId + QStringLiteral(".desktop"));
    }

    const QStringList appDirs = effectiveApplicationDirectories();
    for (const QString &candidate : std::as_const(candidates)) {
        for (const QString &baseDir : appDirs) {
            const QDir dir(baseDir);
            if (!dir.exists()) {
                continue;
            }

            const QString directPath = dir.filePath(candidate);
            if (QFileInfo::exists(directPath) && QFileInfo(directPath).isFile()) {
                bool explicitlyHidden = false;
                if (isDesktopEntryUsable(directPath, &explicitlyHidden)) {
                    return true;
                }
                if (explicitlyHidden) {
                    return false;
                }
            }

            // Desktop file IDs can represent subdirectories with '-' (e.g.
            // org-example-foo.desktop -> org/example/foo.desktop) or be
            // referenced by basename.
            QDirIterator it(baseDir, QDir::Files, QDirIterator::Subdirectories);
            while (it.hasNext()) {
                const QString filePath = it.next();
                const QFileInfo fileInfo = it.fileInfo();
                QString relativeId = dir.relativeFilePath(filePath);
                relativeId.replace(QLatin1Char('/'), QLatin1Char('-'));
                if (relativeId.compare(candidate, Qt::CaseInsensitive) == 0
                    || fileInfo.fileName().compare(candidate, Qt::CaseInsensitive) == 0) {
                    bool explicitlyHidden = false;
                    if (isDesktopEntryUsable(filePath, &explicitlyHidden)) {
                        return true;
                    }
                    if (explicitlyHidden) {
                        return false;
                    }
                }
            }
        }
    }

    if (m_useSystemServiceLookup) {
        KSycoca::self()->ensureCacheValid();
        for (const QString &candidate : std::as_const(candidates)) {
            const KService::Ptr service = KService::serviceByStorageId(candidate);
            if (service && !service->entryPath().isEmpty() && QFileInfo::exists(service->entryPath())
                && isDesktopEntryUsable(service->entryPath())) {
                return true;
            }
        }
    }

    return false;
}

bool LauncherMonitor::isDesktopEntryUsable(const QString &filePath, bool *explicitlyHidden) const
{
    if (explicitlyHidden) {
        *explicitlyHidden = false;
    }

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }

    bool inDesktopEntryGroup = false;
    QString tryExecValue;

    while (!file.atEnd()) {
        const QString line = QString::fromUtf8(file.readLine()).trimmed();
        if (line.isEmpty() || line.startsWith(QLatin1Char('#'))) {
            continue;
        }
        if (line.startsWith(QLatin1Char('[')) && line.endsWith(QLatin1Char(']'))) {
            inDesktopEntryGroup = (line == QLatin1String("[Desktop Entry]"));
            continue;
        }
        if (!inDesktopEntryGroup) {
            continue;
        }

        const qsizetype equalsIndex = line.indexOf(QLatin1Char('='));
        if (equalsIndex <= 0) {
            continue;
        }
        const QString key = line.left(equalsIndex).trimmed();
        const QString value = unquoteDesktopValue(line.mid(equalsIndex + 1));

        if (key == QLatin1String("Hidden") && value.compare(QLatin1String("true"), Qt::CaseInsensitive) == 0) {
            if (explicitlyHidden) {
                *explicitlyHidden = true;
            }
            return false;
        }
        if (key == QLatin1String("TryExec")) {
            tryExecValue = value;
        }
    }

    if (m_validateTryExec && !tryExecValue.isEmpty()) {
        if (tryExecValue.contains(QLatin1Char('/'))) {
            const QFileInfo execInfo(tryExecValue);
            if (!execInfo.exists() || !execInfo.isExecutable()) {
                return false;
            }
        } else if (QStandardPaths::findExecutable(tryExecValue).isEmpty()) {
            return false;
        }
    }

    return true;
}

bool LauncherMonitor::isPackageManagerBusy() const
{
    for (const QString &lockPath : m_lockFilePaths) {
        if (!lockPath.isEmpty() && QFileInfo::exists(lockPath)) {
            return true;
        }
    }
    return false;
}
