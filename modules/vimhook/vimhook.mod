#!/bin/bash
# vimhook module - Open file in vim (Layer 1, F4 = F14)
# Demonstrates layer 1 key registration.
# Requires vim to be installed.

vimhook.init() {
    hackfm.module.register_key "F14" "vimhook.run" "Vim"
}

vimhook.run() {
    local filename filetype path
    IFS='|' read -r filename filetype path <<< "$(get_selected_item)"

    if [ "$filetype" = "d" ] || [ "$filename" = "<empty>" ] || [ "$filename" = ".." ]; then
        return
    fi

    if ! command -v vim &>/dev/null; then
        show_error "vim is not installed"
        return
    fi

    tui.screen.main
    tui.cursor.show
    tui.cursor.style.default
    stty sane

    vim "$path/$filename" < /dev/tty > /dev/tty 2>&1 || true

    tui.screen.alt
    draw_screen
}
