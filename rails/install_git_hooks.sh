#!/bin/bash
set -e

echo "🚀 Starting Lefthook setup..."

# -----------------------------
# Variables
# -----------------------------
LEFTHOOK_YML_URL="https://raw.githubusercontent.com/jarvisconsulting/saral-git-hooks/test/rails/lefthook.yml"

# -----------------------------
# Install Lefthook (APT)
# -----------------------------
if ! command -v lefthook >/dev/null 2>&1; then
  echo "📦 Lefthook not found. Installing via apt..."

  # Add Lefthook APT repo (official)
  curl -1sLf 'https://dl.cloudsmith.io/public/evilmartians/lefthook/setup.deb.sh' | sudo -E bash

  # Install Lefthook
  sudo apt install -y lefthook
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

echo "🎉 Lefthook setup complete"
