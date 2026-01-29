#!/bin/bash
# appframe.h - Constructor for appframe

appframe(){
    local class_code=$(<"$HACKFM_DIR/appframe.class")
    . <(printf '%s' "${class_code//__APPFRAME__/$1}")
}
