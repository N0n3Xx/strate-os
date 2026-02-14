#!/usr/bin/env bash
# strate-os installer
# Usage: ./install.sh
set -euo pipefail

# ── Colors ───────────────────────────────────────────────
CYAN='\033[36m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Paths ────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config"
STRATE_DIR="$CONFIG_DIR/strate-os"
GHOSTTY_DIR="$CONFIG_DIR/ghostty"
BIN_DIR="$HOME/.local/bin"

# ── Helpers ──────────────────────────────────────────────
info()  { echo -e "${CYAN}>>> $1${RESET}"; }
ok()    { echo -e "${GREEN} ✓  $1${RESET}"; }
warn()  { echo -e "${RED} !  $1${RESET}"; }
dim()   { echo -e "${DIM}    $1${RESET}"; }

link_file() {
    local src="$1" dst="$2"
    if [[ -L "$dst" ]]; then
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        mv "$dst" "${dst}.bak"
        dim "Backed up existing $(basename "$dst") → $(basename "$dst").bak"
    fi
    ln -s "$src" "$dst"
}

# Prompt user to pick one option from a list
# Usage: pick_one "VARNAME" "default" "label1:value1:desc1" "label2:value2:desc2" ...
# pick_one sets PICK_RESULT with the chosen value
# Loops until valid input is given. Accepts number, empty (default), or y/yes/n/no for 2-option lists.
PICK_RESULT=""
pick_one() {
    local default="$1"
    shift
    local options=("$@")
    local max=${#options[@]}

    # Display options
    local i=1
    for opt in "${options[@]}"; do
        IFS=':' read -r label value desc <<< "$opt"
        local marker=""
        if [[ "$value" == "$default" ]]; then
            marker=" ${DIM}(default)${RESET}"
        fi
        echo -e "  ${CYAN}${i})${RESET} ${label}${marker}  ${DIM}${desc}${RESET}"
        i=$((i + 1))
    done
    echo ""

    # Find default index
    local default_idx=1
    i=1
    for opt in "${options[@]}"; do
        IFS=':' read -r _ value _ <<< "$opt"
        if [[ "$value" == "$default" ]]; then
            default_idx=$i
        fi
        i=$((i + 1))
    done

    # Input loop
    while true; do
        read -rp "$(echo -e "${CYAN}Choose [1-${max}]:${RESET} ")" choice

        # Empty = default
        if [[ -z "${choice:-}" ]]; then
            IFS=':' read -r _ value _ <<< "${options[$((default_idx-1))]}"
            PICK_RESULT="$value"
            echo ""
            return
        fi

        # y/yes/n/no for 2-option yes/no lists
        if [[ $max -eq 2 ]]; then
            local lower
            lower="$(echo "$choice" | tr '[:upper:]' '[:lower:]')"
            if [[ "$lower" == "y" || "$lower" == "yes" ]]; then
                IFS=':' read -r _ value _ <<< "${options[0]}"
                PICK_RESULT="$value"
                echo ""
                return
            fi
            if [[ "$lower" == "n" || "$lower" == "no" ]]; then
                IFS=':' read -r _ value _ <<< "${options[1]}"
                PICK_RESULT="$value"
                echo ""
                return
            fi
        fi

        # Numeric choice
        if [[ "$choice" -ge 1 && "$choice" -le "$max" ]] 2>/dev/null; then
            IFS=':' read -r _ value _ <<< "${options[$((choice-1))]}"
            PICK_RESULT="$value"
            echo ""
            return
        fi

        # Invalid
        echo -e "  ${RED}Invalid choice. Enter a number between 1 and ${max}.${RESET}"
    done
}

# Prompt user to toggle multiple options (space-separated numbers)
# Usage: pick_many "VARNAME" "label1:value1:brew1:desc1" ...
# Pre-selected items have a + prefix on the value: "label:+value:brew:desc"
# pick_many sets PICK_RESULT with space-separated chosen values
pick_many() {
    local options=("$@")
    local i=1
    local selected=()

    # Show options
    for opt in "${options[@]}"; do
        IFS=':' read -r label value brew desc <<< "$opt"
        local marker=""
        if [[ "$value" == +* ]]; then
            marker=" ${GREEN}●${RESET}"
            value="${value#+}"
        fi
        echo -e "  ${CYAN}${i})${RESET} ${label}${marker}  ${DIM}${desc}${RESET}"
        i=$((i + 1))
    done
    local max=${#options[@]}
    echo ""
    echo -e "  ${DIM}Enter numbers separated by spaces, 'all', 'none', or press Enter for defaults${RESET}"

    while true; do
        read -rp "$(echo -e "${CYAN}Choose:${RESET} ")" choices

        # Empty = pick pre-selected defaults
        if [[ -z "${choices:-}" ]]; then
            for opt in "${options[@]}"; do
                IFS=':' read -r _ value _ _ <<< "$opt"
                if [[ "$value" == +* ]]; then
                    selected+=("${value#+}")
                fi
            done
            break
        fi

        if [[ "$choices" == "all" ]]; then
            for opt in "${options[@]}"; do
                IFS=':' read -r _ value brew _ <<< "$opt"
                value="${value#+}"
                selected+=("$value")
            done
            break
        fi

        if [[ "$choices" == "none" ]]; then
            break
        fi

        # Validate all numbers before accepting
        local valid=1
        for c in $choices; do
            if ! [[ "$c" -ge 1 && "$c" -le "$max" ]] 2>/dev/null; then
                echo -e "  ${RED}Invalid: '$c' is not between 1 and ${max}.${RESET}"
                valid=0
                break
            fi
        done

        if [[ $valid -eq 1 ]]; then
            for c in $choices; do
                IFS=':' read -r _ value brew _ <<< "${options[$((c-1))]}"
                value="${value#+}"
                selected+=("$value")
            done
            break
        fi
    done

    PICK_RESULT="${selected[*]+"${selected[*]}"}"
    echo ""
}

# ── Banner ───────────────────────────────────────────────
echo ""
echo -e "${CYAN}┌──────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}│         strate-os installer               │${RESET}"
echo -e "${CYAN}│  Turn Ghostty into a full work env        │${RESET}"
echo -e "${CYAN}└──────────────────────────────────────────┘${RESET}"
echo ""

# ══════════════════════════════════════════════════════════
# SECTION 0: APPEARANCE
# ══════════════════════════════════════════════════════════

info "APPEARANCE — theme & font"
echo ""

# ── Theme ────────────────────────────────────────────────
echo -e "${BOLD}Color Theme${RESET}  ${DIM}(applied to Ghostty, bat, delta, btop)${RESET}"
pick_one "catppuccin frappe" \
    "Catppuccin Frappe:catppuccin frappe:Pastel dark, warm blue tones" \
    "Catppuccin Mocha:catppuccin mocha:Rich dark, deep purple tones" \
    "Catppuccin Latte:catppuccin latte:Light, creamy pastels" \
    "Catppuccin Macchiato:catppuccin macchiato:Dark, muted warm tones" \
    "Tokyo Night:tokyonight:Dark blue with neon accents" \
    "Gruvbox Dark:GruvboxDark:Retro earthy dark colors" \
    "Dracula:Dracula:Classic dark with vivid accents" \
    "Nord:nord:Arctic, cool blue palette"
THEME="$PICK_RESULT"
ok "Theme: $THEME"

# ── Font ─────────────────────────────────────────────────
echo -e "${BOLD}Font${RESET}  ${DIM}(Nerd Font recommended for icons)${RESET}"
pick_one "JetBrains Mono Nerd Font" \
    "JetBrains Mono:JetBrains Mono Nerd Font:Clean, great for code" \
    "FiraCode:FiraCode Nerd Font:Popular with ligatures" \
    "Hack:Hack Nerd Font:Designed for source code" \
    "CaskaydiaCove:CaskaydiaCove Nerd Font:Microsoft's Cascadia Code" \
    "MesloLGS:MesloLGS Nerd Font:Apple Menlo derivative"
FONT="$PICK_RESULT"
ok "Font: $FONT"

echo -e "${BOLD}Font Size${RESET}"
read -rp "$(echo -e "${CYAN}Size [default: 14]:${RESET} ")" FONT_SIZE
FONT_SIZE="${FONT_SIZE:-14}"
ok "Font size: $FONT_SIZE"
echo ""

# ── Window ───────────────────────────────────────────────
echo -e "${BOLD}Background Opacity${RESET}  ${DIM}(0.0 = fully transparent, 1.0 = solid)${RESET}"
read -rp "$(echo -e "${CYAN}Opacity [default: 0.8]:${RESET} ")" BG_OPACITY
BG_OPACITY="${BG_OPACITY:-0.8}"
ok "Opacity: $BG_OPACITY"
echo ""

echo -e "${BOLD}Background Blur Radius${RESET}  ${DIM}(0 = no blur, 20 = nice frosted glass)${RESET}"
read -rp "$(echo -e "${CYAN}Blur [default: 20]:${RESET} ")" BG_BLUR
BG_BLUR="${BG_BLUR:-20}"
ok "Blur: $BG_BLUR"
echo ""

echo -e "${BOLD}Window Decorations${RESET}  ${DIM}(title bar and window frame)${RESET}"
pick_one "true" \
    "Yes:true:Show title bar and frame" \
    "No:false:Borderless, clean look"
WIN_DECORATION="$PICK_RESULT"
ok "Window decorations: $WIN_DECORATION"

echo -e "${BOLD}Hide Mouse While Typing${RESET}"
pick_one "true" \
    "Yes:true:Mouse cursor disappears when typing" \
    "No:false:Mouse cursor always visible"
MOUSE_HIDE="$PICK_RESULT"
ok "Hide mouse: $MOUSE_HIDE"

# ══════════════════════════════════════════════════════════
# SECTION 1: CORE TOOLS (pick one per category)
# ══════════════════════════════════════════════════════════

info "CORE TOOLS — pick one per category"
echo ""

# ── Text Editor ──────────────────────────────────────────
echo -e "${BOLD}Text Editor${RESET}"
pick_one "helix" \
    "Helix:helix:Post-modern modal editor, built-in LSP" \
    "Neovim:neovim:Extensible Vim fork, huge plugin ecosystem" \
    "Vim:vim:Classic modal editor, universal" \
    "Micro:micro:Modern intuitive editor, easy keybindings" \
    "Nano:nano:Simple beginner-friendly editor"
EDITOR_TOOL="$PICK_RESULT"
ok "Editor: $EDITOR_TOOL"

# ── File Browser ─────────────────────────────────────────
echo -e "${BOLD}File Browser${RESET}"
pick_one "yazi" \
    "Yazi:yazi:Blazing fast, async I/O, image preview" \
    "Ranger:ranger:Vi keybindings, Python plugins" \
    "nnn:nnn:Tiny and efficient, minimal footprint" \
    "lf:lf:Minimal, inspired by Ranger, written in Go" \
    "Midnight Commander:midnight-commander:Classic two-panel file manager" \
    "Superfile:superfile:Modern Go file manager, rich UI"
FILE_BROWSER="$PICK_RESULT"
ok "File browser: $FILE_BROWSER"

# ── Process Monitor ──────────────────────────────────────
echo -e "${BOLD}Process Monitor${RESET}"
pick_one "btop" \
    "btop:btop:Modern, mouse support, GPU monitoring" \
    "htop:htop:Classic interactive process viewer" \
    "bottom:bottom:Rust-based, customizable widgets"
MONITOR_TOOL="$PICK_RESULT"
ok "Monitor: $MONITOR_TOOL"

# ── System Fetch ─────────────────────────────────────────
echo -e "${BOLD}System Fetch (used by 'cls')${RESET}"
pick_one "fastfetch" \
    "Fastfetch:fastfetch:Fast and detailed, C-based" \
    "Neofetch:neofetch:Classic, widely known" \
    "Macchina:macchina:Minimal, performance focused"
FETCH_TOOL="$PICK_RESULT"
ok "Fetch: $FETCH_TOOL"

# ── Git TUI ──────────────────────────────────────────────
echo -e "${BOLD}Git TUI${RESET}"
pick_one "lazygit" \
    "Lazygit:lazygit:Simple terminal UI for git" \
    "GitUI:gitui:Fast Rust-based git TUI" \
    "Tig:tig:Text-mode git interface and browser" \
    "None:none:Skip — use git CLI only"
GIT_TUI="$PICK_RESULT"
ok "Git TUI: $GIT_TUI"

# ══════════════════════════════════════════════════════════
# SECTION 2: MODERN CLI REPLACEMENTS (multi-select)
# ══════════════════════════════════════════════════════════

echo ""
info "MODERN CLI REPLACEMENTS — supercharge your commands"
echo ""

echo -e "${BOLD}Select tools to install${RESET}  ${DIM}(● = recommended)${RESET}"
pick_many \
    "eza:+eza:eza:Modern ls with icons, colors, git" \
    "bat:+bat:bat:cat with syntax highlighting and line numbers" \
    "fd:+fd:fd:Intuitive find alternative" \
    "ripgrep:+ripgrep:ripgrep:Blazing fast grep replacement" \
    "delta:+delta:delta:Beautiful git diff pager" \
    "zoxide:+zoxide:zoxide:Smarter cd, learns your directories" \
    "dust:dust:dust:Visual disk usage (du replacement)" \
    "sd:sd:sd:Intuitive sed replacement" \
    "ncdu:ncdu:ncdu:Interactive disk usage explorer"
CLI_TOOLS="$PICK_RESULT"

if [[ -n "$CLI_TOOLS" ]]; then
    ok "CLI tools: $CLI_TOOLS"
else
    ok "CLI tools: none"
fi

# ══════════════════════════════════════════════════════════
# SECTION 3: EXTRAS (multi-select)
# ══════════════════════════════════════════════════════════

echo ""
info "EXTRAS — optional power tools"
echo ""

echo -e "${BOLD}Shell & Productivity${RESET}"
pick_many \
    "Starship:starship:starship:Fast cross-shell prompt with git info" \
    "Lazydocker:lazydocker:lazydocker:Docker & compose TUI" \
    "jq:jq:jq:JSON processor and query tool" \
    "fx:fx:fx:Interactive JSON viewer" \
    "gping:gping:gping:Graphical ping with live chart" \
    "bandwhich:bandwhich:bandwhich:Network bandwidth monitor" \
    "trippy:trippy:trippy:Visual traceroute tool"
EXTRAS="$PICK_RESULT"

if [[ -n "$EXTRAS" ]]; then
    ok "Extras: $EXTRAS"
else
    ok "Extras: none"
fi

# ══════════════════════════════════════════════════════════
# INSTALL
# ══════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
info "Installing..."
echo ""

# ── Homebrew check ───────────────────────────────────────
if ! command -v brew &>/dev/null; then
    warn "Homebrew not found. Install it from https://brew.sh"
    exit 1
fi

# ── Build package list ───────────────────────────────────
BREW_PACKAGES=(tmux)

# Map tool names to brew packages (only where they differ)
brew_pkg_for() {
    case "$1" in
        delta) echo "git-delta" ;;
        *)     echo "$1" ;;
    esac
}

