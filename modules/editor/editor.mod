#!/bin/bash
# editor module - File editor (F4)

. "$HACKFM_DIR/modules/editor/edithandler.class"

editor.init() {
    hackfm.module.register_key "F4" "editor.run" "Edit"
    hackfm.module.add_menu_item "File" "Edit" "F4" "editor.run"
}

editor.run() {
    tui.color.reset

    local filename filetype path
    IFS='|' read -r filename filetype path <<< "$(get_selected_item)"

    if [ "$filetype" = "d" ] || [ "$filename" = "<empty>" ] || [ "$filename" = ".." ]; then
        return
    fi

    edithandler.open "$path/$filename"

    broker.publish "editor_closed" ""
}
