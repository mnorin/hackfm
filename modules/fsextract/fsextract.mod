#!/bin/bash
# fsextract module - Extract files from archive (F5 when in archive view)

fsextract.init() {
    hackfm.module.register_key "F5" "fsextract.run"
    hackfm.module.register_key_label "F5" "fsextract.fkey_label"
}

fsextract.fkey_label() {
    local panel
    panel=$(get_active_panel)
    if [ "$($panel.in_archive)" = "1" ]; then
        __HACKFM_FKEY_LABEL="Extract"
    fi
}

fsextract.run() {
    local active_panel
    active_panel=$(get_active_panel)
    [ "$($active_panel.in_archive)" != "1" ] && return 1

    local active_list
    active_list=$($active_panel.list_source)
    local other_list
    other_list=$($(get_other_panel).list_source)
    local dest_path
    dest_path=$($other_list.path)

    local archive_path
    archive_path=$($active_panel.archive_path)
    local archive_name
    archive_name=$(basename "$archive_path")

    local filename filetype fpath
    IFS='|' read -r filename filetype fpath <<< "$($active_list.get_selected_item)"

    if [ "$filename" = ".." ] || [ "$filename" = "<empty>" ]; then
        return 1
    fi

    local files_to_extract=()
    local extract_label=""
    local marked_count
    marked_count=$($active_list.count_selected)
    if [ "$marked_count" -gt 0 ]; then
        while IFS= read -r p; do
            files_to_extract+=("$p")
        done < <($active_list.get_marked_paths)
        extract_label="$marked_count file(s)"
    else
        files_to_extract=("$fpath")
        extract_label="\"$filename\""
    fi

    # Dialog dimensions
    local size
    size=$(tui.screen.size)
    local rows=${size% *}
    local cols=${size#* }
    local dialog_width=60
    [ $dialog_width -gt $((cols - 4)) ] && dialog_width=$((cols - 4))
    local dialog_height=9
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
    printf " Extract "
    tui.color.reset

    # Labels
    tui.cursor.move $((dialog_row + 2)) $((dialog_col + 2))
    tui.color.bg_white; tui.color.black
    printf "%-$((dialog_width - 4))s" "From: $archive_name  $extract_label"
    tui.cursor.move $((dialog_row + 3)) $((dialog_col + 2))
    printf "%-$((dialog_width - 4))s" "To:"

    # Destination input
    local input="$dest_path"
    local cursor_pos=${#input}
    local field_width=$((dialog_width - 4))

    tui.cursor.show
    while true; do
        tui.cursor.move $((dialog_row + 4)) $((dialog_col + 2))
        tui.color.bg_cyan; tui.color.black
        local display_input="$input"
        if [ ${#display_input} -gt $field_width ]; then
            display_input="${display_input:$((${#display_input} - field_width))}"
        fi
        printf "%-${field_width}s" "$display_input"
        tui.color.reset

        tui.cursor.move $((dialog_row + 6)) $((dialog_col + dialog_width/2 - 9))
        tui.color.bg_cyan; tui.color.black
        printf "[< Extract >]"
        tui.color.reset
        tui.color.bg_white; tui.color.black
        printf "   [ Cancel ]"
        tui.color.reset

        local visible_cursor=$cursor_pos
        [ ${#input} -gt $field_width ] && visible_cursor=$field_width
        tui.cursor.move $((dialog_row + 4)) $((dialog_col + 2 + visible_cursor))

        local key
        key=$(tui.input.key 2>&1) || continue
        case "$key" in
            ENTER)    tui.cursor.hide; break ;;
            ESC)      tui.cursor.hide; dialog_cleanup; broker.publish "dialog_closed" ""; return 0 ;;
            BACKSPACE)
                if [ $cursor_pos -gt 0 ]; then
                    input="${input:0:$((cursor_pos-1))}${input:$cursor_pos}"
                    cursor_pos=$(( cursor_pos - 1 ))
                fi
                ;;
            DELETE)
                [ $cursor_pos -lt ${#input} ] && input="${input:0:$cursor_pos}${input:$((cursor_pos+1))}"
                ;;
            LEFT)  [ $cursor_pos -gt 0 ] && cursor_pos=$(( cursor_pos - 1 )) ;;
            RIGHT) [ $cursor_pos -lt ${#input} ] && cursor_pos=$(( cursor_pos + 1 )) ;;
            HOME)  cursor_pos=0 ;;
            END)   cursor_pos=${#input} ;;
            *)
                if [ ${#key} -eq 1 ]; then
                    input="${input:0:$cursor_pos}${key}${input:$cursor_pos}"
                    cursor_pos=$(( cursor_pos + 1 ))
                fi
                ;;
        esac
    done

    dialog_cleanup

    local dest="$input"
    if [ -z "$dest" ]; then
        broker.publish "dialog_closed" ""
        return 0
    fi

    local arch_list
    arch_list=$($active_panel.list_source)
    local result
    fsextract._extract_with_progress "$arch_list" "$dest" "${files_to_extract[@]}"
    result=$?

    reload_other_panel
    broker.publish "dialog_closed" ""

    [ $result -ne 0 ] && show_error "Extraction failed"
    return 0
}

fsextract._extract_with_progress() {
    local arch_list="$1"
    local dest="$2"
    shift 2
    local files=("$@")
    local total=${#files[@]}

    tui.cursor.hide

    if [ $total -eq 0 ]; then
        _draw_status_dialog "Extract" "Extracting archive..."
        $arch_list.extract_files "$dest"
        tui.cursor.show
        return $?
    fi

    local failed=0 i
    for ((i=0; i<total; i++)); do
        local f="${files[$i]}"
        local label="${f##*/}"
        _draw_progress_dialog "Extract" "$label" \
            "$i" "$total" "$i" "$total"
        $arch_list.extract_files "$dest" "$f" || failed=1
    done

    _draw_progress_dialog "Extract" "Done" "$total" "$total" "$total" "$total"
    tui.cursor.show
    return $failed
}
