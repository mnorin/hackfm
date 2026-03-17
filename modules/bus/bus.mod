#!/bin/bash
# bus module - External message bus
#
# Provides a FIFO-based message bus for background processes to publish
# broker messages into the main hackfm process.
#
# Architecture:
#   - FIFO opened read-write on fd 9 (kernel-managed buffer, no files accumulate)
#   - Writers append "topic:data\n" directly to fd 9
#   - A timer process sends SIGUSR1 every N seconds (configurable: bus_timer_interval)
#   - The USR1 handler drains fd 9 non-blocking, deduplicates by topic, dispatches via broker
#   - During renders, USR1 is blocked (bus.pause_processing) and flushed on resume
#
# fd 9 is reserved for the message bus FIFO.
# Runtime files: $XDG_RUNTIME_DIR/hackfm.$$/bus.fifo (cleaned up on exit)
#
# API for other modules:
#   hackfm.bus.register_bgprocess PID  — register bg PID for cleanup on exit
#   printf 'topic:data\n' >&9          — publish a message from any subprocess

declare -ag __HACKFM_FIFO_BGPIDS=()
__HACKFM_FIFO=""
__HACKFM_BUS_INTERVAL=1

bus.pre_init() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/hackfm.$$"
    mkdir -p "$runtime_dir"
    __HACKFM_FIFO="$runtime_dir/bus.fifo"

    rm -f "$__HACKFM_FIFO"
    mkfifo "$__HACKFM_FIFO"

    # Open FIFO read-write on fd 9 — prevents blocking on both read and write
    exec 9<>"$__HACKFM_FIFO"

    trap 'bus._handler' USR1
    bus._start_timer
}

bus.init() {
    # Read timer interval from hackfm.conf
    local val
    val=$(grep -m1 '^bus_timer_interval=' "$HACKFM_DIR/conf/hackfm.conf" 2>/dev/null | cut -d= -f2-)
    [ -n "$val" ] && __HACKFM_BUS_INTERVAL="$val"

    broker.subscribe "ui.terminal_opened" "bus.pause_processing"
    broker.subscribe "ui.terminal_closed" "bus.resume_processing"
}

bus.pause_processing.process_message()  { bus.pause_processing; }
bus.resume_processing.process_message() { bus.resume_processing; }

bus.on_exit() {
    local pid
    for pid in "${__HACKFM_FIFO_BGPIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    exec 9>&-
    rm -f "$__HACKFM_FIFO"
    rmdir "$(dirname "$__HACKFM_FIFO")" 2>/dev/null || true
}

bus._handler() {
    trap - ERR
    declare -F "broker.publish" &>/dev/null || return

    # Drain FIFO non-blocking — read all available lines from fd 9
    local -A _seen=()
    local -a _ordered=()
    local _msg _topic
    while IFS= read -r -t 0.01 _msg <&9; do
        [ -z "$_msg" ] && continue
        _topic="${_msg%%:*}"
        [ -z "${_seen[$_topic]+x}" ] && _ordered+=("$_topic")
        _seen["$_topic"]="${_msg#*:}"
    done

    for _topic in "${_ordered[@]}"; do
        broker.publish "$_topic" "${_seen[$_topic]}"
    done
    trap 'error_handler $LINENO' ERR
}

bus._start_timer() {
    local mainpid="$$"
    local interval="$__HACKFM_BUS_INTERVAL"
    (
        while true; do
            sleep "$interval"
            kill -USR1 "$mainpid" 2>/dev/null || exit 0
        done
    ) &
    hackfm.bus.register_bgprocess $!
}

# Register a background process PID for cleanup on exit
hackfm.bus.register_bgprocess() {
    __HACKFM_FIFO_BGPIDS+=("$1")
}

# Pause message processing — block USR1 during critical sections like rendering
bus.pause_processing() {
    trap '' USR1
}

# Resume message processing — restore USR1 handler and flush any queued messages
bus.resume_processing() {
    trap 'bus._handler' USR1
    bus._handler
}
