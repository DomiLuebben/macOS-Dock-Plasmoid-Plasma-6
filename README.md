# macOS Dock Plasmoid for KDE Plasma 6

**English** | [Deutsch](README.de.md) | [Français](README.fr.md)

A standalone macOS-style dock for Plasma 6 with magnification, task
management, window controls, and a blurred background that follows the Qt
color scheme.

## Features

- Smooth macOS-style icon magnification on hover
- Drag-and-drop reordering of launchers and starters with mouse interaction
- Android-style app groups: drop one app onto the center of another, then open
  the animated group list to launch, rename, remove, or ungroup its apps;
  pinned launchers work whether their applications are open or closed
- Optional Downloads/folder stacks with a macOS-style file popover; drag
  folders from the file manager onto the Dock to add more
- Optional progress rings for Plasma jobs and Unity-compatible downloads on
  application icons and matching folder stacks
- Optional KDE Connect badges for recently received links and files; links
  are associated with the system's default browser
- Optional theme-aware Trash with empty/full state and file drop support
- Optional power/session menu with capability-aware sleep, restart, shutdown,
  screen-lock, and logout actions
- Optional virtual desktop switcher on the left or right, with numbers or
  Plasma's desktop names and a persistent button for creating more desktops
- Interactive live window previews on hover with per-window activation and close controls
- Launchers and running applications in a unified task manager
- Context-menu actions to open new windows and minimize, maximize, restore, or
  close individual and grouped windows
- Safe KWin window picker for force-quitting unresponsive windows
- Automatic hiding when a window is maximized
- Fullscreen-safe stacking and forced hiding for media players such as mpv and
  Dragon Player
- Configurable bottom, left, or right placement, always centered on the edge
- Animated slide-in and slide-out at every supported screen edge
- Background, border, and activity indicators based on the Qt system palette
- Theme or custom background color with configurable rounding, border, shadow,
  highlight, and blur
- Precise rounded blur region without a rectangular hover background
- Complete German, US English, and French interface selected from the system language

## Requirements

- KDE Plasma 6
- Qt 6 with Qt Quick/QML
- KDE Frameworks 6 WindowSystem, Service, Solid, I18n, and KIO
- CMake and a C++17 compiler
- Gettext (`msgfmt`) for the translation catalogs

KDE Connect is optional. When it is not installed or running, the recent-share
integration remains inactive without affecting the Dock.

On Arch Linux, the build dependencies can be installed with:

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

The installation script first builds the small native QML module used for the
blur region, KWin window actions, and optional integrations, then installs or
updates the plasmoid.

After choosing “Force Quit Application…”, the pointer becomes a window picker.
Select the unresponsive window or press `Esc` to cancel.

After installation, add **macOS Dock Task Manager** directly to the desktop
through the widget picker. Do not put it in a Plasma panel: the minimal,
invisible desktop widget only stores settings, while the Dock runs in its own
transparent window. Choose bottom, left, or right in the widget settings; the
Dock stays centered along the selected screen edge.

To create an app group, drag an app onto the center of another app. The target
expands immediately; release to group them. Dropping between icons still
reorders the Dock. Grouped apps keep Plasma's native running-task and minimize
behavior. If a grouped application owns several windows, selecting it opens a
nested window list instead of minimizing an arbitrary window.

When upgrading from an older version, first remove the Dock from its previous
Plasma panel. If that panel was created only for the Dock, remove the entire
panel. Then add the widget directly to the desktop.

## License

GPL-2.0-or-later
