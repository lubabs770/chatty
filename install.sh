#!/bin/bash
# Chatty installer — downloads the latest release, de-quarantines it, and
# installs Chatty.app to /Applications (falls back to ~/Applications).
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/lubabs770/chatty/main/install.sh)"
set -euo pipefail

REPO="lubabs770/chatty"
ASSET="Chatty.app.zip"
URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"

echo "==> Downloading latest Chatty release..."
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
curl -fsSL "${URL}" -o "${TMP}/${ASSET}"

echo "==> Unpacking..."
ditto -x -k "${TMP}/${ASSET}" "${TMP}/unpacked"
APP_SRC="$(/usr/bin/find "${TMP}/unpacked" -maxdepth 2 -name 'Chatty.app' -print -quit)"
if [ -z "${APP_SRC}" ]; then
    echo "error: Chatty.app not found in release asset" >&2
    exit 1
fi

# Prefer /Applications; fall back to ~/Applications if it isn't writable.
DEST="/Applications"
if [ ! -w "${DEST}" ]; then
    DEST="${HOME}/Applications"
    mkdir -p "${DEST}"
fi

echo "==> Installing to ${DEST}/Chatty.app"
rm -rf "${DEST}/Chatty.app"
ditto "${APP_SRC}" "${DEST}/Chatty.app"

# Strip the Gatekeeper quarantine so the unsigned app opens without a fight.
xattr -dr com.apple.quarantine "${DEST}/Chatty.app" 2>/dev/null || true

echo "==> Installed."
if ! command -v claude >/dev/null 2>&1 \
   && [ ! -x "${HOME}/.local/bin/claude" ] \
   && [ ! -x /opt/homebrew/bin/claude ] \
   && [ ! -x /usr/local/bin/claude ]; then
    echo "    note: the 'claude' CLI wasn't found. Install Claude Code first:"
    echo "          https://claude.com/claude-code"
fi
echo "    Launch with:  open -a Chatty"
