#!/bin/sh
# ewwii-stack installer
# Builds wlr-taskd + wlr-trayd, places ewwii config, prints autostart snippet.
set -e

HERE=$(cd "$(dirname "$0")" && pwd)
BINDIR="$HOME/.local/bin"
CFGDIR="$HOME/.config/ewwii"

echo "=> Building wlr-taskd (C)…"
"$HERE/wlr-taskd/build.sh"

echo "=> Building wlr-trayd + wlr-tray-menu (Rust)…"
"$HERE/wlr-trayd/build.sh"

echo "=> Installing ewwii config to $CFGDIR …"
mkdir -p "$CFGDIR/scripts"
for f in ewwii.rhai ewwii.scss; do
  install -m644 "$HERE/ewwii/$f" "$CFGDIR/$f"
done
install -m644 "$HERE/ewwii/tray_menu.env.example" "$CFGDIR/tray_menu.env.example"
for s in "$HERE/ewwii/scripts"/*; do
  install -m755 "$s" "$CFGDIR/scripts/$(basename "$s")"
done

cat <<EOF

=> Done. Two more steps:

1) Append to ~/.config/labwc/autostart (or your compositor's equivalent):

   $BINDIR/wlr-taskd >/dev/null 2>&1 &
   $BINDIR/wlr-trayd >/dev/null 2>&1 &
   ewwii daemon >/dev/null 2>&1 &
   sleep 1 && ewwii open bar &

2) Adjust hardware-specific bits in $CFGDIR/scripts/ if needed.
   See INSTALL.md "Hardware-specific tweaks".

EOF
