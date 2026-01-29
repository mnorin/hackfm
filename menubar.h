#!/bin/bash
# menubar.h - Constructor for menubar

menubar(){
    local class_code=$(<menubar.class)
    . <(printf '%s' "${class_code//__MENUBAR__/$1}")
}
