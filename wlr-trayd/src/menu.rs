//! wlr-tray-menu — native GTK4 popup that renders a tray's right-click menu.
//! Talks to wlr-trayd over its unix socket to fetch items and dispatch clicks.
//!
//! Usage:
//!   wlr-tray-menu <tray_id>

use std::io::{Read, Write};
use std::os::unix::net::UnixStream;

use gtk4::prelude::*;
use gtk4::{
    glib, Align, Application, ApplicationWindow, Box as GtkBox, Button, EventControllerKey,
    GestureClick, Label, Orientation, Overlay as GtkOverlay, Separator,
};
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};

const APP_ID: &str = "dev.ewwiistack.WlrTrayMenu";
const BAR_WIDTH: i32 = 150;
const TRAY_BUTTON_WIDTH: i32 = 24; // 16px icon + 4px horizontal padding on each side.
const TRAY_BUTTON_SPACING: i32 = 6;
const MENU_CURSOR_GAP: i32 = 8;
const TRAY_MENU_BOTTOM_MARGIN: i32 = 78;
const FALLBACK_MONITOR_HEIGHT: i32 = 1440;
const FALLBACK_MONITOR_WIDTH: i32 = 2304;
const MAX_EWWII_TRAY_SLOTS: i32 = 8;

fn socket_path() -> String {
    let runtime = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
    format!("{runtime}/wlr-trayd.sock")
}

fn talk(cmd: &str) -> Option<String> {
    let mut s = UnixStream::connect(socket_path()).ok()?;
    s.write_all(cmd.as_bytes()).ok()?;
    s.write_all(b"\n").ok()?;
    s.shutdown(std::net::Shutdown::Write).ok()?;
    let mut buf = String::new();
    s.read_to_string(&mut buf).ok()?;
    Some(buf)
}

#[derive(Debug, Clone)]
struct Item {
    id: i32,
    label: String,
    enabled: bool,
    has_submenu: bool,
    separator: bool,
}

fn fetch_items(tray_id: u32, parent_menu_id: i32) -> Vec<Item> {
    let cmd = if parent_menu_id == 0 {
        format!("menu-flat {tray_id}")
    } else {
        format!("menu-flat {tray_id} {parent_menu_id}")
    };
    let raw = talk(&cmd).unwrap_or_default();
    let mut out = Vec::new();
    for line in raw.lines() {
        let f: Vec<&str> = line.split('\t').collect();
        if f.len() < 5 {
            continue;
        }
        out.push(Item {
            id: f[0].parse().unwrap_or(0),
            label: f[1].to_string(),
            enabled: f[2] == "1",
            has_submenu: f[3] == "1",
            separator: f[4] == "1",
        });
    }
    out
}

fn env_i32(name: &str) -> Option<i32> {
    std::env::var(name).ok()?.parse().ok()
}

fn visible_tray_slots(slot: u32) -> i32 {
    let list_count = std::fs::read_to_string("/tmp/ewwii_tray.list")
        .ok()
        .map(|raw| raw.lines().filter(|line| !line.trim().is_empty()).count() as i32)
        .unwrap_or(0);

    list_count.max(slot as i32).clamp(1, MAX_EWWII_TRAY_SLOTS)
}

fn tray_icon_right_margin(slot: u32) -> i32 {
    if let Some(margin) = env_i32("WLR_TRAY_MENU_RIGHT_MARGIN") {
        return margin;
    }

    let slots = visible_tray_slots(slot);
    let slot_i = (slot as i32).clamp(1, slots) - 1;
    let row_width = slots * TRAY_BUTTON_WIDTH + (slots - 1) * TRAY_BUTTON_SPACING;
    let row_left = ((BAR_WIDTH - row_width) / 2).max(0);
    let icon_center_from_left =
        row_left + slot_i * (TRAY_BUTTON_WIDTH + TRAY_BUTTON_SPACING) + TRAY_BUTTON_WIDTH / 2;
    let icon_center_from_left =
        icon_center_from_left.clamp(TRAY_BUTTON_WIDTH / 2, BAR_WIDTH - TRAY_BUTTON_WIDTH / 2);

    BAR_WIDTH - icon_center_from_left + MENU_CURSOR_GAP
}

fn monitor_size() -> Option<(i32, i32)> {
    let display = gtk4::gdk::Display::default()?;
    let monitors = display.monitors();
    let monitor = monitors.item(0)?.downcast::<gtk4::gdk::Monitor>().ok()?;
    let geometry = monitor.geometry();

    Some((geometry.width(), geometry.height()))
}

fn tray_icon_bottom_margin() -> i32 {
    env_i32("WLR_TRAY_MENU_BOTTOM_MARGIN")
        .unwrap_or(TRAY_MENU_BOTTOM_MARGIN)
        .max(0)
}

