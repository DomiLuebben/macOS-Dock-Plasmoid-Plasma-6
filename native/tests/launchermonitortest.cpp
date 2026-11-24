#include "launchermonitor.h"

#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

namespace
{
void writeDesktopFile(const QString &filePath, const QByteArray &extraLines = {})
{
    QDir().mkpath(QFileInfo(filePath).absolutePath());
    QFile file(filePath);
    QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
    file.write("[Desktop Entry]\nType=Application\nName=Test App\nExec=sh\n");
    if (!extraLines.isEmpty()) {
        file.write(extraLines);
    }
    file.close();
}
} // namespace

class LauncherMonitorTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void detectsPresentAndMissingApplicationLaunchers()
    {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());
        const QString appsDir = tempDir.filePath(QStringLiteral("applications"));
        writeDesktopFile(appsDir + QStringLiteral("/org.kde.konsole.desktop"));
        writeDesktopFile(appsDir + QStringLiteral("/nested/org.example.SubApp.desktop"));

        LauncherMonitor monitor;
        monitor.setApplicationDirectories({appsDir}, false);
        monitor.setValidateTryExec(false);

        QVERIFY(monitor.isLauncherInstalled(QStringLiteral("applications:org.kde.konsole.desktop")));
        QVERIFY(monitor.isLauncherInstalled(QStringLiteral("applications:org.kde.konsole.desktop?iconData=foo")));
        QVERIFY(monitor.isLauncherInstalled(QStringLiteral("application://org.kde.konsole.desktop")));
        QVERIFY(monitor.isLauncherInstalled(QStringLiteral("applications:nested-org.example.SubApp.desktop")));
        QVERIFY(monitor.isLauncherInstalled(QStringLiteral("applications:org.example.SubApp.desktop")));
        QVERIFY(!monitor.isLauncherInstalled(QStringLiteral("applications:org.linuxuniversalappcenter.desktop")));

        const QStringList missing = monitor.missingLaunchers({
            QStringLiteral("preferred://browser"),
            QStringLiteral("preferred://filemanager"),
            QStringLiteral("applications:org.kde.konsole.desktop"),
            QStringLiteral("applications:org.linuxuniversalappcenter.desktop"),
        });
        QCOMPARE(missing, QStringList{QStringLiteral("applications:org.linuxuniversalappcenter.desktop")});
    }

    void keepsSpecialLaunchersAndUnmountedExternalPaths()
    {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());

        LauncherMonitor monitor;
        monitor.setApplicationDirectories({tempDir.path()}, false);

        QVERIFY(monitor.isLauncherInstalled(QStringLiteral("preferred://browser")));
        QVERIFY(monitor.isLauncherInstalled(QStringLiteral("preferred://filemanager")));
        QVERIFY(monitor.isLauncherInstalled(QStringLiteral("application://affinity.exe")));
        QVERIFY(monitor.isLauncherInstalled(QStringLiteral("file:///OneTouch/NonMountedVolume/App.desktop")));
    }

    void treatsHiddenOrBrokenTryExecDesktopOverrideAsUninstalled()
    {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());
        const QString userApps = tempDir.filePath(QStringLiteral("user-apps"));
        const QString sysApps = tempDir.filePath(QStringLiteral("sys-apps"));

        writeDesktopFile(userApps + QStringLiteral("/hidden.desktop"), "Hidden=true\n");
        writeDesktopFile(sysApps + QStringLiteral("/hidden.desktop"));

        writeDesktopFile(userApps + QStringLiteral("/stale-wrapper.desktop"),
                         "TryExec=/nonexistent/macosdock-missing-binary\n");

        LauncherMonitor monitor;
        monitor.setApplicationDirectories({userApps, sysApps}, false);
        monitor.setValidateTryExec(true);

        QVERIFY(!monitor.isLauncherInstalled(QStringLiteral("applications:hidden.desktop")));
        QVERIFY(!monitor.isLauncherInstalled(QStringLiteral("applications:stale-wrapper.desktop")));
    }

    void emitsChangeAfterUninstallOnceLockClears()
    {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());
        const QString appsDir = tempDir.filePath(QStringLiteral("applications"));
        const QString lockPath = tempDir.filePath(QStringLiteral("db.lck"));
        const QString appFile = appsDir + QStringLiteral("/org.example.Removable.desktop");
        writeDesktopFile(appFile);

        QFile lockFile(lockPath);
        QVERIFY(lockFile.open(QIODevice::WriteOnly));
        lockFile.close();

        LauncherMonitor monitor;
        monitor.setDebounceInterval(30);
        monitor.setLockFilePaths({lockPath});
        monitor.setApplicationDirectories({appsDir}, false);

        QSignalSpy changedSpy(&monitor, &LauncherMonitor::applicationsChanged);
        QVERIFY(monitor.isLauncherInstalled(QStringLiteral("applications:org.example.Removable.desktop")));

        QVERIFY(QFile::remove(appFile));
        QTest::qWait(50);
        // Lock is still held: must not emit prematurely during a transaction.
        QCOMPARE(changedSpy.count(), 0);

        QVERIFY(QFile::remove(lockPath));
        QTRY_VERIFY_WITH_TIMEOUT(changedSpy.count() >= 1, 1000);
        QVERIFY(!monitor.isLauncherInstalled(QStringLiteral("applications:org.example.Removable.desktop")));
    }
};

QTEST_MAIN(LauncherMonitorTest)
#include "launchermonitortest.moc"
