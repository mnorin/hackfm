#!/bin/bash
# dialog_demo.sh - Demo of dialog.class

# Load TUI
. ./tui/cursor.class
. ./tui/screen.class
. ./tui/color.class
. ./tui/box.class
. ./tui/input.class

# Load dialog
. dialog.h

# Create dialog instance
dialog test_dialog

# Switch to alternate screen
tui.screen.alt
tui.cursor.hide
tui.screen.clear

# Test 1: Input dialog
tui.cursor.move 2 2
echo "Press any key to test INPUT dialog..."
tui.input.key >/dev/null

test_dialog.show_input "Copy File" "Enter destination path:" "/home/user/backup/"
result=$?

tui.screen.clear
tui.cursor.move 2 2
if [ $result -eq 0 ]; then
    echo "You entered: $(test_dialog.input_value)"
else
    echo "Cancelled"
fi

# Test 2: Confirmation dialog
tui.cursor.move 4 2
echo "Press any key to test CONFIRMATION dialog..."
tui.input.key >/dev/null

test_dialog.show_confirm "Delete File" "Really delete file.txt?"
result=$?

tui.cursor.move 6 2
if [ $result -eq 0 ]; then
    echo "You clicked: YES"
else
    echo "You clicked: NO"
fi

# Test 3: Message dialog
tui.cursor.move 8 2
echo "Press any key to test MESSAGE dialog..."
tui.input.key >/dev/null

test_dialog.show_message "Success" "File copied successfully!"

tui.screen.clear
tui.cursor.move 2 2
echo "Demo complete! Press any key to exit..."
tui.input.key >/dev/null

# Cleanup
tui.cursor.show
tui.screen.main
