#include "removablevolumesmodel.h"

#include <Solid/Device>
#include <Solid/DeviceNotifier>
#include <Solid/StorageAccess>
#include <Solid/StorageDrive>
#include <Solid/StorageVolume>
#include <Solid/OpticalDrive>
#include <Solid/OpticalDisc>
#include <Solid/Block>

#include <KIO/OpenUrlJob>
#include <KLocalizedString>
#include <QDesktopServices>
#include <QDebug>

RemovableVolumesModel::RemovableVolumesModel(QObject *parent)
    : QAbstractListModel(parent)
{
    connect(Solid::DeviceNotifier::instance(), &Solid::DeviceNotifier::deviceAdded,
            this, &RemovableVolumesModel::onDeviceAdded);
    connect(Solid::DeviceNotifier::instance(), &Solid::DeviceNotifier::deviceRemoved,
            this, &RemovableVolumesModel::onDeviceRemoved);

    refreshModel();
}

int RemovableVolumesModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return m_items.size();
}

int RemovableVolumesModel::count() const
{
    return m_items.size();
}

QVariant RemovableVolumesModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) {
        return QVariant();
    }

    const VolumeItem &item = m_items.at(index.row());
    switch (role) {
    case UdiRole:
        return item.udi;
    case DisplayNameRole:
        return item.displayName;
    case IconNameRole:
        return item.iconName;
    case MountUrlRole:
        return item.mountUrl;
    case KindRole:
        return item.kind;
    case MountedRole:
        return item.mounted;
    case BusyRole:
        return item.busy;
    case OperationRole:
        return item.operation;
    case CanOpenRole:
        return item.canOpen;
    case CanRemoveRole:
        return item.canRemove;
    case ErrorTextRole:
        return item.errorText;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> RemovableVolumesModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[UdiRole] = "udi";
    roles[DisplayNameRole] = "displayName";
    roles[IconNameRole] = "iconName";
    roles[MountUrlRole] = "mountUrl";
    roles[KindRole] = "kind";
    roles[MountedRole] = "mounted";
    roles[BusyRole] = "busy";
    roles[OperationRole] = "operation";
    roles[CanOpenRole] = "canOpen";
    roles[CanRemoveRole] = "canRemove";
    roles[ErrorTextRole] = "errorText";
    return roles;
}

int RemovableVolumesModel::findRowByUdi(const QString &udi) const
{
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items.at(i).udi == udi) {
            return i;
        }
    }
    return -1;
}

bool RemovableVolumesModel::shouldIncludeDevice(const QString &udi, VolumeItem &itemOut)
{
    Solid::Device dev(udi);
    if (!dev.isValid()) {
        return false;
    }

    auto *access = dev.as<Solid::StorageAccess>();
    if (!access || access->isIgnored() || !access->isAccessible()) {
        return false;
    }

    QString filePath = access->filePath();
    if (filePath.isEmpty() || filePath == QStringLiteral("/")) {
        return false;
    }

    // Exclude loop devices (/dev/loop*)
    auto *block = dev.as<Solid::Block>();
    if (block && block->device().startsWith(QStringLiteral("/dev/loop"))) {
        return false;
    }

    bool isOptical = dev.isDeviceInterface(Solid::DeviceInterface::OpticalDisc)
                  || dev.isDeviceInterface(Solid::DeviceInterface::OpticalDrive);

    if (!isOptical) {
        auto *volume = dev.as<Solid::StorageVolume>();
        if (!volume || volume->isIgnored() || volume->usage() != Solid::StorageVolume::FileSystem) {
            return false;
        }
    }

    // Find parent StorageDrive to check if removable or hotpluggable
    Solid::Device parentDev = dev;
    Solid::StorageDrive *drive = nullptr;
    while (parentDev.isValid()) {
        if (parentDev.isDeviceInterface(Solid::DeviceInterface::StorageDrive)) {
            drive = parentDev.as<Solid::StorageDrive>();
            break;
        }
        parentDev = parentDev.parent();
    }

    if (!drive) {
        return false;
    }

    if (!drive->isRemovable() && !drive->isHotpluggable()) {
        return false;
    }

    itemOut.udi = udi;
    itemOut.displayName = dev.displayName();
    if (itemOut.displayName.isEmpty()) {
        auto *volume = dev.as<Solid::StorageVolume>();
        itemOut.displayName = volume ? volume->label() : QString();
    }
    if (itemOut.displayName.isEmpty()) {
        itemOut.displayName = dev.product();
    }
    if (itemOut.displayName.isEmpty()) {
        itemOut.displayName = i18n("Removable Drive");
    }

    itemOut.iconName = dev.icon();
    if (itemOut.iconName.isEmpty()) {
        itemOut.iconName = isOptical ? QStringLiteral("media-optical") : QStringLiteral("drive-removable-media");
    }

    itemOut.mountUrl = QUrl::fromLocalFile(filePath);
    itemOut.kind = isOptical ? QStringLiteral("optical") : QStringLiteral("filesystem");
    itemOut.mounted = access->isAccessible();
    itemOut.busy = false;
    itemOut.operation = QStringLiteral("idle");
    itemOut.canOpen = itemOut.mounted;
    itemOut.canRemove = true;
    itemOut.errorText.clear();

    return true;
}

