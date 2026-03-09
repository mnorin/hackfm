#!/bin/bash
# viewer module - File viewer (F3)

. "$HACKFM_DIR/modules/viewer/viewhandler.class"

viewer.init() {
    hackfm.module.register_key "F3" "viewer.run" "View"
    hackfm.module.add_menu_item "File" "View" "F3" "viewer.run"
}

viewer.run() {
    tui.color.reset

    local active_panel
    active_panel=$(get_active_panel)

    if [ "$($active_panel.in_archive)" = "1" ]; then
        local arch_list arch_filename arch_filetype arch_path
        arch_list=$($active_panel.list_source)
        IFS='|' read -r arch_filename arch_filetype arch_path <<< "$($arch_list.get_selected_item)"

        if [ "$arch_filetype" != "f" ] || [ "$arch_filename" = "<empty>" ] || [ "$arch_filename" = ".." ]; then
            return
        fi

        viewhandler.open_archive "$arch_list" "$arch_path" "$arch_filename"
    else
        local filename filetype path
        IFS='|' read -r filename filetype path <<< "$(get_selected_item)"

        if [ "$filetype" != "f" ] || [ "$filename" = "<empty>" ]; then
            return
        fi

        local filepath="$path/$filename"
        if [ ! -f "$filepath" ] || [ ! -r "$filepath" ]; then
            return
        fi

        viewhandler.open "$filepath"
    fi

    broker.publish "viewer_closed" ""
}
