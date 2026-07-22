# macOS Dock Plasmoid für KDE Plasma 6

[English](README.md) | **Deutsch** | [Français](README.fr.md)

Ein eigenständiges Plasma-6-Dock im macOS-Stil mit Vergrößerung, Taskmanager,
Fenstersteuerung und einem zum Qt-Farbschema passenden Blur-Hintergrund.

## Funktionen

- flüssige macOS-artige Vergrößerung beim Überfahren der Symbole
- Verschieben und Anordnen der Starter per Drag-and-Drop mit der Maus
- optionale Download-/Ordnerstapel mit macOS-artiger Dateiansicht; weitere
  Ordner lassen sich direkt aus dem Dateimanager auf das Dock ziehen
- optionaler, designkonformer Papierkorb mit Leer-/Vollstatus und Dateiablage
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
- KDE Frameworks 6 WindowSystem
- CMake und ein C++20-Compiler
- Gettext (`msgfmt`) für die Übersetzungskataloge

Unter Arch Linux werden die Build-Abhängigkeiten beispielsweise mit folgendem
Befehl installiert:

```bash
sudo pacman -S --needed base-devel cmake gettext qt6-declarative kwindowsystem
```

## Installation

```bash
git clone https://github.com/DomiLuebben/macOS-Dock-Plasmoid-Plasma-6.git
cd macOS-Dock-Plasmoid-Plasma-6
./install.sh
systemctl --user restart plasma-plasmashell.service
```

Das Installationsskript baut zuerst das kleine native QML-Modul für die
Blur-Region und die KWin-Fensteraktionen und installiert bzw. aktualisiert
anschließend das Plasmoid.

Bei „Anwendung sofort beenden …“ wird der Mauszeiger zur Zielauswahl. Klicke das
nicht reagierende Fenster an oder brich mit `Esc` ab.

Füge **macOS Dock Task Manager** über „Miniprogramme hinzufügen“ direkt zur
Arbeitsfläche hinzu. Er gehört nicht in eine Plasma-Leiste: Das unsichtbare,
minimale Desktop-Plasmoid speichert nur die Einstellungen, während das Dock in
einem eigenen transparenten Fenster läuft. In den Einstellungen kannst du
unten, links oder rechts wählen; am ausgewählten Bildschirmrand bleibt das
Dock immer mittig ausgerichtet.

Wenn du von einer älteren Version aktualisierst, entferne das Dock zuerst aus
der bisherigen Plasma-Leiste. Falls diese Leiste ausschließlich für das Dock
angelegt wurde, entferne die ganze Leiste. Füge das Miniprogramm anschließend
direkt zur Arbeitsfläche hinzu.

## Lizenz

GPL-2.0-or-later
