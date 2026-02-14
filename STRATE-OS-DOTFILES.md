# strate-os — Dotfiles & Scripts Spec

## Overview

strate-os is NOT a custom terminal emulator. It's a collection of dotfiles, shell scripts, and configs that transform a stock Ghostty installation into a sci-fi terminal environment. No Electron, no custom builds, no forking Ghostty.

## Dependencies

All installable via `brew install`:
- **ghostty** — terminal emulator (already has built-in tiling, GPU rendering, theming)
- **tmux** — only used as a session manager for Claude Code multi-agent workflows
- **helix** (`hx`) — default text editor
- **yazi** — TUI file browser
- **btop** — TUI system monitor
- **fastfetch** — system info display
- **claude** — Claude Code CLI (installed separately)

## File Structure

```
~/.config/ghostty/config          # Ghostty config (theme, fonts, keybindings)
~/.config/strate-os/
    settings.json                 # strate-os preferences
    sounds/profiles/              # Typing sound WAV files
        soft/keyboard.wav
        typewriter/keyboard.wav
        mechanical/keyboard.wav
        soothing/keyboard.wav
        bubbly/keyboard.wav
        cyberpunk/keyboard.wav
~/.zshrc                          # Shell macros, env vars, sound hooks (additions)
~/.local/bin/cc                   # Claude Code + tmux launcher
~/.local/bin/strate-os            # Optional: opens Ghostty with strate-os config
```

## 1. Ghostty Config (`~/.config/ghostty/config`)

```
# Theme: Catppuccin Frappé
theme = catppuccin-frappe

# Font
font-family = JetBrains Mono Nerd Font
font-size = 14

# Window
window-padding-x = 8
window-padding-y = 4
window-decoration = false
macos-titlebar-style = hidden

# Cursor
cursor-style = block
cursor-style-blink = true

# Mouse
mouse-hide-while-typing = true

# Shell
shell-integration = zsh

# Keybindings for splits (Ghostty native tiling)
keybind = super+d=new_split:right
keybind = super+shift+d=new_split:down
keybind = super+w=close_surface
keybind = super+alt+left=goto_split:left
keybind = super+alt+right=goto_split:right
keybind = super+alt+up=goto_split:top
keybind = super+alt+down=goto_split:bottom

# Quick-launch keybindings
# Cmd+Shift+F opens yazi in a new split
keybind = super+shift+f=new_split:right:yazi
# Cmd+Shift+M opens btop in a new split
keybind = super+shift+m=new_split:right:btop
```

Note: Verify Ghostty's actual keybind syntax for launching commands in splits. The above may need adjustment — check `ghostty +show-config` or docs.

## 2. Shell Macros (`~/.zshrc` additions)

Add these to the END of `~/.zshrc`:

```zsh
# ── strate-os shell integration ──────────────────────────

export EDITOR="hx"
export VISUAL="hx"
export STRATE_OS_SOUND_PROFILE="${STRATE_OS_SOUND_PROFILE:-mechanical}"
export STRATE_OS_DIR="$HOME/.config/strate-os"

# ── Macros ────────────────────────────────────────────────

function :help() {
    echo "\033[36m┌──────────────────────────────────────────┐\033[0m"
    echo "\033[36m│  strate-os macros                        │\033[0m"
    echo "\033[36m├──────────────────────────────────────────┤\033[0m"
    echo "\033[36m│  :settings  — edit strate-os config      │\033[0m"
    echo "\033[36m│  :ghostty   — edit ghostty config        │\033[0m"
    echo "\033[36m│  :zsh       — edit zshrc                 │\033[0m"
    echo "\033[36m│  :edit      — open helix editor          │\033[0m"
    echo "\033[36m│  :files     — launch yazi file browser   │\033[0m"
    echo "\033[36m│  :monitor   — launch btop monitor        │\033[0m"
    echo "\033[36m│  :fetch     — show system info           │\033[0m"
    echo "\033[36m│  :sounds    — list sound profiles        │\033[0m"
    echo "\033[36m│  :sound X   — switch sound profile       │\033[0m"
    echo "\033[36m│  :reload    — reload zshrc               │\033[0m"
    echo "\033[36m│  :help      — show this help             │\033[0m"
    echo "\033[36m└──────────────────────────────────────────┘\033[0m"
}

function :settings() { $EDITOR "$STRATE_OS_DIR/settings.json"; }
function :ghostty()  { $EDITOR "$HOME/.config/ghostty/config"; }
function :zsh()      { $EDITOR "$HOME/.zshrc"; }
function :edit()     { $EDITOR "$@"; }
function :files()    { yazi "$@"; }
function :monitor()  { btop; }
function :fetch()    { fastfetch; }
function :reload()   { source "$HOME/.zshrc" && echo "\033[36m>>> zshrc reloaded\033[0m"; }

function :sounds() {
    local current="$STRATE_OS_SOUND_PROFILE"
    echo "\033[36mSound Profiles:\033[0m"
    for d in "$STRATE_OS_DIR/sounds/profiles"/*/; do
        local name="$(basename "$d")"
        if [[ "$name" == "$current" ]]; then
            echo "  \033[32m●\033[0m $name (active)"
        else
            echo "  ○ $name"
        fi
    done
}

function :sound() {
    if [[ -z "$1" ]]; then :sounds; return; fi
    if [[ -d "$STRATE_OS_DIR/sounds/profiles/$1" ]]; then
        export STRATE_OS_SOUND_PROFILE="$1"
        echo "\033[36m>>> Sound profile: $1\033[0m"
    else
        echo "\033[31m>>> Unknown profile: $1\033[0m"
    fi
}

# ── Typing sounds (macOS only) ────────────────────────────
# Plays a subtle sound on each command execution
if [[ "$STRATE_OS_SOUND_PROFILE" != "none" ]]; then
    _strate_sound="$STRATE_OS_DIR/sounds/profiles/$STRATE_OS_SOUND_PROFILE/keyboard.wav"
    if [[ -f "$_strate_sound" ]]; then
        preexec() { afplay "$_strate_sound" &>/dev/null & }
    fi
fi
```

