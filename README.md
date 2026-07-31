# ChillPill-Shell

A Lightweight and Feature-Rich dynamic pill shape bar made in Quickshell especially for those who don't have a Dedicated GPU (Like me) for their GNU/Linux Hyprland machine.

[![ChillPill-Shell 0.1.0](https://img.shields.io/badge/CPShell-0.1.0-blue.svg)](https://github.com/LUCKYS1NGHH/ChillPill-Shell)
[![Quickshell 0.3.0+](https://img.shields.io/badge/Quickshell-0.3.0+-green.svg)](https://github.com/quickshell-mirror/quickshell)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-orange.svg)](https://www.gnu.org/licenses/gpl-3.0)

---

### Resource Usage

- RAM: 200-500 MB (Average 350)
- CPU: Idle 0%, Average 3%, Min 0.1%, Max 10%
- GPU: Idle 0%, Average 15%, Min 6%, Max 50%

> CPU and GPU usage varies with system. a better CPU and GPU use less.

#### My Hardware

- RAM: 8GB (DDR3)
- CPU: i5 3337U (Dualcore)
- GPU: Intel HD 4000 (Integrated)

---

### Showcase

<table>
  <tr>
    <td width="50%">
      <p align="center"><b>Main pill bar</b></p>
      <img src="screenshots/image_1.webp" width="100%" alt="Main pill bar showing battery, volume, workspaces, wifi and clock" />
    </td>
    <td width="50%">
      <p align="center"><b>Control center</b></p>
      <img src="screenshots/image_2.webp" width="100%" alt="Control center with media player, sliders, few buttons and notification stack" />
    </td>
  </tr>
  <tr>
    <td width="50%">
      <p align="center"><b>Media player auto-open on media playing</b></p>
      <img src="screenshots/image_3.webp" width="100%" alt="Media player auto open" />
    </td>
    <td width="50%">
      <p align="center"><b>Notification popup (nusgmon-alert)</b></p>
      <img src="screenshots/image_4.webp" width="100%" alt="Notification popup of nusgmon-alert.sh" />
    </td>
  </tr>
  <tr>
    <td width="50%">
      <p align="center"><b>Cliphist (clipboard manager)</b></p>
      <img src="screenshots/image_5.webp" width="100%" alt="Cliphist clipboard history" />
    </td>
    <td width="50%">
      <p align="center"><b>Mini dashboard — calendar</b></p>
      <img src="screenshots/image_6.webp" width="100%" alt="Mini dashboard with calendar popup" />
    </td>
  </tr>
  <tr>
    <td width="50%">
      <p align="center"><b>Mini dashboard — weather</b></p>
      <img src="screenshots/image_7.webp" width="100%" alt="Mini dashboard with weather popup" />
    </td>
    <td width="50%">
      <p align="center"><b>Volume OSD (has more OSDs like brightness, battery, timer)</b></p>
      <img src="screenshots/image_8.webp" width="100%" alt="Volume OSD" />
    </td>
  </tr>
  <tr>
    <td width="50%">
      <p align="center"><b>App launcher</b></p>
      <img src="screenshots/image_9.webp" width="100%" alt="App launcher with search support and apps index status"
    </td>
    <td width="50%>
      <p align="center"><b>Control center — Wifi panel</b></p>
      <img src="screenshots/image_10.webp" width="100%" alt="Control center with wifi panel opened">
    </td>
</table>

### Features

- Main Pill Bar                : Battery, volume, workspaces, network, clock
- Control Center               : Media Player, Buttons (WiFi, Silent Notifications, Timer), Volume and Brightness Sliders, Notifications Stack
- Cliphist (Clipboard History) : Search, Clipboard images preview, Item index status, `Delete` key to delete any item
- Mini Dashboard               : Profile Image, Username, Hostname, Uptime, Battery, Basic network info, Today bandwidth usage, Datetime, Weather, Calendar, Power buttons (lock, sleep, shutdown, reboot)
- DBus Notification            : App icon (optional), summary, body (YES! you can ditch swaync/dunst fully now)
- OSD                          : Battery, volume, brightness, timer

<details>
<summary>Know more</summary>

---
- Main pill bar width expands on hover
- Audio (to mute/unmute) and workspaces (to switch) in the main pill bar are clickable.
- Control center's media player progress bar is not only for status, it's usable to control the media you playing.
- Control center has WiFi controller which has list of active networks and has password prompt. also timer minutes can be change by right
  click.
- Cliphist shows image previews from `~/.cache/quickshell/cliphist-imgs` by converting image binaries into real images and save there.
- Notifications are able to show in slide animation (like iOS mute) while you playing video game or watching movie in full screen.
  also it can show custom app icon to show in notification, else it shows bell icon.
- Your today's bandwidth status in mini dashboard is shown by [nusgmon](https://github.com/LUCKYS1NGHH/nusgmon) (i am the creator of it too).
---
</details>

### Configurable options
> Located at `~/.config/chillpill-shell/config.jsonc`

| Option | Description | Default |
|---|---|---|
| `displayPicture` | Profile image path for mini dashboard | `/home/<user>/.pfp.png` |
| `clockFormat` | Clock format for the pill bar | `hh:mm` |
| `pillTopMargin` | Top spacing of pill bar | `9` |
| `pillBottomMargin` | Bottom spacing of pill bar | `26` |
| `pillScale` | Scale factor for pill bar size | `1.0` |
| `textFontFamily` | Font family for general text | `Monocraft` |
| `nerdFontFamily` | Font family for icons (Nerd Fonts) | `JetBrainsMono Nerd Font Propo` |
| `timerPresets` | Timer minute presets | `[1, 5, 10, 15, 30]` |
| `mediaAutoOpenDuration` | Media-playing popup duration (ms) | `2000` |
| `maxWorkspaces` | Max workspaces shown in pill bar | `5` |
| `notificationDisplayTime` | Notification popup duration (ms) | `3000` |
| `maxNotificationsInStack` | Max notifications shown in stack | `20` |
| `avoidDuplicateNotifications` | Skip appending duplicate notifications to stack | `true` |
| `bandwidthRefreshInterval` | Bandwidth usage refresh interval (ms) | `300000` (5 min) |
| `screenLockAppCommand` | Screen lock command for mini dashboard's lock button | `hyprlock` |
| `osdDuration` | OSD (on-screen display) duration (ms) | `800` |
| `weatherLocation` | City for weather widget | `Delhi` |
| `weatherUnits` | Temperature units: `metric` (°C) or `imperial` (°F) | `metric` |
| `weatherRefreshInterval` | Weather refresh interval (ms) | `3600000` (1 hr) |
| `defaultTerminal` | Terminal used to open TUI apps from launcher | `kitty` |

<details>
<summary>Raw config example</summary>

```jsonc
{
  "displayPicture": "/home/<user>/.pfp.png",
  "clockFormat": "hh:mm",
  "pillTopMargin": 9,
  "pillBottomMargin": 26,
  "textFontFamily": "Monocraft",
  "nerdFontFamily": "JetBrainsMono Nerd Font Propo",
  "timerPresets": [1, 5, 10, 15, 30],
  "mediaAutoOpenDuration": 2000,
  "maxWorkspaces": 5,
  "notificationDisplayTime": 3000,
  "maxNotificationsInStack": 20,
  "bandwidthRefreshInterval": 300000,
  "screenLockAppCommand": "hyprlock",
  "osdDuration": 800,
  "weatherLocation": "Delhi",
  "weatherUnits": "metric",
  "weatherRefreshInterval": 3600000,
  "avoidDuplicateNotifications": true,
  "defaultTerminal": "kitty",
  "pillScale": 1.0
}
```
</details>

---

### Dependencies
> [!NOTE]
> It's an initial release, tested only on **Arch Linux** + **Hyprland**. other setups unsupported for now.
> Packages below are Arch's; find the equivalent for your distro.
> `brightnessctl` and `cliphist` are likely already installed on most systems.

- [cliphist](https://github.com/sentriz/cliphist)
- [nusgmon](https://github.com/LUCKYS1NGHH/nusgmon) — AUR package; non-Arch users can use the setup script instead
- [inotify-tools](https://github.com/inotify-tools/inotify-tools)
- [brightnessctl](https://github.com/Hummer12007/brightnessctl)
- [wl-clipboard](https://github.com/bugaevc/wl-clipboard)
- Qt Multimedia (`qt6-multimedia` on Arch)

> [!TIP]
> `install.sh` auto-installs all of the above for Arch users, **except** these optional fonts:
> - Monocraft Font (`ttf-monocraft-git` / `ttf-monocraft-nerd` on AUR)
> - JetBrainsMono Nerd Font (`ttf-jetbrains-mono-nerd` on Arch)

---

### Install

> [!TIP]
> Use my Hyprland [dotfiles](https://github.com/LUCKYS1NGHH/dotfiles), it's also made for No Dedicated GPU machines.
> You will get more better performance.


#### Arch users (AUR)

```
paru -S chillpill-shell
```

#### Other
```bash
git clone --depth=1 https://github.com/LUCKYS1NGHH/ChillPill-Shell.git
cd ChillPill-Shell
chmod +x install.sh
sudo ./install.sh
```

<details>
<summary>Uninstall?</summary>

#### Arch
```
paru -R chillpill-shell
```

#### Other
```bash
chmod +x uninstall.sh
sudo ./uninstall.sh
```
</details>

### Auto startup

To auto-run at every time you start your Hyprland, paste this line in your `~/.config/hypr/hyprland.lua` config file

```
hl.exec_cmd("chillpill-shell")
```

---

### Key Bindings

Keybindings are recommended for ChillPill-Shell in your Hyprland, Just paste this code in your Hyprland (Lua) config file.

> Adjust key combinations by your preferences

```
hl.bind(mainMod .. " + CTRL + C",  hl.dsp.exec_cmd("qs ipc -p /usr/share/chillpill-shell call controlCenter toggle"))
hl.bind(mainMod .. " + CTRL + V",  hl.dsp.exec_cmd("qs ipc -p /usr/share/chillpill-shell call cliphist toggle"))
hl.bind(mainMod .. " + CTRL + B",  hl.dsp.exec_cmd("qs ipc -p /usr/share/chillpill-shell call miniDashboard toggle"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("qs ipc -p /usr/share/chillpill-shell call appLauncher toggle"))
```

---

### Thanks

Special thanks to [enhaoswen](https://github.com/enhaoswen) for the Wi-Fi controller backend for Quickshell.

### Author

LUCKYS1NGHH / https://github.com/LUCKYS1NGHH/ChillPill-Shell
