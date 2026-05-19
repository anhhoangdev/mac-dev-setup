# mac-dev-setup

My fresh-macOS VS Code environment, scripted.

## What it sets up

- **Homebrew** (if missing)
- **Fonts:** FiraCode Nerd Font (editor, with ligatures), DejaVu Sans Mono (terminal)
- **VS Code** + extensions
- **Theme:** Catppuccin Mocha · **Icons:** Material Icon Theme
- **Settings & keybindings** copied into `~/Library/Application Support/Code/User/`

## Usage

```bash
git clone https://github.com/anhhoangdev/mac-dev-setup.git
cd mac-dev-setup
./install.sh
```

Existing `settings.json` / `keybindings.json` are backed up (`*.bak.<timestamp>`) before being replaced.

## Layout

| Path | Purpose |
|---|---|
| `install.sh` | One-shot setup script |
| `vscode/settings.json` | Editor + workbench config |
| `vscode/keybindings.json` | Custom keybindings (terminal `shift+enter`) |
| `vscode/extensions.txt` | Full extension list (`code --list-extensions`) |

## Updating the extension list

After installing new extensions, refresh and commit:

```bash
code --list-extensions > vscode/extensions.txt
git commit -am "update extensions"
```

> Tip: VS Code **Settings Sync** (sign in via the Accounts icon) covers the same
> ground automatically. This repo is the version-controlled source of truth / fallback.
