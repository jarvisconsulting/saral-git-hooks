#!/bin/bash
set -e

echo "🔧 Starting git hooks setup..."

# Only run in development
if [ "$RAILS_ENV" != "development" ]; then
  echo "ℹ️ Not in development environment. Skipping."
  exit 0
fi

# Must be inside a git repo
if [ ! -d ".git" ]; then
  echo "❌ .git directory not found. Skipping."
  exit 0
fi

# -----------------------------
# Install pre-commit if missing
# -----------------------------
if ! command -v pre-commit >/dev/null 2>&1; then
  echo "📦 pre-commit not found. Installing..."

  if command -v apt-get >/dev/null 2>&1; then
    echo "➡️ Installing via apt (no apt update)..."
    sudo apt-get install -y pre-commit

  elif command -v brew >/dev/null 2>&1; then
    echo "➡️ Installing via Homebrew..."
    brew install pre-commit

  else
    echo "❌ No supported package manager found."
    exit 1
  fi
else
  echo "✔ pre-commit already installed"
fi

# Final sanity check
if ! command -v pre-commit >/dev/null 2>&1; then
  echo "❌ pre-commit installation failed"
  exit 1
fi

HOOKS_DIR=".git/hooks"

# -----------------------------
# Install pre-push hook
# -----------------------------
if [ ! -f "$HOOKS_DIR/pre-push" ]; then
  echo "🔗 Installing pre-push hook..."
  pre-commit install --hook-type pre-push
else
  echo "✔ pre-push hook already exists"
fi

# -----------------------------
# Install commit-msg hook
# -----------------------------
if [ ! -f "$HOOKS_DIR/commit-msg" ]; then
  echo "🔗 Installing commit-msg hook..."
  pre-commit install --hook-type commit-msg
else
  echo "✔ commit-msg hook already exists"
fi

echo "✅ Git hooks installation complete"
