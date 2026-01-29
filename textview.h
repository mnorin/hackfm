#!/bin/bash
# textview.h - Constructor for textview

textview(){
    local class_code=$(<textview.class)
    . <(printf '%s' "${class_code//__TEXTVIEW__/$1}")
}
