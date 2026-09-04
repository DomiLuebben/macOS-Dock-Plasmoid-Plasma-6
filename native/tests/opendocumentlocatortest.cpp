#include "opendocumentlocator.h"

#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>

class OpenDocumentLocatorTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void matchesFileNameInTypicalWindowTitles()
    {
        const QString fileName = QStringLiteral("ai-knowledge.md");
        QVERIFY(OpenDocumentLocator::titleMentionsFile(
            fileName, QStringLiteral("ai-knowledge.md — Kate")));
        QVERIFY(OpenDocumentLocator::titleMentionsFile(
            fileName,
            QStringLiteral("ai-knowledge.md - Nextcloud - Visual Studio Code")));
        QVERIFY(OpenDocumentLocator::titleMentionsFile(
            fileName, QStringLiteral("AI-KNOWLEDGE.MD - Betrachter")));
    }

    void ignoresTitlesWithoutTheFile()
    {
        QVERIFY(!OpenDocumentLocator::titleMentionsFile(
            QStringLiteral("ai-knowledge.md"),
            QStringLiteral("Posteingang - Thunderbird")));
        QVERIFY(!OpenDocumentLocator::titleMentionsFile(
            QStringLiteral("Abstract.png"), QString()));
        QVERIFY(!OpenDocumentLocator::titleMentionsFile(
            QString(), QStringLiteral("Irgendein Fenster")));
    }

    void requiresAWordBoundaryBeforeTheMatch()
    {
        // Eine fremde Datei, deren Name den unsrigen nur enthält, darf nicht
        // als "Dokument aus diesem Ordner offen" durchgehen.
        QVERIFY(!OpenDocumentLocator::titleMentionsFile(
            QStringLiteral("Abstract.png"),
            QStringLiteral("MeinAbstract.png - Betrachter")));
        QVERIFY(OpenDocumentLocator::titleMentionsFile(
            QStringLiteral("Abstract.png"),
            QStringLiteral("Mein Abstract.png - Betrachter")));
        QVERIFY(OpenDocumentLocator::titleMentionsFile(
            QStringLiteral("Abstract.png"),
            QStringLiteral("/OneTouch/Nextcloud/Abstract.png")));
    }

    void allowsLongerNamesToExtendPastTheMatch()
    {
        // Auch die Sicherungskopie liegt im selben Ordner, die Antwort für den
        // Ordner bleibt damit richtig.
        QVERIFY(OpenDocumentLocator::titleMentionsFile(
            QStringLiteral("ai-knowledge.md"),
            QStringLiteral("ai-knowledge.md.bak-2026-07-21 — Kate")));
    }

    void rejectsShortAndGenericNames()
    {
        // Ohne Endung ist eine Mindestlänge nötig, sonst schlägt der Name in
        // beliebigen Fenstertiteln an.
        QVERIFY(!OpenDocumentLocator::titleMentionsFile(
            QStringLiteral("Notes"), QStringLiteral("Notes - Irgendwas")));
        QVERIFY(!OpenDocumentLocator::titleMentionsFile(
            QStringLiteral("a.md"), QStringLiteral("a.md - Kate")));
        QVERIFY(OpenDocumentLocator::titleMentionsFile(
            QStringLiteral("Reisekosten"),
            QStringLiteral("Reisekosten - ONLYOFFICE")));
    }

    void scansOnlyTheFolderItself()
    {
        QTemporaryDir folder;
        QVERIFY(folder.isValid());
        QVERIFY(writeFile(folder.filePath(QStringLiteral("Vertrag.docx"))));
        QVERIFY(QDir(folder.path()).mkdir(QStringLiteral("Unterordner")));
        QVERIFY(writeFile(folder.filePath(
            QStringLiteral("Unterordner/Versteckt.docx"))));
        // Punktdateien wie die Synchronisierdatenbank des Nextcloud-Clients
        // dürfen nicht mitzählen, sonst wäre die Antwort immer "ja".
        QVERIFY(writeFile(folder.filePath(QStringLiteral(".sync_ab12cd.db"))));

        OpenDocumentLocator locator;
        const QUrl folderUrl = QUrl::fromLocalFile(folder.path());

        QVERIFY(locator.hasOpenDocument(
            folderUrl, {QStringLiteral("Vertrag.docx - ONLYOFFICE")}));
        QVERIFY(!locator.hasOpenDocument(
            folderUrl, {QStringLiteral("Versteckt.docx - ONLYOFFICE")}));
        QVERIFY(!locator.hasOpenDocument(
            folderUrl, {QStringLiteral(".sync_ab12cd.db - Kate")}));
        QVERIFY(!locator.hasOpenDocument(
            folderUrl, {QStringLiteral("Posteingang - Thunderbird")}));
        QVERIFY(!locator.hasOpenDocument(folderUrl, {}));
    }

    void ignoresRemoteAndMissingFolders()
    {
        OpenDocumentLocator locator;
        const QStringList titles = {QStringLiteral("Vertrag.docx - ONLYOFFICE")};

        // KIO-Adressen würden ein blockierendes Netzlisting im Zeichenpfad
        // bedeuten und werden deshalb nicht gelesen.
        QVERIFY(!locator.hasOpenDocument(
            QUrl(QStringLiteral("smb://server/freigabe")), titles));
        QVERIFY(!locator.hasOpenDocument(
            QUrl::fromLocalFile(QStringLiteral("/gibt/es/nicht")), titles));
        QVERIFY(!locator.hasOpenDocument(QUrl(), titles));
    }

private:
    static bool writeFile(const QString &path)
    {
        QFile file(path);
        if (!file.open(QIODevice::WriteOnly)) {
            return false;
        }
        file.write("x");
        return true;
    }
};

QTEST_MAIN(OpenDocumentLocatorTest)

#include "opendocumentlocatortest.moc"
