#!/bin/bash
# titled module - Dynamic title bar
#
# Runs a background loop that publishes "title.update:TEXT" to the message bus
# at a configurable interval. Requires the bus module to be enabled.
#
# Configuration: conf/titled.conf
#   title_command=<shell snippet — stdout becomes the title>
#   title_interval=5

titled.init() {
    local conf="$HACKFM_DIR/conf/titled.conf"
    local cmd=""
    local interval=5

    if [ -f "$conf" ]; then
        local val
        val=$(grep -m1 '^title_command=' "$conf" 2>/dev/null | cut -d= -f2-)
        [ -n "$val" ] && cmd="$val"
        val=$(grep -m1 '^title_interval=' "$conf" 2>/dev/null | cut -d= -f2-)
        [ -n "$val" ] && interval="$val"
    fi

    [ -z "$cmd" ] && return
    [ -z "$__HACKFM_FIFO" ] && return  # bus module not loaded

    broker.subscribe "title.update" "titled._on_update"
    titled._start_loop "$cmd" "$interval"
}

titled._on_update() {
    main_title.text_left = "$1"
    main_title.width = $__HACKFM_COLS
    main_title.render
}
titled._on_update.process_message() { titled._on_update "$2"; }

titled._start_loop() {
    local cmd="$1"
    local interval="$2"
    local fifo="$__HACKFM_FIFO"

    (
        while true; do
            local text
            text=$(eval "$cmd" 2>/dev/null) || true
            if [ -n "$text" ]; then
                printf 'title.update:%s\n' "$text" >> "$fifo" 2>/dev/null || true
            fi
            sleep "$interval"
        done
    ) &

    hackfm.bus.register_bgprocess $!
}
