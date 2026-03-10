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
    # Only handle resize if main_frame exists
    if ! declare -F main_frame.setup &>/dev/null; then
        return
    fi
    
    # Reinitialize frame (reads new terminal size)
    main_frame.setup
    
    # Recalculate panel dimensions from new frame size
    local rows=$(main_frame.rows)
    local cols=$(main_frame.cols)
    local main_height=$(main_frame.main_height)
    local panel_width=$(((cols - 3) / 2))
    local panel_height=$((main_height - 3))
    
    # Update left panel
    left_panel.x = 1
    left_panel.y = 3
    left_panel.width = $panel_width
    left_panel.height = $panel_height

    # Update right panel
    right_panel.x = $((panel_width + 3))
    right_panel.y = 3
    right_panel.width = $((cols - panel_width - 4))
    right_panel.height = $panel_height

    # Update command line geometry
    cmd.row = $((rows - 1))
    cmd.col = 1
    cmd.width = $cols

    # Rebuild row cache for new dimensions
    left_panel.prerender_all_rows
    right_panel.prerender_all_rows
    
    # Redraw everything
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

# App state
ACTIVE_PANEL=0
PANELS_VISIBLE=1
TERMINAL_MODE=0
ORIGINAL_STTY=""

PANELS=("left_panel" "right_panel")
APP_FRAME_CREATED=0
CMDLINE_CREATED=0
TEXTVIEW_CREATED=0
BROKER_CREATED=0
MENU_CREATED=0

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

# MODULE API
declare -Ag __MODULE_KEYS=()
declare -Ag __MODULE_KEY_LABELS=()
declare -Ag __MODULE_KEY_LABEL_FUNCS=()
declare -ag __FKEYBAR_LABELS=()
__HACKFM_FKEY_LABEL=""
__HACKFM_ACTIVE_LAYER=0
__HACKFM_ACTIVE_LAYER=0

hackfm.module.register_key() {
    local key="$1"
    local func="$2"
    local label="${3:-}"
    if [ -n "${__MODULE_KEYS[$key]+x}" ]; then
        __MODULE_KEYS[$key]="${__MODULE_KEYS[$key]} $func"
    else
        __MODULE_KEYS[$key]="$func"
    fi
    if [ -n "$label" ]; then
        __MODULE_KEY_LABELS[$key]="$label"
    fi
}

# Register a dynamic label function for a key.
# The function sets __HACKFM_FKEY_LABEL to a non-empty string if it wants to claim the label,
# or leaves it empty to pass to the next registered function.
# Usage: hackfm.module.register_key_label KEY FUNC
hackfm.module.register_key_label() {
    local key="$1"
    local func="$2"
    if [ -n "${__MODULE_KEY_LABEL_FUNCS[$key]+x}" ]; then
        __MODULE_KEY_LABEL_FUNCS[$key]="${__MODULE_KEY_LABEL_FUNCS[$key]} $func"
    else
        __MODULE_KEY_LABEL_FUNCS[$key]="$func"
    fi
}

hackfm.fkeybar_labels() {
    local i offset
    offset=$(( __HACKFM_ACTIVE_LAYER * 10 ))
    __FKEYBAR_LABELS=()
    for ((i=1; i<=10; i++)); do
        local key="F$(( i + offset ))"
        local label=""
        if [ -n "${__MODULE_KEY_LABEL_FUNCS[$key]+x}" ]; then
            local cb
            for cb in ${__MODULE_KEY_LABEL_FUNCS[$key]}; do
                __HACKFM_FKEY_LABEL=""
                $cb
                if [ -n "$__HACKFM_FKEY_LABEL" ]; then
                    label="$__HACKFM_FKEY_LABEL"
                    break
                fi
            done
        fi
        if [ -z "$label" ]; then
            label="${__MODULE_KEY_LABELS[$key]:-}"
        fi
        __FKEYBAR_LABELS+=("$label")
    done
}

hackfm.fkeybar_layer_count() {
    # Count populated layers (layers with at least one registered key)
    local max_fkey=0
    local key
    for key in "${!__MODULE_KEYS[@]}"; do
        if [[ "$key" =~ ^F([0-9]+)$ ]]; then
            local n="${BASH_REMATCH[1]}"
            [ "$n" -gt "$max_fkey" ] && max_fkey="$n"
        fi
    done
    if [ "$max_fkey" -eq 0 ]; then
        echo 1
    else
        echo $(( (max_fkey - 1) / 10 + 1 ))
    fi
}

hackfm.fkeybar_layer_next() {
    local total
    total=$(hackfm.fkeybar_layer_count)
    __HACKFM_ACTIVE_LAYER=$(( (__HACKFM_ACTIVE_LAYER + 1) % total ))
    draw_main_frame
}

