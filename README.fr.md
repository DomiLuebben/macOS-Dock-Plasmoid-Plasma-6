# macOS Dock Plasmoid pour KDE Plasma 6

[English](README.md) | [Deutsch](README.de.md) | **Français**

Un Dock autonome de style macOS pour Plasma 6, avec agrandissement des icônes,
gestion des tâches, contrôle des fenêtres et arrière-plan flouté adapté aux
couleurs du thème Qt.

## Fonctionnalités

- Agrandissement fluide des icônes au survol
- Réorganisation par glisser-déposer des lanceurs à la souris
- Groupes d’applications de style Android : déposez une application au centre
  d’une autre pour les regrouper, puis utilisez la grille ou la liste
  animée pour lancer, renommer, retirer ou dissocier les applications ; les
  lanceurs épinglés fonctionnent, que l’application soit ouverte ou fermée,
  y compris pour les fenêtres `.exe` de Wine/Proton
- Piles de téléchargements/dossiers facultatives avec vue de fichiers de style
  macOS ; d’autres dossiers peuvent être glissés directement depuis le
  gestionnaire de fichiers, avec une disposition en liste, grille ou éventail
  sélectionnée dans les réglages
- Anneaux de progression facultatifs pour les tâches Plasma et les
  téléchargements compatibles Unity sur les applications et les piles de dossiers correspondantes
- Badges KDE Connect facultatifs pour les liens et fichiers reçus récemment ;
  les liens sont associés au navigateur par défaut du système
- Corbeille facultative adaptée au thème avec état vide/plein et dépôt de fichiers
- Menu alimentation/session facultatif avec mise en veille, redémarrage, arrêt,
  verrouillage et déconnexion selon les capacités du système
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
- Placement configurable en bas, à gauche ou à droite, toujours centré sur le bord
- Animation d’entrée et de sortie sur chaque bord d’écran pris en charge
- Arrière-plan, bordure et indicateurs d’activité selon la palette Qt du système
- Couleur d’arrière-plan du thème ou personnalisée, avec arrondi, bordure,
  ombre, reflet et flou configurables
- Zone de flou précisément arrondie, sans fond rectangulaire au survol
- Interface complète en allemand, anglais américain et français selon la langue du système

## Prérequis

- KDE Plasma 6
- Qt 6 avec Qt Quick/QML
- KDE Frameworks 6 WindowSystem, Service, Solid, I18n et KIO
- CMake et un compilateur C++17
- Gettext (`msgfmt`) pour les catalogues de traduction

KDE Connect est facultatif. S’il n’est pas installé ou en cours d’exécution,
l’intégration des partages récents reste inactive sans affecter le Dock.

Sous Arch Linux, installez les dépendances de compilation avec :

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

Le script compile le petit module QML natif utilisé pour la zone de flou, les
actions KWin et les intégrations facultatives, compile les traductions, puis
installe ou met à jour le composant graphique.

Après « Forcer à quitter l’application… », le pointeur devient un sélecteur de
fenêtre. Sélectionnez la fenêtre bloquée ou appuyez sur `Échap` pour annuler.

Ajoutez ensuite **Gestionnaire de tâches macOS Dock** directement au bureau
depuis le sélecteur de composants graphiques. Ne l’ajoutez pas à un panneau
Plasma : le composant graphique de bureau, minimal et invisible, conserve
uniquement les réglages, tandis que le Dock s’exécute dans sa propre fenêtre
transparente. Choisissez le bas, la gauche ou la droite dans les réglages ; le
Dock reste toujours centré sur le bord d’écran sélectionné.

Pour créer un groupe, faites glisser une application au centre d’une autre. La
cible s’agrandit immédiatement ; relâchez pour créer le groupe. Un dépôt entre
deux icônes continue de simplement réorganiser le Dock. Les applications
groupées conservent le suivi natif des tâches et les animations de réduction de
Plasma. Lorsqu’une application groupée possède plusieurs fenêtres, son entrée
ouvre une liste de fenêtres imbriquée au lieu de réduire une fenêtre arbitraire.
La grille de style Android ou la liste compacte se sélectionne dans les
réglages du Dock.

Lors d’une mise à niveau depuis une ancienne version, retirez d’abord le Dock
de son ancien panneau Plasma. Si ce panneau a été créé uniquement pour le Dock,
supprimez le panneau entier. Ajoutez ensuite le composant directement au bureau.

## Licence

GPL-2.0-or-later
