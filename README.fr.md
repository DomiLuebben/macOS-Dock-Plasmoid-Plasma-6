# macOS Dock Plasmoid pour KDE Plasma 6

[English](README.md) | [Deutsch](README.de.md) | **Français**

Un Dock autonome de style macOS pour Plasma 6, avec agrandissement des icônes,
gestion des tâches, contrôle des fenêtres et arrière-plan flouté adapté aux
couleurs du thème Qt.

## Fonctionnalités

- Agrandissement fluide des icônes au survol
- Réorganisation par glisser-déposer des lanceurs à la souris
- Piles de téléchargements/dossiers facultatives avec vue de fichiers de style
  macOS ; d’autres dossiers peuvent être glissés directement depuis le gestionnaire de fichiers
- Corbeille facultative adaptée au thème avec état vide/plein et dépôt de fichiers
- Sélecteur facultatif de bureaux à gauche ou à droite, avec numéros ou noms
  de bureaux définis dans Plasma et un bouton permanent pour en créer d’autres
- Aperçus interactifs des fenêtres avec activation et fermeture individuelles
- Lanceurs et applications en cours d’exécution dans un gestionnaire commun
- Menu contextuel pour ouvrir de nouvelles fenêtres et réduire, maximiser,
  restaurer ou fermer des fenêtres individuelles ou groupées
- Sélecteur de fenêtre KWin sécurisé pour forcer l’arrêt d’une fenêtre bloquée
- Masquage automatique lorsqu’une fenêtre est maximisée
- Empilement adapté au plein écran et masquage forcé pour les lecteurs comme
  mpv et Dragon Player
- Animation d’entrée et de sortie sur chaque bord de l’écran
- Arrière-plan, bordure et indicateurs d’activité selon la palette Qt du système
- Couleur d’arrière-plan du thème ou personnalisée, avec arrondi, bordure,
  ombre, reflet et flou configurables
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

Le script compile le petit module QML natif utilisé pour la zone de flou et
les actions KWin, compile les traductions, puis installe ou met à jour le
composant graphique.

Après « Forcer à quitter l’application… », le pointeur devient un sélecteur de
fenêtre. Sélectionnez la fenêtre bloquée ou appuyez sur `Échap` pour annuler.

Ajoutez ensuite **Gestionnaire de tâches macOS Dock** à un panneau Plasma depuis
le sélecteur de composants graphiques.

## Licence

GPL-2.0-or-later
