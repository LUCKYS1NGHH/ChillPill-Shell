#!/bin/bash

export LD_LIBRARY_PATH="$HOME/.config/quickshell/chillpill-shell/IslandBackend:$LD_LIBRARY_PATH"
QML_IMPORT_PATH="$HOME/.config/quickshell/chillpill-shell" /usr/bin/qs -p ~/Playground/chillpill-shell