# Map tool names to commands (only where they differ)
cmd_for() {
    case "$1" in
        helix)               echo "hx" ;;
        neovim)              echo "nvim" ;;
        midnight-commander)  echo "mc" ;;
        bottom)              echo "btm" ;;
        ripgrep)             echo "rg" ;;
        *)                   echo "$1" ;;
    esac
}

# Core tools
BREW_PACKAGES+=("$EDITOR_TOOL" "$FILE_BROWSER" "$MONITOR_TOOL" "$FETCH_TOOL")
if [[ "$GIT_TUI" != "none" ]]; then
    BREW_PACKAGES+=("$GIT_TUI")
fi

# CLI replacements
for tool in $CLI_TOOLS; do
    BREW_PACKAGES+=("$tool")
done

# Extras
for tool in $EXTRAS; do
    BREW_PACKAGES+=("$tool")
done

# Deduplicate and find what needs installing
MISSING=()
for pkg in "${BREW_PACKAGES[@]}"; do
    local_cmd="$(cmd_for "$pkg")"
    brew_pkg="$(brew_pkg_for "$pkg")"
    if ! command -v "$local_cmd" &>/dev/null; then
        # Avoid duplicates
        dup=0
        for m in "${MISSING[@]+"${MISSING[@]}"}"; do
            if [[ "$m" == "$brew_pkg" ]]; then
                dup=1
            fi
        done
        if [[ $dup -eq 0 ]]; then
            MISSING+=("$brew_pkg")
        fi
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    info "Installing ${#MISSING[@]} packages: ${MISSING[*]}"
    brew install "${MISSING[@]}"
    ok "Packages installed"
