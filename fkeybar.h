#!/bin/bash
# fkeybar.h - Constructor for fkeybar

fkeybar(){
    local class_code=$(<"$HACKFM_DIR/fkeybar.class")
    . <(printf '%s' "${class_code//__FKEYBAR__/$1}")
}
