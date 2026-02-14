# ── strate-os shell integration ──────────────────────────
# Source this file from your .zshrc:
#   source "$HOME/.config/strate-os/shell/strate-os.zsh"

export STRATE_OS_DIR="$HOME/.config/strate-os"
export STRATE_OS_VIEWS="$STRATE_OS_DIR/views"

# ── Read settings ────────────────────────────────────────
_strate_setting() {
    local key="$1" default="$2"
    if [[ -f "$STRATE_OS_DIR/settings.json" ]]; then
        local val
        val="$(grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$STRATE_OS_DIR/settings.json" | head -1 | sed 's/.*: *"//;s/"//')"
        echo "${val:-$default}"
    else
        echo "$default"
    fi
}

_strate_has_tool() {
    local tools
    tools="$(_strate_setting cliTools '') $(_strate_setting extras '')"
    [[ " $tools " == *" $1 "* ]]
}

# ── Core settings ────────────────────────────────────────
export EDITOR="$(_strate_setting editor hx)"
export VISUAL="$EDITOR"
export STRATE_OS_FETCH_TOOL="$(_strate_setting fetchTool fastfetch)"
export STRATE_OS_FILE_BROWSER="$(_strate_setting fileBrowser yazi)"
export STRATE_OS_MONITOR="$(_strate_setting monitor btop)"
export STRATE_OS_GIT_TUI="$(_strate_setting gitTui lazygit)"

# ── eza aliases (if installed) ───────────────────────────
if command -v eza &>/dev/null && _strate_has_tool eza; then
    alias ls='eza --icons'
    alias la='eza -a --icons'
    alias ll='eza -l --icons --git'
    alias lt='eza --tree --icons'
    alias lla='eza -la --icons --git'
fi

# ── bat aliases (if installed) ───────────────────────────
if command -v bat &>/dev/null && _strate_has_tool bat; then
    alias cat='bat --paging=never'
    alias catp='bat'
fi

# ── fd alias (if installed) ──────────────────────────────
if command -v fd &>/dev/null && _strate_has_tool fd; then
    alias find='fd'
fi

# ── ripgrep alias (if installed) ─────────────────────────
if command -v rg &>/dev/null && _strate_has_tool ripgrep; then
    alias grep='rg'
fi

# ── dust alias (if installed) ────────────────────────────
if command -v dust &>/dev/null && _strate_has_tool dust; then
    alias du='dust'
fi

# ── delta (git pager) ───────────────────────────────────
if command -v delta &>/dev/null && _strate_has_tool delta; then
    export GIT_PAGER="delta"
fi

# ── claude — Claude Code in tmux with teammate mode ─────
function claude() {
    local claude_bin
    claude_bin="$(command -v claude)" || {
        echo "\033[31m>>> claude not found. Install Claude Code first.\033[0m"
        return 1
    }

    local session="claude-${PWD##*/}"

    # Already inside tmux — just run claude directly
    if [[ -n "${TMUX:-}" ]]; then
        command claude --dangerously-skip-permissions "$@"
        return
    fi

    # Attach to existing session
    if tmux has-session -t "$session" 2>/dev/null; then
        exec tmux attach-session -t "$session"
        return
    fi

    # New tmux session running claude
    exec tmux new-session -s "$session" "$claude_bin --dangerously-skip-permissions $*"
}

# ── cls — clear + system info ────────────────────────────
function cls() {
    clear
    local tool="${STRATE_OS_FETCH_TOOL:-fastfetch}"
    if command -v "$tool" &>/dev/null; then
        "$tool"
    else
        echo "\033[31m>>> $tool not found. Install it or change fetchTool in :settings\033[0m"
    fi
}

# ── :strate — hybrid view launcher ──────────────────────
function :strate() {
    if [[ -z "${1:-}" ]]; then
        echo "\033[36m┌──────────────────────────────────────────┐\033[0m"
        echo "\033[36m│  :strate <view>  — launch a view         │\033[0m"
        echo "\033[36m├──────────────────────────────────────────┤\033[0m"
        echo "\033[36m│  Available views:                        │\033[0m"
        for f in "$STRATE_OS_VIEWS"/*.sh; do
            [[ -f "$f" ]] || continue
            local name="$(basename "$f" .sh)"
            local desc=""
            desc="$(sed -n '2s/^# strate-os view: //p' "$f")"
            printf "\033[36m│  %-12s %s\033[0m\n" "$name" "${desc:+— $desc}"
        done
        echo "\033[36m└──────────────────────────────────────────┘\033[0m"
        return 0
    fi

    local view="$1"
    local script="$STRATE_OS_VIEWS/${view}.sh"

    if [[ ! -f "$script" ]]; then
        echo "\033[31m>>> Unknown view: $view\033[0m"
        echo "Run \033[36m:strate\033[0m to see available views."
        return 1
    fi

    exec bash "$script"
}

# ── Shell macros ─────────────────────────────────────────
function :help() {
    echo "\033[36m┌──────────────────────────────────────────┐\033[0m"
    echo "\033[36m│  strate-os commands                      │\033[0m"
    echo "\033[36m├──────────────────────────────────────────┤\033[0m"
    echo "\033[36m│  claude         — Claude Code in tmux    │\033[0m"
    echo "\033[36m│  cls            — clear + system info    │\033[0m"
    echo "\033[36m│  :strate <view> — launch a tmux view     │\033[0m"
    echo "\033[36m│  :settings  — edit strate-os config      │\033[0m"
    echo "\033[36m│  :ghostty   — edit ghostty config        │\033[0m"
    echo "\033[36m│  :zsh       — edit zshrc                 │\033[0m"
    echo "\033[36m│  :edit      — open text editor           │\033[0m"
    echo "\033[36m│  :files     — file browser               │\033[0m"
    echo "\033[36m│  :monitor   — process monitor            │\033[0m"
    echo "\033[36m│  :git       — git TUI                    │\033[0m"
    echo "\033[36m│  :fetch     — system info                │\033[0m"
    echo "\033[36m│  :reload    — reload shell config        │\033[0m"
    echo "\033[36m│  :help      — show this help             │\033[0m"
    echo "\033[36m└──────────────────────────────────────────┘\033[0m"
}

function :settings() { $EDITOR "$STRATE_OS_DIR/settings.json"; }
function :ghostty()  { $EDITOR "$HOME/.config/ghostty/config"; }
function :zsh()      { $EDITOR "$HOME/.zshrc"; }
function :edit()     { $EDITOR "$@"; }
function :files()    { "$STRATE_OS_FILE_BROWSER" "$@"; }
function :monitor()  { "$STRATE_OS_MONITOR"; }
function :fetch()    { "$STRATE_OS_FETCH_TOOL"; }
function :reload()   { source "$HOME/.zshrc" && echo "\033[36m>>> strate-os reloaded\033[0m"; }

function :git() {
    if [[ "$STRATE_OS_GIT_TUI" == "none" ]]; then
        echo "\033[31m>>> No git TUI configured. Run the installer or change gitTui in :settings\033[0m"
        return 1
    fi
    "$STRATE_OS_GIT_TUI" "$@"
}

