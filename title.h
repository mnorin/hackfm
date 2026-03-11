#!/bin/bash
# title.h - Constructor for title

title(){
    local class_code=$(<"$HACKFM_DIR/title.class")
    . <(printf '%s' "${class_code//__TITLE__/$1}")
}
