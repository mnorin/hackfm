#!/bin/bash
# titled module - Dynamic title bar
#
# Runs a background loop that publishes "title.update:TEXT" to the message bus
# at a configurable interval. Requires the bus module to be enabled.
#
# Configuration: conf/titled.conf
#   title_command=<shell snippet — stdout becomes the title>
#   title_interval=5

__TITLED_CMD=""
__TITLED_INTERVAL=5
__TITLED_LOOP_PID=""

titled.init() {
    local conf="$HACKFM_DIR/conf/titled.conf"

    if [ -f "$conf" ]; then
        local val
        val=$(grep -m1 '^title_command=' "$conf" 2>/dev/null | cut -d= -f2-)
        [ -n "$val" ] && __TITLED_CMD="$val"
        val=$(grep -m1 '^title_interval=' "$conf" 2>/dev/null | cut -d= -f2-)
        [ -n "$val" ] && __TITLED_INTERVAL="$val"
    fi

    [ -z "$__TITLED_CMD" ] && return
    [ -z "$__HACKFM_FIFO" ] && return  # bus module not loaded

    broker.subscribe "title.update"    "titled._on_update"
    broker.subscribe "ui.menu_opened"  "titled._on_menu_opened"
    broker.subscribe "ui.menu_closed"  "titled._on_menu_closed"

    titled._start_loop
}

titled._on_update() {
    main_title.text_left = "$1"
    main_title.width = $__HACKFM_COLS
    main_title.render
}
titled._on_update.process_message()    { titled._on_update "$2"; }

titled._on_menu_opened() {
    titled._stop_loop
}
titled._on_menu_opened.process_message()  { titled._on_menu_opened; }

titled._on_menu_closed() {
    titled._start_loop
}
titled._on_menu_closed.process_message()  { titled._on_menu_closed; }

titled._start_loop() {
    local fifo="$__HACKFM_FIFO"
    (
        while true; do
            local text
            text=$(eval "$__TITLED_CMD" 2>/dev/null) || true
            if [ -n "$text" ]; then
                printf 'title.update:%s\n' "$text" >> "$fifo" 2>/dev/null || true
            fi
            sleep "$__TITLED_INTERVAL"
        done
    ) &
    __TITLED_LOOP_PID=$!
    hackfm.bus.register_bgprocess $!
}

titled._stop_loop() {
    if [ -n "$__TITLED_LOOP_PID" ]; then
        kill "$__TITLED_LOOP_PID" 2>/dev/null || true
        __TITLED_LOOP_PID=""
    fi
}
