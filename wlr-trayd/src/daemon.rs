//! wlr-trayd — StatusNotifierItem host that ewwii's bar consumes via unix socket.
//!
//! The `system-tray` crate handles the SNI + DBusMenu protocols. We layer on top:
//!   - assign each tray a stable monotonic id
//!   - persist icons to disk (ARGB32 → PNG, or theme-name lookup)
//!   - cache the current menu tree per tray
//!   - expose a unix socket: list / activate / secondary / menu / menu-click
//!
//! Socket protocol (line-based, one command per connection):
//!   list                          -> id<TAB>title<TAB>icon_path<TAB>has_menu  (per active tray)
//!   activate <id>
//!   secondary <id>
//!   menu <id>                     -> JSON of [{id,label,enabled,visible,separator,toggle,children:[...]}]
//!   menu-click <id> <submenu_id>  -> dispatch the click via DBusMenu

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use anyhow::{anyhow, Context, Result};
use serde::Serialize;
use system_tray::client::{ActivateRequest, Client, Event, UpdateEvent};
use system_tray::item::{IconPixmap, StatusNotifierItem};
use system_tray::menu::{MenuItem, MenuType, TrayMenu};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::Mutex;

const ICON_DIR_NAME: &str = "ewwii_tray";

#[derive(Debug, Clone)]
struct TrayState {
    id: u32,
    address: String,                  // dbus name; used for activate calls
    title: String,
    tooltip: String,
    icon_path: PathBuf,               // empty PathBuf when not yet extracted
    icon_name: Option<String>,
    icon_pixmaps: Vec<IconPixmap>,
    icon_theme_path: Option<String>,
    menu_path: Option<String>,        // dbus path of the menu object
    menu: Option<TrayMenu>,
}

#[derive(Default)]
struct State {
    next_id: u32,
    by_addr: HashMap<String, TrayState>,
    by_id: HashMap<u32, String>,      // id -> address
}

impl State {
    fn new() -> Self {
        Self { next_id: 1, ..Default::default() }
    }

    fn upsert(&mut self, address: &str, item: &StatusNotifierItem) -> u32 {
        if let Some(t) = self.by_addr.get_mut(address) {
            t.title          = item.title.clone().unwrap_or_default();
            t.icon_name      = item.icon_name.clone();
            t.icon_pixmaps   = item.icon_pixmap.clone().unwrap_or_default();
            t.icon_theme_path= item.icon_theme_path.clone();
            t.menu_path      = item.menu.clone();
            return t.id;
        }
        let id = self.next_id;
        self.next_id += 1;
        let t = TrayState {
            id,
            address: address.to_string(),
            title:        item.title.clone().unwrap_or_default(),
            tooltip:      String::new(),
            icon_path:    PathBuf::new(),
            icon_name:    item.icon_name.clone(),
            icon_pixmaps: item.icon_pixmap.clone().unwrap_or_default(),
            icon_theme_path: item.icon_theme_path.clone(),
            menu_path:    item.menu.clone(),
            menu:         None,
        };
        self.by_addr.insert(address.to_string(), t);
        self.by_id.insert(id, address.to_string());
        id
    }

    fn remove(&mut self, address: &str) {
        if let Some(t) = self.by_addr.remove(address) {
            self.by_id.remove(&t.id);
            let _ = std::fs::remove_file(&t.icon_path);
        }
    }

    fn get_mut(&mut self, address: &str) -> Option<&mut TrayState> {
        self.by_addr.get_mut(address)
    }
}

fn icon_dir() -> PathBuf {
    let runtime = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
    PathBuf::from(runtime).join(ICON_DIR_NAME)
}

fn icon_file(id: u32) -> PathBuf {
    icon_dir().join(format!("{id}.png"))
}

fn socket_path() -> PathBuf {
    let runtime = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
    PathBuf::from(runtime).join("wlr-trayd.sock")
}

/// SNI sends pixmaps in network byte order ARGB32 (big-endian: [A,R,G,B]).
/// Convert to RGBA8 then write a PNG.
fn write_pixmap_png(pixmap: &IconPixmap, path: &Path) -> Result<()> {
    let w = u32::try_from(pixmap.width).map_err(|_| anyhow!("bad icon width"))?;
    let h = u32::try_from(pixmap.height).map_err(|_| anyhow!("bad icon height"))?;
    let expected = (w as usize) * (h as usize) * 4;
    if pixmap.pixels.len() < expected {
        return Err(anyhow!("icon pixmap too short: {} < {}", pixmap.pixels.len(), expected));
    }
    let mut rgba = Vec::with_capacity(expected);
    for chunk in pixmap.pixels.chunks_exact(4).take((w * h) as usize) {
        // chunk = [A, R, G, B]  →  [R, G, B, A]
        rgba.extend_from_slice(&[chunk[1], chunk[2], chunk[3], chunk[0]]);
    }
    let img = image::RgbaImage::from_raw(w, h, rgba)
        .ok_or_else(|| anyhow!("pixmap dims didn't match buffer"))?;
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).ok();
    }
    img.save(path).context("write png")?;
    Ok(())
}

