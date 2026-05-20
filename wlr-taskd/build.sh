#!/bin/sh
set -e
cd "$(dirname "$0")"

XML=/usr/share/wlr-protocols/unstable/wlr-foreign-toplevel-management-unstable-v1.xml
if [ ! -f "$XML" ]; then
  echo "missing $XML — install wlr-protocols (sudo pacman -S wlr-protocols)" >&2
  exit 1
fi

wayland-scanner client-header "$XML" wlr-ftm-protocol.h
wayland-scanner private-code  "$XML" wlr-ftm-protocol.c

gcc -O2 -Wall -Wextra -Wno-unused-parameter \
    -o "$HOME/.local/bin/wlr-taskd" \
    wlr-taskd.c wlr-ftm-protocol.c \
    -lwayland-client

gcc -O2 -Wall -Wextra \
    -o "$HOME/.local/bin/wlr-task" \
    wlr-task.c

echo "built: $HOME/.local/bin/wlr-taskd"
echo "built: $HOME/.local/bin/wlr-task"
