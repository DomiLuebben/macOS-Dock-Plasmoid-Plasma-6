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

        // Verify open() with inNewTab overload does not crash
        const QString stickUdi = QStringLiteral("/org/kde/solid/fakehw/volume_part1_size_993218560");
        model.open(stickUdi, true);
        model.open(stickUdi, false);
    }
};

QTEST_GUILESS_MAIN(RemovableVolumesModelTest)

#include "removablevolumesmodeltest.moc"
