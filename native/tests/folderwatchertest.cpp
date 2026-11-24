#include "folderwatcher.h"

#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>

class FolderWatcherTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void filtersMissingLocalDirectories()
    {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());

        const QString existingDir = tempDir.filePath(QStringLiteral("Downloads"));
        QVERIFY(QDir().mkpath(existingDir));

        const QString existingFile = tempDir.filePath(QStringLiteral("not-a-dir.txt"));
        QFile file(existingFile);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.close();

        const QString existingUrl = QUrl::fromLocalFile(existingDir).toString();
        const QString missingUrl = QStringLiteral("file:///OneTouch/Nextcloud");
        const QString fileUrl = QUrl::fromLocalFile(existingFile).toString();
        const QString remoteUrl = QStringLiteral("smb://nas.local/share");

        FolderWatcher watcher;
        watcher.setWatchedUrls({existingUrl, missingUrl, fileUrl, remoteUrl});

        QCOMPARE(watcher.existingUrls(), (QStringList{existingUrl, remoteUrl}));
        QVERIFY(watcher.directoryExists(existingUrl));
        QVERIFY(!watcher.directoryExists(missingUrl));
        QVERIFY(!watcher.directoryExists(fileUrl));
        QVERIFY(watcher.directoryExists(remoteUrl));
    }

    void reactsLiveToDirectoryCreationAndDeletion()
    {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());

        const QString targetDir = tempDir.filePath(QStringLiteral("OneTouch/Nextcloud"));
        const QString targetUrl = QUrl::fromLocalFile(targetDir).toString();

        FolderWatcher watcher;
        watcher.setDebounceInterval(15);
        QSignalSpy existingSpy(&watcher, &FolderWatcher::existingUrlsChanged);

        watcher.setWatchedUrls({targetUrl});
        QVERIFY(watcher.existingUrls().isEmpty());

        // Creating the intermediate and final directory must make it appear automatically.
        QVERIFY(QDir().mkpath(tempDir.filePath(QStringLiteral("OneTouch"))));
        QTest::qWait(40);
        QVERIFY(QDir().mkpath(targetDir));

        QTRY_COMPARE_WITH_TIMEOUT(watcher.existingUrls(), QStringList{targetUrl}, 2000);
        QVERIFY(existingSpy.count() >= 1);

        // Removing the directory must hide it again automatically.
        existingSpy.clear();
        QVERIFY(QDir().rmdir(targetDir));

        QTRY_VERIFY_WITH_TIMEOUT(watcher.existingUrls().isEmpty(), 2000);
        QVERIFY(existingSpy.count() >= 1);
    }
};

QTEST_MAIN(FolderWatcherTest)
#include "folderwatchertest.moc"
