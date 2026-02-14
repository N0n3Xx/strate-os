#!/usr/bin/env bash
# strate-os view: sysmonitor
# Layout: top = btop, bottom = fastfetch (auto-refreshing)
set -euo pipefail

SESSION="strate-sysmonitor"

if tmux has-session -t "$SESSION" 2>/dev/null; then
    exec tmux attach-session -t "$SESSION"
fi

tmux new-session -d -s "$SESSION" -x "$(tput cols)" -y "$(tput lines)"

# Top pane: btop
tmux send-keys -t "$SESSION" "btop" Enter

# Bottom pane: fastfetch in a watch loop
tmux split-window -t "$SESSION" -v -l 30%
tmux send-keys -t "$SESSION" "fastfetch && exec bash -c 'while true; do clear; fastfetch; sleep 60; done'" Enter

tmux select-pane -t "$SESSION:0.0"
exec tmux attach-session -t "$SESSION"