/// Resolve a Freedesktop icon name to an absolute file path under the icon theme dirs.
/// Mirrors what scripts/app_icon does for the taskbar: walk known roots, pick the largest size.
fn resolve_icon_name(name: &str, theme_path: Option<&str>) -> Option<PathBuf> {
    let mut bases: Vec<PathBuf> = Vec::new();
    if let Some(tp) = theme_path { bases.push(PathBuf::from(tp)); }
    if let Some(home) = std::env::var_os("HOME") {
        bases.push(PathBuf::from(home).join(".local/share/icons"));
    }
    bases.push("/usr/share/icons".into());
    bases.push("/usr/share/pixmaps".into());

    let mut best: Option<(u32, PathBuf)> = None;
    for base in &bases {
        if !base.is_dir() { continue; }
        let _ = walk_for_icon(base, name, &mut best);
    }
    best.map(|(_sz, p)| p)
}

fn walk_for_icon(root: &Path, name: &str, best: &mut Option<(u32, PathBuf)>) -> std::io::Result<()> {
    let png  = format!("{name}.png");
    let svg  = format!("{name}.svg");
    let mut stack = vec![root.to_path_buf()];
    while let Some(dir) = stack.pop() {
        let entries = match std::fs::read_dir(&dir) { Ok(e) => e, Err(_) => continue };
        for e in entries.flatten() {
            let p = e.path();
            if p.is_dir() {
                stack.push(p);
                continue;
            }
            let fname = match p.file_name().and_then(|s| s.to_str()) {
                Some(s) => s,
                None => continue,
            };
            if fname == png || fname == svg {
                // crude size extraction: look for a "NxN" segment in path
                let size = p.components()
                    .filter_map(|c| c.as_os_str().to_str())
                    .find_map(|s| {
                        let mut parts = s.split('x');
                        let w = parts.next()?.parse::<u32>().ok()?;
                        let h = parts.next()?.parse::<u32>().ok()?;
                        Some(std::cmp::min(w, h))
                    })
                    .unwrap_or(0);
                let take = match best {
                    None => true,
                    Some((cur, _)) if size > *cur => true,
                    _ => false,
                };
                if take { *best = Some((size, p)); }
            }
        }
    }
    Ok(())
}

/// Persist a tray's current icon to its file path. Pixmap wins over name when both exist
/// (apps usually send both; pixmap is exact).
fn extract_icon(t: &mut TrayState) {
    let path = icon_file(t.id);
    if !t.icon_pixmaps.is_empty() {
        // pick largest pixmap (apps send several sizes)
        let biggest = t.icon_pixmaps.iter().max_by_key(|p| p.width * p.height).unwrap();
        if let Err(e) = write_pixmap_png(biggest, &path) {
            log::warn!("[{}] pixmap write failed: {e}", t.address);
        } else {
            t.icon_path = path;
            return;
        }
    }
    if let Some(name) = &t.icon_name {
        if let Some(resolved) = resolve_icon_name(name, t.icon_theme_path.as_deref()) {
            t.icon_path = resolved;
            return;
        }
        log::debug!("[{}] no icon for name '{name}'", t.address);
    }
    t.icon_path = PathBuf::new();
}

// ---- menu tree → flat JSON for ewwii consumption ----------------------------

#[derive(Serialize)]
struct MenuItemJson {
    id: i32,
    label: String,
    enabled: bool,
    visible: bool,
    separator: bool,
    toggle: i32, // 0=none, 1=checkmark/radio off, 2=checkmark/radio on
    children: Vec<MenuItemJson>,
}

fn menu_item_to_json(m: &MenuItem) -> MenuItemJson {
    let separator = matches!(m.menu_type, MenuType::Separator);
    let toggle = match m.toggle_state {
        system_tray::menu::ToggleState::Off => 1,
        system_tray::menu::ToggleState::On  => 2,
        _ => 0,
    };
    MenuItemJson {
        id: m.id,
        label: m.label.clone().unwrap_or_default(),
        enabled: m.enabled,
        visible: m.visible,
        separator,
        toggle: if matches!(m.toggle_type, system_tray::menu::ToggleType::CannotBeToggled) { 0 } else { toggle },
        children: m.submenu.iter().map(menu_item_to_json).collect(),
    }
}

