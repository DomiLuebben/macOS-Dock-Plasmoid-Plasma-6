# macOS Dock Plasmoid pour KDE Plasma 6

[English](README.md) | [Deutsch](README.de.md) | **Français**

Un Dock autonome de style macOS pour Plasma 6, avec agrandissement des icônes,
gestion des tâches, contrôle des fenêtres et arrière-plan flouté adapté aux
couleurs du thème Qt.

## Fonctionnalités

- Agrandissement fluide des icônes au survol
- Lanceurs et applications en cours d’exécution dans un gestionnaire commun
- Actions de fenêtre et menus contextuels
- Masquage automatique lorsqu’une fenêtre est maximisée
- Animation d’entrée et de sortie sur chaque bord de l’écran
- Arrière-plan, bordure et indicateurs d’activité selon la palette Qt du système
- Zone de flou précisément arrondie, sans fond rectangulaire au survol
- Interface complète en allemand, anglais américain et français selon la langue du système

## Prérequis

- KDE Plasma 6
- Qt 6 avec Qt Quick/QML
- KDE Frameworks 6 WindowSystem
- CMake et un compilateur C++20
- Gettext (`msgfmt`) pour les catalogues de traduction

Sous Arch Linux, installez les dépendances de compilation avec :

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

Le script compile le petit module QML natif utilisé pour la zone de flou,
compile les traductions, puis installe ou met à jour le composant graphique.

Ajoutez ensuite **Gestionnaire de tâches macOS Dock** à un panneau Plasma depuis
le sélecteur de composants graphiques.

## Licence

GPL-2.0-or-later
