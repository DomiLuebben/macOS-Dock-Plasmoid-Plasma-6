#!/usr/bin/env bash

set -euo pipefail

PLASMOID_ID="org.kde.plasma.macosdock"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    printf 'FEHLER: kpackagetool6 wurde nicht gefunden. KDE Plasma 6 wird benötigt.\n' >&2
    exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
    printf 'FEHLER: cmake wurde nicht gefunden und wird zum Bau des Blur-Moduls benötigt.\n' >&2
    exit 1
fi

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

printf '==> Baue natives Blur-Modul ...\n'
cmake -S "$SCRIPT_DIR/native" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --parallel
install -Dm755 "$BUILD_DIR/libmacosdockeffectsplugin.so" \
    "$SCRIPT_DIR/contents/ui/effects/libmacosdockeffectsplugin.so"

printf "==> Installiere/Aktualisiere Plasmoid '%s' für KDE Plasma 6 ...\n" "$PLASMOID_ID"

if kpackagetool6 -t Plasma/Applet --show "$PLASMOID_ID" >/dev/null 2>&1; then
    kpackagetool6 -t Plasma/Applet --upgrade "$SCRIPT_DIR"
else
    kpackagetool6 -t Plasma/Applet --install "$SCRIPT_DIR"
fi

printf '==> Plasmoid erfolgreich installiert.\n'
printf "    Über 'Miniprogramme hinzufügen' kann es einer Plasma-Leiste hinzugefügt werden.\n"

case "${1:-}" in
    --preview|-p)
        if ! command -v plasmoidviewer >/dev/null 2>&1; then
            printf 'FEHLER: plasmoidviewer wurde nicht gefunden (Paket plasma-sdk).\n' >&2
            exit 1
        fi
        printf '==> Starte Vorschau in plasmoidviewer ...\n'
        exec plasmoidviewer -a "$PLASMOID_ID" -l bottomedge -f horizontal
        ;;
esac
