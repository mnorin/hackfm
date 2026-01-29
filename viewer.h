#!/bin/bash
# viewer.h - Constructor for viewer

viewer(){
    local class_code=$(<"$HACKFM_DIR/viewer.class")
    . <(printf '%s' "${class_code//__VIEWER__/$1}")
}
