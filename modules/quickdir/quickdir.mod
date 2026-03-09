#!/bin/bash
# quickdir module - Quick directory jump (Ctrl-D)

. "$HACKFM_DIR/modules/quickdir/quickdir.class"

quickdir.init() {
    hackfm.module.register_key "CTRL-D" "quickdir.run"
}

quickdir.run() {
    local active_panel
    active_panel=$(get_active_panel)

    quickdir.show "$active_panel"

    if [ -n "$__QUICKDIR_result" ]; then
        $active_panel.goto "$__QUICKDIR_result"
    else
        $active_panel.render
    fi
}
