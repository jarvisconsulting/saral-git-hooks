#!/bin/bash
set -e

echo "🚀 Bootstrapping pre-commit & pre-push hooks..."

# --------------------------------------------------
# Resolve project root (git root)
# --------------------------------------------------
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

echo "📁 Project root: $PROJECT_ROOT"

# --------------------------------------------------
# Install pre-commit
# --------------------------------------------------
if ! command -v pre-commit >/dev/null 2>&1; then
  echo "📦 pre-commit not found. Installing via apt-get..."

  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y pre-commit
  else
    echo "❌ apt-get not found. Cannot install pre-commit automatically."
    exit 1
  fi
else
  echo "✔ pre-commit already installed"
fi

# --------------------------------------------------
# Create directories
# --------------------------------------------------
mkdir -p scripts

# --------------------------------------------------
# Write commit-msg hook (JIRA + skip-build)
# NOTE: Inner heredoc uses \EOF so the outer shell
#       does not mistake it for its own EOF delimiter.
# --------------------------------------------------
cat > scripts/commit-msg.sh <<\EOF
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

# Require JIRA ticket anywhere
if ! echo "$MESSAGE" | grep -Eq "\b[A-Z]+-[0-9]+\b"; then
  echo ""
  echo "❌ Commit rejected!"
  echo "👉 Include a JIRA ticket anywhere in the message"
  echo "   Example: Fix login issue (ABC-123)"
  echo ""
  exit 1
fi

echo "✔ Commit message valid"
exit 0
EOF

chmod +x scripts/commit-msg.sh

# --------------------------------------------------
# Write pre-push hook (DYNAMIC BUILD ARGS)
# NOTE: Inner heredoc uses \EOF for the same reason.
# --------------------------------------------------
cat > scripts/pre-push.sh <<\EOF
#!/bin/bash
set -e

CRED_FILE="cred.yml"

MESSAGE=$(git log -1 --pretty=%B)

# --------------------------------------------------
# Skip-build flag
# --------------------------------------------------
if echo "$MESSAGE" | grep -Eq "\bskip[-_ ]?build\b"; then
  echo "⏭ Build skipped (skip-build flag detected)"
  exit 0
fi

# --------------------------------------------------
# JIRA validation
# --------------------------------------------------
if ! echo "$MESSAGE" | grep -Eq "\b[A-Z]+-[0-9]+\b"; then
  echo ""
  echo "❌ Push rejected!"
  echo "👉 Latest commit must contain a JIRA ticket"
  exit 1
fi

# --------------------------------------------------
# Credentials file check
# --------------------------------------------------
if [ ! -f "$CRED_FILE" ]; then
  echo ""
  echo "❌ Missing $CRED_FILE"
  echo "👉 Create it like:"
  echo ""
  echo "KEY: value"
  echo "ANOTHER_KEY: value"
  echo ""
  exit 1
fi

echo ""
echo "📦 Reading build args from $CRED_FILE..."

# --------------------------------------------------
# Parse YAML dynamically (flat key:value only)
# --------------------------------------------------
BUILD_ARGS=""

while IFS=":" read -r key value; do
  # skip comments & empty lines
  [[ -z "$key" || "$key" =~ ^# ]] && continue

  key=$(echo "$key" | xargs)
  value=$(echo "$value" | xargs)

  [[ -z "$key" || -z "$value" ]] && continue

  BUILD_ARGS="$BUILD_ARGS --build-arg $key=$value"

done < "$CRED_FILE"

# --------------------------------------------------
# Debug
# --------------------------------------------------
echo ""
echo "🐳 Docker build args:"
echo "$BUILD_ARGS"
echo ""

# --------------------------------------------------
# Docker build
# --------------------------------------------------
echo "🐳 Running Docker build..."

docker build $BUILD_ARGS .

echo ""
echo "✅ Docker build successful"

exit 0
EOF

chmod +x scripts/pre-push.sh

# --------------------------------------------------
# Write .pre-commit-config.yaml
# NOTE: \EOF used here too for consistency/safety.
# --------------------------------------------------
cat > .pre-commit-config.yaml <<\EOF
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

grep -qxF ".pre-commit-config.yaml" .gitignore || echo ".pre-commit-config.yaml" >> .gitignore
grep -qxF "scripts/" .gitignore || echo "scripts/" >> .gitignore
grep -qxF "cred.yml" .gitignore || echo "cred.yml" >> .gitignore

echo "📝 Updated .gitignore"

# --------------------------------------------------
# Install hooks
# --------------------------------------------------
echo "🔗 Installing git hooks..."
pre-commit install --hook-type commit-msg
pre-commit install --hook-type pre-push

echo ""
echo "🎉 pre-commit & pre-push fully set up!"
echo "✔ JIRA enforced"
echo "✔ skip-build supported"
echo "✔ Dynamic Docker build args from cred.yml"
