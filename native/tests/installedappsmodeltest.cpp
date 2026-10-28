#include "installedappsmodel.h"

#include <QSignalSpy>
#include <QTest>

using Entry = InstalledAppsModel::Entry;

namespace
{
Entry app(const QString &id, const QString &name, const QString &generic = {}, const QString &comment = {},
          const QStringList &keywords = {})
{
    Entry entry;
    entry.storageId = id;
    entry.name = name;
    entry.genericName = generic;
    entry.comment = comment;
    entry.icon = QStringLiteral("icon-") + id;
    entry.keywords = keywords;
    return entry;
}

QStringList names(const InstalledAppsModel &model)
{
    QStringList result;
    for (int row = 0; row < model.rowCount(); ++row) {
        result << model.data(model.index(row), InstalledAppsModel::NameRole).toString();
    }
    return result;
}
}

class InstalledAppsModelTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void sortsByNameIgnoringCase()
    {
        InstalledAppsModel model;
        model.setEntries({app("c.desktop", "zeta"), app("a.desktop", "Alpha"), app("b.desktop", "beta")});
        QCOMPARE(names(model), (QStringList{"Alpha", "beta", "zeta"}));
    }

    void dropsDuplicatesAndIncompleteEntries()
    {
        InstalledAppsModel model;
        model.setEntries({app("a.desktop", "Alpha"), app("a.desktop", "Alpha again"), app("", "No id"),
                          app("n.desktop", "")});
        QCOMPARE(names(model), (QStringList{"Alpha"}));
    }

    void exposesRolesAndLauncherUrl()
    {
        InstalledAppsModel model;
        model.setEntries({app("org.kde.dolphin.desktop", "Dolphin", "File Manager", "Browse files")});
        const QModelIndex index = model.index(0);
        QCOMPARE(model.data(index, InstalledAppsModel::StorageIdRole).toString(), QStringLiteral("org.kde.dolphin.desktop"));
        QCOMPARE(model.data(index, InstalledAppsModel::LauncherUrlRole).toString(),
                 QStringLiteral("applications:org.kde.dolphin.desktop"));
        QCOMPARE(model.data(index, InstalledAppsModel::GenericNameRole).toString(), QStringLiteral("File Manager"));
        QCOMPARE(model.data(index, InstalledAppsModel::IconRole).toString(), QStringLiteral("icon-org.kde.dolphin.desktop"));
        QCOMPARE(model.roleNames().value(InstalledAppsModel::LauncherUrlRole), QByteArray("launcherUrl"));
    }

    void filterMatchesNameGenericCommentAndKeywords()
    {
        InstalledAppsModel model;
        model.setEntries({app("d.desktop", "Dolphin", "File Manager", "Browse files", {"folder", "explorer"}),
                          app("k.desktop", "Kate", "Text Editor", "Edit text", {"notepad"}),
                          app("f.desktop", "Firefox", "Web Browser", "Browse the web")});
        model.setFilter("kate");
        QCOMPARE(names(model), (QStringList{"Kate"}));
        model.setFilter("MANAGER");
        QCOMPARE(names(model), (QStringList{"Dolphin"}));
        model.setFilter("browse");
        QCOMPARE(names(model), (QStringList{"Dolphin", "Firefox"}));
        model.setFilter("notepad");
        QCOMPARE(names(model), (QStringList{"Kate"}));
    }

    void everyWordOfTheFilterMustMatch()
    {
        InstalledAppsModel model;
        model.setEntries({app("d.desktop", "Dolphin", "File Manager"), app("f.desktop", "Firefox", "Web Browser")});
        model.setFilter("file  manager");
        QCOMPARE(names(model), (QStringList{"Dolphin"}));
        model.setFilter("file browser");
        QCOMPARE(model.rowCount(), 0);
    }

    void emptyFilterShowsEverythingAgain()
    {
        InstalledAppsModel model;
        model.setEntries({app("a.desktop", "Alpha"), app("b.desktop", "Beta")});
        model.setFilter("zzz");
        QCOMPARE(model.rowCount(), 0);
        model.setFilter("   ");
        QCOMPARE(model.rowCount(), 2);
    }

    void reportsCountChanges()
    {
        InstalledAppsModel model;
        QSignalSpy counts(&model, &InstalledAppsModel::countChanged);
        model.setEntries({app("a.desktop", "Alpha"), app("b.desktop", "Beta")});
        model.setFilter("alpha");
        QVERIFY(counts.count() >= 1);
        QCOMPARE(model.rowCount(), 1);
    }

    void filterSurvivesReplacingTheEntries()
    {
        InstalledAppsModel model;
        model.setEntries({app("a.desktop", "Alpha")});
        model.setFilter("beta");
        model.setEntries({app("a.desktop", "Alpha"), app("b.desktop", "Beta")});
        QCOMPARE(names(model), (QStringList{"Beta"}));
    }
};

QTEST_MAIN(InstalledAppsModelTest)
#include "installedappsmodeltest.moc"
