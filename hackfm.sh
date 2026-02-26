#!/bin/bash
# hackfm.sh - Hackable File Manager using REAL ba.sh (REFACTORED)

# Get HackFM installation directory (for sourcing class files)
export HACKFM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HACKFM_DIR/hackfm_errors.log"

# Enable error logging
exec 2>"$LOG_FILE"
set -E  # Inherit error traps

# Error handler
error_handler() {
    local line=$1
    tui.cursor.style.default
    tui.cursor.show
    tui.screen.clear
    tui.screen.main
    [ -n "$ORIGINAL_STTY" ] && stty "$ORIGINAL_STTY" 2>/dev/null
    echo "ERROR at line $line"
    echo "Check $LOG_FILE for details"
    tail -20 "$LOG_FILE"
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
    left_panel.width = $panel_width
    left_panel.height = $panel_height
    
    # Update right panel
    right_panel.x = $((panel_width + 3))
    right_panel.width = $panel_width
    right_panel.height = $panel_height
    
    # Redraw everything
    draw_screen
}

# Set up error and resize traps
trap 'error_handler $LINENO' ERR
trap 'resize_handler' WINCH

# Load TUI (from shared tui directory)
. "$HACKFM_DIR/tui/cursor.class"
. "$HACKFM_DIR/tui/screen.class"
. "$HACKFM_DIR/tui/color.class"
. "$HACKFM_DIR/tui/box.class"
. "$HACKFM_DIR/tui/input.class"
. "$HACKFM_DIR/tui/region.class"
. "$HACKFM_DIR/tui/style.class"

# Load components (from HackFM directory)
. "$HACKFM_DIR/appframe.h"
. "$HACKFM_DIR/dialog.h"
. "$HACKFM_DIR/filelist.h"
. "$HACKFM_DIR/archivelist.h"
. "$HACKFM_DIR/panel.h"
. "$HACKFM_DIR/viewer.h"
. "$HACKFM_DIR/editor.h"
. "$HACKFM_DIR/viewhandler.class"
. "$HACKFM_DIR/edithandler.class"
. "$HACKFM_DIR/dialogs.class"
. "$HACKFM_DIR/fs.class"
. "$HACKFM_DIR/commandline.h"
. "$HACKFM_DIR/msgbroker.h"
. "$HACKFM_DIR/menu.h"
. "$HACKFM_DIR/fkeybar.h"

# App state
ACTIVE_PANEL=0
PANELS_VISIBLE=1  # 1 = panels shown, 0 = panels hidden
TERMINAL_MODE=0   # 0 = one-shot command, 1 = persistent terminal (via Ctrl+O)
ORIGINAL_STTY=""  # Save original terminal settings

# Panel and list arrays for cleaner code
PANELS=("left_panel" "right_panel")

# Main appframe
APP_FRAME_CREATED=0

# Command line state
CMDLINE_CREATED=0
TEXTVIEW_CREATED=0

# Message broker
BROKER_CREATED=0

# Menu state
MENU_CREATED=0

# ============================================================================
# HELPER FUNCTIONS (NEW - to eliminate duplication)
# ============================================================================

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

# Get the currently active panel's list object name
# Get the currently active panel object name
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

# Get selected item info from specific panel (0=left, 1=right)
# Returns: filename|filetype|path (pipe-separated)

# Check if selected item is special (.. or <empty>)
# Returns: 0 if special, 1 if normal

# Cleanup after dialog (resets colors and hides cursor)

# Reload the active panel's directory
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

# Reload panel by index (0=left, 1=right)

# Quick search - find next file starting with search text
# Show error dialog and redraw screen
# Custom input dialog with dynamic width for long paths
# Returns 0 on OK, 1 on Cancel
# Result in CUSTOM_INPUT_RESULT variable
CUSTOM_INPUT_RESULT=""



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
    
    # Create file viewer
    viewer file_viewer
    
    # Create file editor
    editor file_editor
    
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
    left_panel.message_broker = broker
    right_panel.message_broker = broker
    cmd.message_broker = broker

    # Wire dialog to panels for status messages
    left_panel.dialog = file_dialog
    right_panel.dialog = file_dialog
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
draw_screen() {
    # Ensure we're on alternate screen
    tui.screen.alt
    
    # Hide cursor while drawing
    tui.cursor.hide
    
    # Draw frame (title + fkeys, no fill)
    main_frame.draw_frame "Help" "" "View" "Edit" "Copy" "Move" "Mkdir" "Delete" "Menu" "Quit"
    
    # Draw panels or output in main area
    if [ $PANELS_VISIBLE -eq 1 ]; then
        # Panels visible - show file browser
        left_panel.render
        right_panel.render
    fi
    
    # Draw command line
    draw_command_line
    
    # Position cursor at end of command line and show it
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
    tui.screen.alt
    main_frame.setup
    reload_both_panels
}

# ============================================================================
# NAVIGATION
# ============================================================================

