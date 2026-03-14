#!/bin/bash
# fscopy module - Copy file/directory operation (F5)

declare -ag __FILE_LIST_SRC=() 2>/dev/null || true
declare -ag __FILE_LIST_DST=() 2>/dev/null || true
declare -ag __FILE_LIST_SIZES=() 2>/dev/null || true
__FILE_LIST_TOTAL_BYTES=0

_fscopy_build_file_list() {
    local src="$1"
    local dst="$2"
    __FILE_LIST_SRC=()
    __FILE_LIST_DST=()
    __FILE_LIST_SIZES=()
    __FILE_LIST_TOTAL_BYTES=0
    _fscopy_build_file_list_recurse "$src" "$dst"
}

_fscopy_build_file_list_recurse() {
    local src="$1"
    local dst="$2"
    if [ -d "$src" ]; then
        local entry
        while IFS= read -r -d '' entry; do
            local name="${entry##*/}"
            _fscopy_build_file_list_recurse "$entry" "$dst/$name"
        done < <(find "$src" -maxdepth 1 -mindepth 1 -print0 2>/dev/null)
    elif [ -f "$src" ]; then
        local size
        size=$(stat -c '%s' "$src" 2>/dev/null || echo 0)
        __FILE_LIST_SRC+=("$src")
        __FILE_LIST_DST+=("$dst")
        __FILE_LIST_SIZES+=("$size")
        __FILE_LIST_TOTAL_BYTES=$(( __FILE_LIST_TOTAL_BYTES + size ))
    fi
}

_fscopy_copy_with_progress() {
    local src="$1"
    local dst="$2"
    local file_size="$3"
    local files_done="$4"
    local files_total="$5"
    local bytes_before="$6"
    local dst_dir="${dst%/*}"
    mkdir -p "$dst_dir" 2>/dev/null
    local file_label="${src##*/}"
    dd if="$src" of="$dst" bs=65536 status=none 2>/dev/null &
    local dd_pid=$!
    while kill -0 $dd_pid 2>/dev/null; do
        local bytes_copied
        bytes_copied=$(stat -c '%s' "$dst" 2>/dev/null || echo 0)
        _draw_progress_dialog "Copy" "$file_label" \
            "$bytes_copied" "$file_size" \
            "$files_done" "$files_total"
        sleep 0.1
    done
    wait $dd_pid
    local rc=$?

    # Preserve permissions, ownership and timestamps
    chmod "$(stat -c '%a' "$src" 2>/dev/null)" "$dst" 2>/dev/null
    touch -r "$src" "$dst" 2>/dev/null
    [ "$EUID" -eq 0 ] && chown "$(stat -c '%u:%g' "$src" 2>/dev/null)" "$dst" 2>/dev/null

    _draw_progress_dialog "Copy" "$file_label" \
        "$file_size" "$file_size" \
        "$((files_done + 1))" "$files_total"
    return $rc
}

fscopy.init() {
    hackfm.module.register_key "F5" "fscopy.run"
    hackfm.module.register_key_label "F5" "fscopy.fkey_label"
    hackfm.module.add_menu_item "File" "Copy" "F5" "fscopy.run"
}

fscopy.fkey_label() {
    local panel
    panel=$(get_active_panel)
    if [ "$($panel.in_archive)" != "1" ]; then
        __HACKFM_FKEY_LABEL="Copy"
    fi
}

fscopy.run() {
    local active_panel
    active_panel=$(get_active_panel)
    [ "$($active_panel.in_archive)" = "1" ] && return 1

    local active_list
    active_list=$(get_active_panel).list
    local source_path
    source_path=$($active_list.path)
    local other_list
    other_list=$(get_other_panel).list
    local dest_path
    dest_path=$($other_list.path)

    local filename_for_restore filetype_tmp path_tmp
    IFS='|' read -r filename_for_restore filetype_tmp path_tmp <<< "$(get_selected_item)"

    local selected_count
    selected_count=$($active_list.count_selected)

    if [ $selected_count -gt 0 ]; then
        fscopy._run_multi "$active_list" "$source_path" "$dest_path" "$filename_for_restore"
    else
        fscopy._run_single "$active_list" "$source_path" "$dest_path"
    fi
}

