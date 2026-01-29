#!/bin/bash
# statusbar.h - Constructor for statusbar

statusbar(){
    local class_code=$(<statusbar.class)
    . <(printf '%s' "${class_code//__STATUSBAR__/$1}")
}
