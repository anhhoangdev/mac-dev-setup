#!/usr/bin/env bash
#
# Trust corporate / GitLab self-signed CA certs so that
# `code --install-extension`, npm, git, and curl stop failing with
# "self-signed certificate in certificate chain".
#
# Drop your CA cert(s) into ~/cert (any .pem / .crt / .cer), then run this.
# It builds a single bundle and wires it into the relevant tools.
#
# Usage:  ./setup-ca.sh
#
set -euo pipefail

CERT_DIR="${CERT_DIR:-$HOME/certs}"
BUNDLE="$HOME/.corp-ca-bundle.pem"
SHELL_RC="$HOME/.zshrc"

info() { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$1"; }

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

# --- 4. Verify ----------------------------------------------------------------
info "Verifying against the VS Code marketplace..."
if curl -fsS --cacert "$BUNDLE" -o /dev/null https://marketplace.visualstudio.com; then
  info "TLS OK. Now run:  source $SHELL_RC  &&  ./install.sh"
else
  warn "Still failing. Your cert in $CERT_DIR may not be the full chain"
  warn "(need the *root* proxy CA, not just the GitLab leaf cert)."
fi