fn build_menu_box(tray_id: u32, parent_menu_id: i32, slot: u32, app: &Application) -> GtkBox {
    let vbox = GtkBox::new(Orientation::Vertical, 0);
    vbox.add_css_class("menu");

    let items = fetch_items(tray_id, parent_menu_id);
    for it in items {
        if it.separator {
            let sep = Separator::new(Orientation::Horizontal);
            sep.add_css_class("menu-sep");
            vbox.append(&sep);
            continue;
        }
        let row = Button::new();
        row.add_css_class("menu-item");
        row.set_sensitive(it.enabled);

        let row_box = GtkBox::new(Orientation::Horizontal, 0);
        let lbl = Label::new(Some(&it.label));
        lbl.set_xalign(0.0);
        lbl.set_hexpand(true);
        row_box.append(&lbl);
        if it.has_submenu {
            let arrow = Label::new(Some("›"));
            arrow.add_css_class("menu-arrow");
            row_box.append(&arrow);
        }
        row.set_child(Some(&row_box));

        let id = it.id;
        let has_sub = it.has_submenu;
        let app_clone = app.clone();
        row.connect_clicked(move |_| {
            if has_sub {
                // Open a submenu in a new window; close current after.
                open_window(&app_clone, tray_id, id, slot);
            } else {
                let _ = talk(&format!("menu-click {tray_id} {id}"));
            }
            close_app_windows(&app_clone);
        });
        vbox.append(&row);
    }
    vbox
}

fn close_app_windows(app: &Application) {
    for w in app.windows() {
        w.close();
    }
}

fn open_window(app: &Application, tray_id: u32, parent_menu_id: i32, slot: u32) {
    let win = ApplicationWindow::new(app);
    win.init_layer_shell();
    win.set_layer(Layer::Top);
    win.set_keyboard_mode(KeyboardMode::OnDemand);
    win.set_anchor(Edge::Top, true);
    win.set_anchor(Edge::Right, true);
    win.set_anchor(Edge::Bottom, true);
    win.set_anchor(Edge::Left, true);
    let (monitor_width, monitor_height) =
        monitor_size().unwrap_or((FALLBACK_MONITOR_WIDTH, FALLBACK_MONITOR_HEIGHT));
    win.set_default_size(monitor_width, monitor_height);
    win.add_css_class("tray-menu-window");
    win.set_decorated(false);
    win.set_resizable(false);

    let overlay = GtkOverlay::new();
    let hitbox = GtkBox::new(Orientation::Vertical, 0);
    hitbox.set_hexpand(true);
    hitbox.set_vexpand(true);
    hitbox.set_can_target(true);
    hitbox.add_css_class("dismiss-overlay");

    let click = GestureClick::new();
    click.set_button(0);
    let app_for_click = app.clone();
    click.connect_pressed(move |_, _, _, _| close_app_windows(&app_for_click));
    hitbox.add_controller(click);

    let menu = build_menu_box(tray_id, parent_menu_id, slot, app);
    menu.set_halign(Align::End);
    menu.set_margin_end(tray_icon_right_margin(slot));
    if let Some(top_margin) = env_i32("WLR_TRAY_MENU_TOP_MARGIN") {
        menu.set_valign(Align::Start);
        menu.set_margin_top(top_margin.max(0));
    } else {
        menu.set_valign(Align::End);
        menu.set_margin_bottom(tray_icon_bottom_margin());
    }

    overlay.set_child(Some(&hitbox));
    overlay.add_overlay(&menu);
    win.set_child(Some(&overlay));

    // Escape closes.
    let key = EventControllerKey::new();
    let app_for_key = app.clone();
    key.connect_key_pressed(move |_, k, _, _| {
        if k == gtk4::gdk::Key::Escape {
            close_app_windows(&app_for_key);
            return glib::Propagation::Stop;
        }
        glib::Propagation::Proceed
    });
    win.add_controller(key);

    win.present();
}

fn load_css() {
    // Minimal tokyonight-inspired styling so the popup looks composed,
    // not the GTK default. The user's overall ewwii.scss is GTK4 CSS too,
    // but this lives in a separate process — own provider, own scope.
    let css = r#"
        window.tray-menu-window {
            background-color: transparent;
        }
        .dismiss-overlay {
            background-color: transparent;
        }
        .menu {
            background-color: rgba(26, 27, 38, 0.96);
            border: 1px solid #24283b;
            border-radius: 6px;
            padding: 4px 0;
            min-width: 200px;
            box-shadow: 0 6px 20px rgba(0,0,0,0.45);
        }
        .menu-item {
            background-color: transparent;
            border: none;
            border-radius: 0;
            padding: 6px 14px;
            color: #c0caf5;
        }
        .menu-item:hover {
            background-color: #24283b;
            color: #7aa2f7;
        }
        .menu-item:disabled {
            color: #565f89;
        }
        .menu-arrow { color: #565f89; padding-left: 8px; }
        .menu-sep {
            background-color: rgba(86, 95, 137, 0.4);
            min-height: 1px;
            margin: 4px 10px;
        }
    "#;
    let provider = gtk4::CssProvider::new();
    provider.load_from_data(css);
    if let Some(display) = gtk4::gdk::Display::default() {
        gtk4::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk4::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }
}

fn main() -> glib::ExitCode {
    let args: Vec<String> = std::env::args().collect();
    let tray_id: u32 = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(0);
    let slot: u32 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(1);
    if tray_id == 0 {
        eprintln!("usage: wlr-tray-menu <tray_id> [slot]");
        return 1.into();
    }
    let app = Application::builder()
        .application_id(APP_ID)
        .flags(gtk4::gio::ApplicationFlags::NON_UNIQUE)
        .build();
    app.connect_activate(move |app| {
        load_css();
        open_window(app, tray_id, 0, slot);
    });
    app.run_with_args::<&str>(&[])
}
