#!/bin/bash
set -e

echo "🚀 Bootstrapping pre-commit & pre-push hooks..."

# --------------------------------------------------
# Resolve project root
# --------------------------------------------------
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

echo "📁 Project root: $PROJECT_ROOT"

# --------------------------------------------------
# Install pre-commit (Cross-platform)
# --------------------------------------------------
if ! command -v pre-commit >/dev/null 2>&1; then
  echo "📦 pre-commit not found. Installing..."

  if command -v apt-get >/dev/null 2>&1; then
    echo "🐧 Detected Linux (apt)"
    sudo apt-get update && sudo apt-get install -y pre-commit

  elif command -v brew >/dev/null 2>&1; then
    echo "🍎 Detected macOS (Homebrew)"
    brew install pre-commit

  elif command -v pip3 >/dev/null 2>&1; then
    echo "🐍 Installing via pip"
    pip3 install --user pre-commit
    export PATH="$HOME/.local/bin:$PATH"

  else
    echo "❌ No supported package manager found."
    echo "👉 Install manually: https://pre-commit.com/#install"
    exit 1
  fi
else
  echo "✔ pre-commit already installed"
fi

# --------------------------------------------------
# Validate Docker
# --------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker is not installed."
  echo "👉 Please install Docker before continuing."
  exit 1
fi

# --------------------------------------------------
# Create scripts directory
# --------------------------------------------------
mkdir -p scripts

# --------------------------------------------------
# commit-msg hook (JIRA + skip-build)
# --------------------------------------------------
cat > scripts/commit-msg.sh <<'EOF'
#!/bin/bash
set -e

COMMIT_MSG_FILE="$1"

if [ -z "$COMMIT_MSG_FILE" ] || [ ! -f "$COMMIT_MSG_FILE" ]; then
  echo "❌ Commit message file not found"
  exit 1
fi

MESSAGE=$(cat "$COMMIT_MSG_FILE")

# Skip-build flag
if echo "$MESSAGE" | grep -Eq "\bskip[-_ ]?build\b"; then
  echo "⏭ skip-build flag detected — commit allowed"
  exit 0
fi

# Require JIRA ticket
if ! echo "$MESSAGE" | grep -Eq "\b[A-Z]+-[0-9]+\b"; then
  echo ""
  echo "❌ Commit rejected!"
  echo "👉 Include a JIRA ticket (e.g., ABC-123)"
  echo ""
  exit 1
fi

echo "✔ Commit message valid"
exit 0
EOF

chmod +x scripts/commit-msg.sh

# --------------------------------------------------
# pre-push hook (Docker build + credentials)
# --------------------------------------------------
cat > scripts/pre-push.sh <<'EOF'
#!/bin/bash
set -e

CRED_FILE="prepush-credentials.yml"

MESSAGE=$(git log -1 --pretty=%B)

# Skip-build flag
if echo "$MESSAGE" | grep -Eq "\bskip[-_ ]?build\b"; then
  echo "⏭ Build skipped (skip-build flag detected)"
  exit 0
fi

# JIRA validation
if ! echo "$MESSAGE" | grep -Eq "\b[A-Z]+-[0-9]+\b"; then
  echo ""
  echo "❌ Push rejected!"
  echo "👉 Latest commit must contain a JIRA ticket"
  exit 1
fi

# Credentials file check
if [ ! -f "$CRED_FILE" ]; then
  echo ""
  echo "❌ Missing $CRED_FILE"
  echo "👉 Create it with:"
  echo "rails_master_key: YOUR_KEY"
  echo "access_token: YOUR_TOKEN"
  echo "image_name: YOUR_IMAGE"
  exit 1
fi

# Safer YAML parsing
get_value() {
  grep "^$1:" "$CRED_FILE" | cut -d':' -f2- | xargs
}

RAILS_MASTER_KEY=$(get_value "rails_master_key")
ACCESS_TOKEN=$(get_value "access_token")
IMAGE_NAME=$(get_value "image_name")

if [ -z "$RAILS_MASTER_KEY" ] || [ -z "$ACCESS_TOKEN" ] || [ -z "$IMAGE_NAME" ]; then
  echo "❌ Credentials file is incomplete"
  exit 1
fi

echo ""
echo "🐳 Docker image to be built:"
echo "👉 Image name: $IMAGE_NAME"
echo ""

# Docker check
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker not installed"
  exit 1
fi

# Build
echo "🐳 Running Docker build..."

docker build \
  --build-arg _RAILS_MASTER_KEY="$RAILS_MASTER_KEY" \
  --build-arg _ACCESS_TOKEN="$ACCESS_TOKEN" \
  -t "$IMAGE_NAME" .

echo ""
echo "✅ Docker build successful"
echo "📦 Built image: $IMAGE_NAME"
exit 0
EOF

chmod +x scripts/pre-push.sh

# --------------------------------------------------
# pre-commit config
# --------------------------------------------------
cat > .pre-commit-config.yaml <<'EOF'
repos:
  - repo: local
    hooks:
      - id: jira-check
        name: JIRA Commit Message Check
        entry: scripts/commit-msg.sh
        language: system
        stages: [commit-msg]

      - id: docker-build
        name: Docker Build Validation
        entry: scripts/pre-push.sh
        language: system
        stages: [pre-push]
EOF

# --------------------------------------------------
# Update .gitignore
# --------------------------------------------------
touch .gitignore

grep -qxF "scripts/" .gitignore || echo "scripts/" >> .gitignore
grep -qxF "prepush-credentials.yml" .gitignore || echo "prepush-credentials.yml" >> .gitignore

echo "📝 Updated .gitignore"

# --------------------------------------------------
# Install hooks
# --------------------------------------------------
echo "🔗 Installing git hooks..."
pre-commit install --hook-type commit-msg
pre-commit install --hook-type pre-push

echo ""
echo "🎉 Setup complete!"
echo "✔ JIRA enforced"
echo "✔ skip-build supported"
echo "✔ Docker validated on push"
echo "✔ Cross-platform (Linux + macOS)"
