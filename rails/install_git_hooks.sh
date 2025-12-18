#!/bin/bash
set -e

echo "🚀 Starting Lefthook setup..."


# Variables
LEFTHOOK_YML_URL="https://raw.githubusercontent.com/jarvisconsulting/saral-git-hooks/test/rails/lefthook.yml"
LEFTHOOK_INSTALL_URL="https://raw.githubusercontent.com/evilmartians/lefthook/master/install.sh"


# Install Lefthook if missing
if ! command -v lefthook >/dev/null 2>&1; then
  echo "📦 Lefthook not found. Installing..."

  curl -fsSL "$LEFTHOOK_INSTALL_URL" | bash

  # Add to PATH for current shell
  if [ -d "$HOME/.lefthook/bin" ]; then
    export PATH="$HOME/.lefthook/bin:$PATH"
  fi
else
  echo "✔ Lefthook already installed"
fi


# Final sanity check
if ! command -v lefthook >/dev/null 2>&1; then
  echo "❌ Lefthook installation failed"
  exit 1
fi

# Download lefthook.yml if missing
if [ ! -f "lefthook.yml" ]; then
  echo "📄 Downloading lefthook.yml..."
  curl -fsSL "$LEFTHOOK_YML_URL" -o lefthook.yml
  echo "✅ lefthook.yml downloaded"
else
  echo "✔ lefthook.yml already exists (skipping)"
fi


# Install git hooks
echo "🔗 Installing git hooks via Lefthook..."
lefthook install || true

echo "✅ Lefthook setup complete"
