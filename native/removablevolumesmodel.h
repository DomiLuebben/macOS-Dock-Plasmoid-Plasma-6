#ifndef REMOVABLEVOLUMESMODEL_H
#define REMOVABLEVOLUMESMODEL_H

#include <QAbstractListModel>
#include <QUrl>
#include <QVariant>
#include <QList>
#include <QString>
#include <QSet>

#include <Solid/SolidNamespace>

class RemovableVolumesModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        UdiRole = Qt::UserRole + 1,
        DisplayNameRole,
        IconNameRole,
        MountUrlRole,
        KindRole,
        MountedRole,
        BusyRole,
        OperationRole,
        CanOpenRole,
        CanRemoveRole,
        ErrorTextRole
    };
    Q_ENUM(Roles)

    struct VolumeItem {
        QString udi;
        QString displayName;
        QString iconName;
        QUrl mountUrl;
        QString kind; // "filesystem" or "optical"
        bool mounted{true};
        bool busy{false};
        QString operation{"idle"}; // "idle", "unmounting", "ejecting"
        bool canOpen{true};
        bool canRemove{true};
        bool openOnMount{false};
        QString errorText;
    };

    explicit RemovableVolumesModel(QObject *parent = nullptr);
    ~RemovableVolumesModel() override = default;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;

    Q_INVOKABLE void open(const QString &udi);
    Q_INVOKABLE void mount(const QString &udi);
    Q_INVOKABLE void remove(const QString &udi);

signals:
    void countChanged();
    void operationFailed(const QString &udi, const QString &message);
    void operationSucceeded(const QString &udi);

private slots:
    void onDeviceAdded(const QString &udi);
    void onDeviceRemoved(const QString &udi);
    void onAccessibilityChanged(bool accessible, const QString &udi);
    void onTeardownRequested(const QString &udi);
    void onSetupDone(Solid::ErrorType error, const QVariant &errorData, const QString &udi);
    void onTeardownDone(Solid::ErrorType error, const QVariant &errorData, const QString &udi);
    void onEjectDone(Solid::ErrorType error, const QVariant &errorData, const QString &udi);

private:
    void refreshModel();
    bool isCandidateDevice(const QString &udi, VolumeItem &itemOut, bool requireMounted = true);
    int findRowByUdi(const QString &udi) const;
    void connectDeviceSignals(const QString &udi);
    void reportError(const QString &udi, const QString &message);

    QList<VolumeItem> m_items;
    QSet<QString> m_watchedUdis;
};

#endif // REMOVABLEVOLUMESMODEL_H
