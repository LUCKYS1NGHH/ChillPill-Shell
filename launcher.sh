#!/bin/bash

export LD_LIBRARY_PATH="$HOME/.config/quickshell/chillpill-shell/IslandBackend:$LD_LIBRARY_PATH"
export QML_IMPORT_PATH="/usr/share/chillpill-shell:$QML_IMPORT_PATH"
exec qs -p /usr/share/chillpill-shell
