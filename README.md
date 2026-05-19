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

## Behind a corporate / GitLab self-signed CA?

If `code --install-extension` fails with
`self-signed certificate in certificate chain`:

```bash
mkdir -p ~/certs
cp /path/to/your/*.pem ~/certs/      # drop ALL CA certs here
./setup-ca.sh                        # builds ~/.corp-ca-bundle.pem, wires git/npm/node/curl
source ~/.zshrc
./install.sh
```

`setup-ca.sh` reads every `.pem/.crt/.cer` in `~/certs`, merges them with the
system root store, and exports `NODE_EXTRA_CA_CERTS`, `CURL_CA_BUNDLE`,
`REQUESTS_CA_BUNDLE`, `SSL_CERT_FILE` (persisted to `~/.zshrc`).

## Layout

| Path | Purpose |
|---|---|
| `install.sh` | One-shot setup script |
| `setup-ca.sh` | Trust corp/GitLab CA certs from `~/certs` (run before install if behind a TLS proxy) |
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
