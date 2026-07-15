# macOS Dock Plasmoid for KDE Plasma 6

**English** | [Deutsch](README.de.md)

A standalone macOS-style dock for Plasma 6 with magnification, task
management, window controls, and a blurred background that follows the Qt
color scheme.

## Features

- Smooth macOS-style icon magnification on hover
- Launchers and running applications in a unified task manager
- Window actions and context menus
- Automatic hiding when a window is maximized
- Animated slide-in and slide-out at every screen edge
- Background, border, and activity indicators based on the Qt system palette
- Precise rounded blur region without a rectangular hover background

## Requirements

- KDE Plasma 6
- Qt 6 with Qt Quick/QML
- KDE Frameworks 6 WindowSystem
- CMake and a C++20 compiler

On Arch Linux, the build dependencies can be installed with:

```bash
sudo pacman -S --needed base-devel cmake qt6-declarative kwindowsystem
```

## Installation

```bash
git clone https://github.com/DomiLuebben/macOS-Dock-Plasmoid-Plasma-6.git
cd macOS-Dock-Plasmoid-Plasma-6
./install.sh
systemctl --user restart plasma-plasmashell.service
```

The installation script first builds the small native QML module used for the
blur region and then installs or updates the plasmoid.

After installation, add **macOS Dock Task Manager** to a Plasma panel through
the widget picker.

## License

GPL-2.0-or-later