# Switch panels
switch_panel() {
    # Toggle active panel
    local old_panel=$(get_active_panel)
    ACTIVE_PANEL=$((1 - ACTIVE_PANEL))
    local new_panel=$(get_active_panel)
    
    # Update active states
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

    # Panel handles directory navigation, archive browsing, and ext.conf lookup
    # We only handle file open actions here

    if [[ "$action" == open:* ]]; then
        local filepath="${action#*:}"
        local ext="${filepath##*.}"
        ext="${ext,,}"

        # Read ext.conf handler (panel already checked it exists, but we need the command)
        local handler=""
        local ext_conf="$HACKFM_DIR/conf/ext.conf"
        if [ -f "$ext_conf" ]; then
            while IFS=' ' read -r conf_ext conf_cmd || [ -n "$conf_ext" ]; do
                [ -z "$conf_ext" ] || [[ "$conf_ext" == \#* ]] && continue
                if [ "${conf_ext,,}" = "$ext" ]; then
                    handler="$conf_cmd"
                    break
                fi
            done < "$ext_conf"
        fi

        if [ -n "$handler" ] && command -v "${handler%% *}" &>/dev/null; then
            $handler "$filepath" &>/dev/null &
        fi
        # No handler or program not found - do nothing

    elif [[ "$action" == execute:* ]]; then
        local filepath="${action#*:}"
        local in_terminal=$(conf_get open_execute_in_terminal 0)

        if [ "$in_terminal" = "1" ]; then
            # Open a new terminal window in the file's directory, run program there
            local filedir=$(dirname "$filepath")
            local terminal=""
            for t in x-terminal-emulator xterm gnome-terminal konsole xfce4-terminal; do
                command -v "$t" &>/dev/null && terminal="$t" && break
            done
            if [ -n "$terminal" ]; then
                local cmd="cd $(printf '%q' "$filedir") && $(printf '%q' "$filepath"); echo; read -rsn1 -p '--- Press any key ---'"
                case "$terminal" in
                    gnome-terminal) "$terminal" --working-directory="$filedir" -- bash -c "$cmd" &>/dev/null & ;;
                    *)              "$terminal" -e "bash -c $(printf '%q' "$cmd")" &>/dev/null & ;;
                esac
            fi
            # Panels stay visible - no screen switch needed
        else
            # Run inline on primary screen (original behaviour, accessible via Ctrl-O)
            tui.screen.main
            stty sane

            local filedir=$(dirname "$filepath")
            local filename=$(basename "$filepath")
            echo "${USER}@$(hostname):${filedir}\$ ${filename}"
            tui.cursor.show

            trap - ERR
            set +e
            "$filepath"
            local _exit=$?
            set -e
            trap '__ba_err_report $? $LINENO' ERR

            echo ""
            echo "--- Program exited with code $_exit. Press any key ---"
            read -rsn1
            tui.cursor.hide

            tui.screen.alt
            stty -echo 2>/dev/null
            main_frame.setup
            reload_both_panels
            draw_screen
        fi
    fi
    # action="" or "ok" - nothing to do
}

# ============================================================================
# MENU FUNCTIONS
# ============================================================================

# ============================================================================
# MENU HANDLERS
# ============================================================================

# Sort handlers for left panel
# Sort panel by field - toggles between asc/desc. Args: panel asc_val desc_val
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

# ============================================================================
# MENU
# ============================================================================

