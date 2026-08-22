#!/bin/bash

# colors
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
BLUE_BG='\e[1;44m'
BLACK='\e[1;30m'
NC='\e[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
die()   { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }

bin_exists() { command -v "$1" >/dev/null; }

if [[ ! "$EUID" -eq 0 ]]; then
    die "Please run this script as root to install chillpill-shell. i have to setup some things."
fi

if [[ "$1" != "--skip-deps" ]]; then
  if command -v pacman &>/dev/null; then
      info "Installing dependencies in your Arch Linux."
      pacman -S --noconfirm --needed quickshell cliphist brightnessctl wl-clipboard \
             inotify-tools cmake qt6-multimedia python-psutil awww blueman pipewire

      PY=/usr/bin/python3

      if ! sudo -u "$SUDO_USER" "$PY" -m pip show holidays >/dev/null 2>/dev/null; then
         read -p "Do you want event dates in calendar popup? It just needs a python lib `holidays` to run [y/N]: " ask

         if [[ "$ask" == "y" || "$ask" == "Y" ]]; then
            if ! sudo -u "$SUDO_USER" "$PY" -m pip --version >/dev/null 2>/dev/null; then
               read -p "Pip not exists in your system. install? [Y/n]: " pip_install
               if [[ "$pip_install" != "n" && "$pip_install" != "N" ]]; then
                  pacman -S --noconfirm python-pip
               fi
            fi

            if sudo -u "$SUDO_USER" "$PY" -m pip --version >/dev/null 2>/dev/null; then
               sudo -u "$SUDO_USER" "$PY" -m pip install holidays --break-system-packages 2>/dev/null \
                 || warn "something wrong with pip, 'holidays' python lib fail to install."

               sudo -u "$SUDO_USER" "$PY" -c "import holidays" 2>/dev/null \
                 || warn "holidays installed but failing to import. check the dependency manually."
            fi
         fi
      fi

      # install nusgmon based on version update
      if [[ ! -d /tmp/nusgmon-build ]]; then
         git clone --depth=1 https://github.com/LUCKYS1NGHH/nusgmon.git /tmp/nusgmon-build
      fi

      nusgmon_install=0
      if bin_exists nusgmon; then
         [[ $(nusgmon --version) != $(/tmp/nusgmon-build/./nusgmon --version) ]] && nusgmon_install=1
      else
         nusgmon_install=1
      fi

      if (( nusgmon_install )); then
          info "Installing nusgmon (to record your bandwidth) through git"
          (cd /tmp/nusgmon-build && ./setup.sh)
      else
          info "nusgmon is already installed and up to date, skipping."
      fi
  fi
fi

bin_exists awww || die "Awww not installed."
bin_exists quickshell || die "Quickshell not installed."
bin_exists cliphist || die "Cliphist not installed."
bin_exists nusgmon || die "Nusgmon not installed."
bin_exists inotifywait || die "Inotify not installed."
bin_exists brightnessctl || die "Brightnessctl not installed."
bin_exists cmake || die "Cmake not installed."
bin_exists blueman-manager || warn "Blueman not installed." # warn here because not everyone use bluetooth
bin_exists pipewire || die "Pipewire not installed."
bin_exists wl-copy || die "Wl-clipabord not installed."

REAL_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)

if [[ -z "$REAL_HOME" ]]; then
   warn "Your home directory not found."
   while true; do
     read -p "Enter your home directory manually: " REAL_HOME
     if [[ -z "$REAL_HOME" ]]; then
        continue
     fi
     if [[ ! -d "$REAL_HOME" ]]; then
        warn "Directory not found."
        continue
     fi
     break
   done
fi

# make directories
info "Creating few new directories"
mkdir -p /usr/share/chillpill-shell/IslandBackend
mkdir -p "$REAL_HOME/.config/chillpill-shell"
mkdir -p "$REAL_HOME/.cache/chillpill-shell"
#mkdir -p /etc/systemd/user

# build backend
SRC_FILES=$(find . -name '*.cpp' -o -name '*.h' -o -name 'CMakeLists.txt')
HASH_FILE='.builds_hash'

needs_build=true
if [[ -d /usr/share/chillpill-shell/IslandBackend ]] && [[ -f "$HASH_FILE" ]]; then
    if sha256sum -c "$HASH_FILE" --status 2>/dev/null; then
        needs_build=false
    fi
fi

if $needs_build; then
    info "Building backend from source files"
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build -j$(nproc)

    info "Copying backend files"
    install -m 644 \
       build/libIslandBackend.so \
       build/libIslandBackendPlugin.so \
       build/qmldir \
       build/IslandBackend.qmltypes \
         /usr/share/chillpill-shell/IslandBackend

    sha256sum $SRC_FILES > "$HASH_FILE"
else
    info "No backend source changes, skipping backend build"
fi

# copy directories
info "Copying scripts and share directory to /usr/share/chillpill-shell"
cp -r scripts /usr/share/chillpill-shell
cp -r share /usr/share/chillpill-shell

# copy QML files
info "Copying QML files"
install -m 644 qml/* /usr/share/chillpill-shell

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
chmod 644 /usr/share/chillpill-shell/share/*
chmod 755 /usr/share/chillpill-shell/scripts
chmod 755 /usr/share/chillpill-shell/scripts/*
chmod 655 /usr/share/chillpill-shell/IslandBackend
chmod 644 /usr/share/chillpill-shell/IslandBackend/*

# setup config file
info "Setting up config file"
install -m 644 config.jsonc /usr/share/chillpill-shell/config.jsonc.example

if [[ -f "$REAL_HOME/.config/chillpill-shell/config.jsonc" ]]; then
   info "Updating your config file..."
   if [[ -f config_update.py ]] && bin_exists python3; then
      python3 config_update.py "$SUDO_USER" || warn "Config file update failed."
   else
      warn "config_update.py missing OR python not installed, skipping config update."
   fi
else
   install -m 644 config.jsonc "$REAL_HOME/.config/chillpill-shell/config.jsonc"
fi

# place systemd file
#info "Copying systemd file to /etc/systemd/user"
#install -m 644 chillpill-shell.service /etc/systemd/user/chillpill-shell.service

# chown back the files permission to real user
chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$REAL_HOME/.config/chillpill-shell"

# cleaning build files
info "Cleaning up build files"
rm -rf build

echo -e "\nRun the command '${GREEN}chillpill-shell${NC}' to start now."
echo -e "or open '${GREEN}CP-Shell${NC}' through your app launcher.\n"
echo -e "To auto-run at every startup, paste this code in your ${BLUE_BG} ${BLACK}~/.config/hypr/hyprland.lua ${NC} config:"
echo -e "${BLUE}hl.on(\"hyprland.start\", function()\n   hl.exec_cmd(\"chillpill-shell\")\nend)${NC}\n"
