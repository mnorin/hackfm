#!/bin/bash
# filelist.h - Constructor for filelist

filelist(){
    local class_code=$(<"$HACKFM_DIR/filelist.class")
    local sanitized="${1//./_}"
    
    # First replace __FILELIST__ with the actual name (e.g., left_panel.list)
    local temp="${class_code//__FILELIST__/$1}"
    
    # Then replace all array names: left_panel.list_properties -> left_panel_list_properties
    temp="${temp//${1}_properties/${sanitized}_properties}"
    temp="${temp//${1}_files/${sanitized}_files}"
    temp="${temp//${1}_types/${sanitized}_types}"
    temp="${temp//${1}_sizes/${sanitized}_sizes}"
    temp="${temp//${1}_times/${sanitized}_times}"
    temp="${temp//${1}_execs/${sanitized}_execs}"
    temp="${temp//${1}_marked/${sanitized}_marked}"
    temp="${temp//${1}_link_targets/${sanitized}_link_targets}"
    temp="${temp//${1}_rendered_rows/${sanitized}_rendered_rows}"
    temp="${temp//${1}_index_name_asc/${sanitized}_index_name_asc}"
    temp="${temp//${1}_index_name_desc/${sanitized}_index_name_desc}"
    temp="${temp//${1}_index_date_asc/${sanitized}_index_date_asc}"
    temp="${temp//${1}_index_date_desc/${sanitized}_index_date_desc}"
    temp="${temp//${1}_index_size_asc/${sanitized}_index_size_asc}"
    temp="${temp//${1}_index_size_desc/${sanitized}_index_size_desc}"
    temp="${temp//${1}_index_ext_asc/${sanitized}_index_ext_asc}"
    temp="${temp//${1}_index_ext_desc/${sanitized}_index_ext_desc}"
    
    . <(printf '%s' "${temp}")
}
