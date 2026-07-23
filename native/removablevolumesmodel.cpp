#ifndef TRANSLATION_DOMAIN
#define TRANSLATION_DOMAIN "plasma_applet_org.kde.plasma.macosdock"
#endif

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
#include <KJob>
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

bool RemovableVolumesModel::isCandidateDevice(const QString &udi, VolumeItem &itemOut, bool requireMounted)
{
    Solid::Device dev(udi);
    if (!dev.isValid()) {
        return false;
    }

    auto *access = dev.as<Solid::StorageAccess>();
    if (!access) {
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

    // Check parent StorageDrive
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

    if (requireMounted) {
        if (!access->isAccessible()) {
            return false;
        }
        QString filePath = access->filePath();
        if (filePath.isEmpty() || filePath == QStringLiteral("/")) {
            return false;
        }
        itemOut.mountUrl = QUrl::fromLocalFile(filePath);
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
    if (m_watchedUdis.contains(udi)) {
        return;
    }

    Solid::Device dev(udi);
    if (!dev.isValid()) {
        return;
    }

    auto *access = dev.as<Solid::StorageAccess>();
    if (access) {
        connect(access, &Solid::StorageAccess::accessibilityChanged, this,
                &RemovableVolumesModel::onAccessibilityChanged, Qt::UniqueConnection);

        connect(access, &Solid::StorageAccess::setupDone, this,
                &RemovableVolumesModel::onSetupDone, Qt::UniqueConnection);

        connect(access, &Solid::StorageAccess::teardownRequested, this,
                &RemovableVolumesModel::onTeardownRequested, Qt::UniqueConnection);

        connect(access, &Solid::StorageAccess::teardownDone, this,
                &RemovableVolumesModel::onTeardownDone, Qt::UniqueConnection);

        m_watchedUdis.insert(udi);
    }

    // Connect optical drive signals if applicable
    Solid::Device parentDev = dev;
    while (parentDev.isValid()) {
        if (parentDev.isDeviceInterface(Solid::DeviceInterface::OpticalDrive)) {
            auto *optical = parentDev.as<Solid::OpticalDrive>();
            if (optical) {
                connect(optical, &Solid::OpticalDrive::ejectDone, this,
                        &RemovableVolumesModel::onEjectDone, Qt::UniqueConnection);
            }
            break;
        }
        parentDev = parentDev.parent();
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
        if (isCandidateDevice(udi, item, false)) {
            connectDeviceSignals(udi);
            // Fill mountUrl if already mounted
            if (item.mounted) {
                Solid::Device d(udi);
                auto *access = d.as<Solid::StorageAccess>();
                if (access) {
                    QString fp = access->filePath();
                    if (!fp.isEmpty() && fp != QStringLiteral("/")) {
                        item.mountUrl = QUrl::fromLocalFile(fp);
                        item.canOpen = true;
                    }
                }
            }
            m_items.append(item);
        }
    }

    const auto opticalDevices = Solid::Device::listFromType(Solid::DeviceInterface::OpticalDisc);
    for (const Solid::Device &dev : opticalDevices) {
        const QString udi = dev.udi();
        VolumeItem item;
        if (isCandidateDevice(udi, item, false) && findRowByUdi(udi) == -1) {
            connectDeviceSignals(udi);
            if (item.mounted) {
                Solid::Device d(udi);
                auto *access = d.as<Solid::StorageAccess>();
                if (access) {
                    QString fp = access->filePath();
                    if (!fp.isEmpty() && fp != QStringLiteral("/")) {
                        item.mountUrl = QUrl::fromLocalFile(fp);
                        item.canOpen = true;
                    }
                }
            }
            m_items.append(item);
        }
    }

    endResetModel();
    emit countChanged();
}

void RemovableVolumesModel::onDeviceAdded(const QString &udi)
{
    VolumeItem item;
    if (isCandidateDevice(udi, item, false) && findRowByUdi(udi) == -1) {
        connectDeviceSignals(udi);
        // Fill mountUrl if already mounted
        if (item.mounted) {
            Solid::Device d(udi);
            auto *access = d.as<Solid::StorageAccess>();
            if (access) {
                QString fp = access->filePath();
                if (!fp.isEmpty() && fp != QStringLiteral("/")) {
                    item.mountUrl = QUrl::fromLocalFile(fp);
                    item.canOpen = true;
                }
            }
        }
        int newRow = m_items.size();
        beginInsertRows(QModelIndex(), newRow, newRow);
        m_items.append(item);
        endInsertRows();
        emit countChanged();
    }
}

void RemovableVolumesModel::onDeviceRemoved(const QString &udi)
{
    m_watchedUdis.remove(udi);
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

    if (row == -1) {
        // Not in model yet — might be a newly detected candidate
        if (accessible) {
            VolumeItem item;
            if (isCandidateDevice(udi, item, false)) {
                connectDeviceSignals(udi);
                Solid::Device d(udi);
                auto *access = d.as<Solid::StorageAccess>();
                if (access) {
                    QString fp = access->filePath();
                    if (!fp.isEmpty() && fp != QStringLiteral("/")) {
                        item.mountUrl = QUrl::fromLocalFile(fp);
                    }
                }
                item.mounted = true;
                item.canOpen = true;
                int newRow = m_items.size();
                beginInsertRows(QModelIndex(), newRow, newRow);
                m_items.append(item);
                endInsertRows();
                emit countChanged();
            }
        }
        return;
    }

    VolumeItem &item = m_items[row];
    item.mounted = accessible;
    item.canOpen = accessible;
    item.busy = false;
    item.operation = QStringLiteral("idle");

    bool shouldOpenAfterMount = false;
    if (accessible) {
        Solid::Device dev(udi);
        auto *access = dev.as<Solid::StorageAccess>();
        if (access) {
            QString fp = access->filePath();
            if (!fp.isEmpty() && fp != QStringLiteral("/")) {
                item.mountUrl = QUrl::fromLocalFile(fp);
            }
        }
        item.errorText.clear();
        shouldOpenAfterMount = item.openOnMount;
        item.openOnMount = false;
    } else {
        item.openOnMount = false;
        item.mountUrl.clear();
    }

    QModelIndex idx = createIndex(row, 0);
    emit dataChanged(idx, idx, {MountedRole, CanOpenRole, MountUrlRole, BusyRole, OperationRole, ErrorTextRole});

    if (shouldOpenAfterMount) {
        open(udi);
    }
}

void RemovableVolumesModel::onTeardownRequested(const QString &udi)
{
    int row = findRowByUdi(udi);
    if (row == -1) {
        return;
    }

    VolumeItem &item = m_items[row];
    item.busy = true;
    item.operation = QStringLiteral("unmounting");
    item.errorText.clear();
    QModelIndex idx = createIndex(row, 0);
    emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});
}

