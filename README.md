# strate-os

Dotfiles that transform a stock [Ghostty](https://ghostty.org) terminal into a full work environment. No terminal emulator, just config files, shell scripts, and your choice of CLI/TUI tools.

## What You Get

The installer walks you through picking tools for every category:

| Category | Options |
|----------|---------|
| Text Editor | Helix (default), Neovim, Vim, Micro, Nano |
| File Browser | Yazi (default), Ranger, nnn, lf, Midnight Commander, Superfile |
| Process Monitor | btop (default), htop, bottom |
| System Fetch | Fastfetch (default), Neofetch, Macchina |
| Git TUI | Lazygit (default), GitUI, Tig, or none |
| CLI Replacements | eza, bat, fd, ripgrep, delta, zoxide, dust, sd, ncdu |
| Extras | Starship prompt, Lazydocker, jq, fx, gping, bandwhich, trippy |
Everything is installed via Homebrew. Re-run `./install.sh` any time to change your picks.

## The Hybrid Layout System

strate-os uses a **hybrid Ghostty + tmux** approach:

- **Ghostty** handles your interactive panes — split freely with `Cmd+D` (right) and `Cmd+Shift+D` (down)
- **`:strate <view>`** fills any pane with a tmux-powered dashboard you don't need to interact with

```
┌─────────────────────┬──────────────────────┐
│                     │ :strate sysmonitor   │
│   your shell        │┌────────────────────┐│
│                     ││ btop               ││
│                     │├────────────────────┤│
│                     ││ fastfetch          ││
│                     │└────────────────────┘│
├─────────────────────┤                      │
│                     │                      │
│   your other shell  │                      │
│                     │                      │
└─────────────────────┴──────────────────────┘
      Ghostty splits        tmux inside pane
```

Ghostty = what you interact with. tmux = passive display widgets.

## Install

```bash
git clone https://github.com/YOUR_USERNAME/strate-os.git ~/.strate-os
cd ~/.strate-os
./install.sh
source ~/.zshrc
```

The interactive installer will:
1. Let you pick a tool for each category (editor, file browser, monitor, etc.)
2. Let you select modern CLI replacements (eza, bat, fd, ripgrep, etc.)
3. Let you pick optional extras (starship, lazydocker, network tools)
4. Install everything via Homebrew
5. Symlink configs and add shell integration

## Keybindings

| Key | Action |
|-----|--------|
| `Cmd+D` | Split right |
| `Cmd+Shift+D` | Split down |
| `Cmd+W` | Close pane |
| `Cmd+Alt+Arrow` | Navigate between panes |

## Commands

| Command | Action |
|---------|--------|
| `claude` | Launch Claude Code in tmux with `--dangerously-skip-permissions` |
| `cls` | Clear screen + show system info |

## Shell Macros

Type `:help` to see all commands:

| Command | Action |
|---------|--------|
| `:strate <view>` | Launch a tmux view in current pane |
| `:settings` | Edit strate-os config |
| `:ghostty` | Edit Ghostty config |
| `:zsh` | Edit .zshrc |
| `:edit <file>` | Open your chosen editor |
| `:files` | Open your chosen file browser |
| `:monitor` | Open your chosen process monitor |
| `:git` | Open your chosen git TUI |
| `:fetch` | Show system info |
| `:reload` | Reload shell config |

## CLI Aliases

When you install modern CLI replacements, strate-os sets up aliases automatically:

| If installed | Aliases created |
|-------------|-----------------|
| **eza** | `ls` `la` `ll` `lt` `lla` — all with icons and colors |
| **bat** | `cat` (no pager), `catp` (with pager) |
| **fd** | `find` |
| **ripgrep** | `grep` |
| **dust** | `du` |
| **delta** | Auto-configured as `GIT_PAGER` |
| **zoxide** | `z` command for smart directory jumping |

## Views

| View | Layout |
|------|--------|
| `sysmonitor` | btop (top) + fastfetch (bottom) |

Create your own: add a script to `views/` and reinstall.

## Configuration

Edit preferences any time with `:settings`. The config lives at `~/.config/strate-os/settings.json`:

```json
{
    "editor": "hx",
    "fileBrowser": "yazi",
    "monitor": "btop",
    "fetchTool": "fastfetch",
    "gitTui": "lazygit",
    "cliTools": "eza bat fd ripgrep delta zoxide",
    "extras": "starship jq",
    "theme": "catppuccin frappe"
}
```

Changes take effect after `:reload`.

## Uninstall

```bash
cd ~/.strate-os
./uninstall.sh
```

Removes symlinks and shell integration. Optionally keeps your settings. Brew packages are left installed.

## Requirements

- macOS (Ghostty for terminal)
- [Homebrew](https://brew.sh)
- [JetBrains Mono Nerd Font](https://www.nerdfonts.com/font-downloads)
