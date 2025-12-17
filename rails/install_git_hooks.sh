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
# Check pre-commit
# -----------------------------
if ! command -v pre-commit >/dev/null 2>&1; then
  echo ""
  echo "❌ pre-commit is not installed."
  echo ""
  echo "👉 Please install it manually:"
  echo "   Ubuntu/Debian: sudo apt install pre-commit"
  echo "   macOS: brew install pre-commit"
  echo ""
  echo "ℹ️ Skipping git hook installation."
  exit 0
else
  echo "✔ pre-commit already installed"
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