void RemovableVolumesModel::onTeardownDone(Solid::ErrorType error, const QVariant &errorData,
                                           const QString &udi)
{
    int row = findRowByUdi(udi);
    if (row == -1) {
        return;
    }

    VolumeItem &item = m_items[row];
    item.busy = false;
    item.operation = QStringLiteral("idle");

    QString errorMessage;
    if (error != Solid::NoError) {
        errorMessage = errorData.toString();
        if (errorMessage.isEmpty()) {
            errorMessage = i18n("Failed to unmount volume.");
        }
        item.errorText = errorMessage;
    } else {
        item.errorText.clear();
    }

    QModelIndex idx = createIndex(row, 0);
    emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});
    if (error != Solid::NoError) {
        emit operationFailed(udi, errorMessage);
    } else {
        emit operationSucceeded(udi);
    }
}

void RemovableVolumesModel::onEjectDone(Solid::ErrorType error, const QVariant &errorData,
                                        const QString &udi)
{
    int row = findRowByUdi(udi);
    if (row == -1) {
        return;
    }

    VolumeItem &item = m_items[row];
    item.busy = false;
    item.operation = QStringLiteral("idle");

    QString errorMessage;
    if (error != Solid::NoError) {
        errorMessage = errorData.toString();
        if (errorMessage.isEmpty()) {
            errorMessage = i18n("Failed to eject optical disc.");
        }
        item.errorText = errorMessage;
    } else {
        item.errorText.clear();
    }

    QModelIndex idx = createIndex(row, 0);
    emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});
    if (error != Solid::NoError) {
        emit operationFailed(udi, errorMessage);
    } else {
        emit operationSucceeded(udi);
    }
}

