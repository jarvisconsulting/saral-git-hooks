#!/bin/bash
set -e

echo "🚀 Bootstrapping pre-commit (single remote file)..."


# 1. Detect project root (git root)
if ! PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo "❌ Not inside a git repository."
  exit 1
fi

cd "$PROJECT_ROOT"
echo "📁 Project root: $PROJECT_ROOT"


# 2. Ensure pre-commit is installed (APT only)
if ! command -v pre-commit >/dev/null 2>&1; then
  echo "📦 pre-commit not found."

  if command -v apt-get >/dev/null 2>&1; then
    echo "➡️ Installing pre-commit via apt-get..."
    sudo apt-get update -y
    sudo apt-get install -y pre-commit
  else
    echo "❌ apt-get not available."
    echo "👉 Install pre-commit manually: https://pre-commit.com/#install"
    exit 1
  fi
else
  echo "✔ pre-commit already installed"
fi


# 3. Ensure .gitignore exists
echo "Checking for .gitignore..."
if [ ! -f .gitignore ]; then
  echo "📄 Creating .gitignore..."
else
  echo "✔ .gitignore already exists"
fi

touch .gitignore


# 4. Add entries to .gitignore if missing
add_to_gitignore() {
  local entry="$1"
  if ! grep -qxF "$entry" .gitignore; then
    echo "$entry" >> .gitignore
    echo "➕ Added '$entry' to .gitignore"
  else
    echo "✔ '$entry' already in .gitignore"
  fi
}

echo "📝 Updating .gitignore..."

add_to_gitignore ".pre-commit-config.yaml"
add_to_gitignore "scripts/"
add_to_gitignore "prepush-credentials.yml"


# 5. Write .pre-commit-config.yaml
echo "📄 Writing .pre-commit-config.yaml..."

cat > .pre-commit-config.yaml <<'YAML'
repos:
  - repo: local
    hooks:
      - id: pre-push-check
        name: Pre-push Validation (JIRA + Docker)
        entry: scripts/pre-push.sh
        language: system
        stages: [pre-push]
YAML

echo "✔ .pre-commit-config.yaml created"


# 6. Write single pre-push hook
echo "📂 Writing pre-push hook..."

mkdir -p scripts

cat > scripts/pre-push.sh <<'EOF'
#!/bin/bash
set -e

echo "🚀 Running pre-push checks..."


# Read latest commit message
MESSAGE=$(git log -1 --pretty=%B)


# JIRA ticket validation (A-Z+-123 format)
if ! echo "$MESSAGE" | grep -Eq "\b[A-Z]+-[0-9]+\b"; then
  echo ""
  echo "❌ Push rejected!"
  echo "👉 Commit message must contain a JIRA ticket (anywhere)"
  echo ""
  echo "✔ Examples:"
  echo "   ABC-123 add login"
  echo "   fix: login (ABC-123)"
  echo "   pre-commit ABC-123"
  echo ""
  exit 1
fi

echo "✔ JIRA ticket found"


# Skip-build flag
if echo "$MESSAGE" | grep -Eq "\bskip[-_ ]?build\b"; then
  echo "⏭ Build skipped (skip-build flag detected)"
  exit 0
fi


# Credentials check
CRED_FILE="prepush-credentials.yml"

if [ ! -f "$CRED_FILE" ]; then
  echo ""
  echo "❌ Missing credentials file: $CRED_FILE"
  echo ""
  echo "👉 Create this file in the PROJECT ROOT:"
  echo ""
  echo "----------------------------------------"
  echo "rails_master_key: <YOUR_RAILS_MASTER_KEY>"
  echo "access_token: <YOUR_ACCESS_TOKEN>"
  echo "----------------------------------------"
  echo ""
  echo "🔐 Do NOT commit this file. It is already ignored."
  echo ""
  exit 1
fi

RAILS_MASTER_KEY=$(awk -F': ' '/rails_master_key/ {print $2}' "$CRED_FILE")
ACCESS_TOKEN=$(awk -F': ' '/access_token/ {print $2}' "$CRED_FILE")

if [ -z "$RAILS_MASTER_KEY" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Invalid $CRED_FILE (both values required)"
  exit 1
fi

echo "🔐 Credentials loaded"


# Docker build
echo "🐳 Running Docker build..."

docker build \
  --build-arg _RAILS_MASTER_KEY="$RAILS_MASTER_KEY" \
  --build-arg _ACCESS_TOKEN="$ACCESS_TOKEN" \
  -t mlmp-app .

echo "✅ Docker build successful"
exit 0
EOF

chmod +x scripts/pre-push.sh
echo "✔ pre-push hook created"


# 7. Install pre-commit hook
echo "🔗 Installing pre-commit hook..."
pre-commit install --hook-type pre-push

echo "🎉 Pre-commit bootstrap complete"
