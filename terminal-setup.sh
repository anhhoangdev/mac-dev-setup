#!/usr/bin/env bash
#
# Terminal prompt setup — Starship, Catppuccin Mocha.
# Assumes Starship is already installed (brew install starship).
# No sudo. Idempotent.
#
# Usage:  ./terminal-setup.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_RC="$HOME/.zshrc"

info() { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$1"; }

# --- 1. Starship config -------------------------------------------------------
if ! command -v starship >/dev/null 2>&1; then
  warn "starship not found on PATH. Install it first:  brew install starship"
  warn "Continuing anyway (config will still be written)."
fi

mkdir -p "$HOME/.config"
DEST="$HOME/.config/starship.toml"
if [ -s "$DEST" ] && ! cmp -s "$REPO_DIR/starship.toml" "$DEST"; then
  cp "$DEST" "$DEST.bak.$(date +%s)"
  info "Backed up existing starship.toml"
fi
cp "$REPO_DIR/starship.toml" "$DEST"
info "Installed Catppuccin Mocha config -> $DEST"

# --- 2. Hook Starship into zsh ------------------------------------------------
touch "$SHELL_RC"
if ! grep -qF 'starship init zsh' "$SHELL_RC"; then
  echo 'eval "$(starship init zsh)"' >> "$SHELL_RC"
  info "Added 'eval \"\$(starship init zsh)\"' to $SHELL_RC"
else
  info "Starship already initialised in $SHELL_RC"
fi

# --- 3. iTerm2 Catppuccin Mocha color preset ---------------------------------
# Downloads the official .itermcolors; import via:
#   iTerm2 > Settings > Profiles > Colors > Color Presets > Import
ITERM_DIR="$HOME/.config/iterm2"
mkdir -p "$ITERM_DIR"
SCHEME="$ITERM_DIR/catppuccin-mocha.itermcolors"
if [ ! -f "$SCHEME" ]; then
  if curl -fsSL -o "$SCHEME" \
    "https://raw.githubusercontent.com/catppuccin/iterm/main/colors/catppuccin-mocha.itermcolors"; then
    info "iTerm2 scheme saved -> $SCHEME"
    info "Import it: iTerm2 > Settings > Profiles > Colors > Color Presets > Import"
  else
    warn "Could not download iTerm2 scheme (network/proxy). Skipping."
    rm -f "$SCHEME"
  fi
fi

# --- 4. Vim: mouse scrolling --------------------------------------------------
VIMRC="$HOME/.vimrc"
touch "$VIMRC"
if ! grep -qF 'mac-dev-setup: scrolling' "$VIMRC"; then
  cat >> "$VIMRC" <<'EOF'

" --- mac-dev-setup: scrolling ---
set mouse=a                 " mouse wheel scrolls in vim
set ttymouse=sgr            " correct mouse past column 223 (iTerm2)
set scrolloff=3             " keep 3 lines of context when scrolling
nnoremap <ScrollWheelUp>   3<C-y>
nnoremap <ScrollWheelDown> 3<C-e>
EOF
  info "Added mouse scrolling to $VIMRC"
else
  info "Vim scrolling already configured in $VIMRC"
fi

# --- 5. zsh: word/line delete (fallback for keyboard, not iTerm2 mappings) ----
# iTerm2's "Natural Text Editing" preset is the primary fix; these zsh binds
# make Ctrl-W (word) / Ctrl-U (line) robust regardless of terminal mappings.
if ! grep -qF 'mac-dev-setup: editing keys' "$SHELL_RC"; then
  cat >> "$SHELL_RC" <<'EOF'

# --- mac-dev-setup: editing keys ---
bindkey '^W' backward-kill-word        # Ctrl-W  delete word
bindkey '^U' backward-kill-line        # Ctrl-U  delete to line start
bindkey '\e^?' backward-kill-word      # Option+Delete (when Opt=Esc+)
bindkey '\e[3~' delete-char            # Forward Delete
EOF
  info "Added word/line delete binds to $SHELL_RC"
else
  info "Editing keybinds already in $SHELL_RC"
fi

# --- 6. Done ------------------------------------------------------------------
info "Done. Reload your shell:  source $SHELL_RC  (or: exec zsh)"
echo
warn "ONE manual iTerm2 step (can't be scripted safely):"
warn "  Settings > Profiles > Keys > Key Mappings > Presets…"
warn "  > choose 'Natural Text Editing'"
warn "  -> enables Option+Delete (word), Cmd+Delete (line), word jumps."
info "Also set iTerm2 font to 'FiraCode Nerd Font' so prompt glyphs render."
