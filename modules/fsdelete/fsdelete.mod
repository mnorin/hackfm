#!/bin/bash
# fsdelete module - Delete file/directory (F8)

fsdelete.init() {
    hackfm.module.register_key "F8" "fsdelete.run" "Delete"
    hackfm.module.add_menu_item "File" "Delete" "F8" "fsdelete.run"
}

fsdelete.run() {
    local active_list
    active_list=$(get_active_panel).list
    local path
    path=$($active_list.path)

    local saved_index
    saved_index=$($active_list.selected)
    local selected_count
    selected_count=$($active_list.count_selected)

    if [ $selected_count -gt 0 ]; then
        fsdelete._run_multi "$active_list" "$path" "$saved_index"
    else
        fsdelete._run_single "$active_list" "$path"
    fi
}

fsdelete._run_multi() {
    local active_list="$1"
    local path="$2"
    local saved_index="$3"

    local sel_info total_bytes size_str
    sel_info=$($active_list.selection_info)
    total_bytes="${sel_info#*|}"
    local selected_count
    selected_count=$($active_list.count_selected)

    if [ $total_bytes -lt 1024 ]; then
        size_str="${total_bytes}B"
    elif [ $total_bytes -lt 1048576 ]; then
        size_str="$((total_bytes / 1024))KB"
    else
        size_str="$((total_bytes / 1048576))MB"
    fi

    file_dialog.show_confirm "Delete" "Delete $selected_count files ($size_str)?"
    dialog_cleanup

    if [ "$(file_dialog.result)" != "0" ]; then
        broker.publish "dialog_closed" ""
        return
    fi

    local failed=0
    local filename filetype
    while IFS='|' read -r filename filetype; do
        local fullpath="$path/$filename"
        if [ "$filetype" = "d" ]; then
            rm -rf "$fullpath" 2>/dev/null || failed=1
        else
            rm "$fullpath" 2>/dev/null || failed=1
        fi
    done < <($active_list.get_selected)

    [ $failed -eq 1 ] && show_error "Some files failed to delete"

    local active_panel
    active_panel=$(get_active_panel)
    $active_panel.reload
    $active_panel.render

    broker.publish "dialog_closed" ""
}

fsdelete._run_single() {
    local active_list="$1"
    local path="$2"

    local filename filetype
    IFS='|' read -r filename filetype path <<< "$(get_selected_item)"

    $active_list.is_special "$filename" && return 0

    local current_index
    current_index=$($active_list.selected)
    local fullpath="$path/$filename"

    if [ "$filetype" = "d" ]; then
        file_dialog.show_confirm "Delete Directory" "Delete directory '$filename'?"
    else
        file_dialog.show_confirm "Delete File" "Delete file '$filename'?"
    fi
    dialog_cleanup

    if [ "$(file_dialog.result)" != "0" ]; then
        broker.publish "dialog_closed" ""
        return
    fi

    local delete_success=0

    if [ "$filetype" = "d" ]; then
        if rmdir "$fullpath" 2>/dev/null; then
            delete_success=1
        else
            file_dialog.show_confirm "Directory Not Empty" "Directory is not empty. Delete recursively?"
            dialog_cleanup
            if [ "$(file_dialog.result)" = "0" ]; then
                if rm -rf "$fullpath" 2>/dev/null; then
                    delete_success=1
                else
                    show_error "Failed to delete directory"
                    return
                fi
            else
                broker.publish "dialog_closed" ""
                return
            fi
        fi
    else
        if rm "$fullpath" 2>/dev/null; then
            delete_success=1
        else
            show_error "Failed to delete file"
            return
        fi
    fi

    if [ $delete_success -eq 1 ]; then
        local active_panel
        active_panel=$(get_active_panel)
        $active_panel.reload
        $active_panel.render
        broker.publish "dialog_closed" ""
    fi
}
