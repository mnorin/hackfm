#!/bin/bash
# fsmove module - Move/rename file/directory (F6)

declare -ag __FSMOVE_FILE_LIST_SRC=() 2>/dev/null || true
declare -ag __FSMOVE_FILE_LIST_DST=() 2>/dev/null || true
declare -ag __FSMOVE_FILE_LIST_SIZES=() 2>/dev/null || true
__FSMOVE_FILE_LIST_TOTAL_BYTES=0

_fsmove_build_file_list() {
    local src="$1"
    local dst="$2"
    __FSMOVE_FILE_LIST_SRC=()
    __FSMOVE_FILE_LIST_DST=()
    __FSMOVE_FILE_LIST_SIZES=()
    __FSMOVE_FILE_LIST_TOTAL_BYTES=0
    _fsmove_build_file_list_recurse "$src" "$dst"
}

_fsmove_build_file_list_recurse() {
    local src="$1"
    local dst="$2"
    if [ -d "$src" ]; then
        local entry
        while IFS= read -r -d '' entry; do
            local name="${entry##*/}"
            _fsmove_build_file_list_recurse "$entry" "$dst/$name"
        done < <(find "$src" -maxdepth 1 -mindepth 1 -print0 2>/dev/null)
    elif [ -f "$src" ]; then
        local size
        size=$(stat -c '%s' "$src" 2>/dev/null || echo 0)
        __FSMOVE_FILE_LIST_SRC+=("$src")
        __FSMOVE_FILE_LIST_DST+=("$dst")
        __FSMOVE_FILE_LIST_SIZES+=("$size")
        __FSMOVE_FILE_LIST_TOTAL_BYTES=$(( __FSMOVE_FILE_LIST_TOTAL_BYTES + size ))
    fi
}

_fsmove_copy_with_progress() {
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
        _draw_progress_dialog "Move" "$file_label" \
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

    _draw_progress_dialog "Move" "$file_label" \
        "$file_size" "$file_size" \
        "$((files_done + 1))" "$files_total"
    return $rc
}

fsmove.init() {
    hackfm.module.register_key "F6" "fsmove.run" "Move"
    hackfm.module.add_menu_item "File" "Move" "F6" "fsmove.run"
}

fsmove.run() {
    local active_list
    active_list=$(get_active_panel).list
    local source_path
    source_path=$($active_list.path)
    local other_list
    other_list=$(get_other_panel).list
    local dest_path
    dest_path=$($other_list.path)

    local saved_index
    saved_index=$($active_list.selected)
    local filename_for_restore filetype_tmp path_tmp
    IFS='|' read -r filename_for_restore filetype_tmp path_tmp <<< "$(get_selected_item)"

    local selected_count
    selected_count=$($active_list.count_selected)

    if [ $selected_count -gt 0 ]; then
        fsmove._run_multi "$active_list" "$source_path" "$dest_path" "$saved_index"
    else
        fsmove._run_single "$active_list" "$source_path" "$dest_path"
    fi
}

