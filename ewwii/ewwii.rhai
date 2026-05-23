// -----------------------------------------------------------------------------
// Vertical bar — labwc / wlroots — gkrellm-vibe edition
// All icon glyphs come from shell scripts (printf '\xHH...') so they survive
// any source-encoding weirdness. Pwr-menu glyphs use Rhai \uHHHH escapes.
// -----------------------------------------------------------------------------

fn rule() {
  return box(#{ class: "rule", height: 1 }, []);
}

// ---- mail -------------------------------------------------------------------
// Shows when this host has a maildir (mail_status non-empty) AND no battery.
// On laptops the battery slot wins and mail stays hidden. Icon highlights via
// .has-mail when the unread count (mail_count) > 0.
fn mail_section() {
  return revealer(#{ transition: "slidedown", duration: "150ms",
                     reveal: mail_status != "" && has_battery != "true" }, [
    eventbox(#{
      class: "mail-box",
      cursor: "pointer",
      tooltip: "click to open mutt",
      onclick: "setsid -f xfce4-terminal -x mutt >/dev/null 2>&1",
    }, [
      box(#{ orientation: "h", space_evenly: false, halign: "center", spacing: 6,
             hexpand: true }, [
        label(#{ class: "mail-icon", text: icon_mail }),
        label(#{ class: mail_class,  text: mail_status }),
      ]),
    ]),
  ]);
}

