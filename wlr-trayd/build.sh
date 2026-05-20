#!/bin/sh
set -e
cd "$(dirname "$0")"
cargo build --release
install -Dm755 target/release/wlr-trayd     "$HOME/.local/bin/wlr-trayd"
install -Dm755 target/release/wlr-tray      "$HOME/.local/bin/wlr-tray"
install -Dm755 target/release/wlr-tray-menu "$HOME/.local/bin/wlr-tray-menu"
echo "installed: $HOME/.local/bin/wlr-trayd"
echo "installed: $HOME/.local/bin/wlr-tray"
echo "installed: $HOME/.local/bin/wlr-tray-menu"
