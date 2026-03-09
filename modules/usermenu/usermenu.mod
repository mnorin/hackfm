#!/bin/bash
# usermenu module - User menu popup (F2)

. "$HACKFM_DIR/modules/usermenu/usermenu.class"

usermenu.init() {
    hackfm.module.register_key "F2" "usermenu.run" "UserMenu"
}

usermenu.run() {
    local filename filetype path
    IFS='|' read -r filename filetype path <<< "$(get_selected_item)"
    usermenu.show "$path/$filename"
    broker.publish "dialog_closed" ""
}
