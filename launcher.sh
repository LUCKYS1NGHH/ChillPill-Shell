#!/bin/bash

# copy the config file if it doesn't exists in user's config dir
if [[ ! -f "$HOME/.config/chillpill-shell/config.jsonc" ]] && [[ -f /usr/share/chillpill-shell/config.jsonc.example ]]; then
   install -Dm644 /usr/share/chillpill-shell/config.jsonc.example "$HOME/.config/chillpill-shell/config.jsonc"
fi

# copy the cava config if it doesn't exists in user's cache dir
if [[ ! -f "$HOME/.cache/chillpill-shell/cava.conf" ]] && [[ -f /usr/share/chillpill-shell/scripts/cava.conf ]]; then
   install -Dm644 /usr/share/chillpill-shell/scripts/cava.conf "$HOME/.cache/chillpill-shell/cava.conf"
fi

export LD_LIBRARY_PATH="$HOME/.config/quickshell/chillpill-shell/IslandBackend:$LD_LIBRARY_PATH"
export QML_IMPORT_PATH="/usr/share/chillpill-shell:$QML_IMPORT_PATH"
exec qs -p /usr/share/chillpill-shell
