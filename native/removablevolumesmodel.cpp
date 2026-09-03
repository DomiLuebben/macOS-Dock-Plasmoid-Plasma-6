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
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDesktopServices>
#include <QProcess>
#include <QRegularExpression>
#include <QTimer>
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

bool RemovableVolumesModel::openInNewTab() const
{
    return m_openInNewTab;
}

void RemovableVolumesModel::setOpenInNewTab(bool openInNewTab)
{
    if (m_openInNewTab == openInNewTab) {
        return;
    }
    m_openInNewTab = openInNewTab;
    emit openInNewTabChanged();
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

    if (requireMounted && !access->isAccessible()) {
        return false;
    }

    if (access->isAccessible()) {
        const QString filePath = access->filePath();
        if (!filePath.isEmpty() && filePath != QStringLiteral("/")) {
            itemOut.mountUrl = QUrl::fromLocalFile(filePath);
        } else if (requireMounted) {
            return false;
        }
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
    m_watchedUdis.clear();

    const auto volumeDevices = Solid::Device::listFromType(Solid::DeviceInterface::StorageVolume);
    for (const Solid::Device &dev : volumeDevices) {
        const QString udi = dev.udi();
        VolumeItem item;
        if (isCandidateDevice(udi, item, false)) {
            connectDeviceSignals(udi);
            m_items.append(item);
        }
    }

    const auto opticalDevices = Solid::Device::listFromType(Solid::DeviceInterface::OpticalDisc);
    for (const Solid::Device &dev : opticalDevices) {
        const QString udi = dev.udi();
        VolumeItem item;
        if (isCandidateDevice(udi, item, false) && findRowByUdi(udi) == -1) {
            connectDeviceSignals(udi);
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
    bool inNewTab = m_openInNewTab;
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
        inNewTab = item.openInNewTabOnMount;
        item.openOnMount = false;
        item.openInNewTabOnMount = false;
    } else {
        item.openOnMount = false;
        item.openInNewTabOnMount = false;
        item.mountUrl.clear();
    }

    QModelIndex idx = createIndex(row, 0);
    emit dataChanged(idx, idx, {MountedRole, CanOpenRole, MountUrlRole, BusyRole, OperationRole, ErrorTextRole});

    if (shouldOpenAfterMount) {
        openWhenReady(udi, inNewTab, 10);
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
    mount(udi, m_openInNewTab);
}

void RemovableVolumesModel::mount(const QString &udi, bool inNewTab)
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
    item.openInNewTabOnMount = inNewTab;
    item.errorText.clear();
    QModelIndex idx = createIndex(row, 0);
    emit dataChanged(idx, idx, {BusyRole, OperationRole, ErrorTextRole});

    if (!access->setup()) {
        const QString errorMsg = i18n("Could not initiate mounting.");
        const int currentRow = findRowByUdi(udi);
        if (currentRow == -1) {
            emit operationFailed(udi, errorMsg);
            return;
        }
        VolumeItem &currentItem = m_items[currentRow];
        currentItem.busy = false;
        currentItem.operation = QStringLiteral("idle");
        currentItem.openOnMount = false;
        currentItem.openInNewTabOnMount = false;
        currentItem.errorText = errorMsg;
        const QModelIndex currentIdx = createIndex(currentRow, 0);
        emit dataChanged(currentIdx, currentIdx,
                         {BusyRole, OperationRole, ErrorTextRole});
        emit operationFailed(udi, errorMsg);
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
        item.openInNewTabOnMount = false;
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

void RemovableVolumesModel::openWhenReady(const QString &udi, bool inNewTab, int retries)
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
    if (access && access->isAccessible()) {
        QString path = access->filePath();
        if (!path.isEmpty() && path != QStringLiteral("/")) {
            const QUrl mountUrl = QUrl::fromLocalFile(path);
            if (m_items[row].mountUrl != mountUrl || !m_items[row].canOpen) {
                m_items[row].mountUrl = mountUrl;
                m_items[row].canOpen = true;
                const QModelIndex idx = createIndex(row, 0);
                emit dataChanged(idx, idx, {MountUrlRole, CanOpenRole});
            }
            openUrl(mountUrl, inNewTab);
            return;
        }
    }

    if (retries > 0) {
        QTimer::singleShot(100, this, [this, udi, inNewTab, retries]() {
            openWhenReady(udi, inNewTab, retries - 1);
        });
    } else {
        reportError(udi, i18n("Failed to open volume."));
    }
}

void RemovableVolumesModel::open(const QString &udi)
{
    open(udi, m_openInNewTab);
}

void RemovableVolumesModel::open(const QString &udi, bool inNewTab)
{
    int row = findRowByUdi(udi);
    if (row == -1) {
        return;
    }

    // If not mounted, mount first — onAccessibilityChanged will update the model
    if (!m_items.at(row).mounted) {
        mount(udi, inNewTab);
        return;
    }

    if (!m_items.at(row).errorText.isEmpty()) {
        m_items[row].errorText.clear();
        const QModelIndex idx = createIndex(row, 0);
        emit dataChanged(idx, idx, {ErrorTextRole});
    }

    openWhenReady(udi, inNewTab, 10);
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
            const QString errorMsg = i18n("Could not initiate eject.");
            const int currentRow = findRowByUdi(udi);
            if (currentRow == -1) {
                emit operationFailed(udi, errorMsg);
                return;
            }
            VolumeItem &currentItem = m_items[currentRow];
            currentItem.busy = false;
            currentItem.operation = QStringLiteral("idle");
            currentItem.errorText = errorMsg;
            const QModelIndex currentIdx = createIndex(currentRow, 0);
            emit dataChanged(currentIdx, currentIdx,
                             {BusyRole, OperationRole, ErrorTextRole});
            emit operationFailed(udi, errorMsg);
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
        const QString errorMsg = i18n("Could not initiate unmounting.");
        const int currentRow = findRowByUdi(udi);
        if (currentRow == -1) {
            emit operationFailed(udi, errorMsg);
            return;
        }
        VolumeItem &currentItem = m_items[currentRow];
        currentItem.busy = false;
        currentItem.operation = QStringLiteral("idle");
        currentItem.errorText = errorMsg;
        const QModelIndex currentIdx = createIndex(currentRow, 0);
        emit dataChanged(currentIdx, currentIdx,
                         {BusyRole, OperationRole, ErrorTextRole});
        emit operationFailed(udi, errorMsg);
    }
}

bool RemovableVolumesModel::openInDolphinTab(const QUrl &url)
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected() || !bus.interface()) {
        return false;
    }

    const QDBusReply<QStringList> servicesReply = bus.interface()->registeredServiceNames();
    if (!servicesReply.isValid()) {
        return false;
    }

    const QStringList services = servicesReply.value();
    QString chosenService;
    QString chosenPath;

    for (const QString &service : services) {
        if (!service.startsWith(QLatin1String("org.kde.dolphin"))) {
            continue;
        }

        QDBusInterface rootIface(service, QStringLiteral("/dolphin"),
                                 QStringLiteral("org.freedesktop.DBus.Introspectable"), bus);
        if (!rootIface.isValid()) {
            continue;
        }

        const QDBusReply<QString> xmlReply = rootIface.call(QStringLiteral("Introspect"));
        if (!xmlReply.isValid()) {
            continue;
        }

        const QString xml = xmlReply.value();
        static const QRegularExpression nodeRe(QStringLiteral("<node name=\"(Dolphin_\\d+)\""));
        auto it = nodeRe.globalMatch(xml);
        while (it.hasNext()) {
            const auto match = it.next();
            const QString winPath = QStringLiteral("/dolphin/") + match.captured(1);
            QDBusInterface winIface(service, winPath,
                                    QStringLiteral("org.kde.dolphin.MainWindow"), bus);
            if (winIface.isValid()) {
                const QDBusReply<bool> activeReply = winIface.call(QStringLiteral("isActiveWindow"));
                if (activeReply.isValid() && activeReply.value()) {
                    chosenService = service;
                    chosenPath = winPath;
                    break;
                } else if (chosenService.isEmpty()) {
                    chosenService = service;
                    chosenPath = winPath;
                }
            }
        }

        if (!chosenService.isEmpty() && !chosenPath.isEmpty()) {
            break;
        }
    }

    if (chosenService.isEmpty() || chosenPath.isEmpty()) {
        return false;
    }

    QDBusInterface winIface(chosenService, chosenPath,
                            QStringLiteral("org.kde.dolphin.MainWindow"), bus);
    if (!winIface.isValid()) {
        return false;
    }

    const QString urlString = url.toString();
    const QDBusMessage reply = winIface.call(QStringLiteral("openDirectories"),
                                             QStringList{urlString}, false);
    if (reply.type() == QDBusMessage::ErrorMessage) {
        return false;
    }

    winIface.call(QStringLiteral("activateWindow"), QString());
    return true;
}

void RemovableVolumesModel::openUrl(const QUrl &url, bool inNewTab)
{
    if (inNewTab) {
        if (openInDolphinTab(url)) {
            return;
        }
        // Fall back to opening via desktop services if no running Dolphin instance is found
        QDesktopServices::openUrl(url);
        return;
    }

    // inNewTab is false: explicitly open in a new window. Dolphin supports `--new-window`
    // which guarantees a separate window even when Dolphin is configured to open in tabs.
    const QString targetArg = url.isLocalFile() ? url.toLocalFile() : url.toString();
    if (QProcess::startDetached(QStringLiteral("dolphin"),
                                QStringList{QStringLiteral("--new-window"), targetArg})) {
        return;
    }

    QDesktopServices::openUrl(url);
}
