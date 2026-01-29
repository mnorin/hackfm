#!/bin/bash
# panel.h - Constructor for panel

panel(){
    local class_code=$(<"$HACKFM_DIR/panel.class")
    . <(printf '%s' "${class_code//__PANEL__/$1}")
}
