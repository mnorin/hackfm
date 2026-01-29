#!/bin/bash
# editor.h - Constructor for editor

editor(){
    local class_code=$(<"$HACKFM_DIR/editor.class")
    . <(printf '%s' "${class_code//__EDITOR__/$1}")
}
