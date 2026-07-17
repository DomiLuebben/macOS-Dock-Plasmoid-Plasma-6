#!/usr/bin/env bash

set -euo pipefail

PLASMOID_ID="org.kde.plasma.macosdock"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOCALE_NAME="${LC_ALL:-${LC_MESSAGES:-${LANG:-en_US}}}"

case "$LOCALE_NAME" in
    de*)
        MSG_NO_KPACKAGE='FEHLER: kpackagetool6 wurde nicht gefunden. KDE Plasma 6 wird benötigt.'
        MSG_NO_CMAKE='FEHLER: cmake wurde nicht gefunden und wird zum Bau des nativen Dock-Moduls benötigt.'
        MSG_NO_MSGFMT='FEHLER: msgfmt wurde nicht gefunden. Gettext wird zum Bau der Übersetzungen benötigt.'
        MSG_TRANSLATIONS='==> Baue deutsche und französische Übersetzungen ...'
        MSG_BUILD='==> Baue natives Dock-Modul ...'
        MSG_INSTALL="==> Installiere/Aktualisiere Plasmoid '$PLASMOID_ID' für KDE Plasma 6 ..."
        MSG_SUCCESS='==> Plasmoid erfolgreich installiert.'
        MSG_ADD="    Über 'Miniprogramme hinzufügen' kann es einer Plasma-Leiste hinzugefügt werden."
        MSG_NO_VIEWER='FEHLER: plasmoidviewer wurde nicht gefunden (Paket plasma-sdk).'
        MSG_PREVIEW='==> Starte Vorschau in plasmoidviewer ...'
        ;;
    fr*)
        MSG_NO_KPACKAGE='ERREUR : kpackagetool6 est introuvable. KDE Plasma 6 est requis.'
        MSG_NO_CMAKE='ERREUR : cmake est introuvable et est nécessaire pour compiler le module natif du Dock.'
        MSG_NO_MSGFMT='ERREUR : msgfmt est introuvable. Gettext est nécessaire pour compiler les traductions.'
        MSG_TRANSLATIONS='==> Compilation des traductions allemande et française...'
        MSG_BUILD='==> Compilation du module natif du Dock...'
        MSG_INSTALL="==> Installation/mise à jour du composant graphique '$PLASMOID_ID' pour KDE Plasma 6..."
        MSG_SUCCESS='==> Composant graphique installé avec succès.'
        MSG_ADD="    Ajoutez-le à un panneau Plasma depuis 'Ajouter des composants graphiques'."
        MSG_NO_VIEWER='ERREUR : plasmoidviewer est introuvable (paquet plasma-sdk).'
        MSG_PREVIEW='==> Lancement de l’aperçu dans plasmoidviewer...'
        ;;
    *)
        MSG_NO_KPACKAGE='ERROR: kpackagetool6 was not found. KDE Plasma 6 is required.'
        MSG_NO_CMAKE='ERROR: cmake was not found and is required to build the native Dock module.'
        MSG_NO_MSGFMT='ERROR: msgfmt was not found. Gettext is required to build the translations.'
        MSG_TRANSLATIONS='==> Building German and French translations...'
        MSG_BUILD='==> Building the native Dock module...'
        MSG_INSTALL="==> Installing/updating plasmoid '$PLASMOID_ID' for KDE Plasma 6..."
        MSG_SUCCESS='==> Plasmoid installed successfully.'
        MSG_ADD="    Add it to a Plasma panel through 'Add Widgets'."
        MSG_NO_VIEWER='ERROR: plasmoidviewer was not found (plasma-sdk package).'
        MSG_PREVIEW='==> Starting preview in plasmoidviewer...'
        ;;
esac

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    printf '%s\n' "$MSG_NO_KPACKAGE" >&2
    exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
    printf '%s\n' "$MSG_NO_CMAKE" >&2
    exit 1
fi

if ! command -v msgfmt >/dev/null 2>&1; then
    printf '%s\n' "$MSG_NO_MSGFMT" >&2
    exit 1
fi

printf '%s\n' "$MSG_TRANSLATIONS"
for language in de fr; do
    po_file="$SCRIPT_DIR/po/$language/plasma_applet_${PLASMOID_ID}.po"
    mo_dir="$SCRIPT_DIR/contents/locale/$language/LC_MESSAGES"
    install -d "$mo_dir"
    msgfmt --check --output-file="$mo_dir/plasma_applet_${PLASMOID_ID}.mo" "$po_file"
done

# Keep all native module build output inside the checked-out project. The
# directory is ignored by Git and can be reused by subsequent installations.
BUILD_DIR="$SCRIPT_DIR/build"

printf '%s\n' "$MSG_BUILD"
cmake -S "$SCRIPT_DIR/native" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --parallel
install -Dm755 "$BUILD_DIR/libmacosdockeffectsplugin.so" \
    "$SCRIPT_DIR/contents/ui/effects/libmacosdockeffectsplugin.so"

printf '%s\n' "$MSG_INSTALL"

if kpackagetool6 -t Plasma/Applet --show "$PLASMOID_ID" >/dev/null 2>&1; then
    kpackagetool6 -t Plasma/Applet --upgrade "$SCRIPT_DIR"
else
    kpackagetool6 -t Plasma/Applet --install "$SCRIPT_DIR"
fi

printf '%s\n' "$MSG_SUCCESS"
printf '%s\n' "$MSG_ADD"

case "${1:-}" in
    --preview|-p)
        if ! command -v plasmoidviewer >/dev/null 2>&1; then
            printf '%s\n' "$MSG_NO_VIEWER" >&2
            exit 1
        fi
        printf '%s\n' "$MSG_PREVIEW"
        exec plasmoidviewer -a "$PLASMOID_ID" -l bottomedge -f horizontal
        ;;
esac
