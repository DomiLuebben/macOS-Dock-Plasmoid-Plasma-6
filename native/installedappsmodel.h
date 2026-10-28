#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QStringList>
#include <QTimer>

// Every application the user can launch, for the "Add Apps" picker.
//
// The model is flat and sorted by name. The text filter matches name, generic
// name, comment and keywords, ignoring case. Rows are read from the desktop
// entry database (KSycoca) and refresh themselves when it changes, e.g. after a
// package is installed while the picker is open.
class InstalledAppsModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    struct Entry {
        QString storageId; // org.kde.dolphin.desktop
        QString name;
        QString genericName;
        QString comment;
        QString icon;
        QStringList keywords;
    };

    enum Roles {
        NameRole = Qt::UserRole + 1,
        GenericNameRole,
        CommentRole,
        IconRole,
        StorageIdRole,
        LauncherUrlRole,
    };

    explicit InstalledAppsModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString filter() const;
    void setFilter(const QString &filter);

    Q_INVOKABLE void reload();

    // Replaces the underlying entries. Duplicates (same storage id) are dropped
    // and the rest is sorted by name. Public so tests need no desktop database.
    void setEntries(const QList<Entry> &entries);

    // True when the entry matches every word of the filter text.
    static bool matches(const Entry &entry, const QString &filter);
    // "applications:<storage id>", the form Plasma pins launchers in.
    static QString launcherUrl(const QString &storageId);

Q_SIGNALS:
    void filterChanged();
    void countChanged();

private:
    void applyFilter();

    QList<Entry> m_all;
    QList<Entry> m_visible;
    QString m_filter;
    QTimer m_reloadTimer;
};