fscopy._run_multi() {
    local active_list="$1"
    local source_path="$2"
    local dest_path="$3"
    local saved_filename="$4"

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

    # Confirmation dialog
    local max_path_len=${#source_path}
    [ ${#dest_path} -gt $max_path_len ] && max_path_len=${#dest_path}
    local dialog_width=$(( max_path_len + 10 ))
    [ $dialog_width -lt 50 ] && dialog_width=50
    [ $dialog_width -gt 70 ] && dialog_width=70
    local dialog_height=9

    local size
    size=$(tui.screen.size)
    local rows=${size% *}
    local cols=${size#* }
    local dialog_row=$(( (rows - dialog_height) / 2 ))
    local dialog_col=$(( (cols - dialog_width) / 2 ))

    # Shadow
    tui.color.bg_black
    local r
    for ((r=dialog_row+1; r<dialog_row+dialog_height+1; r++)); do
        tui.cursor.move $r $((dialog_col + 2))
        printf "%$((dialog_width))s" ""
    done
    tui.color.reset

    # Background + border
    tui.color.bg_white; tui.color.black
    for ((r=dialog_row; r<dialog_row+dialog_height; r++)); do
        tui.cursor.move $r $dialog_col
        printf "%${dialog_width}s" ""
    done
    tui.box.draw $dialog_row $dialog_col $dialog_width $dialog_height

    # Title
    tui.cursor.move $dialog_row $((dialog_col + 2))
    tui.color.bg_white; tui.color.black
    printf " Copy "
    tui.color.reset

    # Message
    tui.cursor.move $((dialog_row + 2)) $((dialog_col + 2))
    tui.color.bg_white; tui.color.black
    printf "Copy %d files (%s)" "$selected_count" "$size_str"

    # From / To
    local from_max=$(( dialog_width - 10 ))
    local from_display="$source_path"
    [ ${#from_display} -gt $from_max ] && from_display="...${source_path: -$((from_max - 3))}"
    local to_display="$dest_path"
    [ ${#to_display} -gt $from_max ] && to_display="...${dest_path: -$((from_max - 3))}"

    tui.cursor.move $((dialog_row + 4)) $((dialog_col + 2))
    tui.color.bg_white; tui.color.black
    printf "From: %s" "$from_display"

    tui.cursor.move $((dialog_row + 5)) $((dialog_col + 2))
    tui.color.bg_white; tui.color.black
    printf "To:   %s" "$to_display"

    # Buttons
    local selected_btn=0
    local confirm_result=1
    while true; do
        tui.cursor.move $((dialog_row + 7)) $((dialog_col + dialog_width/2 - 8))
        if [ $selected_btn -eq 0 ]; then
            tui.color.bg_cyan; tui.color.black
        else
            tui.color.bg_white; tui.color.black
        fi
        printf "[< Yes >]"
        tui.color.reset; tui.color.bg_white; tui.color.black; printf "   "
        if [ $selected_btn -eq 1 ]; then
            tui.color.bg_cyan; tui.color.black
        else
            tui.color.bg_white; tui.color.black
        fi
        printf "[ No ]"
        tui.color.reset

        local key
        key=$(tui.input.key 2>&1) || continue
        case "$key" in
            LEFT|RIGHT|TAB|UP|DOWN) selected_btn=$(( 1 - selected_btn )) ;;
            ENTER) [ $selected_btn -eq 0 ] && confirm_result=0; break ;;
            ESC) break ;;
        esac
    done

    broker.publish "dialog_closed" ""
    [ $confirm_result -ne 0 ] && return

    # Build file list across all selected items
    _draw_status_dialog "Copy" "Preparing..."
    __FILE_LIST_SRC=()
    __FILE_LIST_DST=()
    __FILE_LIST_SIZES=()
    __FILE_LIST_TOTAL_BYTES=0
    local filename filetype
    while IFS='|' read -r filename filetype; do
        _fscopy_build_file_list_recurse "$source_path/$filename" "$dest_path/$filename"
    done < <($active_list.get_selected)

    local failed=0 i
    for ((i=0; i<${#__FILE_LIST_SRC[@]}; i++)); do
        _fscopy_copy_with_progress \
            "${__FILE_LIST_SRC[i]}" \
            "${__FILE_LIST_DST[i]}" \
            "${__FILE_LIST_SIZES[i]}" \
            "$i" "${#__FILE_LIST_SRC[@]}" \
            "0" "Copy" || failed=1
    done

    tui.cursor.show
    [ $failed -eq 1 ] && show_error "Some files failed to copy"

    reload_both_panels
    local active_panel
    active_panel=$(get_active_panel)
    local panel_height
    panel_height=$($active_panel.height)
    $active_list.find_and_select "$saved_filename" $((panel_height - 3))
    broker.publish "dialog_closed" ""
}

fscopy._run_single() {
    local active_list="$1"
    local source_path="$2"
    local dest_path="$3"

    local filename filetype
    IFS='|' read -r filename filetype source_path <<< "$(get_selected_item)"

    $active_list.is_special "$filename" && return

    local default_dest="$dest_path/$filename"
    show_path_input "Copy" "Copy to:" "$default_dest"
    dialog_cleanup

    if [ "$(file_dialog.result)" != "0" ]; then
        broker.publish "dialog_closed" ""
        return
    fi

    local destination
    destination=$(file_dialog.input_value)
    if [ -z "$destination" ]; then
        show_error "Destination cannot be empty"
        return
    fi

    [[ "$destination" != /* ]] && destination="$source_path/$destination"

    local source="$source_path/$filename"

    if [ -e "$destination" ]; then
        file_dialog.show_confirm "Overwrite?" "Destination exists. Overwrite?"
        dialog_cleanup
        if [ "$(file_dialog.result)" != "0" ]; then
            broker.publish "dialog_closed" ""
            return
        fi
    fi

    _draw_status_dialog "Copy" "Preparing..."
    _fscopy_build_file_list "$source" "$destination"

    local i bytes_done=0 failed=0
    for ((i=0; i<${#__FILE_LIST_SRC[@]}; i++)); do
        _fscopy_copy_with_progress \
            "${__FILE_LIST_SRC[i]}" \
            "${__FILE_LIST_DST[i]}" \
            "${__FILE_LIST_SIZES[i]}" \
            "$i" "${#__FILE_LIST_SRC[@]}" \
            "$bytes_done" "Copy" || failed=1
        bytes_done=$(( bytes_done + __FILE_LIST_SIZES[i] ))
    done

    tui.cursor.show
    if [ $failed -eq 0 ]; then
        reload_both_panels
        local active_panel
        active_panel=$(get_active_panel)
        local panel_height
        panel_height=$($active_panel.height)
        $active_list.find_and_select "$filename" $((panel_height - 3))
        $active_panel.prerender_all_rows
        broker.publish "dialog_closed" ""
    else
        show_error "Failed to copy"
    fi
}
