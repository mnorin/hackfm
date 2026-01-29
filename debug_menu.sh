#!/bin/bash
# debug_menu.sh - Debug what's happening

echo "=== Diagnostic Script ==="
echo "Current directory: $(pwd)"
echo ""

# Check files exist
echo "1. Checking if files exist:"
for file in ./tui/cursor.class ./tui/screen.class ./tui/color.class ./tui/box.class ./tui/input.class menu.h menu.class; do
    if [ -f "$file" ]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ $file NOT FOUND"
    fi
done
echo ""

# Try loading input.class
echo "2. Loading input.class..."
. ./tui/input.class
echo "  Loaded (if no error above)"
echo ""

# Check if function exists
echo "3. Checking if tui.input.key exists:"
if type tui.input.key &>/dev/null; then
    echo "  ✓ tui.input.key function EXISTS"
else
    echo "  ✗ tui.input.key function NOT FOUND"
fi
echo ""

# List all tui.* functions
echo "4. All tui.* functions defined:"
declare -F | grep "tui\." | head -20
echo ""

# Try calling tui.input.key
echo "5. Testing tui.input.key (press 'q' to continue):"
if type tui.input.key &>/dev/null; then
    key=$(tui.input.key)
    echo "  Got key: [$key]"
else
    echo "  Cannot test - function doesn't exist"
fi

echo ""
echo "=== End Diagnostic ==="
