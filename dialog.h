#!/bin/bash
# dialog.h - Constructor for dialog

dialog(){
    local class_code=$(<"$HACKFM_DIR/dialog.class")
    . <(printf '%s' "${class_code//__DIALOG__/$1}")
}
