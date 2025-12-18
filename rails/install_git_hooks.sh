#!/bin/bash
set -euo pipefail

echo "🚀 Setting up Lefthook for this project..."

# -----------------------------
# Config
# -----------------------------
LEFTHOOK_YML_URL="https://raw.githubusercontent.com/jarvisconsulting/saral-git-hooks/test/rails/lefthook.yml"
LEFTHOOK_YML_FILE="lefthook.yml"
FORCE_UPDATE="${FORCE_UPDATE:-0}"

# -----------------------------
# Helpers
# -----------------------------
log() {
  echo "👉 $1"
}

error() {
  echo "❌ $1"
  exit 1
}

# -----------------------------
# Check Lefthook exists
# -----------------------------
if ! command -v lefthook >/dev/null 2>&1; then
  error "Lefthook is not installed.

👉 Install it once using:
   cd ~
   curl -1sLf https://dl.cloudsmith.io/public/evilmartians/lefthook/setup.deb.sh | sudo -E bash
   sudo apt install lefthook
"
fi

log "Lefthook found: $(lefthook version)"

# -----------------------------
# Download lefthook.yml
# -----------------------------
if [ ! -f "$LEFTHOOK_YML_FILE" ] || [ "$FORCE_UPDATE" = "1" ]; then
  log "Downloading lefthook.yml..."
  curl -fsSL "$LEFTHOOK_YML_URL" -o "$LEFTHOOK_YML_FILE"
  log "lefthook.yml ready"
else
  log "lefthook.yml already exists (use FORCE_UPDATE=1 to overwrite)"
fi

# -----------------------------
# Install git hooks
# -----------------------------
log "Installing git hooks..."
lefthook install

echo "🎉 Lefthook project setup complete"
