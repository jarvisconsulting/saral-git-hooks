#!/bin/bash
set -e

echo "🚀 Starting Lefthook setup..."

# -----------------------------
# Variables
# -----------------------------
LEFTHOOK_YML_URL="https://raw.githubusercontent.com/jarvisconsulting/saral-git-hooks/test/rails/lefthook.yml"
# LEFTHOOK_VERSION="v1.7.15"   # pin version (recommended)
LEFTHOOK_BIN_URL="https://github.com/evilmartians/lefthook/releases/download/v1.7.15/lefthook_linux_amd64"

# -----------------------------
# Install Lefthook if missing
# -----------------------------
if ! command -v lefthook >/dev/null 2>&1; then
  echo "📦 Lefthook not found. Installing ${LEFTHOOK_VERSION}..."

  mkdir -p "$HOME/.local/bin"

  curl -fsSL "$LEFTHOOK_BIN_URL" -o "$HOME/.local/bin/lefthook"
  chmod +x "$HOME/.local/bin/lefthook"

  export PATH="$HOME/.local/bin:$PATH"
else
  echo "✔ Lefthook already installed"
fi

# -----------------------------
# Final sanity check
# -----------------------------
if ! command -v lefthook >/dev/null 2>&1; then
  echo "❌ Lefthook installation failed"
  exit 1
fi

echo "✅ Lefthook installed: $(lefthook version)"

# -----------------------------
# Download lefthook.yml
# -----------------------------
if [ ! -f "lefthook.yml" ]; then
  echo "📄 Downloading lefthook.yml..."
  curl -fsSL "$LEFTHOOK_YML_URL" -o lefthook.yml
  echo "✅ lefthook.yml downloaded"
else
  echo "✔ lefthook.yml already exists (skipping)"
fi

# -----------------------------
# Install git hooks
# -----------------------------
echo "🔗 Installing git hooks via Lefthook..."
lefthook install || true

echo "✅ Lefthook setup complete"
