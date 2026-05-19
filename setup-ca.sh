#!/usr/bin/env bash
#
# Trust corporate / GitLab self-signed CA certs so that
# `code --install-extension`, npm, git, and curl stop failing with
# "self-signed certificate in certificate chain".
#
# It AUTO-CAPTURES the chain your proxy presents (no need to find the cert
# yourself), plus any cert(s) you drop into ~/certs, builds one bundle, and
# wires it into git/npm/node/curl + the macOS System keychain.
#
# Usage:  ./setup-ca.sh
#
set -euo pipefail

CERT_DIR="${CERT_DIR:-$HOME/certs}"
BUNDLE="$HOME/.corp-ca-bundle.pem"
SHELL_RC="$HOME/.zshrc"

info() { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$1"; }

mkdir -p "$CERT_DIR"

# --- 0. Auto-grab the chain the proxy actually presents -----------------------
# This is the reliable fix: whatever CA is doing TLS interception, we capture
# every cert it sends for the VS Code marketplace + gallery hosts and trust them.
info "Capturing live TLS chain from marketplace/gallery hosts..."
for host in \
  marketplace.visualstudio.com \
  vscode.download.prss.microsoft.com \
  az764295.vo.msecnd.net; do
  out="$CERT_DIR/proxy-${host}.pem"
  if echo | openssl s_client -showcerts -servername "$host" \
        -connect "${host}:443" 2>/dev/null \
      | awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' \
      > "$out" && [ -s "$out" ]; then
    n=$(grep -c 'BEGIN CERTIFICATE' "$out" || echo 0)
    info "  $host -> captured $n cert(s) into $(basename "$out")"
  else
    warn "  could not reach $host (continuing)"
    rm -f "$out"
  fi
done

# --- 1. Collect certs ---------------------------------------------------------
if [ ! -d "$CERT_DIR" ]; then
  warn "No cert directory at $CERT_DIR"
  echo "    Create it and drop ALL your GitLab/corp CA cert(s) in, then re-run:"
  echo "      mkdir -p $CERT_DIR && cp /path/to/*.pem $CERT_DIR/"
  exit 1
fi

shopt -s nullglob
CERTS=("$CERT_DIR"/*.pem "$CERT_DIR"/*.crt "$CERT_DIR"/*.cer)
shopt -u nullglob

if [ ${#CERTS[@]} -eq 0 ]; then
  warn "No .pem/.crt/.cer files found in $CERT_DIR"
  exit 1
fi

info "Found ${#CERTS[@]} cert file(s) in $CERT_DIR:"
for c in "${CERTS[@]}"; do
  subj=$(openssl x509 -in "$c" -noout -subject 2>/dev/null || echo "unreadable")
  echo "    - $(basename "$c")  ->  $subj"
done

# --- 2. Build a combined bundle (corp CA + system roots) ----------------------
info "Building CA bundle at $BUNDLE"
: > "$BUNDLE"
for c in "${CERTS[@]}"; do
  # Normalise DER -> PEM if needed
  if openssl x509 -in "$c" -noout >/dev/null 2>&1; then
    openssl x509 -in "$c" >> "$BUNDLE"
  else
    openssl x509 -inform DER -in "$c" >> "$BUNDLE" 2>/dev/null || warn "skipped (bad cert): $c"
  fi
  echo >> "$BUNDLE"
done

# Append the system root store so we don't *lose* public CAs
for sys in \
  /etc/ssl/cert.pem \
  /opt/homebrew/etc/ca-certificates/cert.pem \
  /usr/local/etc/ca-certificates/cert.pem; do
  [ -f "$sys" ] && cat "$sys" >> "$BUNDLE" && break
done

# --- 3. Wire it into the tools ------------------------------------------------
info "Configuring git, npm, and the shell to use the bundle"

git config --global http.sslCAInfo "$BUNDLE"
command -v npm >/dev/null 2>&1 && npm config set cafile "$BUNDLE"

add_line() { grep -qF "$1" "$SHELL_RC" 2>/dev/null || echo "$1" >> "$SHELL_RC"; }
touch "$SHELL_RC"
add_line "export NODE_EXTRA_CA_CERTS=$BUNDLE"   # VS Code 'code' CLI + Node
add_line "export CURL_CA_BUNDLE=$BUNDLE"        # curl
add_line "export REQUESTS_CA_BUNDLE=$BUNDLE"    # python requests / aws cli
add_line "export SSL_CERT_FILE=$BUNDLE"         # openssl-based tools

export NODE_EXTRA_CA_CERTS="$BUNDLE"

# macOS: VS Code (Electron) also consults the System keychain. Import there too.
if [ "$(uname)" = "Darwin" ]; then
  info "Importing captured certs into the macOS System keychain (needs sudo)..."
  for c in "$CERT_DIR"/proxy-*.pem "$CERT_DIR"/*.crt "$CERT_DIR"/*.cer; do
    [ -e "$c" ] || continue
    sudo security add-trusted-cert -d -r trustRoot \
      -k /Library/Keychains/System.keychain "$c" 2>/dev/null \
      && info "  trusted $(basename "$c")" \
      || warn "  could not import $(basename "$c") (may already be trusted)"
  done
fi

# --- 4. Verify ----------------------------------------------------------------
info "Verifying against the VS Code marketplace..."
if curl -fsS --cacert "$BUNDLE" -o /dev/null https://marketplace.visualstudio.com; then
  info "TLS OK."
  info "Run:  source $SHELL_RC  &&  ./install.sh"
  info "If 'code' STILL fails, fully quit VS Code first (Cmd+Q), then launch"
  info "it from a NEW terminal so it inherits NODE_EXTRA_CA_CERTS."
else
  warn "Still failing after capturing the live chain."
  warn "The proxy may block raw openssl too. Fallback options:"
  warn "  1) Ask IT for the ROOT proxy CA, drop it in $CERT_DIR, re-run."
  warn "  2) Temporary unblock: set \"http.proxyStrictSSL\": false in"
  warn "     VS Code settings.json, OR run:"
  warn "     NODE_TLS_REJECT_UNAUTHORIZED=0 code --install-extension <id>"
fi
