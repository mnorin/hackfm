#!/bin/bash
# editor.sh - Standalone file editor wrapper
# Usage: editor.sh <filepath>

HACKFM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

mkdir -p "$HACKFM_DIR/logs"

. "$HACKFM_DIR/tui/cursor.class"
. "$HACKFM_DIR/tui/screen.class"
. "$HACKFM_DIR/tui/color.class"
. "$HACKFM_DIR/tui/box.class"
. "$HACKFM_DIR/tui/input.class"
. "$HACKFM_DIR/tui/region.class"
. "$HACKFM_DIR/tui/style.class"
. "$HACKFM_DIR/appframe.h"
. "$HACKFM_DIR/dialog.h"
. "$HACKFM_DIR/modules/editor/editor.h"

[ -z "$1" ] && exit 1

editor e

e.open "$1"
