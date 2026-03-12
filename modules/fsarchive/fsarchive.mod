#!/bin/bash
# fsarchive module - Archive and extract files (F12/F13)

fsarchive.init() {
    hackfm.module.register_key "F12" "fsarchive.archive" "Archive"
    hackfm.module.register_key "F13" "fsarchive.extract" "Extract"
}

# ============================================================================
# ARCHIVE
# ============================================================================

fsarchive.archive() {
    local active_list
    active_list=$(get_active_panel).list
    local path
    path=$($active_list.path)
    local selected_count
    selected_count=$($active_list.count_selected)

    # Determine default archive name
    local default_name
    if [ $selected_count -gt 0 ]; then
        default_name="archive.tar.gz"
    else
        local filename filetype
        IFS='|' read -r filename filetype _ <<< "$(get_selected_item)"
        $active_list.is_special "$filename" && return
        default_name="${filename}.tar.gz"
    fi

    # Ask for archive name + format
    file_dialog.show_input "Archive" "Archive name:" "$default_name"
    dialog_cleanup

    if [ "$(file_dialog.result)" != "0" ]; then
        broker.publish "dialog_closed" ""
        return
    fi

    local archive_name
    archive_name=$(file_dialog.input_value)
    [ -z "$archive_name" ] && return

    local archive_path="$path/$archive_name"

    # Build list of items to archive
    local items=()
    if [ $selected_count -gt 0 ]; then
        local fname ftype
        while IFS='|' read -r fname ftype; do
            items+=("$fname")
        done < <($active_list.get_selected)
    else
        local filename
        IFS='|' read -r filename _ <<< "$(get_selected_item)"
        items+=("$filename")
    fi

    # Detect format from extension and run
    _draw_status_dialog "Archive" "Creating $archive_name..."
    local rc=0
    (
        cd "$path" || exit 1
        fsarchive._create "$archive_path" "${items[@]}"
    ) || rc=$?

    if [ $rc -eq 0 ]; then
        broker.publish "selection.clear" ""
        reload_active_panel
        local active_panel
        active_panel=$(get_active_panel)
        $active_list.find_and_select "$archive_name" $(( $($active_panel.height) - 3 ))
        $active_panel.prerender_all_rows
        broker.publish "dialog_closed" ""
    else
        show_error "Failed to create archive: $archive_name"
    fi
}

fsarchive._create() {
    local archive="$1"
    shift
    local items=("$@")

    case "$archive" in
        *.tar.gz|*.tgz)   tar czf "$archive" "${items[@]}" ;;
        *.tar.bz2|*.tbz2) tar cjf "$archive" "${items[@]}" ;;
        *.tar.xz|*.txz)   tar cJf "$archive" "${items[@]}" ;;
        *.tar)             tar cf  "$archive" "${items[@]}" ;;
        *.zip)             zip -r  "$archive" "${items[@]}" ;;
        *.7z)              7z a    "$archive" "${items[@]}" ;;
        *)
            # Default to tar.gz if no recognised extension
            tar czf "${archive}.tar.gz" "${items[@]}"
            ;;
    esac
}

# ============================================================================
# EXTRACT
# ============================================================================

fsarchive.extract() {
    local active_list
    active_list=$(get_active_panel).list
    local path
    path=$($active_list.path)

    local filename filetype
    IFS='|' read -r filename filetype _ <<< "$(get_selected_item)"

    $active_list.is_special "$filename" && return

    if [ "$filetype" != "f" ]; then
        show_error "Select an archive file to extract"
        return
    fi

    local archive_path="$path/$filename"

    # Default destination — other panel path if available, else current
    local other_list
    other_list=$(get_other_panel).list
    local default_dest
    default_dest=$($other_list.path)
    [ -z "$default_dest" ] && default_dest="$path"

    file_dialog.show_input "Extract" "Extract to:" "$default_dest"
    dialog_cleanup

    if [ "$(file_dialog.result)" != "0" ]; then
        broker.publish "dialog_closed" ""
        return
    fi

    local dest
    dest=$(file_dialog.input_value)
    [ -z "$dest" ] && return

    if [ ! -d "$dest" ]; then
        file_dialog.show_confirm "Create directory" "Destination doesn't exist. Create it?"
        dialog_cleanup
        if [ "$(file_dialog.result)" = "0" ]; then
            mkdir -p "$dest" 2>/dev/null || { show_error "Failed to create directory"; return; }
        else
            broker.publish "dialog_closed" ""
            return
        fi
    fi

    _draw_status_dialog "Extract" "Extracting $filename..."
    local rc=0
    fsarchive._extract "$archive_path" "$dest" || rc=$?

    if [ $rc -eq 0 ]; then
        reload_both_panels
        broker.publish "dialog_closed" ""
    else
        show_error "Failed to extract: $filename"
    fi
}

fsarchive._extract() {
    local archive="$1"
    local dest="$2"

    case "$archive" in
        *.tar.gz|*.tgz)   tar xzf  "$archive" -C "$dest" ;;
        *.tar.bz2|*.tbz2) tar xjf  "$archive" -C "$dest" ;;
        *.tar.xz|*.txz)   tar xJf  "$archive" -C "$dest" ;;
        *.tar)             tar xf   "$archive" -C "$dest" ;;
        *.zip)             unzip -q "$archive" -d "$dest" ;;
        *.7z)              7z x     "$archive" -o"$dest"  ;;
        *)
            show_error "Unknown archive format: ${archive##*/}"
            return 1
            ;;
    esac
}