hackfm.fkeybar_layer_prev() {
    local total
    total=$(hackfm.fkeybar_layer_count)
    __HACKFM_ACTIVE_LAYER=$(( (__HACKFM_ACTIVE_LAYER - 1 + total) % total ))
    draw_main_frame
}

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

# Load all enabled modules from hackfm.conf (module_NAME_enabled=1)
hackfm.cleanup() {
    trap - ERR WINCH INT TERM
    tui.cursor.style.default
    tui.cursor.show
    tui.screen.main
    [ -n "$ORIGINAL_STTY" ] && stty "$ORIGINAL_STTY" 2>/dev/null
    main_frame.cleanup
}

hackfm.load_modules.names() {
    local conf="$HACKFM_DIR/conf/hackfm.conf"
    [ -f "$conf" ] || return
    local line
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*$  ]] && continue
        [[ "$line" =~ ^[[:space:]]*\# ]] && continue
        if [[ "$line" =~ ^module_([a-zA-Z0-9_]+)_enabled=1$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local module_script="$HACKFM_DIR/modules/$name/$name.mod"
            if [ -f "$module_script" ]; then
                echo "$name"
            else
                echo "$(date '+%H:%M:%S') load_modules: script not found: $module_script" >&2
            fi
        fi
    done < "$conf"
}

hackfm.load_modules.pre_init() {
    local name
    while IFS= read -r name; do
        echo "$(date '+%H:%M:%S') load_modules: sourcing $name" >&2
        . "$HACKFM_DIR/modules/$name/$name.mod"
        if declare -f "${name}.pre_init" > /dev/null 2>&1; then
            echo "$(date '+%H:%M:%S') load_modules: calling ${name}.pre_init" >&2
            "${name}.pre_init"
            echo "$(date '+%H:%M:%S') load_modules: ${name}.pre_init done" >&2
        fi
    done < <(hackfm.load_modules.names)
}

hackfm.load_modules.init() {
    local name
    while IFS= read -r name; do
        if declare -f "${name}.init" > /dev/null 2>&1; then
            echo "$(date '+%H:%M:%S') load_modules: calling ${name}.init" >&2
            "${name}.init"
            echo "$(date '+%H:%M:%S') load_modules: ${name}.init done" >&2
        fi
    done < <(hackfm.load_modules.names)
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
    main_frame.setup
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

# Initialize
init() {
    # Save original terminal settings before TUI takes over
    ORIGINAL_STTY=$(stty -g 2>/dev/null)

    # Disable echo for entire app lifetime - prevents escape sequences bleeding into display
    stty -echo 2>/dev/null

    # Switch to alternate screen for file manager
    tui.screen.alt

    # Pre-init modules — run before any objects are created so modules can override constructors
    hackfm.load_modules.pre_init

    # Create appframe if needed
    if [ $APP_FRAME_CREATED -eq 0 ]; then
        appframe main_frame
        APP_FRAME_CREATED=1
    fi

    # Configure
    main_frame.title = "HackFM - Hackable File Manager"
    main_frame.show_cursor = 0

    # Setup
    main_frame.setup

    # Get terminal size from appframe
    local rows=$(main_frame.rows)
    local cols=$(main_frame.cols)
    local main_height=$(main_frame.main_height)

    local panel_width=$(( (cols - 3) / 2 ))
    # Panel height = main area height - 3 (border at top, border at bottom, and command line)
    local panel_height=$((main_height - 3))

    # Create left panel with its own filelist
    panel left_panel
    left_panel.x = 1
    left_panel.y = 3
    left_panel.width = $panel_width
    left_panel.height = $panel_height
    
    # Create filelist as a sub-object of left_panel
    filelist left_panel.list
    left_panel.list.path = "$PWD"
    
    # Set active AFTER filelist is created
    left_panel.active = 1
    
    # Create right panel with its own filelist
    panel right_panel
    right_panel.x = $((panel_width + 3))
    right_panel.y = 3
    right_panel.width = $(( cols - panel_width - 4 ))
    right_panel.height = $panel_height
    
    # Create filelist as a sub-object of right_panel
    filelist right_panel.list
    right_panel.list.path = "$HOME"
    
    # Set active AFTER filelist is created
    right_panel.active = 0
    
    # Create dialog
    tui_dialog file_dialog
    
    # Create command line instance
    if [ $CMDLINE_CREATED -eq 0 ]; then
        commandline cmd
        CMDLINE_CREATED=1
    fi

    # Configure command line
    local cmdline_row=$((rows - 1))  # One row above F-key bar
    cmd.row = $cmdline_row
    cmd.col = 1
    cmd.width = $cols
    cmd.prompt = "$USER@$(hostname):$PWD\$ "
    cmd.text = ""
    cmd.cursor_pos = 0

    # Create message broker and wire up pub/sub
    if [ $BROKER_CREATED -eq 0 ]; then
        msgbroker broker
        BROKER_CREATED=1
    fi

    # Register objects with broker - each object subscribes to topics it cares about
    left_panel.register broker
    right_panel.register broker
    cmd.register broker

    # Subscribe to terminal lifecycle events from openhandler
    broker.subscribe "ui.terminal_enter" "handle_terminal_enter"
    broker.subscribe "ui.terminal_exit" "handle_terminal_exit"

    # Subscribe draw_main_frame to topics that require full redraw
    broker.subscribe "viewer_closed"          "draw_main_frame"
    broker.subscribe "editor_closed"          "draw_main_frame"

    # Wire dialog to panels for status messages
    left_panel.dialog = file_dialog
    right_panel.dialog = file_dialog

    # Setup menu structure (must be before load_modules so modules can add items)
    setup_menu

    # Init modules — register keys, menu items, subscriptions
    hackfm.load_modules.init
}

# ============================================================================
# RENDERING
# ============================================================================

# Redraw panels only (no frame, no command line) - used by menu
redraw_panels_only() {
    left_panel.render
    right_panel.render
}

# Redraw only panels that overlap the last dropdown area
redraw_panels_for_dropdown() {
    local drop_col=$(main_menu.last_dropdown_col)
    local drop_right=$(main_menu.last_dropdown_right)
    [ -z "$drop_col" ] && { redraw_panels_only; return; }

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

# Draw screen
draw_main_frame() {
    main_frame.draw_title
    hackfm.fkeybar_labels
    main_frame.draw_fkeys "$__HACKFM_ACTIVE_LAYER" "${__FKEYBAR_LABELS[@]}"
}

draw_screen() {
    tui.screen.alt
    tui.cursor.hide
    hackfm.fkeybar_labels
    main_frame.draw_frame "$__HACKFM_ACTIVE_LAYER" "${__FKEYBAR_LABELS[@]}"
    if [ $PANELS_VISIBLE -eq 1 ]; then
        left_panel.render
        right_panel.render
    fi
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
    case "$command" in
        clear)
            tui.screen.clear
            ;;
            
        exit)
            echo "(Use F10 to quit file manager)"
            ;;
            
        *)
            # Change to exec directory first
            cd "$exec_path"
            
            # Show prompt and command
            echo "$USER@$(hostname):$exec_path\$ $command"
            
            trap - ERR
            set +e
            eval "$command" 2>&1
            set -e
            trap '__ba_err_report $? $LINENO' ERR
            
            # Add newline for visual separation
            echo ""
            ;;
    esac
    
    # Check if directory changed and update panel
    local new_path=$(pwd)
    if [ "$new_path" != "$exec_path" ]; then
        $list.path = "$new_path"
    fi
    
    # Return to panels immediately
    PANELS_VISIBLE=1
    stty -echo 2>/dev/null
    tui.screen.alt
    main_frame.setup
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
    draw_main_frame
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
    draw_main_frame
}

# ============================================================================
# MENU
# ============================================================================

# Sort handlers for left panel
# Sort panel by field - toggles between asc/desc. Args: panel field_asc field_desc
_sort_panel() {
    local panel="$1" asc="$2" desc="$3"
    local current=$($panel.list.sort_order)
    [ "$current" = "$asc" ] && $panel.list.sort_order = "$desc" || $panel.list.sort_order = "$asc"
    $panel.prerender_all_rows
    $panel.render
}

handler_sort_left_name()  { _sort_panel left_panel  name_asc  name_desc; }
handler_sort_left_date()  { _sort_panel left_panel  date_desc date_asc;  }
handler_sort_left_size()  { _sort_panel left_panel  size_desc size_asc;  }
handler_sort_left_ext()   { _sort_panel left_panel  ext_asc   ext_desc;  }
handler_sort_right_name() { _sort_panel right_panel name_asc  name_desc; }
handler_sort_right_date() { _sort_panel right_panel date_desc date_asc;  }
handler_sort_right_size() { _sort_panel right_panel size_desc size_asc;  }
handler_sort_right_ext()  { _sort_panel right_panel ext_asc   ext_desc;  }

setup_menu() {
    menu main_menu
    MENU_CREATED=1

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
    hackfm.module.register_key "CTRL-LEFT"  "hackfm.fkeybar_layer_prev"
    hackfm.module.register_key "CTRL-RIGHT" "hackfm.fkeybar_layer_next"
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
    main_menu.show

    local handler
    handler=$(main_menu.selected)

    if [ -n "$handler" ]; then
        if declare -F "$handler" &>/dev/null; then
            $handler
        fi
    fi

    main_frame.draw_title
    broker.publish "ui.menu_closed" ""
}

# View file (F3)


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
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    # In File Manager workspace - always navigate files
                    navigate UP
                else
                    # In buffer mode - navigate command history
                    cmd.history_prev
                    draw_command_line
                fi
                ;;
                
            DOWN)
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    # In File Manager workspace - always navigate files
                    navigate DOWN
                else
                    # In buffer mode - navigate command history
                    cmd.history_next
                    draw_command_line
                fi
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
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    navigate PAGEUP
                fi
                ;;
                
            PAGEDOWN)
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    navigate PAGEDOWN
                fi
                ;;
                
            HOME)
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    if [ $has_cmdline_text -eq 1 ]; then
                        cmd.move_cursor HOME
                        draw_command_line
                    else
                        navigate HOME
                        $(get_active_panel).render
                    fi
                elif [ $has_cmdline_text -eq 1 ]; then
                    cmd.move_cursor HOME
                    draw_command_line
                fi
                ;;
                
            END)
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    if [ $has_cmdline_text -eq 1 ]; then
                        cmd.move_cursor END
                        draw_command_line
                    else
                        navigate END
                        $(get_active_panel).render
                    fi
                elif [ $has_cmdline_text -eq 1 ]; then
                    cmd.move_cursor END
                    draw_command_line
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
                    # Command line has text - execute command
                    execute_command
                    draw_screen
                elif [ $PANELS_VISIBLE -eq 1 ]; then
                    # Command line empty and panels visible - navigate
                    open_item
                    # Panel renders itself for directory navigation
                    # draw_screen only called for file execution (inside open_item)
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
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    reload_active_panel
                    local active_panel=$(get_active_panel)
                    $active_panel.render
                fi
                ;;

            # Ctrl+U - clear command line (standard shell behavior)
            CTRL-U)
                cmd.clear
                draw_command_line
                ;;
                
            # Tab - switch panels (only in panel mode with empty cmdline)
            TAB)
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    switch_panel
                    draw_command_line  # Update prompt with new active path
                fi
                ;;
                
            # Ctrl+S - Quick search
            CTRL-S)
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    local active_panel=$(get_active_panel)
                    $active_panel.quick_search
                fi
                ;;

            # Ctrl+D - Quick directory jump
            # Ctrl+O - toggle between File Manager and Terminal view
            CTRL-O)
                PANELS_VISIBLE=$((1 - PANELS_VISIBLE))
                # Switch screens and redraw if needed
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    # Switching to panels - use alternate screen
                    TERMINAL_MODE=0
                    tui.screen.alt
                    draw_screen
                else
                    # Switching to terminal - use main screen, enter persistent mode
                    TERMINAL_MODE=1
                    tui.screen.main
                    
                    # Show cursor for terminal
                    tui.cursor.show
                    
                    # Restore terminal to sane interactive mode
                    stty sane
                    
                    # Spawn a real interactive bash with Ctrl+O bound to exit silently
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
                    
                    # When bash exits, return to panels
                    PANELS_VISIBLE=1
                    TERMINAL_MODE=0

                    stty -echo 2>/dev/null
                    tui.screen.alt
                    # Reinitialize appframe to restore terminal settings
                    main_frame.setup
                    reload_both_panels
                    draw_screen
                    # Cursor is hidden by draw_screen
                fi
                ;;
                
            # INSERT - toggle selection and move down
            INSERT)
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    $(get_active_panel).toggle_selection_and_move
                fi
                ;;
                
            # Function keys - only work in panel mode with empty command line

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

            # Other keys - pass to command line or default handling

            # ESC - clear command line
            ESC)
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    cmd.clear
                    draw_command_line
                fi
                ;;
                
            # Regular printable characters - type into command line
            *)
                # Translate F1-F12 physical keys to logical keys based on active layer
                if [[ "$key" =~ ^F([1-9])$ ]] && [ $__HACKFM_ACTIVE_LAYER -gt 0 ]; then
                    local _fnum="${key#F}"
                    key="F$(( _fnum + __HACKFM_ACTIVE_LAYER * 10 ))"
                fi
                # Check module-registered keys first (guard against keys with dots/invalid chars)
                if [[ "$key" =~ ^[A-Za-z0-9_-]+$ ]] && [ -n "${__MODULE_KEYS[$key]+x}" ]; then
                    if [ $PANELS_VISIBLE -eq 1 ] && [ $has_cmdline_text -eq 0 ]; then
                        local _handler
                        for _handler in ${__MODULE_KEYS[$key]}; do
                            if $_handler; then break; fi
                        done
                    fi
                elif [ ${#key} -eq 1 ] && [[ $key != $'\x1b' ]] && [[ $key != $'\x00' ]]; then
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