else
    ok "All packages present"
fi

# ── Directories ──────────────────────────────────────────
info "Setting up directories..."
mkdir -p "$STRATE_DIR/shell"
mkdir -p "$STRATE_DIR/views"
mkdir -p "$GHOSTTY_DIR"
mkdir -p "$BIN_DIR"

# ── Symlinks ─────────────────────────────────────────────
info "Linking config files..."

# Ghostty config is generated later with user's theme/font choices

link_file "$REPO_DIR/zsh/strate-os.zsh" "$STRATE_DIR/shell/strate-os.zsh"
ok "Shell integration"

# Settings — copy (not symlink) so each user gets their own
if [[ ! -f "$STRATE_DIR/settings.json" ]]; then
    cp "$REPO_DIR/strate-os/settings.json" "$STRATE_DIR/settings.json"
fi

# Views
for view in "$REPO_DIR"/views/*.sh; do
    [[ -f "$view" ]] || continue
    link_file "$view" "$STRATE_DIR/views/$(basename "$view")"
done
ok "Views"

# Bin scripts
link_file "$REPO_DIR/bin/cc" "$BIN_DIR/cc"
chmod +x "$BIN_DIR/cc"
ok "cc launcher"

# ── Write settings ───────────────────────────────────────
info "Saving preferences..."

# Resolve editor command
EDITOR_CMD="$(cmd_for "$EDITOR_TOOL")"
FILE_BROWSER_CMD="$(cmd_for "$FILE_BROWSER")"
MONITOR_CMD="$(cmd_for "$MONITOR_TOOL")"
GIT_TUI_CMD="none"
if [[ "$GIT_TUI" != "none" ]]; then
    GIT_TUI_CMD="$(cmd_for "$GIT_TUI")"
fi

cat > "$STRATE_DIR/settings.json" << SETTINGS
{
    "editor": "$EDITOR_CMD",
    "fileBrowser": "$FILE_BROWSER_CMD",
    "monitor": "$MONITOR_CMD",
    "fetchTool": "$FETCH_TOOL",
    "gitTui": "$GIT_TUI_CMD",
    "cliTools": "$CLI_TOOLS",
    "extras": "$EXTRAS",
    "theme": "$THEME",
    "font": "$FONT",
    "fontSize": "$FONT_SIZE",
    "backgroundOpacity": "$BG_OPACITY",
    "backgroundBlur": "$BG_BLUR",
    "windowDecoration": "$WIN_DECORATION",
    "mouseHideWhileTyping": "$MOUSE_HIDE"
}
SETTINGS

ok "Settings saved"

# ── Apply theme to Ghostty config ────────────────────────
info "Applying theme..."

# Back up existing Ghostty config if it's not ours
if [[ -f "$GHOSTTY_DIR/config" ]] && ! grep -q "strate-os" "$GHOSTTY_DIR/config" 2>/dev/null; then
    mv "$GHOSTTY_DIR/config" "$GHOSTTY_DIR/config.bak"
    dim "Backed up existing Ghostty config → config.bak"
fi

# Generate Ghostty config with user's theme and font
cat > "$GHOSTTY_DIR/config" << GHOSTTYCONF
# ── strate-os Ghostty Config (generated) ─────────────────

# Theme
theme = $THEME

# Font
font-family = $FONT
font-size = $FONT_SIZE

# Window
background-opacity = $BG_OPACITY
background-blur-radius = $BG_BLUR
window-decoration = $WIN_DECORATION
window-padding-x = 8
window-padding-y = 4

# Cursor
cursor-style = block
cursor-style-blink = true

# Mouse
mouse-hide-while-typing = $MOUSE_HIDE

# Shell
shell-integration = zsh

# ── Splits (Ghostty native tiling) ───────────────────────
keybind = super+d=new_split:right
keybind = super+shift+d=new_split:down
keybind = super+w=close_surface
keybind = super+alt+left=goto_split:left
keybind = super+alt+right=goto_split:right
keybind = super+alt+up=goto_split:top
keybind = super+alt+down=goto_split:bottom
GHOSTTYCONF

ok "Ghostty config"

# Configure bat theme (if installed)
if command -v bat &>/dev/null && [[ " $CLI_TOOLS " == *" bat "* ]]; then
    # Map strate-os themes to bat themes
    case "$THEME" in
        "catppuccin frappe")    BAT_THEME="Catppuccin Frappe" ;;
        "catppuccin mocha")     BAT_THEME="Catppuccin Mocha" ;;
        "catppuccin latte")     BAT_THEME="Catppuccin Latte" ;;
        "catppuccin macchiato") BAT_THEME="Catppuccin Macchiato" ;;
        tokyonight)           BAT_THEME="tokyonight_night" ;;
        GruvboxDark)          BAT_THEME="gruvbox-dark" ;;
        Dracula)              BAT_THEME="Dracula" ;;
        nord)                 BAT_THEME="Nord" ;;
        *)                    BAT_THEME="base16" ;;
    esac
    mkdir -p "$HOME/.config/bat"
    echo "--theme=\"$BAT_THEME\"" > "$HOME/.config/bat/config"
    ok "bat theme"
fi

# Configure delta theme (if installed)
if command -v delta &>/dev/null && [[ " $CLI_TOOLS " == *" delta "* ]]; then
    case "$THEME" in
        "catppuccin frappe")    DELTA_THEME="Catppuccin Frappe" ;;
        "catppuccin mocha")     DELTA_THEME="Catppuccin Mocha" ;;
        "catppuccin latte")     DELTA_THEME="Catppuccin Latte" ;;
        "catppuccin macchiato") DELTA_THEME="Catppuccin Macchiato" ;;
        Dracula)              DELTA_THEME="Dracula" ;;
        nord)                 DELTA_THEME="Nord" ;;
        *)                    DELTA_THEME="" ;;
    esac
    if [[ -n "$DELTA_THEME" ]]; then
        git config --global delta.syntax-theme "$DELTA_THEME" 2>/dev/null || true
        ok "delta theme"
    fi
fi

# ── Shell config (.zshrc) ───────────────────────────────
info "Configuring shell..."

SOURCE_LINE='[[ -f "$HOME/.config/strate-os/shell/strate-os.zsh" ]] && source "$HOME/.config/strate-os/shell/strate-os.zsh"'

if ! grep -qF "strate-os.zsh" "$HOME/.zshrc" 2>/dev/null; then
    echo "" >> "$HOME/.zshrc"
    echo "# strate-os" >> "$HOME/.zshrc"
    echo "$SOURCE_LINE" >> "$HOME/.zshrc"
    ok "Added source line to .zshrc"
else
    ok ".zshrc already configured"
fi

# PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qF "$BIN_DIR"; then
    if ! grep -qF '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
        ok "Added ~/.local/bin to PATH"
    fi
fi

# Starship init
if [[ " $EXTRAS " == *" starship "* ]]; then
    if ! grep -qF "starship init" "$HOME/.zshrc" 2>/dev/null; then
        echo "" >> "$HOME/.zshrc"
        echo "# starship prompt (strate-os)" >> "$HOME/.zshrc"
        echo 'eval "$(starship init zsh)"' >> "$HOME/.zshrc"
        ok "Starship prompt enabled"
    fi
fi

# Zoxide init
if [[ " $CLI_TOOLS " == *" zoxide "* ]]; then
    if ! grep -qF "zoxide init" "$HOME/.zshrc" 2>/dev/null; then
        echo "" >> "$HOME/.zshrc"
        echo "# zoxide (strate-os)" >> "$HOME/.zshrc"
        echo 'eval "$(zoxide init zsh)"' >> "$HOME/.zshrc"
        ok "Zoxide enabled (use 'z' to jump to directories)"
    fi
fi

# ── Done ─────────────────────────────────────────────────
echo ""
echo -e "${GREEN}┌──────────────────────────────────────────────┐${RESET}"
echo -e "${GREEN}│           strate-os installed!                │${RESET}"
echo -e "${GREEN}├──────────────────────────────────────────────┤${RESET}"
echo -e "${GREEN}│                                              │${RESET}"
echo -e "${GREEN}│  Reload your shell:                          │${RESET}"
echo -e "${GREEN}│    source ~/.zshrc                           │${RESET}"
echo -e "${GREEN}│                                              │${RESET}"
echo -e "${GREEN}│  Quick start:                                │${RESET}"
echo -e "${GREEN}│    :help        — see all commands           │${RESET}"
echo -e "${GREEN}│    cls          — clear + system info        │${RESET}"
echo -e "${GREEN}│    claude       — Claude Code in tmux        │${RESET}"
echo -e "${GREEN}│    :files       — file browser               │${RESET}"
echo -e "${GREEN}│    :strate      — list tmux views            │${RESET}"
echo -e "${GREEN}│                                              │${RESET}"
echo -e "${GREEN}│  Config:        :settings                    │${RESET}"
echo -e "${GREEN}│  Reconfigure:   ./install.sh                 │${RESET}"
echo -e "${GREEN}└──────────────────────────────────────────────┘${RESET}"
echo ""
