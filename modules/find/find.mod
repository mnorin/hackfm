#!/bin/bash
# find module - Find file by name and/or content (Alt-F7)

find.init() {
    hackfm.module.register_key "F17" "find.run" "Find"
    hackfm.module.add_menu_item "Command" "Find File" "F17" "find.run"
}

# State
declare -ag __FIND_RESULTS=()   # "filepath|line|match" entries
__FIND_QUERY_NAME=""
__FIND_QUERY_CONTENT=""
__FIND_START_DIR=""
__FIND_CASE_SENSITIVE=0
__FIND_SKIP_HIDDEN=1

find.run() {
    local active_panel
    active_panel=$(get_active_panel)
    __FIND_START_DIR=$($active_panel.list.path)

    find._show_search_form
}

# ============================================================================
# SEARCH FORM
# ============================================================================

find._show_search_form() {
    local size rows cols
    size=$(tui.screen.size)
    rows=${size% *}
    cols=${size#* }

    local w=60 h=13
    local r=$(( (rows - h) / 2 ))
    local c=$(( (cols - w) / 2 ))
    local inner_w=$(( w - 4 ))

    # Shadow
    tui.color.bg_black
    for ((i=r+1; i<r+h+1; i++)); do
        tui.cursor.move $i $((c+2))
        printf "%${w}s" ""
    done

    # Background
    tui.color.bg_white
    tui.color.black
    for ((i=r; i<r+h; i++)); do
        tui.cursor.move $i $c
        printf "%${w}s" ""
    done

    # Border
    tui.color.bg_white
    tui.color.black
    tui.box.draw $r $c $w $h

    # Title
    tui.cursor.move $r $((c+2))
    tui.color.bg_white
    tui.color.black
    tui.color.bold
    printf " Find File "
    tui.color.reset

    # Labels
    tui.color.bg_white
    tui.color.black
    tui.cursor.move $((r+2)) $((c+2)); printf "%-16s" "File name:"
    tui.cursor.move $((r+4)) $((c+2)); printf "%-16s" "Content:"
    tui.cursor.move $((r+6)) $((c+2)); printf "%-16s" "Start at:"
    tui.cursor.move $((r+8)) $((c+2)); printf "[ ] Case sensitive"
    tui.cursor.move $((r+9)) $((c+2)); printf "[x] Skip hidden"
    tui.color.reset

    # Run the form input loop
    find._form_loop $r $c $w $inner_w
}

find._draw_field() {
    local row=$1 col=$2 width=$3 value=$4 active=$5
    tui.cursor.move $row $((col+18))
    if [ "$active" = "1" ]; then
        tui.color.bg_cyan
        tui.color.black
        tui.color.bold
    else
        tui.color.bg_black
        tui.color.white
    fi
    printf "%-${width}s" "${value:0:$width}"
    tui.color.reset
}

find._draw_checkbox() {
    local row=$1 col=$2 label=$3 value=$4 active=$5
    tui.cursor.move $row $((col+2))
    if [ "$active" = "1" ]; then
        tui.color.bg_cyan
        tui.color.black
        tui.color.bold
    else
        tui.color.bg_white
        tui.color.black
    fi
    if [ "$value" = "1" ]; then
        printf "[x] %s" "$label"
    else
        printf "[ ] %s" "$label"
    fi
    tui.color.reset
}

find._draw_button() {
    local row=$1 col=$2 label=$3 active=$4
    tui.cursor.move $row $col
    if [ "$active" = "1" ]; then
        tui.color.bg_cyan
        tui.color.black
        tui.color.bold
    else
        tui.color.bg_white
        tui.color.black
    fi
    printf "[ %s ]" "$label"
    tui.color.reset
}

find._form_loop() {
    local r=$1 c=$2 w=$3 inner_w=$4
    local field_w=$(( inner_w - 18 ))

    local name_val="$__FIND_QUERY_NAME"
    local content_val="$__FIND_QUERY_CONTENT"
    local dir_val="$__FIND_START_DIR"
    local case_val=$__FIND_CASE_SENSITIVE
    local hidden_val=$__FIND_SKIP_HIDDEN

    # Fields: 0=name 1=content 2=dir 3=case 4=hidden 5=find_btn 6=cancel_btn
    local focus=0

    tui.cursor.show

    while true; do
        # Redraw all fields
        find._draw_field $((r+2)) $c $field_w "$name_val"    "$([ $focus -eq 0 ] && echo 1 || echo 0)"
        find._draw_field $((r+4)) $c $field_w "$content_val" "$([ $focus -eq 1 ] && echo 1 || echo 0)"
        find._draw_field $((r+6)) $c $field_w "$dir_val"     "$([ $focus -eq 2 ] && echo 1 || echo 0)"
        find._draw_checkbox $((r+8)) $c "Case sensitive" "$case_val"   "$([ $focus -eq 3 ] && echo 1 || echo 0)"
        find._draw_checkbox $((r+9)) $c "Skip hidden"    "$hidden_val" "$([ $focus -eq 4 ] && echo 1 || echo 0)"
        find._draw_button $((r+11)) $((c + w/2 - 10)) "Find"   "$([ $focus -eq 5 ] && echo 1 || echo 0)"
        find._draw_button $((r+11)) $((c + w/2 + 1))  "Cancel" "$([ $focus -eq 6 ] && echo 1 || echo 0)"

        # Position cursor in active text field
        case $focus in
            0) tui.cursor.move $((r+2)) $((c+18+${#name_val})) ;;
            1) tui.cursor.move $((r+4)) $((c+18+${#content_val})) ;;
            2) tui.cursor.move $((r+6)) $((c+18+${#dir_val})) ;;
            *) tui.cursor.hide ;;
        esac

        local key
        key=$(tui.input.key)

        case "$key" in
            TAB|DOWN)
                focus=$(( (focus + 1) % 7 ))
                tui.cursor.show
                ;;
            UP)
                focus=$(( (focus + 6) % 7 ))
                tui.cursor.show
                ;;
            ENTER)
                case $focus in
                    0|1|2|3|4) focus=$(( focus + 1 )) ;;  # advance to next
                    5)  # Find button
                        __FIND_QUERY_NAME="$name_val"
                        __FIND_QUERY_CONTENT="$content_val"
                        __FIND_START_DIR="$dir_val"
                        __FIND_CASE_SENSITIVE=$case_val
                        __FIND_SKIP_HIDDEN=$hidden_val
                        tui.cursor.hide
                        find._run_search
                        return
                        ;;
                    6)  # Cancel
                        broker.publish "dialog_closed" ""
                        return
                        ;;
                esac
                ;;
            SPACE)
                case $focus in
                    3) [ "$case_val" = "1" ] && case_val=0 || case_val=1 ;;
                    4) [ "$hidden_val" = "1" ] && hidden_val=0 || hidden_val=1 ;;
                esac
                ;;
            BACKSPACE)
                case $focus in
                    0) [ ${#name_val} -gt 0 ] && name_val="${name_val%?}" ;;
                    1) [ ${#content_val} -gt 0 ] && content_val="${content_val%?}" ;;
                    2) [ ${#dir_val} -gt 0 ] && dir_val="${dir_val%?}" ;;
                esac
                ;;
            ESC)
                broker.publish "dialog_closed" ""
                return
                ;;
            *)
                if [ ${#key} -eq 1 ]; then
                    case $focus in
                        0) [ ${#name_val} -lt $field_w ] && name_val+="$key" ;;
                        1) [ ${#content_val} -lt $field_w ] && content_val+="$key" ;;
                        2) [ ${#dir_val} -lt $field_w ] && dir_val+="$key" ;;
                    esac
                fi
                ;;
        esac
    done
}

# ============================================================================
# SEARCH EXECUTION
# ============================================================================

find._run_search() {
    __FIND_RESULTS=()

    local size rows cols
    size=$(tui.screen.size)
    rows=${size% *}
    cols=${size#* }

    local w=60 h=5
    local r=$(( (rows - h) / 2 ))
    local c=$(( (cols - w) / 2 ))

    # Progress dialog
    tui.color.bg_white
    tui.color.black
    for ((i=r; i<r+h; i++)); do
        tui.cursor.move $i $c
        printf "%${w}s" ""
    done
    tui.color.bg_white
    tui.color.black
    tui.box.draw $r $c $w $h
    tui.cursor.move $r $((c+2))
    tui.color.bg_white
    tui.color.black
    tui.color.bold
    printf " Searching... "
    tui.color.reset
    tui.cursor.move $((r+2)) $((c+2))
    tui.color.bg_white
    tui.color.black
    printf "Searching in: %-$((w-16))s" "${__FIND_START_DIR:0:$((w-16))}"

    # Build find command
    local find_opts=()
    find_opts+=("$__FIND_START_DIR")
    [ "$__FIND_SKIP_HIDDEN" = "1" ] && find_opts+=(-not -path "*/.*")
    find_opts+=(-type f)
    if [ -n "$__FIND_QUERY_NAME" ]; then
        if [ "$__FIND_CASE_SENSITIVE" = "1" ]; then
            find_opts+=(-name "$__FIND_QUERY_NAME")
        else
            find_opts+=(-iname "$__FIND_QUERY_NAME")
        fi
    fi

    local grep_opts=()
    if [ -n "$__FIND_QUERY_CONTENT" ]; then
        grep_opts+=(-l)
        [ "$__FIND_CASE_SENSITIVE" = "0" ] && grep_opts+=(-i)
        grep_opts+=("$__FIND_QUERY_CONTENT")
    fi

    # Execute search
    local file count=0
    while IFS= read -r file; do
        if [ -n "$__FIND_QUERY_CONTENT" ]; then
            if grep -q "${grep_opts[@]}" "$file" 2>/dev/null; then
                __FIND_RESULTS+=("$file")
                count=$(( count + 1 ))
                tui.cursor.move $((r+3)) $((c+2))
                tui.color.bg_white
                tui.color.black
                printf "Found: %-$((w-10))s" "$count files"
            fi
        else
            __FIND_RESULTS+=("$file")
            count=$(( count + 1 ))
            tui.cursor.move $((r+3)) $((c+2))
            tui.color.bg_white
            tui.color.black
            printf "Found: %-$((w-10))s" "$count files"
        fi
    done < <(find "${find_opts[@]}" 2>/dev/null)

    tui.color.reset
    find._show_results
}

# ============================================================================
# RESULTS VIEW
# ============================================================================

__FIND_RESULT_SCROLL=0
__FIND_RESULT_SELECTED=0

find._show_results() {
    local size rows cols
    size=$(tui.screen.size)
    rows=${size% *}
    cols=${size#* }

    local w=$(( cols - 4 ))
    local h=$(( rows - 4 ))
    local r=2
    local c=2
    local list_h=$(( h - 4 ))  # minus title, status, hints

    __FIND_RESULT_SCROLL=0
    __FIND_RESULT_SELECTED=0

    find._draw_results_frame $r $c $w $h $list_h
    find._results_loop $r $c $w $h $list_h
}

find._draw_results_frame() {
    local r=$1 c=$2 w=$3 h=$4 list_h=$5
    local inner_w=$(( w - 2 ))
    local count=${#__FIND_RESULTS[@]}

    # Shadow
    tui.color.bg_black
    for ((i=r+1; i<r+h+1; i++)); do
        tui.cursor.move $i $((c+2))
        printf "%${w}s" ""
    done

    # Background
    tui.color.bg_white
    tui.color.black
    for ((i=r; i<r+h; i++)); do
        tui.cursor.move $i $c
        printf "%${w}s" ""
    done

    tui.box.draw $r $c $w $h

    # Title
    tui.cursor.move $r $((c+2))
    tui.color.bg_white
    tui.color.black
    tui.color.bold
    printf " Find Results "
    tui.color.reset

    # Status
    tui.cursor.move $((r+1)) $((c+1))
    tui.color.bg_white
    tui.color.black
    if [ $count -eq 0 ]; then
        printf " No files found.%-$((inner_w-16))s" ""
    else
        printf " %d file(s) found.%-$((inner_w-17))s" "$count" ""
    fi

    # Hints
    tui.cursor.move $((r+h-2)) $((c+1))
    tui.color.bg_white
    tui.color.black
    printf " Enter=Go to file  F3=View  n=New search  Esc=Close"
    printf "%$((inner_w - 51))s" ""
    tui.color.reset

    find._draw_results_list $r $c $w $list_h
}

find._draw_results_list() {
    local r=$1 c=$2 w=$3 list_h=$4
    local inner_w=$(( w - 2 ))
    local count=${#__FIND_RESULTS[@]}

    for ((i=0; i<list_h; i++)); do
        local idx=$(( __FIND_RESULT_SCROLL + i ))
        tui.cursor.move $((r+2+i)) $((c+1))
        if [ $idx -ge $count ]; then
            tui.color.bg_white
            tui.color.black
            printf "%-${inner_w}s" ""
        elif [ $idx -eq $__FIND_RESULT_SELECTED ]; then
            tui.color.bg_cyan
            tui.color.black
            printf "%-${inner_w}s" "${__FIND_RESULTS[$idx]}"
        else
            tui.color.bg_white
            tui.color.black
            printf "%-${inner_w}s" "${__FIND_RESULTS[$idx]}"
        fi
    done
    tui.color.reset
}

find._results_loop() {
    local r=$1 c=$2 w=$3 h=$4 list_h=$5
    local count=${#__FIND_RESULTS[@]}

    while true; do
        local key
        key=$(tui.input.key)

        case "$key" in
            UP)
                if [ $__FIND_RESULT_SELECTED -gt 0 ]; then
                    __FIND_RESULT_SELECTED=$(( __FIND_RESULT_SELECTED - 1 ))
                    if [ $__FIND_RESULT_SELECTED -lt $__FIND_RESULT_SCROLL ]; then
                        __FIND_RESULT_SCROLL=$(( __FIND_RESULT_SCROLL - 1 ))
                    fi
                    find._draw_results_list $r $c $w $list_h
                fi
                ;;
            DOWN)
                if [ $__FIND_RESULT_SELECTED -lt $(( count - 1 )) ]; then
                    __FIND_RESULT_SELECTED=$(( __FIND_RESULT_SELECTED + 1 ))
                    if [ $__FIND_RESULT_SELECTED -ge $(( __FIND_RESULT_SCROLL + list_h )) ]; then
                        __FIND_RESULT_SCROLL=$(( __FIND_RESULT_SCROLL + 1 ))
                    fi
                    find._draw_results_list $r $c $w $list_h
                fi
                ;;
            ENTER)
                [ $count -gt 0 ] && find._goto_file
                broker.publish "dialog_closed" ""
                return
                ;;
            F3)
                [ $count -gt 0 ] && find._view_file
                find._draw_results_frame $r $c $w $h $list_h
                ;;
            n|N)
                find._show_search_form
                return
                ;;
            ESC)
                broker.publish "dialog_closed" ""
                return
                ;;
        esac
    done
}

find._goto_file() {
    local filepath="${__FIND_RESULTS[$__FIND_RESULT_SELECTED]}"
    local dirpath
    dirpath=$(dirname "$filepath")
    local filename
    filename=$(basename "$filepath")

    local active_panel
    active_panel=$(get_active_panel)
    local list
    list=$($active_panel.list_source)
    local panel_height
    panel_height=$($active_panel.height)

    $list.path = "$dirpath"
    $list.load
    $list.find_and_select "$filename" $(( panel_height - 3 ))
    $active_panel.prerender_all_rows
}

find._view_file() {
    local filepath="${__FIND_RESULTS[$__FIND_RESULT_SELECTED]}"
    viewhandler.open "$filepath"
}
