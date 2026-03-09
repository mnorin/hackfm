#!/bin/bash
# fileattr.h - Constructor for fileattr

fileattr(){
    local class_code=$(<"$HACKFM_DIR/fileattr.class")
    . <(printf '%s' "${class_code//__FILEATTR__/$1}")
}
