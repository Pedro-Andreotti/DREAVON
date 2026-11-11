#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$ROOT/build.sh"
# Ícone do widget na lista "Adicionar widgets".
install -Dm644 "$ROOT/package/contents/ui/assets/icon.png" "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps/dreavon.png"
if [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/local.dreavon" ]]; then
    kpackagetool6 -t Plasma/Applet -u "$ROOT/dreavon.plasmoid"
else
    kpackagetool6 -t Plasma/Applet -i "$ROOT/dreavon.plasmoid"
fi
echo 'Instalado. Em Adicionar ou gerenciar widgets, procure DREAVON.'
