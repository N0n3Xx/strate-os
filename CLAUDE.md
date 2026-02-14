# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**strate-os** is a dotfiles collection that transforms a stock Ghostty terminal into a full work environment on macOS. Users pick their tools during an interactive install — editor, file browser, monitor, git TUI, CLI replacements, and more. Everything installs via Homebrew.

## Repo Structure

- `install.sh` — interactive installer: tool selection, brew install, symlinks, shell config
- `uninstall.sh` — removes symlinks, cleans .zshrc, optionally keeps settings
- `ghostty/config` — Ghostty terminal config (theme, font, split keybinds)
- `zsh/strate-os.zsh` — all shell functions and aliases, dynamically reads settings.json
- `views/*.sh` — tmux layout scripts for `:strate` command (each file = one view)
- `bin/cc` — Claude Code + tmux launcher
- `strate-os/settings.json` — template settings (copied to user's config on install)

## Architecture

### Tool Selection System
The installer (`install.sh`) uses `pick_one` (single choice) and `pick_many` (multi-select) helper functions to walk users through categories: editor, file browser, monitor, fetch tool, git TUI, CLI replacements, and extras. Choices are saved to `~/.config/strate-os/settings.json`.

### Dynamic Shell Integration
`zsh/strate-os.zsh` reads `settings.json` via `_strate_setting()` on shell startup. All macros (`:files`, `:monitor`, `:git`, etc.) call the user's chosen tool. CLI replacement aliases (eza, bat, fd, etc.) are only set up if the tool is both installed and listed in `cliTools`.

### Hybrid Layout System
Ghostty handles interactive panes (native splits). `:strate <view>` fills a Ghostty pane with a tmux session running a predefined layout. Views are standalone bash scripts in `views/`.

### Install Flow
`install.sh` walks through tool selection, brews missing packages, symlinks configs into `~/.config/`, copies settings.json (not symlinked — user-editable), and adds one source line to `.zshrc`. Starship and zoxide get their init lines added separately.

## Key Conventions

- Shell macros use colon prefix (`:help`, `:strate`, `:files`, `:git`, etc.)
- `claude` and `cls` are regular commands (no colon)
- Settings are the command name, not the brew package (e.g. `hx` not `helix`, `nvim` not `neovim`)
- `BREW_MAP` and `CMD_MAP` in install.sh map between package names and binary names
- macOS-only (Ghostty for terminal)
