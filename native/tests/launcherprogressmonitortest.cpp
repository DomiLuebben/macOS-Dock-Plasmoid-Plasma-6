#include "launcherprogressmonitor.h"

#include <QSignalSpy>
#include <QTest>
#include <QVariantMap>

// The monitor's `update` slot is what the Unity LauncherEntry signal calls.
// Driving it directly keeps the test independent of the session bus.
class LauncherProgressMonitorTest : public QObject
{
    Q_OBJECT

private:
    static void publish(LauncherProgressMonitor &monitor,
                        const QString &appUri,
                        const QVariantMap &properties)
    {
        QVERIFY(QMetaObject::invokeMethod(&monitor, "update",
                                          Q_ARG(QString, appUri),
                                          Q_ARG(QVariantMap, properties)));
    }

private Q_SLOTS:
    void reportsVisibleCount()
    {
        LauncherProgressMonitor monitor;
        QSignalSpy counts(&monitor, &LauncherProgressMonitor::countUpdated);
        QSignalSpy progress(&monitor, &LauncherProgressMonitor::progressUpdated);

        publish(monitor, QStringLiteral("application://org.example.chat.desktop"),
                {{QStringLiteral("count"), qlonglong(3)},
                 {QStringLiteral("count-visible"), true}});

        QCOMPARE(counts.count(), 1);
        const QList<QVariant> args = counts.takeFirst();
        QCOMPARE(args.at(0).toString(), QStringLiteral("org.example.chat"));
        QCOMPARE(args.at(1).toLongLong(), qlonglong(3));
        QVERIFY(args.at(2).toBool());
        QCOMPARE(progress.count(), 0);
    }

    void clearsWhenCountBecomesHidden()
    {
        LauncherProgressMonitor monitor;
        QSignalSpy counts(&monitor, &LauncherProgressMonitor::countUpdated);
        const QString app = QStringLiteral("application://org.example.chat.desktop");

        publish(monitor, app, {{QStringLiteral("count"), qlonglong(5)},
                               {QStringLiteral("count-visible"), true}});
        publish(monitor, app, {{QStringLiteral("count-visible"), false}});

        QCOMPARE(counts.count(), 2);
        QVERIFY(!counts.at(1).at(2).toBool());
    }

    void ignoresUnchangedCountAndNegativeValues()
    {
        LauncherProgressMonitor monitor;
        QSignalSpy counts(&monitor, &LauncherProgressMonitor::countUpdated);
        const QString app = QStringLiteral("application://org.example.chat.desktop");

        publish(monitor, app, {{QStringLiteral("count"), qlonglong(2)},
                               {QStringLiteral("count-visible"), true}});
        publish(monitor, app, {{QStringLiteral("count"), qlonglong(2)},
                               {QStringLiteral("count-visible"), true}});
        QCOMPARE(counts.count(), 1);

        publish(monitor, app, {{QStringLiteral("count"), qlonglong(-7)}});
        QCOMPARE(counts.count(), 2);
        QCOMPARE(counts.at(1).at(1).toLongLong(), qlonglong(0));
    }

    void progressStillWorksAlongsideCounts()
    {
        LauncherProgressMonitor monitor;
        QSignalSpy counts(&monitor, &LauncherProgressMonitor::countUpdated);
        QSignalSpy progress(&monitor, &LauncherProgressMonitor::progressUpdated);

        publish(monitor, QStringLiteral("application://org.example.dl.desktop"),
                {{QStringLiteral("progress"), 0.5},
                 {QStringLiteral("progress-visible"), true}});

        QCOMPARE(progress.count(), 1);
        QCOMPARE(counts.count(), 0);
    }

    void ignoresUpdatesWithoutAnyKnownProperty()
    {
        LauncherProgressMonitor monitor;
        QSignalSpy counts(&monitor, &LauncherProgressMonitor::countUpdated);
        QSignalSpy progress(&monitor, &LauncherProgressMonitor::progressUpdated);

        publish(monitor, QStringLiteral("application://org.example.chat.desktop"),
                {{QStringLiteral("urgent"), true}});

        QCOMPARE(counts.count(), 0);
        QCOMPARE(progress.count(), 0);
    }
};

QTEST_MAIN(LauncherProgressMonitorTest)
#include "launcherprogressmonitortest.moc"
