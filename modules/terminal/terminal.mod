#!/bin/bash
# terminal module - Interactive shell via Ctrl-O
#
# Registers CTRL-O and handles the full interactive shell lifecycle.
# Publishes ui.terminal_opened / ui.terminal_closed around the session.

terminal.init() {
    hackfm.module.register_key "CTRL-O" "terminal.open" ""
}

terminal.open() {
    broker.publish "ui.terminal_opened" ""

    tui.screen.main
    tui.cursor.show
    stty sane

    trap - ERR
    set +e
    bash --rcfile <(cat <<'RCFILE'
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi
__hackfm_exit() { exit; }
bind -x '"\C-o": __hackfm_exit'
RCFILE
) -i < /dev/tty > /dev/tty 2>&1 || true
    set -e
    trap '__ba_err_report $? $LINENO' ERR

    tui.screen.alt
    stty -echo 2>/dev/null
    hackfm.read_term_size
    broker.publish "ui.terminal_closed" ""
}
