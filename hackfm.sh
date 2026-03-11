#!/bin/bash
# hackfm.sh - Hackable File Manager

# Get HackFM installation directory (for sourcing class files)
export HACKFM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$HACKFM_DIR/logs"
LOG_FILE="$HACKFM_DIR/logs/hackfm.log"

# Enable error logging
exec 2>"$LOG_FILE"
set -E  # Inherit error traps

# Error handler
error_handler() {
    local line=$1
    declare -F tui.cursor.style.default &>/dev/null && tui.cursor.style.default
    declare -F tui.cursor.show          &>/dev/null && tui.cursor.show
    declare -F tui.screen.clear         &>/dev/null && tui.screen.clear
    declare -F tui.screen.main          &>/dev/null && tui.screen.main
    [ -n "$ORIGINAL_STTY" ] && stty "$ORIGINAL_STTY" 2>/dev/null
    echo "ERROR at line $line in ${BASH_SOURCE[1]:-unknown}"
    echo "Call stack:"
    local i
    for ((i=1; i<${#FUNCNAME[@]}; i++)); do
        echo "  ${FUNCNAME[$i]} (${BASH_SOURCE[$i+1]:-?}:${BASH_LINENO[$i-1]})"
    done
    echo "Check $LOG_FILE for details"
    exit 1
}

# Terminal resize handler
resize_handler() {
    hackfm.read_term_size
    local panel_width=$(((__HACKFM_COLS - 3) / 2))
    local panel_height=$((__HACKFM_ROWS - 5))

    left_panel.x = 1
    left_panel.y = 3
    left_panel.width = $panel_width
    left_panel.height = $panel_height

    right_panel.x = $((panel_width + 3))
    right_panel.y = 3
    right_panel.width = $((__HACKFM_COLS - panel_width - 4))
    right_panel.height = $panel_height

    cmd.row = $((__HACKFM_ROWS - 1))
    cmd.col = 1
    cmd.width = $__HACKFM_COLS

    left_panel.prerender_all_rows
    right_panel.prerender_all_rows
    draw_screen
}

# Set up error and resize traps
trap 'error_handler $LINENO' ERR
trap 'resize_handler' WINCH
trap 'hackfm.cleanup; exit 0' INT TERM

# Load TUI (from shared tui directory)
. "$HACKFM_DIR/tui/cursor.class"
. "$HACKFM_DIR/tui/screen.class"
. "$HACKFM_DIR/tui/color.class"
. "$HACKFM_DIR/tui/box.class"
. "$HACKFM_DIR/tui/input.class"
. "$HACKFM_DIR/tui/region.class"
. "$HACKFM_DIR/tui/style.class"

# Load components (from HackFM directory)
. "$HACKFM_DIR/hackfmlib.h"

. "$HACKFM_DIR/openhandler.class"

. "$HACKFM_DIR/dialogs.class"
. "$HACKFM_DIR/modules.class"

# App state
ACTIVE_PANEL=0
ORIGINAL_STTY=""

PANELS=("left_panel" "right_panel")

# Terminal dimensions — set by hackfm.read_term_size
__HACKFM_ROWS=24
__HACKFM_COLS=80

# Read current terminal size into __HACKFM_ROWS / __HACKFM_COLS
hackfm.read_term_size() {
    local size
    size=$(tui.screen.size)
    __HACKFM_ROWS=${size% *}
    __HACKFM_COLS=${size#* }
    stty -ixon 2>/dev/null
}

# Top-level object instantiation — declarative, order matters for dependencies
modules.pre_init

fkeybar main_fkeybar
title main_title
main_title.text_left = "HackFM - Hackable File Manager"

panel left_panel
filelist left_panel.list
left_panel.list.path = "$PWD"

panel right_panel
filelist right_panel.list
right_panel.list.path = "$HOME"

tui_dialog file_dialog

commandline cmd
cmd.text = ""
cmd.cursor_pos = 0

msgbroker broker

menu main_menu

# Read a value from hackfm.conf
# Usage: conf_get KEY [DEFAULT]
conf_get() {
    local key="$1"
    local default="${2:-}"
    local conf="$HACKFM_DIR/conf/hackfm.conf"
    if [ -f "$conf" ]; then
        local val
        val=$(grep -m1 "^${key}=" "$conf" 2>/dev/null | cut -d= -f2-)
        [ -n "$val" ] && echo "$val" && return
    fi
    echo "$default"
}

# MODULE API — thin wrappers around fkeybar
hackfm.module.register_key()       { fkeybar.register_key "$@"; }
hackfm.module.register_key_label() { fkeybar.register_key_label "$@"; }

hackfm.module.add_menu_item() {
    local menu="$1"
    local label="$2"
    local hotkey="$3"
    local func="$4"
    main_menu.add_subitem "$menu" "$label" "$hotkey" "$func"
}

hackfm.module.subscribe() {
    local topic="$1"
    local handler="$2"
    broker.subscribe "$topic" "$handler"
}

hackfm.cleanup() {
    trap - ERR WINCH INT TERM USR1
    tui.cursor.style.default
    tui.cursor.show
    tui.screen.clear
    tui.screen.main
    stty ixon 2>/dev/null
    [ -n "$ORIGINAL_STTY" ] && stty "$ORIGINAL_STTY" 2>/dev/null
    modules.on_exit
}

get_active_panel() {
    echo "${PANELS[$ACTIVE_PANEL]}"
}

# Get the inactive (other) panel object name
get_other_panel() {
    local other_idx=$((1 - ACTIVE_PANEL))
    echo "${PANELS[$other_idx]}"
}

# Get selected item info from active panel
# Returns: filename|filetype|path (pipe-separated)
# Usage: IFS='|' read -r filename filetype path <<< "$(get_selected_item)"
get_selected_item() {
    local panel=$(get_active_panel)
    $panel.get_selected_item
}

reload_active_panel() {
    local panel=$(get_active_panel)
    $panel.reload
}

reload_other_panel() {
    local panel=$(get_other_panel)
    $panel.reload
}

# Reload both panels' directories
reload_both_panels() {
    left_panel.reload
    right_panel.reload
}

# Terminal lifecycle handlers
handle_terminal_enter() {
    tui.screen.main
    tui.cursor.show
    stty sane
}

handle_terminal_exit() {
    tui.screen.alt
    stty -echo 2>/dev/null
    hackfm.read_term_size
    reload_both_panels
    draw_screen
}

# process_message wrappers for plain function broker subscribers
handle_terminal_enter.process_message() { handle_terminal_enter; }
handle_terminal_exit.process_message()  { handle_terminal_exit;  }
draw_main_frame.process_message()       { draw_main_frame;       }

# ============================================================================
# INITIALIZATION
# ============================================================================

init() {
    # Save original terminal settings before TUI takes over
    ORIGINAL_STTY=$(stty -g 2>/dev/null)

    # Disable echo for entire app lifetime
    stty -echo 2>/dev/null

    # Switch to alternate screen
    tui.screen.alt

    # Read terminal size
    hackfm.read_term_size
    local panel_width=$(((__HACKFM_COLS - 3) / 2))
    local panel_height=$((__HACKFM_ROWS - 5))

    left_panel.x = 1
    left_panel.y = 3
    left_panel.width = $panel_width
    left_panel.height = $panel_height
    left_panel.active = 1

    right_panel.x = $((panel_width + 3))
    right_panel.y = 3
    right_panel.width = $((__HACKFM_COLS - panel_width - 4))
    right_panel.height = $panel_height
    right_panel.active = 0

    # Set command line geometry and prompt
    cmd.row = $((__HACKFM_ROWS - 1))
    cmd.col = 1
    cmd.width = $__HACKFM_COLS
    cmd.prompt = "$USER@$(hostname):$PWD\$ "

    # Wire objects to broker
    left_panel.register broker
    right_panel.register broker
    cmd.register broker

    # Subscribe to broker topics
    broker.subscribe "ui.terminal_enter"  "handle_terminal_enter"
    broker.subscribe "ui.terminal_exit"   "handle_terminal_exit"
    broker.subscribe "viewer_closed"      "draw_main_frame"
    broker.subscribe "editor_closed"      "draw_main_frame"

    # Wire dialog to panels
    left_panel.dialog = file_dialog
    right_panel.dialog = file_dialog

    # Setup menu and init modules
    setup_menu
    modules.init
}

# ============================================================================
# RENDERING
# ============================================================================

# Redraw only panels that overlap the last dropdown area
redraw_panels_for_dropdown() {
    local drop_col=$(main_menu.last_dropdown_col)
    local drop_right=$(main_menu.last_dropdown_right)
    if [ -z "$drop_col" ]; then
        left_panel.render
        right_panel.render
        return
    fi

    local lx=$(left_panel.x)
    local lright=$((lx + $(left_panel.width) + 1))
    local rx=$(right_panel.x)
    local rright=$((rx + $(right_panel.width) + 1))

    # Redraw panel if dropdown overlaps its column range
    if [ "$drop_right" -ge "$lx" ] && [ "$drop_col" -le "$lright" ]; then
        left_panel.render
    fi
    if [ "$drop_right" -ge "$rx" ] && [ "$drop_col" -le "$rright" ]; then
        right_panel.render
    fi
}

# Draw title bar and F-key bar
draw_main_frame() {
    main_title.width = $__HACKFM_COLS
    main_title.render
    fkeybar.update_labels
    main_fkeybar.row = $__HACKFM_ROWS
    main_fkeybar.width = $__HACKFM_COLS
    main_fkeybar.render
}

draw_screen() {
    tui.screen.alt
    tui.cursor.hide
    tui.screen.clear
    fkeybar.update_labels
    main_title.width = $__HACKFM_COLS
    main_title.render
    main_fkeybar.row = $__HACKFM_ROWS
    main_fkeybar.width = $__HACKFM_COLS
    main_fkeybar.render
    left_panel.render
    right_panel.render
    draw_command_line
    local cmd_text=$(cmd.text)
    local cmd_row=$(cmd.row)
    local cmd_prompt=$(cmd.prompt)
    local prompt_len=${#cmd_prompt}
    local cursor_col=$((prompt_len + ${#cmd_text} + 1))
    tui.cursor.move $cmd_row $cursor_col
    tui.cursor.show
}

# Draw command line (just above F-key bar)
draw_command_line() {
    cmd.render
}

# ============================================================================
# COMMAND LINE FUNCTIONS
# ============================================================================

# Execute command from command line
execute_command() {
    local command=$(cmd.text)
    
    # Skip if empty
    if [ -z "$command" ]; then
        return
    fi
    
    # Get current directory for execution
    local list=$(get_active_panel).list
    local exec_path=$($list.path)
    
    # Add command to history (using commandline's execute method)
    cmd.execute > /dev/null
    
    # Clear command line for next command
    cmd.clear
    
    # Switch to main screen for terminal output
    tui.screen.main
    
    # Restore terminal to sane interactive mode
    stty sane
    
    # Reset colors for command execution
    tui.color.reset
    
    # Execute the command
    cd "$exec_path"
    echo "$USER@$(hostname):$exec_path\$ $command"

    trap - ERR
    set +e
    eval "$command" 2>&1
    set -e
    trap '__ba_err_report $? $LINENO' ERR

    echo ""
    
    # Check if directory changed and update panel
    local new_path=$(pwd)
    if [ "$new_path" != "$exec_path" ]; then
        $list.path = "$new_path"
    fi
    
    stty -echo 2>/dev/null
    tui.screen.alt
    hackfm.read_term_size
    reload_both_panels
}

# ============================================================================
# NAVIGATION
# ============================================================================

# Switch panels
switch_panel() {
    local old_panel=$(get_active_panel)
    ACTIVE_PANEL=$((1 - ACTIVE_PANEL))
    local new_panel=$(get_active_panel)
    $old_panel.active = 0
    $new_panel.active = 1
}

# Navigate
navigate() {
    local direction=$1
    local panel=$(get_active_panel)
    $panel.navigate "$direction"
}

# Open item
open_item() {
    local panel=$(get_active_panel)
    $panel.enter
    local action=$($panel.enter_result)

    if [[ "$action" == open:* ]] || [[ "$action" == execute:* ]]; then
        local filepath="${action#*:}"
        openhandler.open "$filepath"
    fi
}

# ============================================================================
# MENU
# ============================================================================

handler_sort_left_name()  { left_panel.sort name; }
handler_sort_left_date()  { left_panel.sort date; }
handler_sort_left_size()  { left_panel.sort size; }
handler_sort_left_ext()   { left_panel.sort ext;  }
handler_sort_right_name() { right_panel.sort name; }
handler_sort_right_date() { right_panel.sort date; }
handler_sort_right_size() { right_panel.sort size; }
handler_sort_right_ext()  { right_panel.sort ext;  }

setup_menu() {
    main_menu.background_redraw = "redraw_panels_for_dropdown"
    main_menu.clear

    # Left panel menu
    main_menu.add_item "Left"
    main_menu.add_subitem "Left" "Sort by Name" "" "handler_sort_left_name"
    main_menu.add_subitem "Left" "Sort by Time" "" "handler_sort_left_date"
    main_menu.add_subitem "Left" "Sort by Size" "" "handler_sort_left_size"
    main_menu.add_subitem "Left" "Sort by Extension" "" "handler_sort_left_ext"

    # File menu
    main_menu.add_item "File"

    # Command menu
    main_menu.add_item "Command"

    # Options menu
    main_menu.add_item "Options"

    # Right panel menu
    main_menu.add_item "Right"
    main_menu.add_subitem "Right" "Sort by Name" "" "handler_sort_right_name"
    main_menu.add_subitem "Right" "Sort by Time" "" "handler_sort_right_date"
    main_menu.add_subitem "Right" "Sort by Size" "" "handler_sort_right_size"
    main_menu.add_subitem "Right" "Sort by Extension" "" "handler_sort_right_ext"

    # Register built-in F-key bindings
    hackfm.module.register_key "F9"  "show_menu"  "Menu"
    hackfm.module.register_key "F10" "hackfm.quit" "Quit"
    hackfm.module.register_key "CTRL-LEFT"  "fkeybar.layer_prev"
    hackfm.module.register_key "CTRL-RIGHT" "fkeybar.layer_next"
}

hackfm.quit() {
    file_dialog.show_confirm "Quit" "Do you want to quit HackFM?"
    dialog_cleanup
    if [ "$(file_dialog.result)" = "0" ]; then
        hackfm.cleanup
        exit 0
    fi
    broker.publish "dialog_closed" ""
}

show_menu() {
    broker.publish "ui.menu_opened" ""
    main_menu.show

    local handler
    handler=$(main_menu.selected)

    if [ -n "$handler" ]; then
        if declare -F "$handler" &>/dev/null; then
            $handler
        fi
    fi

    main_title.render
    broker.publish "ui.menu_closed" ""
}

# Main loop
main_loop() {
    # Signal that we're in main loop (for resize handler)
    IN_MAIN_LOOP=1
    
    draw_screen
    
    while true; do
        local key=$(tui.input.key)

        # Check if command line has text
        local cmdline_text=$(cmd.text)
        local has_cmdline_text=0
        if [ -n "$cmdline_text" ]; then
            has_cmdline_text=1
        fi
        
        case "$key" in
            # Navigation keys - behavior depends on context
            UP)
                navigate UP
                ;;
                
            DOWN)
                navigate DOWN
                ;;

            CTRL-UP)
                cmd.history_prev
                draw_command_line
                ;;

            CTRL-DOWN)
                cmd.history_next
                draw_command_line
                ;;
                
            PAGEUP)
                navigate PAGEUP
                ;;
                
            PAGEDOWN)
                navigate PAGEDOWN
                ;;
                
            HOME)
                if [ $has_cmdline_text -eq 1 ]; then
                    cmd.move_cursor HOME
                    draw_command_line
                else
                    navigate HOME
                    $(get_active_panel).render
                fi
                ;;
                
            END)
                if [ $has_cmdline_text -eq 1 ]; then
                    cmd.move_cursor END
                    draw_command_line
                else
                    navigate END
                    $(get_active_panel).render
                fi
                ;;
                
            LEFT)
                if [ $has_cmdline_text -eq 1 ]; then
                    cmd.move_cursor LEFT
                    draw_command_line
                fi
                ;;
                
            RIGHT)
                if [ $has_cmdline_text -eq 1 ]; then
                    cmd.move_cursor RIGHT
                    draw_command_line
                fi
                ;;
                
            # ENTER key - smart behavior
            ENTER)
                if [ $has_cmdline_text -eq 1 ]; then
                    execute_command
                    draw_screen
                else
                    open_item
                fi
                ;;
                
            # Backspace - delete from command line
            BACKSPACE)
                if [ $has_cmdline_text -eq 1 ]; then
                    cmd.delete
                    draw_command_line
                fi
                ;;
                
            # Delete key
            DELETE)
                if [ $has_cmdline_text -eq 1 ]; then
                    cmd.delete_forward
                    draw_command_line
                fi
                ;;
                
            # Ctrl+R - reload active panel
            CTRL-R)
                reload_active_panel
                $(get_active_panel).render
                ;;

            # Ctrl+U - clear command line (standard shell behavior)
            CTRL-U)
                cmd.clear
                draw_command_line
                ;;
                
            # Tab - switch panels (only in panel mode with empty cmdline)
            TAB)
                switch_panel
                draw_command_line
                ;;
                
            # Ctrl+S - Quick search
            CTRL-S)
                $(get_active_panel).quick_search
                ;;

            # Ctrl+O - toggle between File Manager and Terminal view
            CTRL-O)
                tui.screen.main
                tui.cursor.show
                stty sane

                trap - ERR
                set +e
                bash --rcfile <(cat <<'RCFILE'
# Source user's bashrc if it exists
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

# Bind Ctrl+O to exit silently — wrap in function to suppress bash printing the command
__hackfm_exit() { exit; }
bind -x '"\C-o": __hackfm_exit'
RCFILE
) -i < /dev/tty > /dev/tty 2>&1 || true
                set -e
                trap '__ba_err_report $? $LINENO' ERR

                stty -echo 2>/dev/null
                tui.screen.alt
                hackfm.read_term_size
                reload_both_panels
                draw_screen
                ;;
                
            # INSERT - toggle selection and move down
            INSERT)
                $(get_active_panel).toggle_selection_and_move
                ;;
                
            CTRL-SLASH)
                # Insert filename under cursor into command line
                local active=$(get_active_panel)
                local selected_info=$($active.get_selected_item)
                local fname="${selected_info%%|*}"
                fname="${fname//$'\n'/}"
                fname="${fname//$'\r'/}"
                if [ -n "$fname" ]; then
                    cmd.append "$fname"
                    draw_command_line
                fi
                ;;

            # ESC - clear command line
            ESC)
                cmd.clear
                draw_command_line
                ;;
                
            # Regular printable characters - type into command line
            *)
                # Translate F1-F12 physical keys to logical keys based on active layer
                local _active_layer
                _active_layer=$(main_fkeybar.active_layer)
                if [[ "$key" =~ ^F([1-9])$ ]] && [ $_active_layer -gt 0 ]; then
                    local _fnum="${key#F}"
                    key="F$(( _fnum + _active_layer * 10 ))"
                fi
                # Check module-registered keys first (guard against keys with dots/invalid chars)
                local _dispatched=0
                if [ $has_cmdline_text -eq 0 ]; then
                    fkeybar.dispatch_key "$key" && _dispatched=1 || true
                fi
                if [ $_dispatched -eq 0 ] && [ ${#key} -eq 1 ] && [[ $key != $'\x1b' ]] && [[ $key != $'\x00' ]]; then
                    cmd.insert "$key"
                    draw_command_line
                fi
                ;;
        esac

        # Always return terminal cursor to command line input position
        local _cmd_row=$(cmd.row)
        local _cmd_col=$(cmd.col)
        local _cmd_prompt=$(cmd.prompt)
        local _cmd_text=$(cmd.text)
        local _cmd_cursor=$(cmd.cursor_pos)
        local _cmd_width=$(cmd.width)
        local _prompt_len=${#_cmd_prompt}
        local _text_width=$((_cmd_width - _prompt_len))
        local _display_cursor=$_cmd_cursor
        if [ ${#_cmd_text} -gt $_text_width ] && [ $_cmd_cursor -ge $_text_width ]; then
            _display_cursor=$((_text_width - 1))
        fi
        tui.cursor.move $_cmd_row $((_cmd_col + _prompt_len + _display_cursor))
        tui.cursor.style.blinking_underline
        tui.cursor.show
    done
}

# ============================================================================
# MAIN
# ============================================================================

# Main
init
main_loop
hackfm.cleanup