fsmove._run_multi() {
    local active_list="$1"
    local source_path="$2"
    local dest_path="$3"
    local saved_index="$4"

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

    local max_path_len=${#source_path}
    [ ${#dest_path} -gt $max_path_len ] && max_path_len=${#dest_path}
    local dialog_width=$(( max_path_len + 10 ))
    [ $dialog_width -lt 50 ] && dialog_width=50
    [ $dialog_width -gt 70 ] && dialog_width=70
    local dialog_height=8

    local size
    size=$(tui.screen.size)
    local rows=${size% *}
    local cols=${size#* }
    local dialog_row=$(( (rows - dialog_height) / 2 ))
    local dialog_col=$(( (cols - dialog_width) / 2 ))

    tui.color.bg_black
    local r
    for ((r=dialog_row+1; r<dialog_row+dialog_height+1; r++)); do
        tui.cursor.move $r $((dialog_col + 2))
        printf "%$((dialog_width))s" ""
    done
    tui.color.reset

    tui.color.bg_white; tui.color.black
    for ((r=dialog_row; r<dialog_row+dialog_height; r++)); do
        tui.cursor.move $r $dialog_col
        printf "%${dialog_width}s" ""
    done
    tui.box.draw $dialog_row $dialog_col $dialog_width $dialog_height

    tui.cursor.move $dialog_row $((dialog_col + 2))
    tui.color.bg_white; tui.color.black
    printf " Move "
    tui.color.reset

    tui.cursor.move $((dialog_row + 2)) $((dialog_col + 2))
    tui.color.bg_white; tui.color.black
    printf "Move %d files (%s)" "$selected_count" "$size_str"

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

    local selected_btn=0
    local confirm_result=1
    while true; do
        tui.cursor.move $((dialog_row + 6)) $((dialog_col + dialog_width/2 - 8))
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

    local failed=0
    local -a _mv_src=() _mv_dst=()
    local filename filetype
    while IFS='|' read -r filename filetype; do
        local source="$source_path/$filename"
        local destination="$dest_path/$filename"
        if ! mv "$source" "$destination" 2>/dev/null; then
            _mv_src+=("$source")
            _mv_dst+=("$destination")
        fi
    done < <($active_list.get_selected)

    if [ ${#_mv_src[@]} -gt 0 ]; then
        _draw_status_dialog "Move" "Preparing..."
        __FSMOVE_FILE_LIST_SRC=()
        __FSMOVE_FILE_LIST_DST=()
        __FSMOVE_FILE_LIST_SIZES=()
        __FSMOVE_FILE_LIST_TOTAL_BYTES=0
        local j
        for ((j=0; j<${#_mv_src[@]}; j++)); do
            _fsmove_build_file_list_recurse "${_mv_src[j]}" "${_mv_dst[j]}"
        done
        local i
        for ((i=0; i<${#__FSMOVE_FILE_LIST_SRC[@]}; i++)); do
            _fsmove_copy_with_progress \
                "${__FSMOVE_FILE_LIST_SRC[i]}" \
                "${__FSMOVE_FILE_LIST_DST[i]}" \
                "${__FSMOVE_FILE_LIST_SIZES[i]}" \
                "$i" "${#__FSMOVE_FILE_LIST_SRC[@]}" \
                "0" || { failed=1; break; }
        done
        if [ $failed -eq 0 ]; then
            for ((j=0; j<${#_mv_src[@]}; j++)); do
                rm -rf "${_mv_src[j]}" 2>/dev/null || failed=1
            done
        fi
    fi

    tui.cursor.show
    [ $failed -eq 1 ] && show_error "Some files failed to move"

    reload_both_panels

    local file_count
    file_count=$($active_list.count)
    local new_index=$saved_index
    [ $new_index -ge $file_count ] && [ $file_count -gt 0 ] && new_index=$(( file_count - 1 ))
    $active_list.selected = $new_index

    local active_panel
    active_panel=$(get_active_panel)
    local panel_height
    panel_height=$($active_panel.height)
    local max_visible=$(( panel_height - 3 ))
    local scroll
    scroll=$($active_list.scroll)
    [ $new_index -lt $scroll ] && $active_list.scroll = $new_index
    [ $new_index -ge $(( scroll + max_visible )) ] && $active_list.scroll = $(( new_index - max_visible + 1 ))

    broker.publish "dialog_closed" ""
}

fsmove._run_single() {
    local active_list="$1"
    local source_path="$2"
    local dest_path="$3"

    local filename filetype
    IFS='|' read -r filename filetype source_path <<< "$(get_selected_item)"

    $active_list.is_special "$filename" && return 0

    local current_index
    current_index=$($active_list.selected)
    local default_dest="$dest_path/$filename"

    show_path_input "Move/Rename" "Move to:" "$default_dest"
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

    local move_ok=0
    if mv "$source" "$destination" 2>/dev/null; then
        move_ok=1
    else
        _draw_status_dialog "Move" "Preparing..."
        _fsmove_build_file_list "$source" "$destination"
        local i bytes_done=0 failed=0
        for ((i=0; i<${#__FSMOVE_FILE_LIST_SRC[@]}; i++)); do
            _fsmove_copy_with_progress \
                "${__FSMOVE_FILE_LIST_SRC[i]}" \
                "${__FSMOVE_FILE_LIST_DST[i]}" \
                "${__FSMOVE_FILE_LIST_SIZES[i]}" \
                "$i" "${#__FSMOVE_FILE_LIST_SRC[@]}" \
                "$bytes_done" || { failed=1; break; }
            bytes_done=$(( bytes_done + __FSMOVE_FILE_LIST_SIZES[i] ))
        done
        [ $failed -eq 0 ] && rm -rf "$source" 2>/dev/null && move_ok=1
    fi

    tui.cursor.show
    if [ $move_ok -eq 1 ]; then
        reload_both_panels

        local file_count
        file_count=$($active_list.count)
        local new_index=$current_index
        [ $current_index -ge $(( file_count - 1 )) ] && [ $current_index -gt 0 ] && new_index=$(( current_index - 1 ))
        $active_list.selected = $new_index

        local active_panel
        active_panel=$(get_active_panel)
        local panel_height
        panel_height=$($active_panel.height)
        local max_visible=$(( panel_height - 3 ))
        local scroll
        scroll=$($active_list.scroll)
        [ $new_index -lt $scroll ] && $active_list.scroll = $new_index
        [ $new_index -ge $(( scroll + max_visible )) ] && $active_list.scroll = $(( new_index - max_visible + 1 ))

        $active_panel.prerender_all_rows
        broker.publish "dialog_closed" ""
    else
        show_error "Failed to move"
    fi
}
