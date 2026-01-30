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
    tui.screen.clear
    tui.cursor.show
    tui.screen.main
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

# Load components (from HackFM directory)
. "$HACKFM_DIR/appframe.h"
. "$HACKFM_DIR/dialog.h"
. "$HACKFM_DIR/filelist.h"
. "$HACKFM_DIR/archivelist.h"
. "$HACKFM_DIR/panel.h"
. "$HACKFM_DIR/viewer.h"
. "$HACKFM_DIR/editor.h"
. "$HACKFM_DIR/commandline.h"
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

# Menu state
MENU_CREATED=0

# ============================================================================
# HELPER FUNCTIONS (NEW - to eliminate duplication)
# ============================================================================

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
dialog_cleanup() {
    tui.color.reset
    tui.cursor.hide
}

# Reload the active panel's directory
reload_active_panel() {
    local panel=$(get_active_panel)
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

show_path_input() {
    local title="$1"
    local message="$2"
    local default="$3"
    
    CUSTOM_INPUT_RESULT="$default"
    
    # Calculate dialog width based on path length
    local dialog_width=$((${#default} + 8))
    [ $dialog_width -lt 60 ] && dialog_width=60
    [ $dialog_width -gt 100 ] && dialog_width=100
    
    local dialog_height=7
    
    # Get terminal size
    local size=$(tui.screen.size)
    local rows=${size% *}
    local cols=${size#* }
    local dialog_row=$(( (rows - dialog_height) / 2 ))
    local dialog_col=$(( (cols - dialog_width) / 2 ))
    
    # Draw shadow
    tui.color.bg_black
    for ((r=dialog_row+1; r<dialog_row+dialog_height+1; r++)); do
        tui.cursor.move $r $((dialog_col + 2))
        printf "%$((dialog_width))s" ""
    done
    tui.color.reset
    
    # Draw dialog box
    tui.color.bg_white
    tui.color.black
    for ((r=dialog_row; r<dialog_row+dialog_height; r++)); do
        tui.cursor.move $r $dialog_col
        printf "%${dialog_width}s" ""
    done
    
    # Draw border
    tui.box.draw $dialog_row $dialog_col $dialog_width $dialog_height
    
    # Draw title
    tui.cursor.move $dialog_row $((dialog_col + 2))
    tui.color.bg_white
    tui.color.black
    tui.color.bold
    printf " %s " "$title"
    tui.color.reset
    
    # Draw message
    tui.cursor.move $((dialog_row + 2)) $((dialog_col + 2))
    tui.color.bg_white
    tui.color.black
    printf "%-$((dialog_width - 4))s" "$message"
    
    # Input field
    local input="$CUSTOM_INPUT_RESULT"
    local cursor_pos=${#input}
    local input_width=$((dialog_width - 4))
    
    # Show cursor for input
    tui.cursor.show
    
    while true; do
        # Draw input field
        tui.cursor.move $((dialog_row + 3)) $((dialog_col + 2))
        tui.color.bg_cyan
        tui.color.black
        
        # Show scrollable portion of input
        local display_start=0
        if [ $cursor_pos -ge $input_width ]; then
            display_start=$((cursor_pos - input_width + 1))
        fi
        local display_input="${input:$display_start:$input_width}"
        printf "%-${input_width}s" "$display_input"
        
        # Position cursor
        local cursor_col=$((cursor_pos - display_start))
        tui.cursor.move $((dialog_row + 3)) $((dialog_col + 2 + cursor_col))
        
        # Read key
        local key=$(tui.input.key)
        
        case "$key" in
            ENTER)
                CUSTOM_INPUT_RESULT="$input"
                return 0
                ;;
            ESC)
                return 1
                ;;
            BACKSPACE)
                if [ $cursor_pos -gt 0 ]; then
                    input="${input:0:$((cursor_pos-1))}${input:$cursor_pos}"
                    cursor_pos=$((cursor_pos - 1))
                fi
                ;;
            DELETE)
                if [ $cursor_pos -lt ${#input} ]; then
                    input="${input:0:$cursor_pos}${input:$((cursor_pos+1))}"
                fi
                ;;
            LEFT)
                [ $cursor_pos -gt 0 ] && cursor_pos=$((cursor_pos - 1))
                ;;
            RIGHT)
                [ $cursor_pos -lt ${#input} ] && cursor_pos=$((cursor_pos + 1))
                ;;
            HOME)
                cursor_pos=0
                ;;
            END)
                cursor_pos=${#input}
                ;;
            *)
                # Regular character input
                if [[ ${#key} -eq 1 && "$key" =~ [[:print:]] ]]; then
                    input="${input:0:$cursor_pos}${key}${input:$cursor_pos}"
                    cursor_pos=$((cursor_pos + 1))
                fi
                ;;
        esac
    done
}

show_error() {
    local message="$1"
    file_dialog.show_message "Error" "$message"
    dialog_cleanup
    draw_screen
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Initialize
init() {
    # Save original terminal settings before TUI takes over
    ORIGINAL_STTY=$(stty -g 2>/dev/null)
    
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
    right_panel.width = $panel_width
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
    dialog file_dialog
    
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
}

# ============================================================================
# RENDERING
# ============================================================================

# Redraw panels only (no frame, no command line) - used by menu
redraw_panels_only() {
    left_panel.render
    right_panel.render
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
    # Update command line prompt with current directory
    cmd.prompt = "$USER@$(hostname):$PWD\$ "
    
    # Render command line
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
    
    # Panel handles directory navigation and renders itself
    # We only handle file actions
    
    if [[ "$action" == execute:* ]]; then
        # Execute file
        local filepath="${action#execute:}"
        
        tui.screen.main
        stty sane
        
        trap - ERR
        set +e
        "$filepath"
        set -e
        trap '__ba_err_report $? $LINENO' ERR
        
        tui.screen.alt
        main_frame.setup
        reload_both_panels
        draw_screen
    elif [[ "$action" == open:* ]]; then
        # Open with default application
        local filepath="${action#open:}"
        
        if command -v xdg-open &>/dev/null; then
            xdg-open "$filepath" &>/dev/null &
        elif command -v open &>/dev/null; then
            # macOS
            open "$filepath" &>/dev/null &
        else
            # No xdg-open available - fallback to viewer
            view_file
        fi
    fi
    # If action is "ok", panel navigated and already rendered itself
    # If action is "", nothing happened (special item)
}

# ============================================================================
# MENU FUNCTIONS
# ============================================================================

# ============================================================================
# MENU HANDLERS
# ============================================================================

# Sort handlers for left panel
handler_sort_left_name() {
    local current=$(left_panel.list.sort_order)
    if [ "$current" = "name_asc" ]; then
        left_panel.list.sort_order = "name_desc"
    else
        left_panel.list.sort_order = "name_asc"
    fi
    left_panel.prerender_all_rows
    left_panel.render
}

handler_sort_left_date() {
    local current=$(left_panel.list.sort_order)
    if [ "$current" = "date_desc" ]; then
        left_panel.list.sort_order = "date_asc"
    else
        left_panel.list.sort_order = "date_desc"
    fi
    left_panel.prerender_all_rows
    left_panel.render
}

handler_sort_left_size() {
    local current=$(left_panel.list.sort_order)
    if [ "$current" = "size_desc" ]; then
        left_panel.list.sort_order = "size_asc"
    else
        left_panel.list.sort_order = "size_desc"
    fi
    left_panel.prerender_all_rows
    left_panel.render
}

handler_sort_left_ext() {
    local current=$(left_panel.list.sort_order)
    if [ "$current" = "ext_asc" ]; then
        left_panel.list.sort_order = "ext_desc"
    else
        left_panel.list.sort_order = "ext_asc"
    fi
    left_panel.prerender_all_rows
    left_panel.render
}

# Sort handlers for right panel
handler_sort_right_name() {
    local current=$(right_panel.list.sort_order)
    if [ "$current" = "name_asc" ]; then
        right_panel.list.sort_order = "name_desc"
    else
        right_panel.list.sort_order = "name_asc"
    fi
    right_panel.prerender_all_rows
    right_panel.render
}

handler_sort_right_date() {
    local current=$(right_panel.list.sort_order)
    if [ "$current" = "date_desc" ]; then
        right_panel.list.sort_order = "date_asc"
    else
        right_panel.list.sort_order = "date_desc"
    fi
    right_panel.prerender_all_rows
    right_panel.render
}

handler_sort_right_size() {
    local current=$(right_panel.list.sort_order)
    if [ "$current" = "size_desc" ]; then
        right_panel.list.sort_order = "size_asc"
    else
        right_panel.list.sort_order = "size_desc"
    fi
    right_panel.prerender_all_rows
    right_panel.render
}

handler_sort_right_ext() {
    local current=$(right_panel.list.sort_order)
    if [ "$current" = "ext_asc" ]; then
        right_panel.list.sort_order = "ext_desc"
    else
        right_panel.list.sort_order = "ext_asc"
    fi
    right_panel.prerender_all_rows
    right_panel.render
}

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
        main_menu.background_redraw = "redraw_panels_only"
        
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
    
    # Redraw title bar to clear menu, then redraw panels
    main_frame.draw_frame "Help" "" "View" "Edit" "Copy" "Move" "Mkdir" "Delete" "Menu" "Quit"
    redraw_panels_only
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

# View file (F3)
view_file() {
    # Reset colors first (in case we have reverse video or colors active from panel)
    tui.color.reset
    
    # Get selected item
    local filename filetype path
    IFS='|' read -r filename filetype path <<< "$(get_selected_item)"
    
    # Only view files
    if [ "$filetype" != "f" ] || [ "$filename" = "<empty>" ]; then
        return
    fi
    
    local filepath="$path/$filename"
    
    # Check readable
    if [ ! -f "$filepath" ] || [ ! -r "$filepath" ]; then
        return
    fi
    
    # Use viewer class
    file_viewer.open "$filepath"
    
    # Return to file manager
    draw_screen
}

# Edit file (F4)
edit_file() {
    # Reset colors first
    tui.color.reset
    
    # Get selected item
    local filename filetype path
    IFS='|' read -r filename filetype path <<< "$(get_selected_item)"
    
    # Only edit files (or create new if doesn't exist)
    if [ "$filetype" = "d" ] || [ "$filename" = "<empty>" ] || [ "$filename" = ".." ]; then
        return
    fi
    
    local filepath="$path/$filename"
    
    # Use editor class
    file_editor.open "$filepath"
    
    # Reload directory (in case file was created/modified)
    reload_active_panel
    
    # Return to file manager
    draw_screen
}

# Make directory (F7)
make_directory() {
    # Get current path from active panel
    local list=$(get_active_panel).list
    local path=$($list.path)
    
    # Show input dialog (capture result without triggering error trap)
    local dialog_result=0
    file_dialog.show_input "Make Directory" "Enter directory name:" "" || dialog_result=$?
    
    # Cleanup after dialog
    dialog_cleanup
    
    if [ $dialog_result -eq 0 ]; then
        local dirname="$(file_dialog.input_value)"
        
        # Validate input
        if [ -z "$dirname" ]; then
            show_error "Directory name cannot be empty"
            return
        fi
        
        # Create directory
        local fullpath="$path/$dirname"
        
        if mkdir "$fullpath" 2>/dev/null; then
            # Success - reload directory and select newly created
            reload_active_panel
            
            # Find and select the new directory
            local panel=$(get_active_panel)
            local panel_height=$($panel.height)
            $list.find_and_select "$dirname" $((panel_height - 3))
            
            draw_screen
        else
            # Error
            show_error "Failed to create directory: $dirname"
        fi
    else
        # Cancelled
        draw_screen
    fi
}

# Delete file/directory (F8)
delete_item() {
    local active_list=$(get_active_panel).list
    local path=$($active_list.path)
    
    # Remember cursor position before operation
    local saved_index=$($active_list.selected)
    
    # Check if there are selected files
    local selected_count=$($active_list.count_selected)
    
    if [ $selected_count -gt 0 ]; then
        # Get selection info from filelist
        local sel_info=$($active_list.selection_info)
        local total_bytes="${sel_info#*|}"
        
        # Format total size
        local size_str
        if [ $total_bytes -lt 1024 ]; then
            size_str="${total_bytes}B"
        elif [ $total_bytes -lt 1048576 ]; then
            size_str="$((total_bytes / 1024))KB"
        else
            size_str="$((total_bytes / 1048576))MB"
        fi
        
        # Delete selected files
        local confirm_result=0
        file_dialog.show_confirm "Delete" "Delete $selected_count files ($size_str)?" || confirm_result=$?
        
        dialog_cleanup
        
        if [ $confirm_result -ne 0 ]; then
            draw_screen
            return
        fi
        
        # Delete each selected file
        local failed=0
        while IFS='|' read -r filename filetype; do
            local fullpath="$path/$filename"
            
            if [ "$filetype" = "d" ]; then
                rm -rf "$fullpath" 2>/dev/null || failed=1
            else
                rm "$fullpath" 2>/dev/null || failed=1
            fi
        done < <($active_list.get_selected)
        
        if [ $failed -eq 1 ]; then
            show_error "Some files failed to delete"
        fi
        
        reload_active_panel
        
        # Position cursor intelligently after delete (files are gone)
        local file_count=$($active_list.count)
        
        local new_index=$saved_index
        if [ $new_index -ge $file_count ] && [ $file_count -gt 0 ]; then
            new_index=$((file_count - 1))
        fi
        
        $active_list.selected = $new_index
        
        # Adjust scroll if needed
        local active_panel=$(get_active_panel)
        local panel_height=$($active_panel.height)
        local max_visible=$((panel_height - 3))
        local scroll=$($active_list.scroll)
        
        if [ $new_index -lt $scroll ]; then
            $active_list.scroll = $new_index
        elif [ $new_index -ge $((scroll + max_visible)) ]; then
            $active_list.scroll = $((new_index - max_visible + 1))
        fi
        
        draw_screen
    else
        # No selection - delete cursor item (original behavior)
        local filename filetype
        IFS='|' read -r filename filetype path <<< "$(get_selected_item)"
        
        if $active_list.is_special "$filename"; then
            return
        fi
        
        local current_index=$($active_list.selected)
        local fullpath="$path/$filename"
        
        local confirm_result=0
        if [ "$filetype" = "d" ]; then
            file_dialog.show_confirm "Delete Directory" "Delete directory '$filename'?" || confirm_result=$?
        else
            file_dialog.show_confirm "Delete File" "Delete file '$filename'?" || confirm_result=$?
        fi
        
        dialog_cleanup
        
        if [ $confirm_result -ne 0 ]; then
            draw_screen
            return
        fi
        
        local delete_success=0
        
        if [ "$filetype" = "d" ]; then
            if rmdir "$fullpath" 2>/dev/null; then
                delete_success=1
            else
                local recursive_result=0
                file_dialog.show_confirm "Directory Not Empty" "Directory is not empty. Delete recursively?" || recursive_result=$?
                dialog_cleanup
                
                if [ $recursive_result -eq 0 ]; then
                    if rm -rf "$fullpath" 2>/dev/null; then
                        delete_success=1
                    else
                        show_error "Failed to delete directory"
                        return
                    fi
                else
                    draw_screen
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
            reload_active_panel
            
            local file_count=$($active_list.count)
            
            local new_index=$current_index
            if [ $current_index -ge $((file_count - 1)) ] && [ $current_index -gt 0 ]; then
                new_index=$((current_index - 1))
            fi
            
            $active_list.selected = $new_index
            
            local active_panel=$(get_active_panel)
            local panel_height=$($active_panel.height)
            local max_visible=$((panel_height - 3))
            local scroll=$($active_list.scroll)
            
            if [ $new_index -lt $scroll ]; then
                $active_list.scroll = $new_index
            elif [ $new_index -ge $((scroll + max_visible)) ]; then
                $active_list.scroll = $((new_index - max_visible + 1))
            fi
            
            draw_screen
        fi
    fi
}

# Copy file/directory (F5)
copy_item() {
    local active_list=$(get_active_panel).list
    local source_path=$($active_list.path)
    local other_list=$(get_other_panel).list
    local dest_path=$($other_list.path)
    
    # Remember cursor position before operation
    local saved_index=$($active_list.selected)
    local filename_for_restore filetype_tmp path_tmp
    IFS='|' read -r filename_for_restore filetype_tmp path_tmp <<< "$(get_selected_item)"
    
    # Check if there are selected files
    local selected_count=$($active_list.count_selected)
    
    if [ $selected_count -gt 0 ]; then
        # Get selection info from filelist
        local sel_info=$($active_list.selection_info)
        local total_bytes="${sel_info#*|}"
        
        # Format total size
        local size_str
        if [ $total_bytes -lt 1024 ]; then
            size_str="${total_bytes}B"
        elif [ $total_bytes -lt 1048576 ]; then
            size_str="$((total_bytes / 1024))KB"
        else
            size_str="$((total_bytes / 1048576))MB"
        fi
        
        # Show confirmation with From/To in a custom dialog
        local confirm_result=0
        
        # Calculate dialog size based on path lengths
        local max_path_len=${#source_path}
        [ ${#dest_path} -gt $max_path_len ] && max_path_len=${#dest_path}
        
        local dialog_width=$((max_path_len + 10))  # Add padding
        [ $dialog_width -lt 50 ] && dialog_width=50  # Minimum width
        [ $dialog_width -gt 70 ] && dialog_width=70  # Maximum width
        
        local dialog_height=9
        
        # Get terminal size
        local size=$(tui.screen.size)
        local rows=${size% *}
        local cols=${size#* }
        local dialog_row=$(( (rows - dialog_height) / 2 ))
        local dialog_col=$(( (cols - dialog_width) / 2 ))
        
        # Draw dialog background (shadow)
        tui.color.bg_black
        for ((r=dialog_row+1; r<dialog_row+dialog_height+1; r++)); do
            tui.cursor.move $r $((dialog_col + 2))
            printf "%$((dialog_width))s" ""
        done
        tui.color.reset
        
        # Draw dialog box
        tui.color.bg_white
        tui.color.black
        for ((r=dialog_row; r<dialog_row+dialog_height; r++)); do
            tui.cursor.move $r $dialog_col
            printf "%${dialog_width}s" ""
        done
        
        # Draw border
        tui.cursor.move $dialog_row $dialog_col
        tui.box.draw $dialog_row $dialog_col $dialog_width $dialog_height
        
        # Draw title
        tui.cursor.move $dialog_row $((dialog_col + 2))
        tui.color.bg_white
        tui.color.black
        tui.color.bold
        printf " Copy "
        tui.color.reset
        
        # Draw message
        tui.cursor.move $((dialog_row + 2)) $((dialog_col + 2))
        tui.color.bg_white
        tui.color.black
        printf "Copy %d files (%s)" "$selected_count" "$size_str"
        
        # Draw From:
        tui.cursor.move $((dialog_row + 4)) $((dialog_col + 2))
        tui.color.bold
        printf "From: "
        tui.color.reset
        tui.color.bg_white
        tui.color.black
        # Truncate path if too long
        local from_max=$((dialog_width - 10))
        local from_display="$source_path"
        if [ ${#from_display} -gt $from_max ]; then
            from_display="...${source_path: -$((from_max - 3))}"
        fi
        printf "%s" "$from_display"
        
        # Draw To:
        tui.cursor.move $((dialog_row + 5)) $((dialog_col + 2))
        tui.color.bold
        printf "To:   "
        tui.color.reset
        tui.color.bg_white
        tui.color.black
        local to_display="$dest_path"
        if [ ${#to_display} -gt $from_max ]; then
            to_display="...${dest_path: -$((from_max - 3))}"
        fi
        printf "%s" "$to_display"
        
        # Draw buttons
        local selected_btn=0  # 0=Yes, 1=No
        
        while true; do
            tui.cursor.move $((dialog_row + 7)) $((dialog_col + dialog_width/2 - 8))
            
            if [ $selected_btn -eq 0 ]; then
                tui.color.bg_cyan
                tui.color.black
                tui.color.bold
            else
                tui.color.bg_white
                tui.color.black
            fi
            printf "[ Yes ]"
            tui.color.reset
            
            tui.color.bg_white
            tui.color.black
            printf "   "
            
            if [ $selected_btn -eq 1 ]; then
                tui.color.bg_cyan
                tui.color.black
                tui.color.bold
            else
                tui.color.bg_white
                tui.color.black
            fi
            printf "[ No ]"
            tui.color.reset
            
            # Read key
            local key=$(tui.input.key)
            
            case "$key" in
                LEFT|RIGHT|TAB)
                    selected_btn=$((1 - selected_btn))
                    ;;
                ENTER)
                    if [ $selected_btn -eq 0 ]; then
                        confirm_result=0
                    else
                        confirm_result=1
                    fi
                    break
                    ;;
                ESC)
                    confirm_result=1
                    break
                    ;;
            esac
        done
        
        # Clear dialog
        tui.screen.alt
        draw_screen
        
        if [ $confirm_result -ne 0 ]; then
            return
        fi
        
        # Copy each selected file to destination path
        local failed=0
        while IFS='|' read -r filename filetype; do
            local source="$source_path/$filename"
            local destination="$dest_path/$filename"
            
            if [ "$filetype" = "d" ]; then
                cp -r "$source" "$destination" 2>/dev/null || failed=1
            else
                cp "$source" "$destination" 2>/dev/null || failed=1
            fi
        done < <($active_list.get_selected)
        
        if [ $failed -eq 1 ]; then
            show_error "Some files failed to copy"
        fi
        
        reload_both_panels
        
        # Restore cursor position
        local active_panel=$(get_active_panel)
        local panel_height=$($active_panel.height)
        $active_list.find_and_select "$filename_for_restore" $((panel_height - 3))
        
        draw_screen
    else
        # No selection - copy cursor item (original behavior)
        local filename filetype
        IFS='|' read -r filename filetype source_path <<< "$(get_selected_item)"
        
        # Don't copy special items
        if $active_list.is_special "$filename"; then
            return
        fi
        
        # Remember current selection to restore later
        local current_selection="$filename"
        
        # Show input dialog with default destination (other panel's path)
        local default_dest="$dest_path/$filename"
        
        if ! show_path_input "Copy" "Copy to:" "$default_dest"; then
            # Cancelled
            tui.screen.clear
            draw_screen
            return
        fi
        
        local destination="$CUSTOM_INPUT_RESULT"
        
        # Validate input
        if [ -z "$destination" ]; then
            show_error "Destination cannot be empty"
            return
        fi
        
        # If destination is relative (no leading /), make it relative to source directory
        if [[ "$destination" != /* ]]; then
            destination="$source_path/$destination"
        fi
        
        local source="$source_path/$filename"
        
        # Check if destination exists
        if [ -e "$destination" ]; then
            local confirm_result=0
            file_dialog.show_confirm "Overwrite?" "Destination exists. Overwrite?" || confirm_result=$?
            dialog_cleanup
            
            if [ $confirm_result -ne 0 ]; then
                draw_screen
                return
            fi
        fi
        
        # Copy file or directory
        local copy_cmd
        if [ "$filetype" = "d" ]; then
            copy_cmd="cp -r"
        else
            copy_cmd="cp"
        fi
        
        if $copy_cmd "$source" "$destination" 2>/dev/null; then
            # Success - reload both panels
            reload_both_panels
            
            # Restore cursor position to the same file in source panel
            local active_panel=$(get_active_panel)
            local panel_height=$($active_panel.height)
            $active_list.find_and_select "$current_selection" $((panel_height - 3))
            $active_panel.prerender_all_rows
            
            tui.screen.clear
            draw_screen
        else
            show_error "Failed to copy"
        fi
    fi
}

# Move/rename file/directory (F6)
move_item() {
    local active_list=$(get_active_panel).list
    local source_path=$($active_list.path)
    local other_list=$(get_other_panel).list
    local dest_path=$($other_list.path)
    
    # Remember cursor position before operation
    local saved_index=$($active_list.selected)
    local filename_for_restore filetype_tmp path_tmp
    IFS='|' read -r filename_for_restore filetype_tmp path_tmp <<< "$(get_selected_item)"
    
    # Check if there are selected files
    local selected_count=$($active_list.count_selected)
    
    if [ $selected_count -gt 0 ]; then
        # Get selection info from filelist
        local sel_info=$($active_list.selection_info)
        local total_bytes="${sel_info#*|}"
        
        # Format total size
        local size_str
        if [ $total_bytes -lt 1024 ]; then
            size_str="${total_bytes}B"
        elif [ $total_bytes -lt 1048576 ]; then
            size_str="$((total_bytes / 1024))KB"
        else
            size_str="$((total_bytes / 1048576))MB"
        fi
        
        # Show confirmation with From/To in a custom dialog
        local confirm_result=0
        
        # Calculate dialog size based on path lengths
        local max_path_len=${#source_path}
        [ ${#dest_path} -gt $max_path_len ] && max_path_len=${#dest_path}
        
        local dialog_width=$((max_path_len + 10))
        [ $dialog_width -lt 50 ] && dialog_width=50
        [ $dialog_width -gt 70 ] && dialog_width=70
        
        local dialog_height=9
        
        # Get terminal size
        local size=$(tui.screen.size)
        local rows=${size% *}
        local cols=${size#* }
        local dialog_row=$(( (rows - dialog_height) / 2 ))
        local dialog_col=$(( (cols - dialog_width) / 2 ))
        
        # Draw dialog background (shadow)
        tui.color.bg_black
        for ((r=dialog_row+1; r<dialog_row+dialog_height+1; r++)); do
            tui.cursor.move $r $((dialog_col + 2))
            printf "%$((dialog_width))s" ""
        done
        tui.color.reset
        
        # Draw dialog box
        tui.color.bg_white
        tui.color.black
        for ((r=dialog_row; r<dialog_row+dialog_height; r++)); do
            tui.cursor.move $r $dialog_col
            printf "%${dialog_width}s" ""
        done
        
        # Draw border
        tui.cursor.move $dialog_row $dialog_col
        tui.box.draw $dialog_row $dialog_col $dialog_width $dialog_height
        
        # Draw title
        tui.cursor.move $dialog_row $((dialog_col + 2))
        tui.color.bg_white
        tui.color.black
        tui.color.bold
        printf " Move "
        tui.color.reset
        
        # Draw message
        tui.cursor.move $((dialog_row + 2)) $((dialog_col + 2))
        tui.color.bg_white
        tui.color.black
        printf "Move %d files (%s)" "$selected_count" "$size_str"
        
        # Draw From:
        tui.cursor.move $((dialog_row + 4)) $((dialog_col + 2))
        tui.color.bold
        printf "From: "
        tui.color.reset
        tui.color.bg_white
        tui.color.black
        local from_max=$((dialog_width - 10))
        local from_display="$source_path"
        if [ ${#from_display} -gt $from_max ]; then
            from_display="...${source_path: -$((from_max - 3))}"
        fi
        printf "%s" "$from_display"
        
        # Draw To:
        tui.cursor.move $((dialog_row + 5)) $((dialog_col + 2))
        tui.color.bold
        printf "To:   "
        tui.color.reset
        tui.color.bg_white
        tui.color.black
        local to_display="$dest_path"
        if [ ${#to_display} -gt $from_max ]; then
            to_display="...${dest_path: -$((from_max - 3))}"
        fi
        printf "%s" "$to_display"
        
        # Draw buttons
        local selected_btn=0
        
        while true; do
            tui.cursor.move $((dialog_row + 7)) $((dialog_col + dialog_width/2 - 8))
            
            if [ $selected_btn -eq 0 ]; then
                tui.color.bg_cyan
                tui.color.black
                tui.color.bold
            else
                tui.color.bg_white
                tui.color.black
            fi
            printf "[ Yes ]"
            tui.color.reset
            
            tui.color.bg_white
            tui.color.black
            printf "   "
            
            if [ $selected_btn -eq 1 ]; then
                tui.color.bg_cyan
                tui.color.black
                tui.color.bold
            else
                tui.color.bg_white
                tui.color.black
            fi
            printf "[ No ]"
            tui.color.reset
            
            local key=$(tui.input.key)
            
            case "$key" in
                LEFT|RIGHT|TAB)
                    selected_btn=$((1 - selected_btn))
                    ;;
                ENTER)
                    if [ $selected_btn -eq 0 ]; then
                        confirm_result=0
                    else
                        confirm_result=1
                    fi
                    break
                    ;;
                ESC)
                    confirm_result=1
                    break
                    ;;
            esac
        done
        
        # Clear dialog
        tui.screen.alt
        draw_screen
        
        if [ $confirm_result -ne 0 ]; then
            return
        fi
        
        # Move each selected file
        local failed=0
        while IFS='|' read -r filename filetype; do
            local source="$source_path/$filename"
            local destination="$dest_path/$filename"
            mv "$source" "$destination" 2>/dev/null || failed=1
        done < <($active_list.get_selected)
        
        if [ $failed -eq 1 ]; then
            show_error "Some files failed to move"
        fi
        
        reload_both_panels
        
        # After move, files are gone, so position cursor intelligently
        local file_count=$($active_list.count)
        
        local new_index=$saved_index
        if [ $new_index -ge $file_count ] && [ $file_count -gt 0 ]; then
            new_index=$((file_count - 1))
        fi
        
        $active_list.selected = $new_index
        
        # Adjust scroll if needed
        local active_panel=$(get_active_panel)
        local panel_height=$($active_panel.height)
        local max_visible=$((panel_height - 3))
        local scroll=$($active_list.scroll)
        
        if [ $new_index -lt $scroll ]; then
            $active_list.scroll = $new_index
        elif [ $new_index -ge $((scroll + max_visible)) ]; then
            $active_list.scroll = $((new_index - max_visible + 1))
        fi
        
        draw_screen
    else
        # No selection - move cursor item (original behavior)
        local filename filetype
        IFS='|' read -r filename filetype source_path <<< "$(get_selected_item)"
        
        if $active_list.is_special "$filename"; then
            return
        fi
        
        local current_index=$($active_list.selected)
        local default_dest="$dest_path/$filename"
        
        if ! show_path_input "Move/Rename" "Move to:" "$default_dest"; then
            tui.screen.clear
            draw_screen
            return
        fi
        
        local destination="$CUSTOM_INPUT_RESULT"
        
        if [ -z "$destination" ]; then
            show_error "Destination cannot be empty"
            return
        fi
        
        if [[ "$destination" != /* ]]; then
            destination="$source_path/$destination"
        fi
        
        local source="$source_path/$filename"
        
        if [ -e "$destination" ]; then
            local confirm_result=0
            file_dialog.show_confirm "Overwrite?" "Destination exists. Overwrite?" || confirm_result=$?
            dialog_cleanup
            
            if [ $confirm_result -ne 0 ]; then
                draw_screen
                return
            fi
        fi
        
        if mv "$source" "$destination" 2>/dev/null; then
            reload_both_panels
            
            local file_count=$($active_list.count)
            
            local new_index=$current_index
            if [ $current_index -ge $((file_count - 1)) ] && [ $current_index -gt 0 ]; then
                new_index=$((current_index - 1))
            fi
            
            $active_list.selected = $new_index
            
            local active_panel=$(get_active_panel)
            local panel_height=$($active_panel.height)
            local max_visible=$((panel_height - 3))
            local scroll=$($active_list.scroll)
            
            if [ $new_index -lt $scroll ]; then
                $active_list.scroll = $new_index
            elif [ $new_index -ge $((scroll + max_visible)) ]; then
                $active_list.scroll = $((new_index - max_visible + 1))
            fi
            
            $active_panel.prerender_all_rows
            
            tui.screen.clear
            draw_screen
        else
            show_error "Failed to move"
        fi
    fi
}

# ============================================================================
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
                    cmd.render
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
                    cmd.render
                else
                    # In buffer mode - navigate command history
                    cmd.history_next
                    draw_command_line
                fi
                ;;
                
            PAGEUP)
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    navigate PAGEUP
                    cmd.render
                fi
                ;;
                
            PAGEDOWN)
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    navigate PAGEDOWN
                    cmd.render
                fi
                ;;
                
            HOME)
                if [ $PANELS_VISIBLE -eq 1 ]; then
                    if [ $has_cmdline_text -eq 1 ]; then
                        # Move cursor to start of command line
                        cmd.move_cursor HOME
                        cmd.render
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
                        # Move cursor to end of command line
                        cmd.move_cursor END
                        cmd.render
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
                
            # Ctrl+U - clear command line (standard shell behavior)
            CTRL-U)
                cmd.clear
                draw_command_line
                ;;
                
            # Tab - switch panels (only in panel mode with empty cmdline)
            TAB)
                if [ $PANELS_VISIBLE -eq 1 ] && [ $has_cmdline_text -eq 0 ]; then
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
                    local list=$(get_active_panel).list
                    $list.toggle_selection
                    navigate DOWN
                    $(get_active_panel).render
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
                    copy_item
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
tui.screen.main
main_frame.cleanup
