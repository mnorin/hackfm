#!/bin/bash
# archivelist.h - Constructor for archivelist

archivelist(){
    local class_code=$(<"$HACKFM_DIR/archivelist.class")
    local sanitized="${1//./_}"
    
    # Replace __ARCHIVELIST__ with instance name
    local temp="${class_code//__ARCHIVELIST__/$1}"
    
    # Replace array names for sanitization
    temp="${temp//${1}_properties/${sanitized}_properties}"
    temp="${temp//${1}_all_entries/${sanitized}_all_entries}"
    temp="${temp//${1}_files/${sanitized}_files}"
    temp="${temp//${1}_types/${sanitized}_types}"
    temp="${temp//${1}_sizes/${sanitized}_sizes}"
    temp="${temp//${1}_times/${sanitized}_times}"
    temp="${temp//${1}_full_paths/${sanitized}_full_paths}"
    
    . <(printf '%s' "${temp}")
}
