#!/bin/bash
# fsattr module - File attributes dialog (Ctrl-A)

fsattr.init() {
    hackfm.module.register_key "CTRL-A" "fsattr.run"
    hackfm.module.add_menu_item "File" "Attributes" "Ctrl-A" "fsattr.run"
}

fsattr.run() {
    local filename filetype path
    IFS='|' read -r filename filetype path <<< "$(get_selected_item)"

    if [ "$filename" = "<empty>" ] || [ "$filename" = ".." ]; then
        return 0
    fi

    local filepath="$path/$filename"

    fileattr fa
    fa.show "$filepath"
    local result
    result=$(fa.result)
    fa.destroy

    if [ "$result" = "0" ]; then
        local active_panel
        active_panel=$(get_active_panel)
        $active_panel.reload
    fi
    broker.publish "dialog_closed" ""
}
