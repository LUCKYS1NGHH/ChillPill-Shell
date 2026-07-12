#!/bin/bash

# colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
die()   { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }

if [[ ! "$EUID" -eq 0 ]]; then
    die "Please run this script as root to install chillpill-shell. i have to setup some files."
fi

command -v quickshell >/dev/null || die "Quickshell not installed."
command -v cliphist >/dev/null || die "Cliphist not installed."
command -v nusgmon >/dev/null || die "Nusgmon not installed."
command -v inotifywait >/dev/null || die "Inotify not installed."
command -v brightnessctl >/dev/null || die "Brightnessctl not installed."
command -v cmake >/dev/null || die "Cmake not installed."

REAL_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)

# make directories
info "Creating few new directories"
mkdir -p /usr/share/chillpill-shell/IslandBackend
mkdir -p "$REAL_HOME/.config/chillpill-shell"

# build backend
info "Building backend from source files"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)

# copy directories
info "Copying scripts and share directory to /usr/share/chillpill-shell"
cp -r scripts /usr/share/chillpill-shell
cp -r share /usr/share/chillpill-shell

# copy QML files
info "Copying QML files"
install -m 644 qml/* /usr/share/chillpill-shell

# copy backend files
info "Copying backend files"
install -m 644 \
    build/libIslandBackend.so \
    build/libIslandBackendplugin.so \
    build/qmldir \
    build/IslandBackend.qmltypes \
    /usr/share/chillpill-shell/IslandBackend

# copy launcher (bash)
info "Copying the launcher.sh"
install -m 755 launcher.sh /usr/local/bin/chillpill-shell

# copy app launcher
info "Copying app launcher"
install -m 644 chillpill.desktop /usr/share/applications

# set correct permissions at last
info "Setting up right permissions"

chmod 755 /usr/share/chillpill-shell
chmod 755 /usr/share/chillpill-shell/share
chmod 755 /usr/share/chillpill-shell/share/*
chmod 755 /usr/share/chillpill-shell/scripts
chmod 755 /usr/share/chillpill-shell/scripts/*
chmod 755 /usr/share/chillpill-shell/IslandBackend
chmod 755 /usr/share/chillpill-shell/IslandBackend/*

# place config file if it not exists
if [[ ! -f "$REAL_HOME/.config/chillpill-shell/config.jsonc" ]]; then
   info "Copying config file to ~/.config/chillpill-shell"
   install -m 644 config.jsonc "$REAL_HOME/.config/chillpill-shell/config.jsonc"
fi

# chown back the files permission to real user
chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$REAL_HOME/.config/chillpill-shell"

# cleaning build files
info "Cleaning up build files"
rm -rf build

echo -e "\nRun the command 'chillpill-shell' to start now."
echo -e "or open 'CP-Shell' through your app launcher.\n"
