#include "removablevolumesmodel.h"

#include <Solid/Device>
#include <Solid/StorageAccess>

#include <QSignalSpy>
#include <QTest>

class RemovableVolumesModelTest : public QObject
{
    Q_OBJECT

private:
    static int rowForUdi(const RemovableVolumesModel &model, const QString &udi)
    {
        for (int row = 0; row < model.rowCount(); ++row) {
            if (model.data(model.index(row, 0), RemovableVolumesModel::UdiRole).toString() == udi) {
                return row;
            }
        }
        return -1;
    }

private slots:
    void initTestCase()
    {
        qputenv("SOLID_FAKEHW", QByteArrayLiteral(TEST_DATA));
    }

    void tracksMountedAndLaterMountedVolumes()
    {
        const QString mountedUdi = QStringLiteral("/org/kde/solid/fakehw/mounted-volume");
        const QString laterMountedUdi =
            QStringLiteral("/org/kde/solid/fakehw/later-mounted-volume");
        const QString ignoredUdi = QStringLiteral("/org/kde/solid/fakehw/ignored-volume");
        const QString loopUdi = QStringLiteral("/org/kde/solid/fakehw/loop-volume");
        const QString internalUdi = QStringLiteral("/org/kde/solid/fakehw/internal-volume");
        const QString opticalUdi = QStringLiteral("/org/kde/solid/fakehw/optical-disc");

        RemovableVolumesModel model;

        QCOMPARE(model.rowCount(), 3);
        QCOMPARE(rowForUdi(model, ignoredUdi), -1);
        QCOMPARE(rowForUdi(model, loopUdi), -1);
        QCOMPARE(rowForUdi(model, internalUdi), -1);

        const int mountedRow = rowForUdi(model, mountedUdi);
        QVERIFY(mountedRow >= 0);
        QCOMPARE(
            model.data(model.index(mountedRow, 0), RemovableVolumesModel::MountedRole).toBool(),
            true);
        QCOMPARE(
            model.data(model.index(mountedRow, 0), RemovableVolumesModel::MountUrlRole).toUrl(),
            QUrl::fromLocalFile(QStringLiteral("/media/Mounted")));

        const int opticalRow = rowForUdi(model, opticalUdi);
        QVERIFY(opticalRow >= 0);
        QCOMPARE(model.data(model.index(opticalRow, 0), RemovableVolumesModel::KindRole).toString(),
                 QStringLiteral("optical"));

        Solid::Device laterMountedDevice(laterMountedUdi);
        auto *access = laterMountedDevice.as<Solid::StorageAccess>();
        QVERIFY(access);
        QVERIFY(!access->isAccessible());

        const int initialLaterRow = rowForUdi(model, laterMountedUdi);
        QVERIFY(initialLaterRow >= 0);
        QCOMPARE(
            model.data(model.index(initialLaterRow, 0), RemovableVolumesModel::MountedRole).toBool(),
            false);

        QSignalSpy dataChangedSpy(&model, &RemovableVolumesModel::dataChanged);
        QVERIFY(access->setup());
        QTRY_COMPARE(
            model.data(model.index(initialLaterRow, 0), RemovableVolumesModel::MountedRole).toBool(),
            true);
        QVERIFY(dataChangedSpy.count() >= 1);

        QCOMPARE(model.data(model.index(initialLaterRow, 0), RemovableVolumesModel::MountUrlRole)
                     .toUrl(),
                 QUrl::fromLocalFile(QStringLiteral("/media/Later")));

        QVERIFY(access->teardown());
        QTRY_COMPARE(
            model.data(model.index(initialLaterRow, 0), RemovableVolumesModel::MountedRole).toBool(),
            false);
        QCOMPARE(model.data(model.index(initialLaterRow, 0), RemovableVolumesModel::MountUrlRole)
                     .toUrl(),
                 QUrl());
    }