# Initialize and show menu
show_menu() {
    # Create menu if not already created
    if [ $MENU_CREATED -eq 0 ]; then
        menu main_menu
        MENU_CREATED=1
        
        # Set background redraw callback
        main_menu.background_redraw = "redraw_panels_for_dropdown"
        
        # Setup menu structure
        main_menu.clear
        
        # Left panel menu
        main_menu.add_item "Left"
        main_menu.add_subitem "Left" "Sort by Name" "" "handler_sort_left_name"
        main_menu.add_subitem "Left" "Sort by Time" "" "handler_sort_left_date"
        main_menu.add_subitem "Left" "Sort by Size" "" "handler_sort_left_size"
        main_menu.add_subitem "Left" "Sort by Extension" "" "handler_sort_left_ext"
        
        # File menu
        main_menu.add_item "File"
        main_menu.add_subitem "File" "View" "F3" "view_file"
        main_menu.add_subitem "File" "Edit" "F4" "edit_file"
        main_menu.add_subitem "File" "Copy" "F5" "copy_file"
        main_menu.add_subitem "File" "Move" "F6" "move_file"
        main_menu.add_subitem "File" "MkDir" "F7" "make_directory"
        main_menu.add_subitem "File" "Delete" "F8" "delete_file"
        
        # Command menu
        main_menu.add_item "Command"
        # Add command items later
        
        # Options menu
        main_menu.add_item "Options"
        # Add options items later
        
        # Right panel menu
        main_menu.add_item "Right"
        main_menu.add_subitem "Right" "Sort by Name" "" "handler_sort_right_name"
        main_menu.add_subitem "Right" "Sort by Time" "" "handler_sort_right_date"
        main_menu.add_subitem "Right" "Sort by Size" "" "handler_sort_right_size"
        main_menu.add_subitem "Right" "Sort by Extension" "" "handler_sort_right_ext"
    fi
    
    # Show menu
    main_menu.show
    
    # Get selected handler
    local handler=$(main_menu.selected)
    
    # Call handler if one was selected (not ESC)
    if [ -n "$handler" ]; then
        # Check if handler function exists
        if declare -F "$handler" &>/dev/null; then
            $handler
        else
            echo "Warning: Handler '$handler' not found" >&2
        fi
    fi
    
    # Restore title bar only - dropdown area was already cleaned up by background_redraw
    # inside the menu loop before it returned
    main_frame.draw_title
    broker.publish "ui.menu_closed" ""
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

# View file (F3)
view_file() {
    tui.color.reset

    local active_panel=$(get_active_panel)
    local in_archive=$($active_panel.in_archive)

    if [ "$in_archive" = "1" ]; then
        local arch_list=$($active_panel.list_source)
        local arch_filename arch_filetype arch_path
        IFS='|' read -r arch_filename arch_filetype arch_path <<< "$($arch_list.get_selected_item)"

        if [ "$arch_filetype" != "f" ] || [ "$arch_filename" = "<empty>" ] || [ "$arch_filename" = ".." ]; then
            return
        fi

        viewhandler.open_archive "$arch_list" "$arch_path" "$arch_filename"
    else
        local filename filetype path
        IFS='|' read -r filename filetype path <<< "$(get_selected_item)"

        if [ "$filetype" != "f" ] || [ "$filename" = "<empty>" ]; then
            return
        fi

        local filepath="$path/$filename"
        if [ ! -f "$filepath" ] || [ ! -r "$filepath" ]; then
            return
        fi

        viewhandler.open "$filepath"
    fi

    draw_screen
}

# Edit file (F4)
edit_file() {
    tui.color.reset

    local filename filetype path
    IFS='|' read -r filename filetype path <<< "$(get_selected_item)"

    if [ "$filetype" = "d" ] || [ "$filename" = "<empty>" ] || [ "$filename" = ".." ]; then
        return
    fi

    local filepath="$path/$filename"

    edithandler.open "$filepath"

    reload_active_panel
    draw_screen
}

# Make directory (F7)
# MAIN LOOP
# ============================================================================

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
                    draw_screen
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
                
            # Ctrl+O - toggle between File Manager and Terminal output
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
                    
                    # Spawn a real interactive bash with Ctrl+O bound to exit
                    trap - ERR
                    set +e
                    bash --rcfile <(cat <<'RCFILE'
# Source user's bashrc if it exists
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

# Bind Ctrl+O to exit - use PROMPT_COMMAND to ensure it's set
PROMPT_COMMAND='bind "\"\C-o\": \"exit\n\""; '"${PROMPT_COMMAND}"
RCFILE
) -i < /dev/tty > /dev/tty 2>&1 || true
                    set -e
                    trap '__ba_err_report $? $LINENO' ERR
                    
                    # When bash exits, return to panels
                    PANELS_VISIBLE=1
                    TERMINAL_MODE=0
                    
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
            F3)
                if [ $PANELS_VISIBLE -eq 1 ] && [ $has_cmdline_text -eq 0 ]; then
                    view_file
                fi
                ;;
            F4)
                if [ $PANELS_VISIBLE -eq 1 ] && [ $has_cmdline_text -eq 0 ]; then
                    edit_file
                fi
                ;;
            F5)
                if [ $PANELS_VISIBLE -eq 1 ] && [ $has_cmdline_text -eq 0 ]; then
                    active_panel=$(get_active_panel)
                    in_archive=$($active_panel.in_archive)
                    if [ "$in_archive" = "1" ]; then
                        extract_item
                    else
                        copy_item
                    fi
                fi
                ;;
            F6)
                if [ $PANELS_VISIBLE -eq 1 ] && [ $has_cmdline_text -eq 0 ]; then
                    move_item
                fi
                ;;
            F7)
                if [ $PANELS_VISIBLE -eq 1 ] && [ $has_cmdline_text -eq 0 ]; then
                    make_directory
                fi
                ;;
            F8)
                if [ $PANELS_VISIBLE -eq 1 ] && [ $has_cmdline_text -eq 0 ]; then
                    delete_item
                fi
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
            F9)
                # Open menu
                show_menu
                ;;
            F10)
                # Ask for confirmation before quitting
                local confirm_result=0
                file_dialog.show_confirm "Quit" "Do you want to quit HackFM?" || confirm_result=$?
                dialog_cleanup
                
                if [ $confirm_result -eq 0 ]; then
                    # User confirmed - quit
                    break
                fi
                # User cancelled - redraw and continue
                draw_screen
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
                if [ ${#key} -eq 1 ] && [[ $key != $'\x1b' ]] && [[ $key != $'\x00' ]]; then
                    cmd.insert "$key"
                    draw_command_line
                fi
                ;;
        esac
    done
}

# ============================================================================
# MAIN
# ============================================================================

# Main
init
main_loop

# Cleanup
trap - ERR WINCH
tui.cursor.style.default
tui.cursor.show
tui.screen.main
[ -n "$ORIGINAL_STTY" ] && stty "$ORIGINAL_STTY" 2>/dev/null
main_frame.cleanup
