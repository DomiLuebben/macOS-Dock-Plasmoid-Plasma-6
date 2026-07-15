# macOS Dock Plasmoid für KDE Plasma 6

[English](README.md) | **Deutsch** | [Français](README.fr.md)

Ein eigenständiges Plasma-6-Dock im macOS-Stil mit Vergrößerung, Taskmanager,
Fenstersteuerung und einem zum Qt-Farbschema passenden Blur-Hintergrund.

## Funktionen

- flüssige macOS-artige Vergrößerung beim Überfahren der Symbole
- Launcher und laufende Anwendungen in einem gemeinsamen Taskmanager
- Fensteraktionen und Kontextmenüs
- automatisches Ausblenden bei maximierten Fenstern
- animiertes Ein- und Ausfahren an allen Bildschirmkanten
- Hintergrund, Rahmen und Aktivitätsanzeigen aus der Qt-Systempalette
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
Blur-Region und installiert bzw. aktualisiert anschließend das Plasmoid.

Danach kann **macOS Dock Task Manager** über „Miniprogramme hinzufügen“ zu
einer Plasma-Leiste hinzugefügt werden.

## Lizenz

GPL-2.0-or-later
