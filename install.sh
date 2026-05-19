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

add_rc() { grep -qF "$1" "$HOME/.zshrc" 2>/dev/null || echo "$1" >> "$HOME/.zshrc"; }
touch "$HOME/.zshrc"

# --- 1. Homebrew (no-sudo, $HOME prefix) --------------------------------------
export PATH="$HOME/homebrew/bin:$PATH"
if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew into ~/homebrew (no sudo)..."
  mkdir -p "$HOME/homebrew"
  curl -L https://github.com/Homebrew/brew/tarball/master \
    | tar xz --strip 1 -C "$HOME/homebrew"
  add_rc 'export PATH="$HOME/homebrew/bin:$PATH"'
else
  info "Homebrew found: $(command -v brew)"
fi

# --- 1b. mise (language runtimes: node, python, go, ruby, java, rust) ---------
if ! command -v mise >/dev/null 2>&1; then
  info "Installing mise..."
  curl -fsSL https://mise.run | sh
  add_rc 'eval "$("$HOME/.local/bin/mise" activate zsh)"'
fi
export PATH="$HOME/.local/bin:$PATH"
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)" 2>/dev/null || true
  # Node is required for the npm-based AI CLIs (Claude Code, Gemini CLI, …)
  mise use -g node@lts 2>/dev/null && info "mise: node@lts active" || true
fi

# No-sudo cask installs: put apps in ~/Applications, fonts in ~/Library/Fonts
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications --fontdir=$HOME/Library/Fonts"
mkdir -p "$HOME/Applications"

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

# Put the bundled `code` CLI on PATH (cask in ~/Applications isn't auto-linked)
if ! command -v code >/dev/null 2>&1; then
  for app in "$HOME/Applications/Visual Studio Code.app" \
             "/Applications/Visual Studio Code.app"; do
    cli="$app/Contents/Resources/app/bin"
    if [ -x "$cli/code" ]; then
      export PATH="$cli:$PATH"
      add_rc "export PATH=\"$cli:\$PATH\""
      info "Linked code CLI from $app"
      break
    fi
  done
fi
command -v code >/dev/null 2>&1 || { info "code CLI not found — skipping extensions"; exit 0; }

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
