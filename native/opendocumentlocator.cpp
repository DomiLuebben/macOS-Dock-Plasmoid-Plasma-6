#include "opendocumentlocator.h"

#include <QDir>
#include <QFileInfo>

namespace
{
// Ein Dateiname mit Endung ist als Zeichenkette schon aussagekräftig genug
// ("ai-knowledge.md"). Ohne Endung braucht er eine größere Mindestlänge, sonst
// schlägt eine Datei namens "Bilder" in jedem beliebigen Fenstertitel an.
constexpr int minimumLengthWithSuffix = 5;
constexpr int minimumLengthWithoutSuffix = 8;

bool hasFileSuffix(const QString &fileName)
{
    // Nur ein Punkt in der Mitte zählt: ".bashrc" ist eine versteckte Datei
    // ohne Endung, "foo." hat keine.
    const qsizetype dot = fileName.lastIndexOf(QLatin1Char('.'));
    return dot > 0 && dot < fileName.size() - 1;
}
}

OpenDocumentLocator::OpenDocumentLocator(QObject *parent)
    : QObject(parent)
{
}

bool OpenDocumentLocator::titleMentionsFile(const QString &fileName,
                                            const QString &windowTitle)
{
    if (fileName.isEmpty() || windowTitle.isEmpty()) {
        return false;
    }

    const int minimumLength = hasFileSuffix(fileName)
        ? minimumLengthWithSuffix
        : minimumLengthWithoutSuffix;
    if (fileName.size() < minimumLength) {
        return false;
    }

    qsizetype from = 0;
    while (from <= windowTitle.size() - fileName.size()) {
        const qsizetype at =
            windowTitle.indexOf(fileName, from, Qt::CaseInsensitive);
        if (at < 0) {
            return false;
        }
        // Der Treffer muss an einer Wortgrenze beginnen, sonst würde
        // "Abstract.png" auch in "MeinAbstract.png" anschlagen. Nach hinten
        // wird bewusst nicht geprüft: "ai-knowledge.md" darf in
        // "ai-knowledge.md.bak-2026-07-21" treffen — auch diese Datei liegt
        // im Ordner, die Antwort für den Ordner bleibt also richtig.
        if (at == 0 || !windowTitle.at(at - 1).isLetterOrNumber()) {
            return true;
        }
        from = at + 1;
    }
    return false;
}

bool OpenDocumentLocator::titlesMentionFile(const QString &fileName,
                                            const QStringList &windowTitles)
{
    for (const QString &windowTitle : windowTitles) {
        if (titleMentionsFile(fileName, windowTitle)) {
            return true;
        }
    }
    return false;
}

bool OpenDocumentLocator::hasOpenDocument(const QUrl &folderUrl,
                                          const QStringList &windowTitles) const
{
    if (windowTitles.isEmpty() || !folderUrl.isValid()
            || !folderUrl.isLocalFile()) {
        return false;
    }

    const QDir folder(folderUrl.toLocalFile());
    if (!folder.exists()) {
        return false;
    }

    // Ohne QDir::Hidden bleiben Punktdateien außen vor — sonst würde die
    // Synchronisierdatenbank des Nextcloud-Clients dauerhaft mitzählen.
    const QStringList fileNames = folder.entryList(
        QDir::Files | QDir::NoDotAndDotDot | QDir::Readable, QDir::Unsorted);
    for (const QString &fileName : fileNames) {
        if (titlesMentionFile(fileName, windowTitles)) {
            return true;
        }
    }
    return false;
}
