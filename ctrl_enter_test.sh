#!/bin/bash
echo "Press Ctrl+Enter, then Ctrl+C to exit"
while true; do
    IFS= read -rsn1 char
    printf "Got: "
    printf '%s' "$char" | od -An -tx1
    echo
done

