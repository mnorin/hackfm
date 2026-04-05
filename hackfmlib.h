#!/bin/bash
# hackfmlib.h - All constructors and class loaders for hackfm
# Sourced once by hackfm.sh; subprocess scripts (modules/viewer/viewer.sh, modules/editor/editor.sh)
# source their own .h files independently.

tui_dialog(){
    local class_code=$(<"$HACKFM_DIR/dialog.class")
    . <(printf '%s' "${class_code//__DIALOG__/$1}")
}

filelist(){
    local class_code=$(<"$HACKFM_DIR/filelist.class")
    local sanitized="${1//./_}"

    local temp="${class_code//__FILELIST__/$1}"
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
    temp="${temp//${1}_raw_sizes/${sanitized}_raw_sizes}"

    . <(printf '%s' "${temp}")
}

archivelist(){
    local class_code=$(<"$HACKFM_DIR/archivelist.class")
    local sanitized="${1//./_}"

    local temp="${class_code//__ARCHIVELIST__/$1}"
    temp="${temp//${1}_properties/${sanitized}_properties}"
    temp="${temp//${1}_all_entries/${sanitized}_all_entries}"
    temp="${temp//${1}_files/${sanitized}_files}"
    temp="${temp//${1}_types/${sanitized}_types}"
    temp="${temp//${1}_sizes/${sanitized}_sizes}"
    temp="${temp//${1}_times/${sanitized}_times}"
    temp="${temp//${1}_full_paths/${sanitized}_full_paths}"
    temp="${temp//${1}_marked/${sanitized}_marked}"

    . <(printf '%s' "${temp}")
}

panel(){
    local class_code=$(<"$HACKFM_DIR/panel.class")
    . <(printf '%s' "${class_code//__PANEL__/$1}")
}

fileattr(){
    local class_code=$(<"$HACKFM_DIR/modules/fsattr/fileattr.class")
    . <(printf '%s' "${class_code//__FILEATTR__/$1}")
}

commandline(){
    local class_code=$(<"$HACKFM_DIR/commandline.class")
    . <(printf '%s' "${class_code//__COMMANDLINE__/$1}")
}

msgbroker(){
    local class_code=$(<"$HACKFM_DIR/msgbroker.class")
    local sanitized="${1//./_}"

    local temp="${class_code//__MSGBROKER__/$1}"
    temp="${temp//${1}_subscribers/${sanitized}_subscribers}"

    . <(printf '%s' "${temp}")
}

menu(){
    local class_code=$(<"$HACKFM_DIR/menu.class")
    local sanitized="${1//./_}"

    local temp="${class_code//__MENU__/$1}"
    temp="${temp//${1}_properties/${sanitized}_properties}"
    temp="${temp//${1}_menu_names/${sanitized}_menu_names}"
    temp="${temp//${1}_menu_items/${sanitized}_menu_items}"
    temp="${temp//${1}_menu_positions/${sanitized}_menu_positions}"

    . <(printf '%s' "${temp}")
}

fkeybar(){
    local class_code=$(<"$HACKFM_DIR/fkeybar.class")
    . <(printf '%s' "${class_code//__FKEYBAR__/$1}")
}

title(){
    local class_code=$(<"$HACKFM_DIR/title.class")
    . <(printf '%s' "${class_code//__TITLE__/$1}")
}

# Stub implementations — overridden by bus.mod when bus is loaded
bus.pause_processing()  { return 0; }
bus.resume_processing() { return 0; }
