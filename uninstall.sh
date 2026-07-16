#!/bin/bash

if [[ ! "$EUID" -eq 0 ]]; then
   echo "Please run this script as root, i need permissions to delete few files in '/'"
   exit 1
fi

if [[ -e /usr/share/chillpill-shell ]]; then
   rm -rf /usr/share/chillpill-shell
fi

if [[ -e /usr/local/bin/chillpill-shell ]]; then
   rm /usr/local/bin/chillpill-shell
fi

if [[ -e /usr/share/applications/chillpill.desktop ]]; then
   rm /usr/share/applications/chillpill.desktop
fi

if [[ -e /etc/systemd/user/chillpill-shell.service ]]; then
   rm /etc/systemd/user/chillpill-shell.service
fi

pkill qs

echo "ChillPill-Shell uninstalled successfully :("
