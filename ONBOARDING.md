# Onboarding — ewwii-stack

If you're a future Claude (or human) picking this up cold, read this before changing anything. It captures the architecture, the bugs we've already hit, and the design decisions we've already made.

---

## What this is

A vertical-bar desktop setup for **labwc** (and other wlroots compositors), built on top of [ewwii](https://github.com/Ewwii-sh/ewwii). It fills in the two things ewwii doesn't ship natively — a real taskbar and a system tray — with two small companion daemons that talk to ewwii over its `ewwii update` IPC.

---

## Architecture

```
┌─────────────────────────┐        ┌─────────────────────────┐
│ wlr-taskd  (C)          │        │ wlr-trayd  (Rust)       │
│ wlr-foreign-toplevel    │        │ StatusNotifierWatcher    │
│  → tracks windows       │        │  → tracks tray apps     │
│  → push state to ewwii  │ ───┐   │  → extracts icons       │
│    via `ewwii update`   │    │   │  → exposes unix socket  │
└─────────────────────────┘    │   └─────────────────────────┘
                               │             │
       /tmp/ewwii_wlrctl.list  │             │ /run/user/UID/wlr-trayd.sock
       (sorted toplevels)      │             │
                               ▼             ▼
                       ┌───────────────────────────┐
                       │ ewwii                     │
                       │  bar window (sidebar)     │
                       │  - clock, monitors, top   │
                       │  - taskbar (pre-alloc 32) │
                       │  - tray row  (pre-alloc 8)│
                       │  - vol/bri/wifi/lock      │
                       │  tray_menu window         │  ← rarely used; replaced by
                       └───────────────────────────┘    standalone wlr-tray-menu
                                                       (a GTK4 popup in its own process)
```

**Why two daemons instead of patching ewwii:** ewwii's plugin API (`ewwii_plugin_api` crate) only exposes `register_function` and `register_config_engine`. You **cannot add new widget types** through a plugin — that needs patching ewwii's core (the `WIDGET_NAME_SYSTRAY` line is commented out in `crates/ewwii/src/widgets/build_widget.rs:86`). So we built sidecar daemons and stream data into ewwii's existing widgets via the `ewwii update` IPC.

---

## The daemons

### wlr-taskd (C, ~700 lines)

Subscribes to `zwlr_foreign_toplevel_manager_v1`. Maintains a sorted (alphabetical-by-title) list of toplevels with stable per-window IDs. Three behaviors worth knowing:

1. **Push, don't poll.** On every batch of toplevel changes (delivered as `on_done`), the daemon diffs current vs. previous slot state and spawns `ewwii update <mappings>` with only the fields that changed. Sub-100ms taskbar updates instead of 1-second polling.

2. **Rate-limited, not debounced.** `BROADCAST_MIN_INTERVAL_MS = 100`. A spinner-title (xerotty, ghostty) fires title events constantly; a pure debounce ("wait for N ms of quiet") never settles because the spinner keeps resetting the timer. We use a rate limiter that broadcasts at most once per 100ms regardless of event rate.

3. **Taskbar debounce for new toplevels.** Brand-new toplevels are hidden from the bar for `TASKBAR_DEBOUNCE_MS = 1500`. Reason: flameshot creates a toplevel for its screen-capture overlay that lives for ~1s. Without debounce, the taskbar grows by a row, then shrinks, and the bar's layer surface gets reconfigured taller and never shrinks back. **Caveat**: when a real user-opened window appears, it shows in the taskbar 1.5s late.

4. **Single-focus invariant.** When `on_state` sets a toplevel's `activated=1`, we explicitly clear `activated` on every other toplevel. Some compositors fire the activate event for the new window but forget to fire the deactivate for the old one. Without this, the bar would show two focused rows.

5. **Slot reassignment ≠ field diff.** When sort order shifts (e.g. spinner-title rotation moves a window past its alphabetical neighbor), slot N now contains a DIFFERENT window. We detect `cur[i].id != prev_snap[i].id` and force-push ALL fields for that slot — otherwise the old window's focused class would carry over to the new occupant.

6. **Icon resolution in-daemon.** The daemon shells out to the user's `~/.config/ewwii/scripts/app_icon` whenever a slot's `app_id` changes and pushes the resulting path as `win_N_icon`. Avoids a polling lag where icons trail titles by up to 3s after a reshuffle.

Source: `wlr-taskd/wlr-taskd.c` (daemon) and `wlr-task.c` (tiny CLI client).

### wlr-trayd (Rust, ~500 lines daemon + ~300 lines menu binary)

Hosts `org.kde.StatusNotifierWatcher` on the session bus via the [`system-tray`](https://crates.io/crates/system-tray) crate. Tray apps (flameshot, nm-applet, spotify when configured, etc.) register with it, send their icon data, and publish a DBusMenu.

Three binaries:

- `wlr-trayd` — the daemon. Saves pixmap icons to `$XDG_RUNTIME_DIR/ewwii_tray/<id>.png`. Exposes unix socket with `list`, `activate <id>`, `secondary <id>`, `menu <id>`, `menu-flat <id>`, `menu-click <id> <submenu_id>`.
- `wlr-tray` — tiny CLI client (mirrors `wlr-task`).
- `wlr-tray-menu` — **separate GTK4 popup** for right-click menus. Uses `gtk4-layer-shell` for positioning. Spawned via `setsid` so ewwii's 200ms click-timeout doesn't kill it.

**Why a separate menu binary instead of rendering in ewwii:** ewwii can't render a *dynamic list* of menu items because its widget tree is built statically — no for-loop over a runtime list. We tried using `bound()` (returns `GlobalCompare`, not a widget — fails at runtime in the children array). We tried `jq()` and `.split()` on the polled value — both reject the `GlobalVar` wrapper. So the menu lives in its own GTK4 client which renders the items natively.

**Why we can't position the menu under the cursor:** Wayland doesn't expose global cursor coordinates to clients. The cursor is only delivered to a surface receiving pointer events. ewwii's right-click event has the click's widget-local (x,y) but doesn't forward them to the script handler — and even if it did, widget-local coords aren't screen coords. To get truly under-cursor popups, the icon and the menu would need to be in the SAME client (xdg-popup with the icon's surface as parent). We're not doing that. Positioning is computed heuristically from slot index + bar geometry.

Source: `wlr-trayd/src/{daemon,client,menu}.rs`.

---

## The ewwii config

`ewwii/ewwii.rhai` is the layout in Rhai. `ewwii/ewwii.scss` is the styling. `ewwii/scripts/` has ~30 helper scripts.

### Layout (top to bottom)

```
clock                ←  hour, minute, day, month
rule
cpu_section          ←  %, graph (60s history), freq, temp
rule
mem_section
rule
disk_section        ←  used/total, rd graph, wr graph, nvme temp
rule
net_section         ←  dn graph, up graph (KB/s)
rule
temp_section        ←  cpu/gpu/ssd temps + bars, fan rpm
rule
battery_section     ←  icon, %, progress bar, time remaining
rule
top_section         ←  top 5 by CPU (ps -eo)
rule
taskbar()           ←  32 pre-allocated slots
rule
[vexpand spacer]    ←  pushes the rest to the bottom of a full-height bar
tray_row()          ←  8 pre-allocated tray slots
rule
vol / bri / wifi / lock ←  horizontal row of 4 icons
```

### Slot architecture

The taskbar is **NOT dynamic**. There are 32 pre-allocated `task_btn(n, ...)` widgets in the layout, and the daemon's push updates per-slot globals (`win_1_title`, `win_2_title`, etc.). Slots whose `win_N_exists` is `"false"` collapse via `visible:` — see "gotcha #5" below.

Same for tray: 8 pre-allocated `tray_btn(n, ...)` slots, daemon pushes per-slot globals.

This is the only architecture ewwii allows. See "the dynamic taskbar dead-ends" below for what we tried.

### Window geometry

```rhai
defwindow("bar", #{
    monitor: 0,
    stacking: "fg",      // NOT "bg" — see gotcha #6
    exclusive: true,
    geometry: #{
        x: "0px", y: "0px",
        width: "150px", height: "100%",
        anchor: "center right",
    },
}, bar()),
```

Full-height bar with `vexpand` on the root box and a vexpand-spacer between the taskbar and tray_row. Layout absorbs any compositor configure-event size drift (e.g. when flameshot's overlay reconfigures the layer surface).

---

## Gotchas — bugs we've already hit, don't re-discover them

1. **ewwii `update <MAPPINGS>` uses COMMAS, not spaces.** The docs example shows `foo="val1" baz="val2"` which is misleading. Actual parser (see `crates/ewwii/src/opts.rs` → `parse_inject_var_map`) splits on `,`. Use `key1="val1",key2="val2"`.

2. **Rust argv requires valid UTF-8.** If any arg has a mid-codepoint truncated multi-byte sequence, `std::env::args()` either panics or silently drops args. Truncate titles by *codepoint count*, not byte length. See `utf8_step()` + `display_title()` in `wlr-taskd.c`.

3. **Em-dash in Rhai comments breaks the parser.** The Rhai parser (used by ewwii) panics with `byte index N is not a char boundary` when slicing a string that contains `—`. Stick to ASCII dashes in `.rhai` files.

4. **ewwii's `BufReader::lines()` requires a trailing newline.** A poll command using `printf "value"` (no `\n`) makes `BufReader::next_line()` block forever waiting for newline; the variable stays at its initial value. Always `echo` or `printf "%s\n"`.

5. **`visible: <GlobalVar>` only works when the value is exactly `"true"` or `"false"`.** Internally ewwii does `s.parse::<bool>()` (strict Rust bool parsing). Trailing newlines or other text → defaults to `true`. Use `echo true` / `echo false` (yes echo adds `\n`, BufReader strips it, parse succeeds; printf without `\n` blocks — see gotcha #4).

6. **`stacking: "bg"` puts the bar BEHIND the wallpaper on some compositor setups.** Use `"fg"` (which maps to wlr-layer-shell's "top" layer). Works reliably across wlroots compositors.

7. **`bound()` returns a `GlobalCompare`, not a widget.** You cannot return `bound([var], |v| { return box(...) })` to dynamically generate widget trees. The error is `Expected WidgetNode in children array, found ewwii_shared_utils::variables::GlobalCompare`. It works only for primitive values fed into props like `text:`, `value:`, `class:`.

8. **`split()` and `jq()` don't work on `GlobalVar` directly.** `Function not found: split (ewwii_shared_utils::variables::GlobalVar, ...)`. They need a Rust `String`. You can unwrap inside a `bound()` closure (e.g. `bound([var], |v| { v[0].split("...") })`), but only the closure's return-as-value path works — not widget rendering.

9. **`literal` widget is commented out** in ewwii's source (`crates/ewwii/src/widgets/build_widget.rs:64`). The docs mention it as TODO. Don't try to use it.

10. **Click handler timeout is 200ms.** ewwii's `run_command` does `wait_timeout(200ms)` and `child.kill()` on timeout. Any handler that needs to spawn a long-running process (like our GTK4 menu popup) must `setsid <cmd> &` and exit immediately so the parent ssees clean exit before the timeout.

11. **Wayland cursor position is not queryable.** No protocol delivers global cursor coords to clients; the cursor is only known to surfaces receiving input. So context menus that "pop where you clicked" need icon + menu in the SAME client (via xdg-popup). We don't, hence the heuristic positioning.

12. **Compositor `activated` events are inconsistent.** Some labwc paths fire `activated` for the new window but forget to fire `!activated` for the old. Daemon enforces a "at most one activated" invariant in `on_state`.

13. **Spinner-title windows shuffle slot order.** Alphabetical sort means a single character change in a title (xerotty's ⠐→⠂ spinner) can move a window past its neighbor. Always re-push all of a slot's fields when its `id` changes (slot replacement), not just the diff.

14. **app_icon's negative cache is sticky.** `~/.config/ewwii/scripts/app_icon` writes a 0-byte cache file when an app's icon resolves to nothing. Subsequent calls short-circuit to empty. After installing a new app, `find /tmp/ewwii_appicon_cache -size 0 -delete`. (Or the daemon's `resolve_icon` will skip this issue if it caches differently — currently it just shells out to the script.)

15. **`app_icon` had a desktop-file precedence bug.** Earlier the script would match `claude-code-url-handler.desktop` before `claude.desktop` because it did fuzzy match in the first dir before trying exact in other dirs. Now does all exact-passes first, falls back to fuzzy only after.

---

## The dynamic-taskbar dead ends

These were tried and don't work. Don't re-attempt unless ewwii adds new APIs:

- `for entry in <GlobalVar>` — the `for` only iterates local Rhai arrays
- `bound([var], |v| { return box(...) })` — bound returns GlobalCompare, not Widget
- `jq(var, ".[]")` — jq() rejects GlobalVar
- `literal` widget — commented out in source
- An ewwii plugin that adds a systray/tasklist widget — plugin API can't add widgets
- A separate wlr-tray-menu-style binary embedded *inside* ewwii's window — GTK4 removed GtkSocket/GtkPlug; no cross-process widget embedding
- A standalone GTK4 sibling layer-shell tray with xdg-popup — possible, but not built (would need to draw icons AND menus in one client; a real chunk of work)

So: **pre-allocated N slots with daemon push is the architecture**. Don't try to make it "truly dynamic" — that battle is lost at the toolkit level.

---

## Tunable knobs

- `~/.config/ewwii/tray_menu.env` — `WLR_TRAY_MENU_RIGHT_MARGIN`, `WLR_TRAY_MENU_TOP_FROM_BOTTOM` for menu position
- `wlr-taskd.c` — `TASKBAR_DEBOUNCE_MS` (default 1500), `BROADCAST_MIN_INTERVAL_MS` (default 100), `BCAST_SLOTS` (default 32), `BCAST_TITLE_DISP` (default 18 codepoints), `BCAST_TITLE_TRUNC` (default 14)
- `wlr-trayd/src/menu.rs` — `BAR_WIDTH`, `TRAY_BUTTON_WIDTH`, geometry constants
- `ewwii.rhai` — poll intervals are now safety-nets (default 5s-30s) since the daemon pushes in real time. Don't tighten unless the daemon isn't running.

---

## Development workflow

```bash
# rebuild daemon after editing C
~/git/ewwii-stack/wlr-taskd/build.sh
pkill -x wlr-taskd && setsid ~/.local/bin/wlr-taskd </dev/null >/dev/null 2>&1 &

# rebuild Rust daemon
cd ~/git/ewwii-stack/wlr-trayd && cargo build --release
install -Dm755 target/release/wlr-{trayd,tray,tray-menu} ~/.local/bin/
pkill -x wlr-trayd && setsid ~/.local/bin/wlr-trayd </dev/null >/dev/null 2>&1 &

# edit ewwii config, hot reload (most changes)
ewwii reload

# full ewwii restart (some changes — geometry, new polls, new defwindows)
pkill -x ewwii && sleep 1 && setsid ewwii daemon </dev/null >/dev/null 2>&1 &
sleep 4 && ewwii open bar

# debug
ewwii state                     # all GlobalVars and their current values
ewwii list-windows              # active windows
~/.local/bin/wlr-task list      # what wlr-taskd sees
~/.local/bin/wlr-tray list      # what wlr-trayd sees
cat ~/.cache/ewwii/ewwii_*.log  # ewwii panics, parser errors
```

---

## Hardware-specific paths in scripts

The helper scripts hardcode some device names. Adjust per machine:

| Script | Hardcoded | What to change |
|---|---|---|
| `battery_icon`, `battery_time` | `BAT0` | `ls /sys/class/power_supply/` |
| `net_io` | `wlan0` | `ip link` |
| `disk_io` | `nvme0n1` | `lsblk` |
| `gpu_temp`, `fan_rpm` | `amdgpu`, `thinkpad` hwmon names | `cat /sys/class/hwmon/hwmon*/name` |
| `cpu_temp` poll cmd in `ewwii.rhai` | `k10temp` | Your CPU sensor (`sensors`) |

---

## Repo

GitHub: [LXXero/ewwii-stack](https://github.com/LXXero/ewwii-stack)
