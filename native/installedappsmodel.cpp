#include "installedappsmodel.h"

#include <QCollator>
#include <QHash>
#include <QLocale>
#include <QSet>

#include <KApplicationTrader>
#include <KService>
#include <KSycoca>

#include <algorithm>

InstalledAppsModel::InstalledAppsModel(QObject *parent)
    : QAbstractListModel(parent)
{
    // The database can signal several times for one package operation.
    m_reloadTimer.setSingleShot(true);
    m_reloadTimer.setInterval(400);
    connect(&m_reloadTimer, &QTimer::timeout, this, &InstalledAppsModel::reload);
    connect(KSycoca::self(), &KSycoca::databaseChanged, &m_reloadTimer, qOverload<>(&QTimer::start));

    reload();
}

int InstalledAppsModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_visible.size();
}

QVariant InstalledAppsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_visible.size()) {
        return {};
    }
    const Entry &entry = m_visible.at(index.row());
    switch (role) {
    case NameRole:
    case Qt::DisplayRole:
        return entry.name;
    case GenericNameRole:
        return entry.genericName;
    case CommentRole:
        return entry.comment;
    case IconRole:
        return entry.icon;
    case StorageIdRole:
        return entry.storageId;
    case LauncherUrlRole:
        return launcherUrl(entry.storageId);
    }
    return {};
}

QHash<int, QByteArray> InstalledAppsModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {GenericNameRole, "genericName"},
        {CommentRole, "comment"},
        {IconRole, "icon"},
        {StorageIdRole, "storageId"},
        {LauncherUrlRole, "launcherUrl"},
    };
}

QString InstalledAppsModel::filter() const
{
    return m_filter;
}

void InstalledAppsModel::setFilter(const QString &filter)
{
    if (m_filter == filter) {
        return;
    }
    m_filter = filter;
    applyFilter();
    Q_EMIT filterChanged();
}

void InstalledAppsModel::reload()
{
    // Only applications that appear in menus and run in this desktop.
    const KService::List services = KApplicationTrader::query([](const KService::Ptr &service) {
        return service->isApplication() && !service->noDisplay() && service->showInCurrentDesktop()
            && !service->exec().isEmpty();
    });

    QList<Entry> entries;
    entries.reserve(services.size());
    for (const KService::Ptr &service : services) {
        Entry entry;
        entry.storageId = service->storageId();
        entry.name = service->name();
        entry.genericName = service->genericName();
        entry.comment = service->comment();
        entry.icon = service->icon();
        entry.keywords = service->keywords();
        entries.append(entry);
    }
    setEntries(entries);
}

void InstalledAppsModel::setEntries(const QList<Entry> &entries)
{
    QSet<QString> seen;
    QList<Entry> unique;
    unique.reserve(entries.size());
    for (const Entry &entry : entries) {
        if (entry.storageId.isEmpty() || entry.name.isEmpty() || seen.contains(entry.storageId)) {
            continue;
        }
        seen.insert(entry.storageId);
        unique.append(entry);
    }

    QCollator collator(QLocale::system());
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::stable_sort(unique.begin(), unique.end(), [&collator](const Entry &a, const Entry &b) {
        return collator.compare(a.name, b.name) < 0;
    });

    m_all = unique;
    applyFilter();
}

bool InstalledAppsModel::matches(const Entry &entry, const QString &filter)
{
    const QStringList words = filter.simplified().split(QLatin1Char(' '), Qt::SkipEmptyParts);
    if (words.isEmpty()) {
        return true;
    }
    const QString haystack = (entry.name + QLatin1Char('\n') + entry.genericName + QLatin1Char('\n')
                              + entry.comment + QLatin1Char('\n') + entry.keywords.join(QLatin1Char('\n')))
                                 .toLower();
    return std::all_of(words.cbegin(), words.cend(), [&haystack](const QString &word) {
        return haystack.contains(word.toLower());
    });
}

QString InstalledAppsModel::launcherUrl(const QString &storageId)
{
    return QStringLiteral("applications:") + storageId;
}

void InstalledAppsModel::applyFilter()
{
    QList<Entry> visible;
    for (const Entry &entry : std::as_const(m_all)) {
        if (matches(entry, m_filter)) {
            visible.append(entry);
        }
    }

    const int oldCount = m_visible.size();
    beginResetModel();
    m_visible = visible;
    endResetModel();
    if (oldCount != m_visible.size()) {
        Q_EMIT countChanged();
    }
}