    void reportsOpticalEjectStartFailure()
    {
        const QString opticalUdi = QStringLiteral("/org/kde/solid/fakehw/optical-disc");
        RemovableVolumesModel model;
        const int opticalRow = rowForUdi(model, opticalUdi);
        QVERIFY(opticalRow >= 0);

        QSignalSpy failureSpy(&model, &RemovableVolumesModel::operationFailed);
        model.remove(opticalUdi);

        QCOMPARE(failureSpy.count(), 1);
        QCOMPARE(model.data(model.index(opticalRow, 0), RemovableVolumesModel::BusyRole).toBool(),
                 false);
        QCOMPARE(
            model.data(model.index(opticalRow, 0), RemovableVolumesModel::OperationRole).toString(),
            QStringLiteral("idle"));
        QVERIFY(!model.data(model.index(opticalRow, 0), RemovableVolumesModel::ErrorTextRole)
                     .toString()
                     .isEmpty());

        QSignalSpy successSpy(&model, &RemovableVolumesModel::operationSucceeded);
        QVERIFY(QMetaObject::invokeMethod(&model, "onEjectDone", Qt::DirectConnection,
                                          Q_ARG(Solid::ErrorType, Solid::NoError),
                                          Q_ARG(QVariant, QVariant()), Q_ARG(QString, opticalUdi)));
        QCOMPARE(successSpy.count(), 1);
        QCOMPARE(model.data(model.index(opticalRow, 0), RemovableVolumesModel::ErrorTextRole)
                     .toString(),
                 QString());
    }

    void openInNewTabPropertyAndMethods()
    {
        RemovableVolumesModel model;
        QCOMPARE(model.openInNewTab(), false);

        QSignalSpy spy(&model, &RemovableVolumesModel::openInNewTabChanged);
        model.setOpenInNewTab(true);
        QCOMPARE(model.openInNewTab(), true);
        QCOMPARE(spy.count(), 1);

        // Setting same value should not emit signal
        model.setOpenInNewTab(true);
        QCOMPARE(spy.count(), 1);

        model.setOpenInNewTab(false);
        QCOMPARE(model.openInNewTab(), false);
        QCOMPARE(spy.count(), 2);
    }

    /**
     * Der Kern der Regression aus 1.14.0: Die Standardaktion (Klick auf das
     * Symbol, erster Menueintrag) darf bei ausgeschalteter Tab-Option KEINE
     * Anwendung erzwingen. Vorher lief sie in `dolphin --new-window` und
     * ersetzte damit den eingestellten Dateimanager.
     *
     * Der frueher hier stehende Aufruf `model.open(<erfundene UDI>, true)`
     * hat das nicht geprueft: `findRowByUdi()` liefert fuer eine unbekannte
     * UDI -1, beide Aufrufe kehrten in der ersten Zeile zurueck und haben den
     * Oeffnen-Pfad nie erreicht.
     */
    void defaultOpenModeFollowsConfiguration()
    {
        RemovableVolumesModel model;

        QCOMPARE(model.openInNewTab(), false);
        QCOMPARE(model.defaultOpenMode(), RemovableVolumesModel::OpenMode::DefaultApplication);

        model.setOpenInNewTab(true);
        QCOMPARE(model.defaultOpenMode(), RemovableVolumesModel::OpenMode::DolphinTab);

        model.setOpenInNewTab(false);
        QCOMPARE(model.defaultOpenMode(), RemovableVolumesModel::OpenMode::DefaultApplication);
    }

    /**
     * `openInDolphinTab()` schickt einem fremden Prozess einen Einhaengepfad
     * und ruft danach `activateWindow`. Jede lokale Anwendung darf sich einen
     * beliebigen Namen auf dem Sitzungsbus registrieren — der Abgleich muss
     * deshalb exakt sein und nicht per Praefix raten.
     */
    void dolphinServiceNameMatching_data()
    {
        QTest::addColumn<QString>("service");
        QTest::addColumn<bool>("expected");

        QTest::newRow("plain") << QStringLiteral("org.kde.dolphin") << true;
        QTest::newRow("with pid") << QStringLiteral("org.kde.dolphin-1234") << true;
        QTest::newRow("suffix word") << QStringLiteral("org.kde.dolphinator") << false;
        QTest::newRow("sub-namespace") << QStringLiteral("org.kde.dolphin.evil") << false;
        QTest::newRow("dangling dash") << QStringLiteral("org.kde.dolphin-") << false;
        QTest::newRow("non-numeric suffix") << QStringLiteral("org.kde.dolphin-abc") << false;
        QTest::newRow("prefixed") << QStringLiteral("com.example.org.kde.dolphin") << false;
        QTest::newRow("unrelated") << QStringLiteral("org.kde.konsole") << false;
        QTest::newRow("empty") << QString() << false;
    }

    void dolphinServiceNameMatching()
    {
        QFETCH(QString, service);
        QFETCH(bool, expected);
        QCOMPARE(RemovableVolumesModel::isDolphinService(service), expected);
    }
};

QTEST_GUILESS_MAIN(RemovableVolumesModelTest)

#include "removablevolumesmodeltest.moc"
