#!/bin/bash
# bus module - External message bus
#
# Provides a FIFO-based message bus for background processes to publish
# broker messages into the main hackfm process.
#
# Background processes write "topic:data" lines to $__HACKFM_FIFO.
# A listener process reads them, appends to an inbox file, and sends SIGUSR1
# to the main process. The SIGUSR1 handler drains the inbox and dispatches
# via the broker, deduplicating by topic so stale messages don't pile up.
#
# API for other modules:
#   hackfm.bus.register_bgprocess PID  — register bg PID for cleanup on exit
#   $__HACKFM_FIFO                     — path to write messages to

declare -ag __HACKFM_FIFO_BGPIDS=()
__HACKFM_FIFO=""
__HACKFM_FIFO_INBOX=""

bus.pre_init() {
    mkdir -p "$HACKFM_DIR/run"
    __HACKFM_FIFO="$HACKFM_DIR/run/bus.fifo"
    __HACKFM_FIFO_INBOX="$HACKFM_DIR/run/bus.inbox"

    rm -f "$__HACKFM_FIFO" "$__HACKFM_FIFO_INBOX"
    mkfifo "$__HACKFM_FIFO"
    > "$__HACKFM_FIFO_INBOX"

    trap 'bus._handler' USR1
    bus._start_listener
}

bus.on_exit() {
    local pid
    for pid in "${__HACKFM_FIFO_BGPIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    rm -f "$__HACKFM_FIFO" "$__HACKFM_FIFO_INBOX"
}

bus._handler() {
    trap - ERR
    [ -f "$__HACKFM_FIFO_INBOX" ] || return
    local _data
    _data=$(cat "$__HACKFM_FIFO_INBOX" 2>/dev/null) || true
    > "$__HACKFM_FIFO_INBOX"

    # Deduplicate by topic — keep only the last message per topic
    local -A _seen=()
    local -a _ordered=()
    local _msg _topic
    while IFS= read -r _msg; do
        [ -z "$_msg" ] && continue
        _topic="${_msg%%:*}"
        [ -z "${_seen[$_topic]+x}" ] && _ordered+=("$_topic")
        _seen["$_topic"]="${_msg#*:}"
    done <<< "$_data"

    for _topic in "${_ordered[@]}"; do
        broker.publish "$_topic" "${_seen[$_topic]}"
    done
    trap 'error_handler $LINENO' ERR
}

bus._start_listener() {
    local fifo="$__HACKFM_FIFO"
    local inbox="$__HACKFM_FIFO_INBOX"
    local mainpid="$$"
    (
        exec 8<>"$fifo"
        while IFS= read -r _line <&8; do
            if [ -n "$_line" ]; then
                printf '%s\n' "$_line" >> "$inbox"
                kill -USR1 "$mainpid" 2>/dev/null || exit 0
            fi
        done
    ) &
    hackfm.bus.register_bgprocess $!
}

# Register a background process PID for cleanup on exit
hackfm.bus.register_bgprocess() {
    __HACKFM_FIFO_BGPIDS+=("$1")
}

# No-op — kept for compatibility if anything calls it
bus._drain() { return 0; }
