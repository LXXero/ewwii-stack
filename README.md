# ewwii-stack

A complete vertical-bar desktop setup for **labwc** (and other wlroots compositors), built on [ewwii](https://github.com/Ewwii-sh/ewwii). System monitors, taskbar, system tray with native right-click menus, hover-reveal volume/brightness sliders, screen lock — all in one bar.

Two small custom daemons fill in the bits ewwii doesn't do natively:

| Daemon | Purpose |
|---|---|
| `wlr-taskd` | C daemon. Tracks toplevels via `wlr-foreign-toplevel-management`, assigns stable per-window IDs, pushes diffs to ewwii via `ewwii update` so the taskbar updates in ~100ms instead of polling. |
| `wlr-trayd` | Rust daemon. Hosts `StatusNotifierWatcher` on dbus, captures tray-app icons + menus, exposes them over a unix socket. Includes `wlr-tray-menu`, a tiny GTK4 popup that draws native right-click menus. |

## What you get

- **System monitor strip** at the top: clock, CPU/MEM/DISK/NET/TEMP/BAT graphs (conky-style), TOP processes by CPU
- **Taskbar** in the middle: alphabetically-sorted window list, focused/minimized state highlighting, left-click to focus, right-click to minimize
- **System tray** above the controls: native right-click menus that pop where you expect, NM-applet/flameshot/spotify/discord all just work
- **Bottom row**: volume (click to mute, scroll to adjust), brightness (scroll), wifi (opens `nm-connection-editor`), lock screen (`swaylock`)

## Repo layout

```
ewwii-stack/
├── wlr-taskd/        ← C taskbar daemon (Wayland foreign-toplevel)
├── wlr-trayd/        ← Rust tray daemon + GTK4 popup menu binary
├── ewwii/            ← ewwii config (rhai + scss) and helper scripts
├── labwc/            ← autostart snippet
├── install.sh        ← bootstrap: deps + build + symlink configs
├── INSTALL.md
└── README.md
```

## Quick start

```
git clone https://github.com/<you>/ewwii-stack.git
cd ewwii-stack
./install.sh
```

The installer pulls Arch dependencies (`sudo pacman -S …`), compiles both daemons, symlinks the ewwii config into `~/.config/ewwii/`, and prints the labwc autostart lines to append.

See [INSTALL.md](INSTALL.md) for hardware-specific knobs (battery name, network interface, brightness backlight, etc.).

## Why it exists

Most Wayland bars (waybar, sfwbar, …) bundle taskbar + tray + monitors into one binary. ewwii does monitors and widgets beautifully but ships no taskbar or tray. This stack fills that gap with two ~700-line daemons that talk to ewwii over its `update` IPC. End result: an ewwii bar that's actually usable as a daily-driver desktop bar without losing ewwii's customizability.

## Status

Built for and tested on **labwc 0.9** + **ewwii 0.6**. Should work on other wlroots compositors (sway, hyprland, river) but isn't tested there.

## License

MIT — see [LICENSE](LICENSE).