// ---- clock ------------------------------------------------------------------
fn clock() {
  return box(#{ orientation: "v", class: "clock", space_evenly: false, spacing: 2,
                halign: "fill", hexpand: true }, [
    box(#{ orientation: "h", space_evenly: false, halign: "center", spacing: 1 }, [
      label(#{ class: "clock-hour", text: hour }),
      label(#{ class: "clock-sep",  text: ":" }),
      label(#{ class: "clock-min",  text: minute }),
    ]),
    box(#{ orientation: "h", space_evenly: false, halign: "center", spacing: 4 }, [
      label(#{ class: "clock-day", text: day }),
      label(#{ class: "clock-mon", text: month }),
    ]),
  ]);
}

// ---- CPU --------------------------------------------------------------------
fn cpu_section() {
  return box(#{ orientation: "v", space_evenly: false, spacing: 2, hexpand: true }, [
    box(#{ orientation: "h", space_evenly: false }, [
      label(#{ class: "metric-label", text: "CPU", xalign: 0.0, hexpand: true }),
      label(#{ class: "metric-val",   text: cpu_pct, xalign: 1.0 }),
      label(#{ class: "metric-val",   text: "%",     xalign: 0.0 }),
    ]),
    graph(#{ class: "g-cpu", value: cpu_pct, min: 0.0, max: 100.0,
             type: "fill", time_range: "60s", thickness: 1.0,
             width: 134, height: 28 }),
    box(#{ orientation: "h", space_evenly: false }, [
      label(#{ class: "metric-sub", text: cpu_freq, xalign: 0.0, hexpand: true }),
      label(#{ class: "metric-sub-hot", text: cpu_temp, xalign: 1.0 }),
      label(#{ class: "metric-sub-hot", text: "°",      xalign: 0.0 }),
    ]),
  ]);
}

// ---- MEM --------------------------------------------------------------------
fn mem_section() {
  return box(#{ orientation: "v", space_evenly: false, spacing: 2, hexpand: true }, [
    box(#{ orientation: "h", space_evenly: false }, [
      label(#{ class: "metric-label", text: "MEM", xalign: 0.0, hexpand: true }),
      label(#{ class: "metric-val",   text: mem_pct, xalign: 1.0 }),
      label(#{ class: "metric-val",   text: "%",     xalign: 0.0 }),
    ]),
    graph(#{ class: "g-mem", value: mem_pct, min: 0.0, max: 100.0,
             type: "fill", time_range: "60s", thickness: 1.0,
             width: 134, height: 28 }),
    box(#{ orientation: "h", space_evenly: false }, [
      label(#{ class: "metric-sub", text: mem_h,    xalign: 0.0, hexpand: true }),
      label(#{ class: "metric-sub", text: "sw",     xalign: 1.0 }),
      label(#{ class: "metric-sub", text: swap_pct, xalign: 1.0 }),
      label(#{ class: "metric-sub", text: "%",      xalign: 0.0 }),
    ]),
  ]);
}

// ---- DISK -------------------------------------------------------------------
fn disk_section() {
  return box(#{ orientation: "v", space_evenly: false, spacing: 2, hexpand: true }, [
    box(#{ orientation: "h", space_evenly: false }, [
      label(#{ class: "metric-label", text: "DISK", xalign: 0.0, hexpand: true }),
      label(#{ class: "metric-val",   text: disk_pct, xalign: 1.0 }),
      label(#{ class: "metric-val",   text: "%",      xalign: 0.0 }),
    ]),
    label(#{ class: "metric-sub", text: disk_h, xalign: 0.0 }),
    box(#{ orientation: "h", space_evenly: false }, [
      label(#{ class: "metric-sub", text: "rd",   xalign: 0.0 }),
      label(#{ class: "metric-sub", text: disk_rd, xalign: 1.0, hexpand: true }),
      label(#{ class: "metric-sub", text: "K",    xalign: 0.0 }),
    ]),
    graph(#{ class: "g-disk-rd", value: disk_rd, min: 0.0, max: 100000.0, dynamic: true,
             type: "fill", time_range: "60s", thickness: 1.0,
             width: 134, height: 18 }),
    box(#{ orientation: "h", space_evenly: false }, [
      label(#{ class: "metric-sub", text: "wr",   xalign: 0.0 }),
      label(#{ class: "metric-sub", text: disk_wr, xalign: 1.0, hexpand: true }),
      label(#{ class: "metric-sub", text: "K",    xalign: 0.0 }),
    ]),
    graph(#{ class: "g-disk-wr", value: disk_wr, min: 0.0, max: 100000.0, dynamic: true,
             type: "fill", time_range: "60s", thickness: 1.0,
             width: 134, height: 18 }),
  ]);
}

// ---- NET --------------------------------------------------------------------
fn net_section() {
  return box(#{ orientation: "v", space_evenly: false, spacing: 2, hexpand: true }, [
    box(#{ orientation: "h", space_evenly: false }, [
      label(#{ class: "metric-label", text: "NET", xalign: 0.0, hexpand: true }),
      label(#{ class: "metric-sub", text: "wlan0", xalign: 1.0 }),
    ]),
    box(#{ orientation: "h", space_evenly: false }, [
      label(#{ class: "metric-sub", text: "dn",   xalign: 0.0 }),
      label(#{ class: "metric-sub", text: net_dn, xalign: 1.0, hexpand: true }),
      label(#{ class: "metric-sub", text: "K",    xalign: 0.0 }),
    ]),
    graph(#{ class: "g-net-dn", value: net_dn, min: 0.0, max: 1000.0, dynamic: true,
             type: "fill", time_range: "60s", thickness: 1.0,
             width: 134, height: 18 }),
    box(#{ orientation: "h", space_evenly: false }, [
      label(#{ class: "metric-sub", text: "up",   xalign: 0.0 }),
      label(#{ class: "metric-sub", text: net_up, xalign: 1.0, hexpand: true }),
      label(#{ class: "metric-sub", text: "K",    xalign: 0.0 }),
    ]),
    graph(#{ class: "g-net-up", value: net_up, min: 0.0, max: 1000.0, dynamic: true,
             type: "fill", time_range: "60s", thickness: 1.0,
             width: 134, height: 18 }),
  ]);
}

// ---- TEMP -------------------------------------------------------------------
fn temp_row(label_text, value, klass) {
  return box(#{ orientation: "h", space_evenly: false }, [
    label(#{ class: "metric-sub", text: label_text, xalign: 0.0 }),
    label(#{ class: klass, text: value, xalign: 1.0, hexpand: true }),
    label(#{ class: klass, text: "°", xalign: 0.0 }),
    progress(#{ class: "t-bar", value: value, min: 0.0, max: 100.0,
                orientation: "h", width: 50, height: 4 }),
  ]);
}

fn temp_section() {
  return box(#{ orientation: "v", space_evenly: false, spacing: 2, hexpand: true }, [
    label(#{ class: "metric-label", text: "TEMP", xalign: 0.0 }),
    temp_row("cpu", cpu_temp,  "metric-sub-hot"),
    temp_row("gpu", gpu_temp,  "metric-sub-hot"),
    temp_row("ssd", nvme_temp, "metric-sub-hot"),
    box(#{ orientation: "h", space_evenly: false }, [
      label(#{ class: "metric-sub", text: "fan",   xalign: 0.0 }),
      label(#{ class: "metric-sub", text: fan_rpm, xalign: 1.0, hexpand: true }),
    ]),
  ]);
}

// ---- BATTERY ----------------------------------------------------------------
// Hidden on hosts without a battery (desktop); mail_section() fills the slot.
fn battery_section() {
  return revealer(#{ transition: "slidedown", duration: "150ms",
                     reveal: has_battery == "true" }, [
    box(#{ orientation: "v", space_evenly: false, spacing: 2, hexpand: true }, [
      box(#{ orientation: "h", space_evenly: false }, [
        label(#{ class: "metric-label", text: "BAT", xalign: 0.0, hexpand: true }),
        label(#{ class: "icon bat-icon", text: battery_icon, xalign: 1.0 }),
        label(#{ class: "metric-val", text: battery_pct, xalign: 1.0 }),
        label(#{ class: "metric-val", text: "%",         xalign: 0.0 }),
      ]),
      progress(#{ class: "bat-bar", value: battery_pct, min: 0.0, max: 100.0,
                  orientation: "h", width: 134, height: 5 }),
      box(#{ orientation: "h", space_evenly: false }, [
        label(#{ class: "metric-sub", text: battery_stat, xalign: 0.0, hexpand: true }),
        label(#{ class: "metric-sub", text: battery_time, xalign: 1.0 }),
      ]),
    ]),
  ]);
}

// ---- TOP processes ----------------------------------------------------------
fn top_row(name_v, val_v, val_class) {
  return box(#{ orientation: "h", space_evenly: false }, [
    label(#{ class: "metric-sub", text: name_v, xalign: 0.0, hexpand: true }),
    label(#{ class: val_class, text: val_v, xalign: 1.0 }),
  ]);
}

fn top_section() {
  return box(#{ orientation: "v", space_evenly: false, spacing: 1, hexpand: true }, [
    label(#{ class: "metric-label", text: "TOP", xalign: 0.0 }),
    top_row(top_cpu_n1, top_cpu_v1, "metric-val"),
    top_row(top_cpu_n2, top_cpu_v2, "metric-val"),
    top_row(top_cpu_n3, top_cpu_v3, "metric-val"),
    top_row(top_cpu_n4, top_cpu_v4, "metric-val"),
    top_row(top_cpu_n5, top_cpu_v5, "metric-val"),
  ]);
}

// ---- interactive controls ---------------------------------------------------
// ---- TRAY -------------------------------------------------------------------
fn tray_btn(n, title, icon_path, exists) {
  return eventbox(#{
    class: "tray-item",
    visible: exists,
    tooltip: title,
    cursor: "pointer",
    onclick:       "$HOME/.config/ewwii/scripts/tray_activate "  + n,
    onmiddleclick: "$HOME/.config/ewwii/scripts/tray_secondary " + n,
    onrightclick:  "$HOME/.config/ewwii/scripts/tray_menu_open " + n,
  }, [
    box(#{ orientation: "h", space_evenly: false }, [
      image(#{ path: icon_path, image_width: 13, image_height: 13,
               preserve_aspect_ratio: true }),
    ]),
  ]);
}

// ---- TRAY MENU POPUP --------------------------------------------------------
fn menu_item(n, lbl, klass, exists) {
  return eventbox(#{
    class: klass,
    visible: exists,
    cursor: "pointer",
    onclick: "$HOME/.config/ewwii/scripts/menu_click " + n,
  }, [
    label(#{ class: "menu-label", text: lbl, xalign: 0.0, hexpand: true }),
  ]);
}

fn tray_menu_widget() {
  return box(#{ class: "tray-menu", orientation: "v", space_evenly: false, spacing: 0 }, [
    menu_item( 1, menu_1_label,  menu_1_class,  menu_1_exists),
    menu_item( 2, menu_2_label,  menu_2_class,  menu_2_exists),
    menu_item( 3, menu_3_label,  menu_3_class,  menu_3_exists),
    menu_item( 4, menu_4_label,  menu_4_class,  menu_4_exists),
    menu_item( 5, menu_5_label,  menu_5_class,  menu_5_exists),
    menu_item( 6, menu_6_label,  menu_6_class,  menu_6_exists),
    menu_item( 7, menu_7_label,  menu_7_class,  menu_7_exists),
    menu_item( 8, menu_8_label,  menu_8_class,  menu_8_exists),
    menu_item( 9, menu_9_label,  menu_9_class,  menu_9_exists),
    menu_item(10, menu_10_label, menu_10_class, menu_10_exists),
    menu_item(11, menu_11_label, menu_11_class, menu_11_exists),
    menu_item(12, menu_12_label, menu_12_class, menu_12_exists),
  ]);
}

fn tray_row() {
  return box(#{ orientation: "h", space_evenly: false, halign: "center", spacing: 6 }, [
    tray_btn(1, tray_1_title, tray_1_icon, tray_1_exists),
    tray_btn(2, tray_2_title, tray_2_icon, tray_2_exists),
    tray_btn(3, tray_3_title, tray_3_icon, tray_3_exists),
    tray_btn(4, tray_4_title, tray_4_icon, tray_4_exists),
    tray_btn(5, tray_5_title, tray_5_icon, tray_5_exists),
    tray_btn(6, tray_6_title, tray_6_icon, tray_6_exists),
    tray_btn(7, tray_7_title, tray_7_icon, tray_7_exists),
    tray_btn(8, tray_8_title, tray_8_icon, tray_8_exists),
  ]);
}

fn vol() {
  let icon_class = if muted == "true" { "icon vol-muted" } else { "icon vol-icon" };
  return eventbox(#{
    class: icon_class,
    cursor: "pointer",
    tooltip: "scroll to adjust · click to mute · right-click for mixer",
    onclick:  "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    onrightclick: "setsid -f pavucontrol >/dev/null 2>&1",
    onscroll: "[ '{}' = 'up' ] && wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ || wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
  }, [
    box(#{ orientation: "v", space_evenly: false, spacing: 1 }, [
      label(#{ class: icon_class, text: volume_icon }),
      progress(#{ class: "ctl-bar ctl-vol", value: volume, min: 0.0, max: 100.0,
                  orientation: "h", width: 30, height: 3 }),
    ]),
  ]);
}

fn bri() {
  return eventbox(#{
    class: "icon bri-icon",
    cursor: "pointer",
    tooltip: "scroll to adjust brightness",
    onscroll: "[ '{}' = 'up' ] && brightnessctl set 5%+ || brightnessctl set 5%-",
  }, [
    box(#{ orientation: "v", space_evenly: false, spacing: 1 }, [
      label(#{ class: "icon bri-icon", text: icon_brightness }),
      progress(#{ class: "ctl-bar ctl-bri", value: brightness, min: 0.0, max: 100.0,
                  orientation: "h", width: 30, height: 3 }),
    ]),
  ]);
}

fn wifi() {
  let tip = if wifi_ssid != "" { wifi_ssid } else { "disconnected" };
  return box(#{ orientation: "v", tooltip: tip }, [
    button(#{ class: "icon wifi-icon", onclick: "nm-connection-editor &", label: wifi_icon }),
  ]);
}


// ---- TASKBAR ----------------------------------------------------------------
// Build one taskbar row from a parsed line of wlrctl_data
fn task_btn(n, title, klass, icon_path, exists) {
  return eventbox(#{
    class: klass,
    visible: exists,
    onclick:      "$HOME/.config/ewwii/scripts/focus_slot " + n,
    onrightclick: "$HOME/.config/ewwii/scripts/minimize_slot " + n,
    cursor: "pointer",
  }, [
    box(#{ orientation: "h", space_evenly: false, spacing: 4 }, [
      image(#{ path: icon_path, image_width: 10, image_height: 10,
               preserve_aspect_ratio: true }),
      label(#{ class: "tb-title", text: title, xalign: 0.0, hexpand: true }),
    ]),
  ]);
}

fn taskbar() {
  return box(#{ orientation: "v", space_evenly: false, spacing: 2, hexpand: true }, [
    label(#{ class: "metric-label", text: "WIN", xalign: 0.0 }),
    task_btn( 1, win_1_title, win_1_focused, win_1_icon, win_1_exists),
    task_btn( 2, win_2_title, win_2_focused, win_2_icon, win_2_exists),
    task_btn( 3, win_3_title, win_3_focused, win_3_icon, win_3_exists),
    task_btn( 4, win_4_title, win_4_focused, win_4_icon, win_4_exists),
    task_btn( 5, win_5_title, win_5_focused, win_5_icon, win_5_exists),
    task_btn( 6, win_6_title, win_6_focused, win_6_icon, win_6_exists),
    task_btn( 7, win_7_title, win_7_focused, win_7_icon, win_7_exists),
    task_btn( 8, win_8_title, win_8_focused, win_8_icon, win_8_exists),
    task_btn( 9, win_9_title, win_9_focused, win_9_icon, win_9_exists),
    task_btn(10, win_10_title, win_10_focused, win_10_icon, win_10_exists),
    task_btn(11, win_11_title, win_11_focused, win_11_icon, win_11_exists),
    task_btn(12, win_12_title, win_12_focused, win_12_icon, win_12_exists),
    task_btn(13, win_13_title, win_13_focused, win_13_icon, win_13_exists),
    task_btn(14, win_14_title, win_14_focused, win_14_icon, win_14_exists),
    task_btn(15, win_15_title, win_15_focused, win_15_icon, win_15_exists),
    task_btn(16, win_16_title, win_16_focused, win_16_icon, win_16_exists),
    task_btn(17, win_17_title, win_17_focused, win_17_icon, win_17_exists),
    task_btn(18, win_18_title, win_18_focused, win_18_icon, win_18_exists),
    task_btn(19, win_19_title, win_19_focused, win_19_icon, win_19_exists),
    task_btn(20, win_20_title, win_20_focused, win_20_icon, win_20_exists),
    task_btn(21, win_21_title, win_21_focused, win_21_icon, win_21_exists),
    task_btn(22, win_22_title, win_22_focused, win_22_icon, win_22_exists),
    task_btn(23, win_23_title, win_23_focused, win_23_icon, win_23_exists),
    task_btn(24, win_24_title, win_24_focused, win_24_icon, win_24_exists),
    task_btn(25, win_25_title, win_25_focused, win_25_icon, win_25_exists),
    task_btn(26, win_26_title, win_26_focused, win_26_icon, win_26_exists),
    task_btn(27, win_27_title, win_27_focused, win_27_icon, win_27_exists),
    task_btn(28, win_28_title, win_28_focused, win_28_icon, win_28_exists),
    task_btn(29, win_29_title, win_29_focused, win_29_icon, win_29_exists),
    task_btn(30, win_30_title, win_30_focused, win_30_icon, win_30_exists),
    task_btn(31, win_31_title, win_31_focused, win_31_icon, win_31_exists),
    task_btn(32, win_32_title, win_32_focused, win_32_icon, win_32_exists),
  ]);
}

fn lock_btn() {
  return box(#{ orientation: "v", tooltip: "lock" }, [
    button(#{ class: "icon pwr-lock",
              onclick: "swaylock -f -c 000000 &",
              label: icon_lock }),
  ]);
}

// ---- bar layout -------------------------------------------------------------
fn bar() {
  return box(#{ class: "bar", orientation: "v", space_evenly: false, spacing: 6,
                hexpand: true, vexpand: true }, [
    clock(),
    rule(),
    cpu_section(),
    rule(),
    mem_section(),
    rule(),
    disk_section(),
    rule(),
    net_section(),
    rule(),
    temp_section(),
    rule(),
    battery_section(),
    mail_section(),
    rule(),
    top_section(),
    rule(),
    taskbar(),
    rule(),
    /* Spacer fills remaining vertical space so the systray + bottom row of
     * icons pin to the bottom of the (full-height) bar. */
    box(#{ vexpand: true }, []),
    tray_row(),
    rule(),
    box(#{ orientation: "h", space_evenly: true, halign: "fill", hexpand: true }, [
      vol(), bri(), wifi(), lock_btn()
    ]),
  ]);
}

tree([
  // ---- date / time ---------------------------------------------------------
  poll("hour",   #{ initial: "00", interval: "10s", cmd: "date '+%H'" }),
  poll("minute", #{ initial: "00", interval: "10s", cmd: "date '+%M'" }),
  poll("day",    #{ initial: "01", interval: "10m", cmd: "date '+%d'" }),
  poll("month",  #{ initial: "??", interval: "10m", cmd: "date '+%b'" }),

  // ---- mail (hidden when maildir absent) -----------------------------------
  // mail_status is the pre-formatted "<new>/<total>" string shown in the bar.
  // mail_count is just <new> and is used to toggle the .has-mail highlight.
  poll("mail_count",  #{ initial: "0", interval: "5s",
    cmd: "$HOME/.config/ewwii/scripts/mail_count" }),
  poll("mail_status", #{ initial: "", interval: "5s",
    cmd: "$HOME/.config/ewwii/scripts/mail_status" }),
  poll("icon_mail",   #{ initial: "", interval: "1h",
    cmd: "$HOME/.config/ewwii/scripts/static_icon mail" }),
  poll("mail_class",  #{ initial: "mail-count", interval: "5s",
    cmd: "$HOME/.config/ewwii/scripts/mail_class" }),

  // ---- host capability flag: battery presence -----------------------------
  poll("has_battery", #{ initial: "false", interval: "1h",
    cmd: "ls /sys/class/power_supply/BAT* >/dev/null 2>&1 && echo true || echo false" }),

  // ---- monitors ------------------------------------------------------------
  poll("cpu_pct",   #{ initial: "0", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/cpu_pct" }),
  poll("cpu_freq",  #{ initial: "0", interval: "5s",
    cmd: "awk '/cpu MHz/{f+=$4; n++} END{printf \"%.1fG\\n\", f/n/1000}' /proc/cpuinfo" }),
  poll("cpu_temp",  #{ initial: "0", interval: "5s",
    cmd: "for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name 2>/dev/null)\" = k10temp ] && echo $(( $(cat $h/temp1_input) / 1000 )); done | head -1" }),
  poll("gpu_temp",  #{ initial: "0", interval: "5s",
    cmd: "$HOME/.config/ewwii/scripts/gpu_temp" }),
  poll("fan_rpm",   #{ initial: "0", interval: "5s",
    cmd: "$HOME/.config/ewwii/scripts/fan_rpm" }),

  poll("mem_pct",   #{ initial: "0", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/mem_pct" }),
  poll("swap_pct",  #{ initial: "0", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/swap_pct" }),
  poll("mem_h",     #{ initial: "?",  interval: "5s", cmd: "$HOME/.config/ewwii/scripts/mem_h" }),

  poll("disk_pct",  #{ initial: "0", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/disk_pct" }),
  poll("disk_h",    #{ initial: "?", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/disk_h" }),
  poll("disk_rd",   #{ initial: "0", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/disk_io rd" }),
  poll("disk_wr",   #{ initial: "0", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/disk_io wr" }),
  poll("nvme_temp", #{ initial: "0", interval: "5s",
    cmd: "for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name 2>/dev/null)\" = nvme ] && echo $(( $(cat $h/temp1_input) / 1000 )); done | head -1" }),

  poll("net_dn",    #{ initial: "0", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/net_io rx" }),
  poll("net_up",    #{ initial: "0", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/net_io tx" }),

  // ---- top processes -------------------------------------------------------
  poll("top_cpu_n1", #{ initial: "-", interval: "3s", cmd: "$HOME/.config/ewwii/scripts/top_name cpu 1" }),
  poll("top_cpu_v1", #{ initial: "0", interval: "3s", cmd: "$HOME/.config/ewwii/scripts/top_val  cpu 1" }),
  poll("top_cpu_n2", #{ initial: "-", interval: "3s", cmd: "$HOME/.config/ewwii/scripts/top_name cpu 2" }),
  poll("top_cpu_v2", #{ initial: "0", interval: "3s", cmd: "$HOME/.config/ewwii/scripts/top_val  cpu 2" }),
  poll("top_cpu_n3", #{ initial: "-", interval: "3s", cmd: "$HOME/.config/ewwii/scripts/top_name cpu 3" }),
  poll("top_cpu_v3", #{ initial: "0", interval: "3s", cmd: "$HOME/.config/ewwii/scripts/top_val  cpu 3" }),
  poll("top_cpu_n4", #{ initial: "-", interval: "3s", cmd: "$HOME/.config/ewwii/scripts/top_name cpu 4" }),
  poll("top_cpu_v4", #{ initial: "0", interval: "3s", cmd: "$HOME/.config/ewwii/scripts/top_val  cpu 4" }),
  poll("top_cpu_n5", #{ initial: "-", interval: "3s", cmd: "$HOME/.config/ewwii/scripts/top_name cpu 5" }),
  poll("top_cpu_v5", #{ initial: "0", interval: "3s", cmd: "$HOME/.config/ewwii/scripts/top_val  cpu 5" }),

  // ---- battery -------------------------------------------------------------
  poll("battery_pct",  #{ initial: "0", interval: "10s", cmd: "cat /sys/class/power_supply/BAT0/capacity" }),
  poll("battery_stat", #{ initial: "?", interval: "10s", cmd: "cat /sys/class/power_supply/BAT0/status" }),
  poll("battery_icon", #{ initial: "",  interval: "10s", cmd: "$HOME/.config/ewwii/scripts/battery_icon" }),
  poll("battery_time", #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/battery_time" }),

  // ---- wifi ----------------------------------------------------------------
  poll("wifi_icon", #{ initial: "", interval: "5s",  cmd: "$HOME/.config/ewwii/scripts/wifi_icon" }),
  poll("wifi_ssid", #{ initial: "", interval: "10s",
    cmd: "nmcli -t -f active,ssid dev wifi | awk -F: '$1==\"yes\"{print $2; exit}'" }),

  // ---- audio + brightness --------------------------------------------------
  poll("volume",      #{ initial: "0",     interval: "1s",
    cmd: "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}'" }),
  poll("muted",       #{ initial: "false", interval: "1s",
    cmd: "wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED && echo true || echo false" }),
  poll("volume_icon", #{ initial: "", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/volume_icon" }),
  poll("brightness",  #{ initial: "50", interval: "2s",
    cmd: "brightnessctl -m | awk -F, '{print substr($4,1,length($4)-1)}'" }),

  // ---- static icons (Write-tool-safe; emitted via printf hex) -------------
  // ---- taskbar cache refresh (one poll snapshots wlrctl for all slots) -----
  // ---- tray cache refresh ----
  poll("tray_refresh", #{ initial: "ok", interval: "1s",
    cmd: "$HOME/.local/bin/wlr-tray list > /tmp/ewwii_tray.list.tmp 2>/dev/null && mv -f /tmp/ewwii_tray.list.tmp /tmp/ewwii_tray.list; echo ok" }),

  poll("tray_1_title",  #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 1 title" }),
  poll("tray_1_icon",   #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 1 icon" }),
  poll("tray_1_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 1 exists" }),
  poll("tray_2_title",  #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 2 title" }),
  poll("tray_2_icon",   #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 2 icon" }),
  poll("tray_2_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 2 exists" }),
  poll("tray_3_title",  #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 3 title" }),
  poll("tray_3_icon",   #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 3 icon" }),
  poll("tray_3_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 3 exists" }),
  poll("tray_4_title",  #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 4 title" }),
  poll("tray_4_icon",   #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 4 icon" }),
  poll("tray_4_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 4 exists" }),
  poll("tray_5_title",  #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 5 title" }),
  poll("tray_5_icon",   #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 5 icon" }),
  poll("tray_5_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 5 exists" }),
  poll("tray_6_title",  #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 6 title" }),
  poll("tray_6_icon",   #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 6 icon" }),
  poll("tray_6_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 6 exists" }),
  poll("tray_7_title",  #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 7 title" }),
  poll("tray_7_icon",   #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 7 icon" }),
  poll("tray_7_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 7 exists" }),
  poll("tray_8_title",  #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 8 title" }),
  poll("tray_8_icon",   #{ initial: "", interval: "2s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 8 icon" }),
  poll("tray_8_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/tray_slot 8 exists" }),
  // ---- tray menu cache refresh (only writes when a tray is currently targeted) ----
  poll("menu_refresh", #{ initial: "ok", interval: "1s",
    cmd: "tray=$(cat /tmp/ewwii_tray_current 2>/dev/null); if [ -n \"$tray\" ]; then $HOME/.local/bin/wlr-tray menu-flat \"$tray\" > /tmp/ewwii_menu.list.tmp 2>/dev/null && mv -f /tmp/ewwii_menu.list.tmp /tmp/ewwii_menu.list; fi; echo ok" }),

  poll("menu_1_label",  #{ initial: "", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 1 label" }),
  poll("menu_1_class",  #{ initial: "menu-empty", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 1 class" }),
  poll("menu_1_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 1 exists" }),
  poll("menu_2_label",  #{ initial: "", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 2 label" }),
  poll("menu_2_class",  #{ initial: "menu-empty", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 2 class" }),
  poll("menu_2_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 2 exists" }),
  poll("menu_3_label",  #{ initial: "", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 3 label" }),
  poll("menu_3_class",  #{ initial: "menu-empty", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 3 class" }),
  poll("menu_3_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 3 exists" }),
  poll("menu_4_label",  #{ initial: "", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 4 label" }),
  poll("menu_4_class",  #{ initial: "menu-empty", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 4 class" }),
  poll("menu_4_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 4 exists" }),
  poll("menu_5_label",  #{ initial: "", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 5 label" }),
  poll("menu_5_class",  #{ initial: "menu-empty", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 5 class" }),
  poll("menu_5_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 5 exists" }),
  poll("menu_6_label",  #{ initial: "", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 6 label" }),
  poll("menu_6_class",  #{ initial: "menu-empty", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 6 class" }),
  poll("menu_6_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 6 exists" }),
  poll("menu_7_label",  #{ initial: "", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 7 label" }),
  poll("menu_7_class",  #{ initial: "menu-empty", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 7 class" }),
  poll("menu_7_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 7 exists" }),
  poll("menu_8_label",  #{ initial: "", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 8 label" }),
  poll("menu_8_class",  #{ initial: "menu-empty", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 8 class" }),
  poll("menu_8_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 8 exists" }),
  poll("menu_9_label",  #{ initial: "", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 9 label" }),
  poll("menu_9_class",  #{ initial: "menu-empty", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 9 class" }),
  poll("menu_9_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 9 exists" }),
  poll("menu_10_label",  #{ initial: "", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 10 label" }),
  poll("menu_10_class",  #{ initial: "menu-empty", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 10 class" }),
  poll("menu_10_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 10 exists" }),
  poll("menu_11_label",  #{ initial: "", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 11 label" }),
  poll("menu_11_class",  #{ initial: "menu-empty", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 11 class" }),
  poll("menu_11_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 11 exists" }),
  poll("menu_12_label",  #{ initial: "", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 12 label" }),
  poll("menu_12_class",  #{ initial: "menu-empty", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 12 class" }),
  poll("menu_12_exists", #{ initial: "false", interval: "1s", cmd: "$HOME/.config/ewwii/scripts/menu_slot 12 exists" }),
  poll("wlrctl_refresh", #{ initial: "ok", interval: "2s",
    cmd: "$HOME/.local/bin/wlr-task list > /tmp/ewwii_wlrctl.list.tmp 2>/dev/null && mv -f /tmp/ewwii_wlrctl.list.tmp /tmp/ewwii_wlrctl.list; echo ok" }),

  poll("win_1_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 1 title" }),
  poll("win_1_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 1 app_id" }),
  poll("win_1_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 1 focused" }),
  poll("win_1_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 1 app_id)\"" }),
  poll("win_1_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 1 exists" }),
  poll("win_2_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 2 title" }),
  poll("win_2_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 2 app_id" }),
  poll("win_2_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 2 focused" }),
  poll("win_2_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 2 app_id)\"" }),
  poll("win_2_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 2 exists" }),
  poll("win_3_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 3 title" }),
  poll("win_3_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 3 app_id" }),
  poll("win_3_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 3 focused" }),
  poll("win_3_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 3 app_id)\"" }),
  poll("win_3_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 3 exists" }),
  poll("win_4_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 4 title" }),
  poll("win_4_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 4 app_id" }),
  poll("win_4_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 4 focused" }),
  poll("win_4_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 4 app_id)\"" }),
  poll("win_4_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 4 exists" }),
  poll("win_5_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 5 title" }),
  poll("win_5_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 5 app_id" }),
  poll("win_5_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 5 focused" }),
  poll("win_5_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 5 app_id)\"" }),
  poll("win_5_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 5 exists" }),
  poll("win_6_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 6 title" }),
  poll("win_6_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 6 app_id" }),
  poll("win_6_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 6 focused" }),
  poll("win_6_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 6 app_id)\"" }),
  poll("win_6_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 6 exists" }),
  poll("win_7_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 7 title" }),
  poll("win_7_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 7 app_id" }),
  poll("win_7_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 7 focused" }),
  poll("win_7_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 7 app_id)\"" }),
  poll("win_7_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 7 exists" }),
  poll("win_8_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 8 title" }),
  poll("win_8_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 8 app_id" }),
  poll("win_8_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 8 focused" }),
  poll("win_8_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 8 app_id)\"" }),
  poll("win_8_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 8 exists" }),
  poll("win_9_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 9 title" }),
  poll("win_9_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 9 app_id" }),
  poll("win_9_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 9 focused" }),
  poll("win_9_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 9 app_id)\"" }),
  poll("win_9_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 9 exists" }),
  poll("win_10_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 10 title" }),
  poll("win_10_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 10 app_id" }),
  poll("win_10_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 10 focused" }),
  poll("win_10_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 10 app_id)\"" }),
  poll("win_10_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 10 exists" }),
  poll("win_11_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 11 title" }),
  poll("win_11_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 11 app_id" }),
  poll("win_11_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 11 focused" }),
  poll("win_11_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 11 app_id)\"" }),
  poll("win_11_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 11 exists" }),
  poll("win_12_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 12 title" }),
  poll("win_12_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 12 app_id" }),
  poll("win_12_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 12 focused" }),
  poll("win_12_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 12 app_id)\"" }),
  poll("win_12_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 12 exists" }),
  poll("win_13_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 13 title" }),
  poll("win_13_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 13 app_id" }),
  poll("win_13_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 13 focused" }),
  poll("win_13_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 13 app_id)\"" }),
  poll("win_13_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 13 exists" }),
  poll("win_14_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 14 title" }),
  poll("win_14_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 14 app_id" }),
  poll("win_14_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 14 focused" }),
  poll("win_14_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 14 app_id)\"" }),
  poll("win_14_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 14 exists" }),
  poll("win_15_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 15 title" }),
  poll("win_15_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 15 app_id" }),
  poll("win_15_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 15 focused" }),
  poll("win_15_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 15 app_id)\"" }),
  poll("win_15_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 15 exists" }),
  poll("win_16_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 16 title" }),
  poll("win_16_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 16 app_id" }),
  poll("win_16_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 16 focused" }),
  poll("win_16_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 16 app_id)\"" }),
  poll("win_16_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 16 exists" }),
  poll("win_17_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 17 title" }),
  poll("win_17_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 17 app_id" }),
  poll("win_17_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 17 focused" }),
  poll("win_17_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 17 app_id)\"" }),
  poll("win_17_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 17 exists" }),
  poll("win_18_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 18 title" }),
  poll("win_18_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 18 app_id" }),
  poll("win_18_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 18 focused" }),
  poll("win_18_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 18 app_id)\"" }),
  poll("win_18_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 18 exists" }),
  poll("win_19_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 19 title" }),
  poll("win_19_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 19 app_id" }),
  poll("win_19_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 19 focused" }),
  poll("win_19_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 19 app_id)\"" }),
  poll("win_19_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 19 exists" }),
  poll("win_20_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 20 title" }),
  poll("win_20_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 20 app_id" }),
  poll("win_20_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 20 focused" }),
  poll("win_20_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 20 app_id)\"" }),
  poll("win_20_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 20 exists" }),
  poll("win_21_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 21 title" }),
  poll("win_21_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 21 app_id" }),
  poll("win_21_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 21 focused" }),
  poll("win_21_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 21 app_id)\"" }),
  poll("win_21_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 21 exists" }),
  poll("win_22_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 22 title" }),
  poll("win_22_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 22 app_id" }),
  poll("win_22_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 22 focused" }),
  poll("win_22_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 22 app_id)\"" }),
  poll("win_22_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 22 exists" }),
  poll("win_23_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 23 title" }),
  poll("win_23_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 23 app_id" }),
  poll("win_23_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 23 focused" }),
  poll("win_23_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 23 app_id)\"" }),
  poll("win_23_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 23 exists" }),
  poll("win_24_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 24 title" }),
  poll("win_24_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 24 app_id" }),
  poll("win_24_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 24 focused" }),
  poll("win_24_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 24 app_id)\"" }),
  poll("win_24_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 24 exists" }),
  poll("win_25_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 25 title" }),
  poll("win_25_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 25 app_id" }),
  poll("win_25_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 25 focused" }),
  poll("win_25_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 25 app_id)\"" }),
  poll("win_25_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 25 exists" }),
  poll("win_26_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 26 title" }),
  poll("win_26_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 26 app_id" }),
  poll("win_26_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 26 focused" }),
  poll("win_26_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 26 app_id)\"" }),
  poll("win_26_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 26 exists" }),
  poll("win_27_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 27 title" }),
  poll("win_27_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 27 app_id" }),
  poll("win_27_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 27 focused" }),
  poll("win_27_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 27 app_id)\"" }),
  poll("win_27_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 27 exists" }),
  poll("win_28_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 28 title" }),
  poll("win_28_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 28 app_id" }),
  poll("win_28_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 28 focused" }),
  poll("win_28_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 28 app_id)\"" }),
  poll("win_28_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 28 exists" }),
  poll("win_29_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 29 title" }),
  poll("win_29_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 29 app_id" }),
  poll("win_29_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 29 focused" }),
  poll("win_29_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 29 app_id)\"" }),
  poll("win_29_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 29 exists" }),
  poll("win_30_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 30 title" }),
  poll("win_30_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 30 app_id" }),
  poll("win_30_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 30 focused" }),
  poll("win_30_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 30 app_id)\"" }),
  poll("win_30_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 30 exists" }),
  poll("win_31_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 31 title" }),
  poll("win_31_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 31 app_id" }),
  poll("win_31_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 31 focused" }),
  poll("win_31_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 31 app_id)\"" }),
  poll("win_31_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 31 exists" }),
  poll("win_32_title",   #{ initial: "", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 32 title" }),
  poll("win_32_id",      #{ initial: "", interval: "30s", cmd: "$HOME/.config/ewwii/scripts/task_slot 32 app_id" }),
  poll("win_32_focused", #{ initial: "tb-item", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 32 focused" }),
  poll("win_32_icon",    #{ initial: "", interval: "60s", cmd: "$HOME/.config/ewwii/scripts/app_icon \"$($HOME/.config/ewwii/scripts/task_slot 32 app_id)\"" }),
  poll("win_32_exists",  #{ initial: "false", interval: "5s", cmd: "$HOME/.config/ewwii/scripts/task_slot 32 exists" }),
  poll("icon_lock",       #{ initial: "L", interval: "24h", cmd: "$HOME/.config/ewwii/scripts/static_icon lock" }),
  poll("icon_brightness", #{ initial: "B", interval: "24h", cmd: "$HOME/.config/ewwii/scripts/static_icon brightness" }),

  // ---- hover state ---------------------------------------------------------
  poll("vol_open", #{ initial: "false", interval: "1h", cmd: "echo false" }),
  poll("bri_open", #{ initial: "false", interval: "1h", cmd: "echo false" }),

  // ---- window --------------------------------------------------------------
  defwindow("bar", #{
    monitor: 0,
    stacking: "fg",
    exclusive: true,
    geometry: #{
      x: "0px",
      y: "0px",
      width: "150px",
      height: "100%",
      anchor: "center right",
    },
  }, bar()),

  defwindow("tray_menu", #{
    monitor: 0,
    stacking: "fg",
    geometry: #{
      x: "152px",
      y: "90px",
      width: "220px",
      anchor: "bottom right",
    },
  }, tray_menu_widget()),
]);
