#!/bin/bash
# menu.h - Constructor for menu

menu(){
    local class_code=$(<"$HACKFM_DIR/menu.class")
    local sanitized="${1//./_}"
    
    local temp="${class_code//__MENU__/$1}"
    
    # Sanitize array names
    temp="${temp//${1}_properties/${sanitized}_properties}"
    temp="${temp//${1}_menu_names/${sanitized}_menu_names}"
    temp="${temp//${1}_menu_items/${sanitized}_menu_items}"
    temp="${temp//${1}_menu_positions/${sanitized}_menu_positions}"
    
    . <(printf '%s' "${temp}")
}
