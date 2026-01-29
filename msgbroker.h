#!/bin/bash
# msgbroker.h - Constructor for message broker

msgbroker(){
    local class_code=$(<msgbroker.class)
    local sanitized="${1//./_}"
    
    # Replace __MSGBROKER__ with the actual instance name
    local temp="${class_code//__MSGBROKER__/$1}"
    
    # Replace array names to sanitize dots
    temp="${temp//${1}_subscribers/${sanitized}_subscribers}"
    
    . <(printf '%s' "${temp}")
}