/// Find a submenu by its numeric menu_id anywhere in the tree.
fn find_submenu(items: &[MenuItem], target: i32) -> Option<&[MenuItem]> {
    for it in items {
        if it.id == target {
            return Some(&it.submenu);
        }
        if let Some(found) = find_submenu(&it.submenu, target) {
            return Some(found);
        }
    }
    None
}

fn menu_to_json(menu: &TrayMenu) -> String {
    let items: Vec<MenuItemJson> = menu.submenus.iter().map(menu_item_to_json).collect();
    serde_json::to_string(&items).unwrap_or_else(|_| "[]".to_string())
}

// ---- socket handler ----------------------------------------------------------

async fn handle_client(
    client: Arc<Client>,
    state: Arc<Mutex<State>>,
    stream: UnixStream,
) -> Result<()> {
    let (rd, mut wr) = stream.into_split();
    let mut reader = BufReader::new(rd);
    let mut line = String::new();
    let n = reader.read_line(&mut line).await?;
    if n == 0 { return Ok(()); }
    let line = line.trim_end();
    let mut parts = line.split_whitespace();
    let cmd = match parts.next() { Some(c) => c, None => return Ok(()) };

    match cmd {
        "list" => {
            let st = state.lock().await;
            let mut entries: Vec<_> = st.by_addr.values().collect();
            // Stable sort by SNI app title — survives close/reopen.
            // Ties broken by daemon id so app-with-multiple-instances stays sane.
            entries.sort_by(|a, b| a.title.cmp(&b.title).then(a.id.cmp(&b.id)));
            for t in entries {
                let icon = t.icon_path.to_string_lossy();
                let has_menu = if t.menu.is_some() { "1" } else { "0" };
                let row = format!("{}\t{}\t{}\t{}\n", t.id, t.title, icon, has_menu);
                wr.write_all(row.as_bytes()).await?;
            }
        }
        "activate" | "secondary" => {
            let id: u32 = parts.next().and_then(|s| s.parse().ok()).unwrap_or(0);
            let addr = {
                let st = state.lock().await;
                st.by_id.get(&id).cloned()
            };
            if let Some(address) = addr {
                let req = if cmd == "activate" {
                    ActivateRequest::Default { address, x: 0, y: 0 }
                } else {
                    ActivateRequest::Secondary { address, x: 0, y: 0 }
                };
                if let Err(e) = client.activate(req).await {
                    log::warn!("activate failed: {e}");
                }
            }
        }
        "menu" => {
            let id: u32 = parts.next().and_then(|s| s.parse().ok()).unwrap_or(0);
            let json = {
                let st = state.lock().await;
                match st.by_id.get(&id).and_then(|a| st.by_addr.get(a)) {
                    Some(t) => t.menu.as_ref().map(menu_to_json).unwrap_or_else(|| "[]".into()),
                    None => "[]".into(),
                }
            };
            wr.write_all(json.as_bytes()).await?;
            wr.write_all(b"\n").await?;
        }
        "menu-flat" => {
            // TAB rows: menu_id<TAB>label<TAB>enabled<TAB>has_submenu<TAB>separator
            // Walks only visible items. Optional 2nd arg = parent menu_id to nest into (0 = root).
            let id: u32 = parts.next().and_then(|s| s.parse().ok()).unwrap_or(0);
            let parent: i32 = parts.next().and_then(|s| s.parse().ok()).unwrap_or(0);
            let st = state.lock().await;
            let items = st.by_id.get(&id)
                .and_then(|a| st.by_addr.get(a))
                .and_then(|t| t.menu.as_ref());
            if let Some(menu) = items {
                let pool: &[MenuItem] = if parent == 0 {
                    &menu.submenus
                } else {
                    find_submenu(&menu.submenus, parent).unwrap_or(&menu.submenus)
                };
                for it in pool {
                    if !it.visible { continue; }
                    let sep = matches!(it.menu_type, MenuType::Separator);
                    let has_sub = !it.submenu.is_empty();
                    let label = it.label.clone().unwrap_or_default();
                    let row = format!(
                        "{}\t{}\t{}\t{}\t{}\n",
                        it.id,
                        label,
                        if it.enabled { "1" } else { "0" },
                        if has_sub  { "1" } else { "0" },
                        if sep      { "1" } else { "0" },
                    );
                    wr.write_all(row.as_bytes()).await?;
                }
            }
        }
        "menu-click" => {
            let id: u32 = parts.next().and_then(|s| s.parse().ok()).unwrap_or(0);
            let sub: i32 = parts.next().and_then(|s| s.parse().ok()).unwrap_or(0);
            let (address, menu_path) = {
                let st = state.lock().await;
                match st.by_id.get(&id).and_then(|a| st.by_addr.get(a)) {
                    Some(t) => (t.address.clone(), t.menu_path.clone()),
                    None => (String::new(), None),
                }
            };
            if let Some(mp) = menu_path {
                let req = ActivateRequest::MenuItem { address, menu_path: mp, submenu_id: sub };
                if let Err(e) = client.activate(req).await {
                    log::warn!("menu-click failed: {e}");
                }
            }
        }
        _ => {}
    }
    Ok(())
}

