#pragma once

#include <QObject>
#include <QStringList>
#include <QUrl>

/**
 * Beantwortet die Frage "hat ein laufendes Programm gerade eine Datei aus
 * diesem Ordner offen?".
 *
 * Der naheliegende Weg — offene Dateizeiger unter /proc durchsehen — trägt
 * nicht: Editoren halten ihr Dokument nicht dauerhaft offen, sie lesen es
 * einmal und schließen den Zeiger wieder. Am 04.09.2026 auf diesem Rechner
 * gemessen, standen unter dem Ordner nur der Nextcloud-Synchronisierdienst
 * (mit seiner eigenen Datenbank) und eine Shell — kein einziges Programm mit
 * einem geöffneten Dokument.
 *
 * Verlässlich verfügbar ist stattdessen der Fenstertitel: Editoren,
 * Office-Programme und Betrachter nennen dort den Dateinamen samt Endung.
 * Diese Klasse gleicht deshalb die Dateinamen des Ordners gegen die
 * Fenstertitel ab, die das QML aus dem Tasks-Model einsammelt.
 */
class OpenDocumentLocator : public QObject
{
    Q_OBJECT

public:
    explicit OpenDocumentLocator(QObject *parent = nullptr);

    /**
     * Wahr, sobald einer der Fenstertitel eine Datei benennt, die direkt in
     * folderUrl liegt. Nur lokale Ordner werden gelesen; für KIO-Adressen
     * (smb://, sftp:// …) wäre ein Verzeichnislisting eine blockierende
     * Netzabfrage im Zeichenpfad, deshalb liefert die Abfrage dort false.
     * Unterordner werden bewusst nicht durchsucht: der Nutzen wäre klein und
     * die Abfrage läuft beim Überfahren mit der Maus.
     */
    Q_INVOKABLE bool hasOpenDocument(const QUrl &folderUrl,
                                     const QStringList &windowTitles) const;

    /**
     * Die reine Zuordnungsregel ohne Dateisystemzugriff, damit sie sich
     * ohne Ordner auf der Platte prüfen lässt.
     */
    static bool titleMentionsFile(const QString &fileName,
                                  const QString &windowTitle);
    static bool titlesMentionFile(const QString &fileName,
                                  const QStringList &windowTitles);
};
