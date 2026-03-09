#!/bin/bash
# fsmkdir module - Make directory (F7)

fsmkdir.init() {
    hackfm.module.register_key "F7" "fsmkdir.run" "Mkdir"
    hackfm.module.add_menu_item "File" "MkDir" "F7" "fsmkdir.run"
}

fsmkdir.run() {
    local list
    list=$(get_active_panel).list
    local path
    path=$($list.path)

    file_dialog.show_input "Make Directory" "Enter directory name:" ""
    dialog_cleanup

    if [ "$(file_dialog.result)" = "0" ]; then
        local dirname
        dirname=$(file_dialog.input_value)

        if [ -z "$dirname" ]; then
            show_error "Directory name cannot be empty"
            return 0
        fi

        local fullpath="$path/$dirname"

        if mkdir "$fullpath" 2>/dev/null; then
            reload_active_panel
            local panel
            panel=$(get_active_panel)
            local panel_height
            panel_height=$($panel.height)
            $list.find_and_select "$dirname" $((panel_height - 3))
            $panel.prerender_all_rows
            broker.publish "dialog_closed" ""
        else
            show_error "Failed to create directory: $dirname"
        fi
    else
        broker.publish "dialog_closed" ""
    fi
}
