#!/bin/bash
set -e

echo "🔧 Starting git hooks setup..."

# -----------------------------
# Install pre-commit if missing
# -----------------------------
if ! command -v pre-commit >/dev/null 2>&1; then
  echo "📦 pre-commit not found."

  if command -v apt-get >/dev/null 2>&1; then
    echo "➡️ Installing pre-commit via apt-get..."
    sudo apt-get install -y pre-commit
  else
    echo ""
    echo "❌ Automatic installation not supported on this system."
    echo ""
    echo "👉 Please install pre-commit manually:"
    echo ""
    echo "   Ubuntu / Debian:"
    echo "     sudo apt install pre-commit"
    echo ""
    echo "   macOS:"
    echo "     brew install pre-commit"
    echo ""
    echo "   Docs:"
    echo "     https://pre-commit.com/#install"
    echo ""
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

# -----------------------------
# Install git hooks
# -----------------------------
echo "🔗 Installing pre-push hook..."
pre-commit install --hook-type pre-push || true

echo "🔗 Installing commit-msg hook..."
pre-commit install --hook-type commit-msg || true

echo "✅ Git hooks installation complete"