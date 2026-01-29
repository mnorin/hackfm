#!/bin/bash
# commandline.h - Constructor for commandline

commandline(){
    local class_code=$(<commandline.class)
    . <(printf '%s' "${class_code//__COMMANDLINE__/$1}")
}
