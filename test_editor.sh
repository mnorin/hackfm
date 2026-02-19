#!/bin/bash
# test_editor.sh - Test if editor works with the fixed class

# Load TUI
. ./tui/cursor.class
. ./tui/screen.class
. ./tui/color.class
. ./tui/box.class
. ./tui/input.class
. ./tui/style.class

# Load fixed classes
. appframe.h
. editor.h

# Create a test file
echo "Line 1: This is a test file" > /tmp/test_edit.txt
echo "Line 2: Testing the editor" >> /tmp/test_edit.txt
echo "Line 3: Press F2 to save, F10 to quit" >> /tmp/test_edit.txt

# Create editor instance
editor my_editor

# Load file
my_editor.load "/tmp/test_edit.txt"

# Show editor
echo "Opening editor..."
my_editor.show

echo "Editor exited normally"
