#!/bin/bash
set -e

echo "🔧 Starting pre-commit setup..."

# Config (REMOTE REPO)
REMOTE_BASE_URL="https://raw.githubusercontent.com/jarvisconsulting/saral-git-hooks/test/rails"

PRE_COMMIT_CONFIG_URL="$REMOTE_BASE_URL/.pre-commit-config.yaml"
SCRIPTS_BASE_URL="$REMOTE_BASE_URL/scripts"

LOCAL_SCRIPTS_DIR="scripts"


# Install pre-commit if missing
if ! command -v pre-commit >/dev/null 2>&1; then
  echo "📦 pre-commit not found."

  if command -v apt-get >/dev/null 2>&1; then
    echo "➡️ Installing pre-commit via apt-get..."
    sudo apt-get install -y pre-commit
  else
    echo ""
    echo "❌ Automatic installation not supported on this system."
    echo "👉 Install manually: https://pre-commit.com/#install"
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


# Download .pre-commit-config.yaml
echo "📄 Downloading .pre-commit-config.yaml..."
curl -fsSL "$PRE_COMMIT_CONFIG_URL" -o .pre-commit-config.yaml
echo "✔ .pre-commit-config.yaml ready"


# Download hook scripts
echo "📂 Setting up hook scripts..."

mkdir -p "$LOCAL_SCRIPTS_DIR"

curl -fsSL "$SCRIPTS_BASE_URL/jira-check.sh" -o "$LOCAL_SCRIPTS_DIR/jira-check.sh"
curl -fsSL "$SCRIPTS_BASE_URL/docker-build.sh" -o "$LOCAL_SCRIPTS_DIR/docker-build.sh"

chmod +x "$LOCAL_SCRIPTS_DIR/"*.sh

echo "✔ Hook scripts downloaded"


# Install git hooks
echo "🔗 Installing pre-commit hooks..."

pre-commit install --hook-type pre-push || true
pre-commit install --hook-type commit-msg || true

echo "✅ pre-commit setup complete"