void RemovableVolumesModel::connectDeviceSignals(const QString &udi)
{
    Solid::Device dev(udi);
    if (!dev.isValid()) {
        return;
    }

    auto *access = dev.as<Solid::StorageAccess>();
    if (access) {
        connect(access, &Solid::StorageAccess::accessibilityChanged,
                this, [this, udi](bool accessible) {
            onAccessibilityChanged(accessible, udi);
        }, Qt::UniqueConnection);

        connect(access, &Solid::StorageAccess::teardownDone,
                this, [this, udi](Solid::ErrorType error, const QVariant &errorData) {
            onTeardownDone(static_cast<int>(error), errorData, udi);
        }, Qt::UniqueConnection);
    }
}

void RemovableVolumesModel::refreshModel()
{
    beginResetModel();
    m_items.clear();

    const auto volumeDevices = Solid::Device::listFromType(Solid::DeviceInterface::StorageVolume);
    for (const Solid::Device &dev : volumeDevices) {
        const QString udi = dev.udi();
        VolumeItem item;
        if (shouldIncludeDevice(udi, item)) {
            m_items.append(item);
            connectDeviceSignals(udi);
        }
    }

    const auto opticalDevices = Solid::Device::listFromType(Solid::DeviceInterface::OpticalDisc);
    for (const Solid::Device &dev : opticalDevices) {
        const QString udi = dev.udi();
        if (findRowByUdi(udi) != -1) {
            continue;
        }
        VolumeItem item;
        if (shouldIncludeDevice(udi, item)) {
            m_items.append(item);
            connectDeviceSignals(udi);
        }
    }

    endResetModel();
    emit countChanged();
}

void RemovableVolumesModel::onDeviceAdded(const QString &udi)
{
    if (findRowByUdi(udi) != -1) {
        return;
    }

    VolumeItem item;
    if (shouldIncludeDevice(udi, item)) {
        int newRow = m_items.size();
        beginInsertRows(QModelIndex(), newRow, newRow);
        m_items.append(item);
        endInsertRows();
        connectDeviceSignals(udi);
        emit countChanged();
    }
}

void RemovableVolumesModel::onDeviceRemoved(const QString &udi)
{
    int row = findRowByUdi(udi);
    if (row != -1) {
        beginRemoveRows(QModelIndex(), row, row);
        m_items.removeAt(row);
        endRemoveRows();
        emit countChanged();
    }
}

void RemovableVolumesModel::onAccessibilityChanged(bool accessible, const QString &udi)
{
    int row = findRowByUdi(udi);
    if (!accessible && row != -1) {
        beginRemoveRows(QModelIndex(), row, row);
        m_items.removeAt(row);
        endRemoveRows();
        emit countChanged();
    } else if (accessible && row == -1) {
        onDeviceAdded(udi);
    }
}

void RemovableVolumesModel::onTeardownDone(int error, const QVariant &errorData, const QString &udi)
{
    int row = findRowByUdi(udi);
    if (row == -1) {
        return;
    }

    VolumeItem &item = m_items[row];
    item.busy = false;
    item.operation = QStringLiteral("idle");

    if (error != 0) { // Solid::NoError == 0
        QString msg = errorData.toString();
        if (msg.isEmpty()) {
            msg = i18n("Failed to unmount device.");
        }
        item.errorText = msg;
        QModelIndex idx = createIndex(row, 0);
        emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});
        emit operationFailed(udi, msg);
    } else {
        item.errorText.clear();
        emit operationSucceeded(udi);
    }
}

void RemovableVolumesModel::open(const QString &udi)
{
    int row = findRowByUdi(udi);
    if (row == -1) {
        return;
    }

    Solid::Device dev(udi);
    if (!dev.isValid()) {
        return;
    }

    auto *access = dev.as<Solid::StorageAccess>();
    if (!access || !access->isAccessible()) {
        return;
    }

    QUrl url = QUrl::fromLocalFile(access->filePath());
    auto *job = new KIO::OpenUrlJob(url);
    job->start();
}

void RemovableVolumesModel::remove(const QString &udi)
{
    int row = findRowByUdi(udi);
    if (row == -1) {
        return;
    }

    VolumeItem &item = m_items[row];
    if (item.busy) {
        return;
    }

    Solid::Device dev(udi);
    if (!dev.isValid()) {
        return;
    }

    if (dev.isDeviceInterface(Solid::DeviceInterface::OpticalDrive)) {
        auto *optical = dev.as<Solid::OpticalDrive>();
        if (optical) {
            item.busy = true;
            item.operation = QStringLiteral("ejecting");
            item.errorText.clear();
            QModelIndex idx = createIndex(row, 0);
            emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});

            optical->eject();
            return;
        }
    }

    auto *access = dev.as<Solid::StorageAccess>();
    if (!access) {
        return;
    }

    item.busy = true;
    item.operation = QStringLiteral("unmounting");
    item.errorText.clear();
    QModelIndex idx = createIndex(row, 0);
    emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});

    if (!access->teardown()) {
        item.busy = false;
        item.operation = QStringLiteral("idle");
        item.errorText = i18n("Could not initiate unmounting.");
        emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});
        emit operationFailed(udi, item.errorText);
    }
}
