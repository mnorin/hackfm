#!/bin/bash
# colors module - File type coloring for panels
# Uses pre_init to wrap panel() constructor before panels are created.

# Global: associative array of ext/type -> color escape sequence
declare -Ag __HACKFM_COLORS=()

colors._load_conf() {
    local colors_conf="$HACKFM_DIR/conf/colors.conf"
    [ -f "$colors_conf" ] || return
    local line ext colorname
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        ext="${line%% *}"
        colorname="${line##* }"
        colorname="${colorname%%[[:space:]]*}"
        if [ -z "$ext" ] || [ -z "$colorname" ]; then continue; fi
        # Pre-capture escape sequence — no subshell at render time
        if declare -f "tui.color.$colorname" > /dev/null 2>&1; then
            __HACKFM_COLORS[$ext]=$(tui.color.$colorname)
        fi
    done < "$colors_conf"
}

colors.pre_init() {
    # Load color mappings
    colors._load_conf

    # Redefine panel() constructor to also source colorpanel.class after the original
    panel() {
        local class_code=$(<"$HACKFM_DIR/panel.class")
        . <(printf '%s' "${class_code//__PANEL__/$1}")
        class_code=$(<"$HACKFM_DIR/modules/colors/colorpanel.class")
        . <(printf '%s' "${class_code//__PANEL__/$1}")
    }
}
