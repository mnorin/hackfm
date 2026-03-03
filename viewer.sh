#!/bin/bash
# viewer.sh - Standalone file viewer wrapper
# Usage: viewer.sh <filepath>

HACKFM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$HACKFM_DIR/tui/cursor.class"
. "$HACKFM_DIR/tui/screen.class"
. "$HACKFM_DIR/tui/color.class"
. "$HACKFM_DIR/tui/input.class"
. "$HACKFM_DIR/tui/region.class"
. "$HACKFM_DIR/tui/style.class"
. "$HACKFM_DIR/appframe.h"
. "$HACKFM_DIR/viewer.h"

[ -z "$1" ] && exit 1
[ ! -f "$1" ] && exit 1

viewer v

size=$(tui.screen.size)
v.rows = "${size% *}"
v.cols = "${size#* }"

v.open "$1"