## 3. Claude Code + tmux Launcher (`~/.local/bin/cc`)

```bash
#!/usr/bin/env bash
# Launch Claude Code inside tmux for multi-agent support
set -euo pipefail

SESSION="claude-${PWD##*/}"  # Session name based on current directory

# If already in tmux, just run claude
if [[ -n "${TMUX:-}" ]]; then
    exec claude "$@"
fi

# Check for existing session
if tmux has-session -t "$SESSION" 2>/dev/null; then
    exec tmux attach-session -t "$SESSION"
fi

# Create new tmux session with claude
exec tmux new-session -s "$SESSION" "claude $*"
```

Make executable: `chmod +x ~/.local/bin/cc`

This gives Claude Code a tmux session automatically. Claude can then split panes for multi-agent work. The session name is based on the directory, so you can have multiple Claude sessions for different projects.

## 4. Sound Profiles

Copy the generated WAV files to `~/.config/strate-os/sounds/profiles/`. Each profile has a `keyboard.wav` file:

| Profile | Character |
|---------|-----------|
| soft | Quiet muted thuds |
| typewriter | Classic typewriter clacks |
| mechanical | Cherry MX clicks (default) |
| soothing | Gentle musical tones |
| bubbly | Playful bubble pops |
| cyberpunk | Sharp electronic beeps |
| none | Silent (no file needed) |

The sound files already exist in this repo at `sounds/profiles/*/keyboard.wav`.

## 5. strate-os Settings (`~/.config/strate-os/settings.json`)

```json
{
    "layout": "default",
    "soundProfile": "mechanical",
    "editor": "hx",
    "theme": "catppuccin-frappe"
}
```

This file is opened by `:settings`. It's read by the shell config on startup to set defaults.

## 6. Installation

One-time setup:

```bash
# Install dependencies
brew install ghostty tmux helix yazi btop fastfetch

# Install Claude Code
# (follow Anthropic's instructions)

# Create directories
mkdir -p ~/.config/strate-os/sounds/profiles
mkdir -p ~/.local/bin

# Copy sound profiles from this repo
cp -r sounds/profiles/* ~/.config/strate-os/sounds/profiles/

# Copy the cc script
cp cc ~/.local/bin/cc  # (or create it manually per section 3)
chmod +x ~/.local/bin/cc

# Add ~/.local/bin to PATH (if not already)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc

# Add the shell macros from section 2 to ~/.zshrc
# (copy the block manually or use an installer script)

# Set up Ghostty config from section 1
# (copy to ~/.config/ghostty/config)

# Reload
source ~/.zshrc
```

## Summary

| What | How |
|------|-----|
| Terminal emulator | Stock Ghostty |
| Window tiling | Ghostty native splits |
| Theming | Ghostty config (catppuccin-frappe) |
| File browser | yazi (via `:files` or keybind) |
| System monitor | btop (via `:monitor` or keybind) |
| Text editor | Helix (via `$EDITOR`, `:edit`, `:settings`) |
| System info | fastfetch (via `:fetch`) |
| Claude Code | `cc` script (auto-tmux for multi-agent) |
| Shell macros | zsh functions (`:help`, `:files`, etc.) |
| Typing sounds | zsh preexec hook + afplay |
| Config | ~/.config/strate-os/settings.json |

Total footprint: ~200 lines of config across 4 files. Zero custom code, zero compilation, zero Electron.