void RemovableVolumesModel::reportError(const QString &udi, const QString &message)
{
    int row = findRowByUdi(udi);
    if (row != -1) {
        VolumeItem &item = m_items[row];
        item.errorText = message;
        QModelIndex idx = createIndex(row, 0);
        emit dataChanged(idx, idx, {ErrorTextRole});
    }
    emit operationFailed(udi, message);
}

void RemovableVolumesModel::mount(const QString &udi)
{
    int row = findRowByUdi(udi);
    if (row == -1) {
        return;
    }

    VolumeItem &item = m_items[row];
    if (item.busy || item.mounted) {
        return;
    }

    Solid::Device dev(udi);
    if (!dev.isValid()) {
        return;
    }

    auto *access = dev.as<Solid::StorageAccess>();
    if (!access) {
        return;
    }

    item.busy = true;
    item.operation = QStringLiteral("mounting");
    item.openOnMount = true;
    item.errorText.clear();
    QModelIndex idx = createIndex(row, 0);
    emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});

    if (!access->setup()) {
        item.busy = false;
        item.operation = QStringLiteral("idle");
        item.openOnMount = false;
        item.errorText = i18n("Could not initiate mounting.");
        emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});
        emit operationFailed(udi, item.errorText);
    }
}

void RemovableVolumesModel::onSetupDone(Solid::ErrorType error, const QVariant &errorData,
                                        const QString &udi)
{
    int row = findRowByUdi(udi);
    if (row == -1) {
        return;
    }

    VolumeItem &item = m_items[row];
    item.busy = false;
    item.operation = QStringLiteral("idle");

    if (error != Solid::NoError) {
        item.openOnMount = false;
        QString msg = errorData.toString();
        if (msg.isEmpty()) {
            msg = i18n("Failed to mount volume.");
        }
        item.errorText = msg;
        QModelIndex idx = createIndex(row, 0);
        emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});
        emit operationFailed(udi, msg);
    } else {
        item.errorText.clear();
        // mounted state will be updated by onAccessibilityChanged
        QModelIndex idx = createIndex(row, 0);
        emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});
        emit operationSucceeded(udi);
    }
}

void RemovableVolumesModel::open(const QString &udi)
{
    int row = findRowByUdi(udi);
    if (row == -1) {
        return;
    }

    // If not mounted, mount first — onAccessibilityChanged will update the model
    if (!m_items.at(row).mounted) {
        mount(udi);
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

    VolumeItem &item = m_items[row];
    if (!item.errorText.isEmpty()) {
        item.errorText.clear();
        QModelIndex idx = createIndex(row, 0);
        emit dataChanged(idx, idx, {ErrorTextRole});
    }

    QUrl url = QUrl::fromLocalFile(access->filePath());
    auto *job = new KIO::OpenUrlJob(url);
    connect(job, &KJob::result, this, [this, udi, job]() {
        if (!job->error()) {
            return;
        }

        QString message = job->errorText();
        if (message.isEmpty()) {
            message = i18n("Failed to open volume.");
        }
        reportError(udi, message);
    });
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

    // Check optical drive parent / interface
    Solid::Device parentDev = dev;
    Solid::OpticalDrive *optical = nullptr;
    while (parentDev.isValid()) {
        if (parentDev.isDeviceInterface(Solid::DeviceInterface::OpticalDrive)) {
            optical = parentDev.as<Solid::OpticalDrive>();
            break;
        }
        parentDev = parentDev.parent();
    }

    if (optical) {
        item.busy = true;
        item.operation = QStringLiteral("ejecting");
        item.errorText.clear();
        QModelIndex idx = createIndex(row, 0);
        emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});

        if (!optical->eject()) {
            item.busy = false;
            item.operation = QStringLiteral("idle");
            item.errorText = i18n("Could not initiate eject.");
            emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});
            emit operationFailed(udi, item.errorText);
        }
        return;
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