// ---- main --------------------------------------------------------------------

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    std::fs::create_dir_all(icon_dir()).ok();

    let client = Arc::new(Client::new().await?);
    let mut tray_rx = client.subscribe();

    let state = Arc::new(Mutex::new(State::new()));

    // initial snapshot (Client may have items already if it raced our connect)
    {
        let mut st = state.lock().await;
        let initial = client.items();
        // items() returns Arc<std::sync::Mutex<...>>, NOT a tokio Mutex
        let guard = initial.lock().expect("items mutex poisoned");
        for (addr, (item, menu)) in guard.iter() {
            let id = st.upsert(addr, item);
            if let Some(t) = st.get_mut(addr) {
                extract_icon(t);
                t.menu = menu.clone();
                log::info!("[seed] id={id} title={:?}", t.title);
            }
        }
    }

    // socket listener
    let sock = socket_path();
    let _ = std::fs::remove_file(&sock);
    let listener = UnixListener::bind(&sock)?;
    let _ = std::fs::set_permissions(&sock, {
        use std::os::unix::fs::PermissionsExt;
        std::fs::Permissions::from_mode(0o600)
    });
    log::info!("listening on {}", sock.display());

    let listener_client = Arc::clone(&client);
    let listener_state  = Arc::clone(&state);
    tokio::spawn(async move {
        loop {
            match listener.accept().await {
                Ok((stream, _)) => {
                    let c = Arc::clone(&listener_client);
                    let s = Arc::clone(&listener_state);
                    tokio::spawn(async move {
                        if let Err(e) = handle_client(c, s, stream).await {
                            log::debug!("client error: {e}");
                        }
                    });
                }
                Err(e) => {
                    log::warn!("accept: {e}");
                    tokio::time::sleep(std::time::Duration::from_millis(200)).await;
                }
            }
        }
    });

    // main event loop — tray events into our state
    loop {
        match tray_rx.recv().await {
            Ok(Event::Add(address, item)) => {
                let mut st = state.lock().await;
                let id = st.upsert(&address, &item);
                if let Some(t) = st.get_mut(&address) {
                    extract_icon(t);
                    log::info!("[add] id={id} address={address} title={:?}", t.title);
                }
            }
            Ok(Event::Update(address, evt)) => {
                let mut st = state.lock().await;
                match evt {
                    UpdateEvent::Icon { icon_name, icon_pixmap } => {
                        if let Some(t) = st.get_mut(&address) {
                            t.icon_name = icon_name;
                            t.icon_pixmaps = icon_pixmap.unwrap_or_default();
                            extract_icon(t);
                        }
                    }
                    UpdateEvent::Title(title) => {
                        if let Some(t) = st.get_mut(&address) {
                            t.title = title.unwrap_or_default();
                        }
                    }
                    UpdateEvent::Tooltip(tt) => {
                        if let Some(t) = st.get_mut(&address) {
                            t.tooltip = tt.map(|x| x.title).unwrap_or_default();
                        }
                    }
                    UpdateEvent::Menu(menu) => {
                        if let Some(t) = st.get_mut(&address) {
                            t.menu = Some(menu);
                        }
                    }
                    UpdateEvent::MenuDiff(_) => {
                        // For simplicity, ask the Client for the fresh menu via its API.
                        // (Diffs would update existing items; we just re-fetch on next Menu event.)
                    }
                    _ => {}
                }
            }
            Ok(Event::Remove(address)) => {
                let mut st = state.lock().await;
                st.remove(&address);
                log::info!("[remove] address={address}");
            }
            Err(e) => {
                log::error!("tray channel closed: {e}");
                break;
            }
        }
    }

    let _ = std::fs::remove_file(&sock);
    Ok(())
}
