#!/usr/bin/env bash
#
# Fresh macOS dev environment setup.
# Restores VS Code (theme, settings, keybindings, extensions) + fonts.
#
# Usage:  ./install.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_USER_DIR="$HOME/Library/Application Support/Code/User"

info() { printf "\033[1;34m==>\033[0m %s\n" "$1"; }

# --- 1. Homebrew --------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Apple Silicon brew is in /opt/homebrew
  [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
else
  info "Homebrew already installed."
fi

# --- 2. Fonts -----------------------------------------------------------------
info "Installing fonts (FiraCode Nerd Font, DejaVu)..."
brew install --cask font-fira-code-nerd-font font-dejavu || true

# --- 3. VS Code ---------------------------------------------------------------
if ! command -v code >/dev/null 2>&1; then
  info "Installing Visual Studio Code..."
  brew install --cask visual-studio-code
else
  info "VS Code already installed."
fi

# --- 4. Settings & keybindings ------------------------------------------------
info "Linking VS Code settings & keybindings..."
mkdir -p "$CODE_USER_DIR"
for f in settings.json keybindings.json; do
  if [ -e "$CODE_USER_DIR/$f" ] && [ ! -L "$CODE_USER_DIR/$f" ]; then
    mv "$CODE_USER_DIR/$f" "$CODE_USER_DIR/$f.bak.$(date +%s)"
    info "  backed up existing $f"
  fi
  cp "$REPO_DIR/vscode/$f" "$CODE_USER_DIR/$f"
done

# --- 5. Extensions ------------------------------------------------------------
info "Installing VS Code extensions..."
while read -r ext; do
  [ -z "$ext" ] && continue
  code --install-extension "$ext" --force || echo "  skipped: $ext"
done < "$REPO_DIR/vscode/extensions.txt"

info "Done. Restart VS Code to apply the Catppuccin Mocha theme."
