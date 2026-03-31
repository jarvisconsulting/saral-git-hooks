#!/bin/bash
set -e
echo "🚀 Bootstrapping pre-commit (single-file remote installer)..."
# --------------------------------------------------
# 1. Detect project root
# --------------------------------------------------
if ! PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo "❌ Not inside a git repository."
  exit 1
fi
echo "📁 Project root: $PROJECT_ROOT"
cd "$PROJECT_ROOT"
# --------------------------------------------------
# 2. Ensure pre-commit is installed
# --------------------------------------------------
if ! command -v pre-commit >/dev/null 2>&1; then
  echo "📦 pre-commit not found."
  if command -v apt-get >/dev/null 2>&1; then
    echo "➡️ Installing pre-commit via apt-get..."
    sudo apt-get install -y pre-commit
  else
    echo "❌ pre-commit not installed and automatic install not supported."
    echo "👉 Install manually: https://pre-commit.com/#install"
    exit 1
  fi
else
  echo "✔ pre-commit already installed"
fi
# --------------------------------------------------
# 3. Write .pre-commit-config.yaml
# --------------------------------------------------
echo "📄 Writing .pre-commit-config.yaml..."
cat > .pre-commit-config.yaml <<'YAML'
repos:
  - repo: local
    hooks:
      - id: jira-check
        name: JIRA Commit Message Check
        entry: scripts/jira-check.sh
        language: system
        stages: [commit-msg]
      - id: docker-build
        name: Docker Build Validation
        entry: scripts/docker-build.sh
        language: system
        stages: [push]
YAML
echo "✔ .pre-commit-config.yaml created"
# --------------------------------------------------
# 4. Write hook scripts
# --------------------------------------------------
echo "📂 Writing hook scripts..."
mkdir -p scripts

# ---- jira-check.sh ----
cat > scripts/jira-check.sh <<'EOF'
#!/bin/bash
set -e
echo "🔍 Validating commit message for JIRA ticket..."
COMMIT_MSG_FILE="$1"
if [ -z "$COMMIT_MSG_FILE" ] || [ ! -f "$COMMIT_MSG_FILE" ]; then
  echo "❌ Commit message file not found"
  exit 1
fi
MESSAGE=$(cat "$COMMIT_MSG_FILE")
# JIRA ticket anywhere in message
if ! echo "$MESSAGE" | grep -Eq "\b[A-Z]+-[0-9]+\b"; then
  echo ""
  echo "❌ Commit rejected!"
  echo "👉 Please include a JIRA ticket number anywhere in the commit message"
  echo "   Example: fix login (ABC-123)"
  echo ""
  exit 1
fi
echo "✔ Commit message contains valid JIRA ticket"
exit 0
EOF

# ---- docker-build.sh ----
cat > scripts/docker-build.sh <<'EOF'
#!/bin/bash
set -e
echo "🐳 Running Docker build validation..."

MESSAGE=$(git log -1 --pretty=%B)

# Skip build flag
if echo "$MESSAGE" | grep -Eq "\bskip[-_ ]?build\b"; then
  echo "⏭ Build skipped via commit message"
  exit 0
fi

# --------------------------------------------------
# Dynamically load build args from cred.yml file
# --------------------------------------------------
BUILD_ARGS=""
CRED_FILE="${DOCKER_CRED_FILE:-cred.yml}"

if [ -f "$CRED_FILE" ]; then
  echo "📄 Loading build args from $CRED_FILE..."

  # Require yq for YAML parsing
  if ! command -v yq >/dev/null 2>&1; then
    echo "❌ 'yq' is required to parse cred.yml but was not found."
    echo "👉 Install it: https://github.com/mikefarah/yq#install"
    exit 1
  fi

  while IFS="=" read -r KEY VALUE; do
    [ -z "$KEY" ] && continue
    if [ -z "$VALUE" ]; then
      echo "  ⚠️  Skipping $KEY — no value set"
      continue
    fi
    BUILD_ARGS="$BUILD_ARGS --build-arg $KEY=$VALUE"
    echo "  ✔ $KEY"
  done < <(yq e '. | to_entries | .[] | .key + "=" + .value' "$CRED_FILE")
else
  echo "⚠️  No cred.yml found at '$CRED_FILE' — building without build args"
fi

# --------------------------------------------------
# Run Docker build
# --------------------------------------------------
echo "🔨 Building Docker image..."
docker build $BUILD_ARGS -t precommit-check .

echo "✅ Docker build successful"
exit 0
EOF

chmod +x scripts/*.sh
echo "✔ Hook scripts created"
# --------------------------------------------------
# 5. Install pre-commit hooks
# --------------------------------------------------
echo "🔗 Installing pre-commit hooks..."
pre-commit install --hook-type commit-msg || true
pre-commit install --hook-type pre-push || true
echo "🎉 Pre-commit bootstrap complete"
