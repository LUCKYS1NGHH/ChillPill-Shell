#!/usr/bin/env bash

export QML_IMPORT_PATH="/usr/share/chillpill-shell:$QML_IMPORT_PATH"

# lock with the built-in lockscreen; LOCK_NOW locks on start and quits after unlock
DIR="/usr/share/chillpill-shell"
LOCK_NOW=1 qs -p "$DIR/Lockscreen.qml"
