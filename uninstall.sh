#!/usr/bin/env bash
# strate-os uninstaller
# Removes symlinks, shell integration, and config.
# Does not uninstall brew packages.
set -euo pipefail

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
DIM='\033[2m'
RESET='\033[0m'

STRATE_DIR="$HOME/.config/strate-os"
GHOSTTY_CONFIG="$HOME/.config/ghostty/config"
BIN_DIR="$HOME/.local/bin"

info()  { echo -e "${CYAN}>>> $1${RESET}"; }
ok()    { echo -e "${GREEN} ✓  $1${RESET}"; }
dim()   { echo -e "${DIM}    $1${RESET}"; }

remove_link() {
    local path="$1"
    if [[ -L "$path" ]]; then
        rm "$path"
        if [[ -e "${path}.bak" ]]; then
            mv "${path}.bak" "$path"
            dim "Restored $(basename "$path") from backup"
        fi
        return 0
    fi
    return 1
}

echo ""
echo -e "${CYAN}┌──────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}│         strate-os uninstaller             │${RESET}"
echo -e "${CYAN}└──────────────────────────────────────────┘${RESET}"
echo ""

# ── Confirm ──────────────────────────────────────────────
read -rp "$(echo -e "${YELLOW}Remove strate-os? [y/N]:${RESET} ")" confirm
if [[ "${confirm,,}" != "y" ]]; then
    echo "Cancelled."
    exit 0
fi
echo ""

# ── Remove symlinks ──────────────────────────────────────
info "Removing symlinks..."

# Ghostty config may be generated (not symlinked)
if [[ -L "$GHOSTTY_CONFIG" ]]; then
    remove_link "$GHOSTTY_CONFIG" && ok "Ghostty config (symlink)"
elif [[ -f "$GHOSTTY_CONFIG" ]]; then
    if grep -q "strate-os" "$GHOSTTY_CONFIG" 2>/dev/null; then
        rm "$GHOSTTY_CONFIG"
        if [[ -e "${GHOSTTY_CONFIG}.bak" ]]; then
            mv "${GHOSTTY_CONFIG}.bak" "$GHOSTTY_CONFIG"
            dim "Restored Ghostty config from backup"
        fi
        ok "Ghostty config (generated)"
    fi
fi
remove_link "$BIN_DIR/cc" && ok "cc launcher"

if [[ -d "$STRATE_DIR" ]]; then
    remove_link "$STRATE_DIR/shell/strate-os.zsh" 2>/dev/null
    for f in "$STRATE_DIR"/views/*.sh; do
        [[ -L "$f" ]] && rm "$f"
    done
    ok "strate-os symlinks"
fi

# ── Ask about settings ───────────────────────────────────
if [[ -f "$STRATE_DIR/settings.json" ]]; then
    echo ""
    read -rp "$(echo -e "${YELLOW}Delete your settings.json? [y/N]:${RESET} ")" del_settings
    if [[ "$(echo "$del_settings" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
        rm "$STRATE_DIR/settings.json"
        ok "Deleted settings.json"
    else
        dim "Kept settings.json at $STRATE_DIR/settings.json"
    fi
fi

# ── Clean tool configs ────────────────────────────────────
if [[ -f "$HOME/.config/bat/config" ]]; then
    rm "$HOME/.config/bat/config"
    ok "bat config"
fi
git config --global --unset delta.syntax-theme 2>/dev/null || true

# ── Clean .zshrc ─────────────────────────────────────────
info "Cleaning .zshrc..."

if [[ -f "$HOME/.zshrc" ]]; then
    sed -i '' '/# strate-os/d' "$HOME/.zshrc"
    sed -i '' '/strate-os\.zsh/d' "$HOME/.zshrc"
    sed -i '' '/# starship prompt (strate-os)/d' "$HOME/.zshrc"
    sed -i '' '/starship init zsh/d' "$HOME/.zshrc"
    sed -i '' '/# zoxide (strate-os)/d' "$HOME/.zshrc"
    sed -i '' '/zoxide init zsh/d' "$HOME/.zshrc"
    ok "Removed strate-os from .zshrc"
fi

# ── Clean up empty dirs ──────────────────────────────────
rmdir "$STRATE_DIR/shell" 2>/dev/null || true
rmdir "$STRATE_DIR/views" 2>/dev/null || true

# ── Installed packages ───────────────────────────────────
echo ""
echo -e "${GREEN}strate-os uninstalled.${RESET}"
echo ""
echo -e "${DIM}Brew packages were not removed. To list what was installed:${RESET}"
echo -e "${DIM}  cat $STRATE_DIR/settings.json${RESET}"
echo ""
