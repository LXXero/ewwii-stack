# Install

## Dependencies

```
sudo pacman -S \
  wayland wlr-protocols wayland-protocols   \
  gtk4 gtk4-layer-shell                     \
  rust gcc make pkgconf                     \
  ewwii                                     \
  jq nmcli brightnessctl wpctl playerctl    \
  flameshot grim                            \
  swaylock swayidle wlopm                   \
  nm-connection-editor network-manager-applet
```

If `ewwii` isn't in your distro's repos, install from AUR:

```
yay -S ewwii
```

Optional but useful:

- `conky` if you want a secondary monitor strip
- `xfce4-terminal` (default terminal for nmtui — change to your preferred terminal in `ewwii/ewwii.rhai`)

## Build & install

```
./install.sh
```

Steps the installer runs:

1. `cd wlr-taskd && ./build.sh`   → builds `wlr-taskd` + `wlr-task` into `~/.local/bin/`
2. `cd wlr-trayd && ./build.sh`   → builds `wlr-trayd` + `wlr-tray` + `wlr-tray-menu` into `~/.local/bin/`
3. Symlinks `ewwii/*` into `~/.config/ewwii/` (or copies if you prefer)
4. Prints the lines to add to `~/.config/labwc/autostart`

You can also do this manually — see what each `build.sh` does, it's three lines.

## Hardware-specific tweaks

The helper scripts assume reasonably common hardware. Edit `ewwii/scripts/*` if yours differs:

| Script | Hardcoded | What to change |
|---|---|---|
| `battery_icon`, `battery_time` | `BAT0` | Your battery's name (`ls /sys/class/power_supply/`) |
| `net_io` | `wlan0` | Your network interface (`ip link`) |
| `disk_io` | `nvme0n1` | Your main disk (`lsblk`) |
| `gpu_temp` | `amdgpu` hwmon | Set to `coretemp`, `nvidia`, etc. |
| `cpu_temp` (in `ewwii.rhai`) | `k10temp` (AMD Ryzen) | Your CPU temp sensor name |
| `fan_rpm` | `thinkpad` hwmon | Your fan sensor source |

Run `sensors` (from `lm_sensors`) and `ls /sys/class/hwmon/hwmon*/name` to see what your machine exposes.

## Display scale

If your bar feels too small or too big, your display scaling lives in `~/.config/kanshi/config` (not in this repo). Typical Wayland fractional scales are `1.25`, `1.33`, `1.5`.

## Tray menu positioning

`~/.config/ewwii/tray_menu.env` (created from `ewwii/tray_menu.env.example`) lets you nudge where the right-click popup appears without rebuilding:

```
WLR_TRAY_MENU_RIGHT_MARGIN=160   # px from right edge of screen
WLR_TRAY_MENU_TOP_FROM_BOTTOM=520 # px from bottom of screen for the menu's top edge
```

## labwc autostart

Append to `~/.config/labwc/autostart`:

```sh
~/.local/bin/wlr-taskd >/dev/null 2>&1 &
~/.local/bin/wlr-trayd >/dev/null 2>&1 &
ewwii daemon >/dev/null 2>&1 &
sleep 1 && ewwii open bar &
```

## Verifying

After login:

```
pgrep -a wlr-taskd wlr-trayd ewwii    # all three running
ewwii list-windows                     # should show 'bar'
~/.local/bin/wlr-task list             # should list your windows
~/.local/bin/wlr-tray list             # should list any SNI tray apps
```
