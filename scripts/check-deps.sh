#!/usr/bin/env bash

# ChillPill-Shell dependency check. Prints one JSON array, exits 0 no matter what

out=""
add() { # id label cat arch nix desc found [copy]
  [[ -n "$out" ]] && out+=","
  local c="${8:-$4}"
  out+="{\"id\":\"$1\",\"label\":\"$2\",\"cat\":\"$3\",\"arch\":\"$4\",\"nix\":\"$5\",\"desc\":\"$6\",\"found\":$7,\"copyCmd\":\"$c\"}"
}
bin()  { command -v "$1" >/dev/null 2>&1; }
pkg()  { pkg-config --exists "$1" 2>/dev/null; }
font() { [[ "$(fc-match -f '%{family}' "$1" 2>/dev/null)" == *"$1"* ]]; }
qtimg() { pkg "$1" || [[ -e /usr/lib/qt6/plugins/imageformats/libqwebp.so || -e /usr/lib64/qt6/plugins/imageformats/libqwebp.so ]]; }
holpy() {
  local s="/usr/share/chillpill-shell/scripts/calendar_events.py"
  [[ -f "$s" ]] || s="$(cd "$(dirname "$0")" && pwd)/calendar_events.py"
  local p="$(head -1 "$s" 2>/dev/null | sed 's/^#!//')"
  [[ -z "$p" ]] && p="$(command -v python3)"
  [[ -n "$p" ]] && "$p" -c "import holidays" 2>/dev/null
}

add cliphist cliphist required cliphist cliphist "Clipboard history backend"                    $(bin cliphist && echo true || echo false)
add inotifywait inotify-tools required inotify-tools inotify-tools "File watcher" $(bin inotifywait && echo true || echo false)
add brightnessctl brightnessctl required brightnessctl brightnessctl "Backlight control"        $(bin brightnessctl && echo true || echo false)
add wl-copy wl-clipboard required wl-clipboard wl-clipboard "Wayland clipboard (wl-clipboard)"   $(bin wl-copy && echo true || echo false)
add pw-cli pipewire required pipewire pipewire "PipeWire audio server"                          $(bin pw-cli && echo true || echo false)
add blueman-applet blueman required blueman blueman "Bluetooth manager"                         $(bin blueman-applet && echo true || echo false)
add nusgmon nusgmon required "nusgmon (AUR)" nusgmon "Data usage backend"                       $(bin nusgmon && echo true || echo false)
add Qt6Multimedia qt6-multimedia required qt6-multimedia qt6-multimedia "Qt multimedia library" $(pkg Qt6Multimedia && echo true || echo false)

add Monocraft "Monocraft font" optional "ttf-monocraft-git / ttf-monocraft-nerd" monocraft "Text font family" $(font Monocraft && echo true || echo false)
add "JetBrainsMono Nerd Font" "JetBrainsMono Nerd Font" optional ttf-jetbrains-mono-nerd "jetbrains-mono-nerd" "UI and nerd icon font" $(font "JetBrainsMono Nerd Font" && echo true || echo false)
add Qt6ImageFormats qt6-imageformats optional qt6-imageformats qt6-imageformats "Extra image formats preview (e.g. WebP)" $(qtimg Qt6ImageFormats && echo true || echo false)
add holidays holidays optional holidays python3-holidays "Calendar event dates (Python / PIP package)"   $(holpy && echo true || echo false) "sudo python3 -m pip uninstall holidays -y --break-system-packages"
add cava cava optional cava cava "Audio visualizer"                                             $(bin cava && echo true || echo false)
add awww awww optional awww awww "Wallpaper backend"                                              $(bin awww && echo true || echo false)

add quickshell quickshell runtime quickshell quickshell "Quickshell runtime (qs)"               $(bin qs && echo true || echo false)
add chillpill chillpill-shell runtime chillpill-shell chillpill-shell "Main shell process"       $(pgrep -fx "qs -p /usr/share/chillpill-shell" >/dev/null 2>&1 && echo true || echo false)

echo "[$out]"
