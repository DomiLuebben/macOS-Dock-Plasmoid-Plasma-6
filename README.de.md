# macOS Dock Plasmoid für KDE Plasma 6

[English](README.md) | **Deutsch** | [Français](README.fr.md)

Ein eigenständiges Plasma-6-Dock im macOS-Stil mit Vergrößerung, Taskmanager,
Fenstersteuerung und einem zum Qt-Farbschema passenden Blur-Hintergrund.

## Funktionen

- flüssige macOS-artige Vergrößerung beim Überfahren der Symbole
- Verschieben und Anordnen der Starter per Drag-and-Drop mit der Maus
- App-Gruppen im Android-Stil: Eine App mittig auf einer anderen ablegen, um
  sie zu gruppieren; Raster oder Liste dienen zum Starten, Umbenennen,
  Entfernen einzelner Apps oder Auflösen der Gruppe; angeheftete Starter
  funktionieren unabhängig davon, ob ihre App geöffnet oder geschlossen ist,
  einschließlich der Zuordnung von Wine-/Proton-`.exe`-Fenstern
- optionale Download-/Ordnerstapel mit macOS-artiger Dateiansicht; weitere
  Ordner lassen sich direkt aus dem Dateimanager auf das Dock ziehen; Liste,
  Raster oder Fächer werden in den Dock-Einstellungen ausgewählt
- optionale Fortschrittsringe für Plasma-Aufträge und Unity-kompatible
  Downloads auf Anwendungssymbolen und passenden Ordnerstapeln
- optionale KDE-Connect-Badges für kürzlich empfangene Links und Dateien;
  Links werden dem Standardbrowser des Systems zugeordnet
- optionaler, designkonformer Papierkorb mit Leer-/Vollstatus und Dateiablage
- optionales Energie-/Sitzungsmenü mit systemabhängig verfügbaren Aktionen für
  Energiesparmodus, Neustart, Herunterfahren, Bildschirmsperre und Abmeldung
- optionaler Desktopumschalter links oder rechts mit Zahlen oder den in Plasma
  festgelegten Desktopnamen sowie einer dauerhaften Schaltfläche für weitere Desktops
- interaktive Live-Fenstervorschauen mit Aktivieren und Schließen einzelner Fenster
- Launcher und laufende Anwendungen in einem gemeinsamen Taskmanager
- Kontextmenü zum Öffnen neuer Fenster sowie zum Minimieren, Maximieren,
  Wiederherstellen und Schließen einzelner oder gruppierter Fenster
- sichere KWin-Fensterauswahl zum sofortigen Beenden nicht reagierender Fenster
- automatisches Ausblenden bei maximierten Fenstern
- vollbildsichere Ebenen und erzwungenes Ausblenden bei Mediaplayern wie mpv
  und Dragon Player
- einstellbare Platzierung unten, links oder rechts, immer mittig am Rand
- animiertes Ein- und Ausfahren an allen unterstützten Bildschirmkanten
- Hintergrund, Rahmen und Aktivitätsanzeigen aus der Qt-Systempalette
- Theme- oder eigene Hintergrundfarbe sowie einstellbare Rundung, Rahmen,
  Schatten, Glanzlicht und Blur
- präzise, abgerundete Blur-Region ohne rechteckigen Hover-Hintergrund
- vollständige deutsche, US-englische und französische Oberfläche nach Systemsprache

## Voraussetzungen

- KDE Plasma 6
- Qt 6 mit Qt Quick/QML
- KDE Frameworks 6 WindowSystem, Service, Solid, I18n und KIO
- CMake und ein C++17-Compiler
- Gettext (`msgfmt`) für die Übersetzungskataloge

KDE Connect ist optional. Wenn es nicht installiert ist oder nicht läuft,
bleibt die Integration für kürzlich geteilte Elemente ohne Auswirkungen auf
das Dock inaktiv.

Unter Arch Linux werden die Build-Abhängigkeiten beispielsweise mit folgendem
Befehl installiert:

```bash
sudo pacman -S --needed base-devel cmake gettext qt6-declarative kservice kwindowsystem solid ki18n kio
```

## Installation

```bash
git clone https://github.com/DomiLuebben/macOS-Dock-Plasmoid-Plasma-6.git
cd macOS-Dock-Plasmoid-Plasma-6
./install.sh
systemctl --user restart plasma-plasmashell.service
```

Das Installationsskript baut zuerst das kleine native QML-Modul für die
Blur-Region, die KWin-Fensteraktionen und die optionalen Integrationen und
installiert bzw. aktualisiert anschließend das Plasmoid.

Bei „Anwendung sofort beenden …“ wird der Mauszeiger zur Zielauswahl. Klicke das
nicht reagierende Fenster an oder brich mit `Esc` ab.

Füge **macOS Dock Task Manager** über „Miniprogramme hinzufügen“ direkt zur
Arbeitsfläche hinzu. Er gehört nicht in eine Plasma-Leiste: Das unsichtbare,
minimale Desktop-Plasmoid speichert nur die Einstellungen, während das Dock in
einem eigenen transparenten Fenster läuft. In den Einstellungen kannst du
unten, links oder rechts wählen; am ausgewählten Bildschirmrand bleibt das
Dock immer mittig ausgerichtet.

Zum Erstellen einer App-Gruppe ziehst du eine App mittig auf eine andere. Das
Ziel vergrößert sich sofort; beim Loslassen entsteht die Gruppe. Das Ablegen
zwischen zwei Symbolen ordnet das Dock weiterhin nur neu. Gruppierte Apps
behalten Plasmas natives Verhalten für laufende Tasks und Minimieranimationen.
Besitzt eine gruppierte App mehrere Fenster, öffnet ihr Eintrag eine
verschachtelte Fensterauswahl, statt ein beliebiges Fenster zu minimieren.
Android-artiges Raster oder kompakte Liste lassen sich in den
Dock-Einstellungen auswählen.

Wenn du von einer älteren Version aktualisierst, entferne das Dock zuerst aus
der bisherigen Plasma-Leiste. Falls diese Leiste ausschließlich für das Dock
angelegt wurde, entferne die ganze Leiste. Füge das Miniprogramm anschließend
direkt zur Arbeitsfläche hinzu.

## Lizenz

GPL-2.0-or-later
