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
    sudo apt-get install -y pre-commit

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
# Write .pre-commit-config.yaml
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
# Write hook scripts
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

# ---- docker-build.sh (ENHANCED WITH IMAGE HASH MAP) ----
cat > scripts/docker-build.sh <<'EOF'
#!/bin/bash
set -e

# ==================================================
# DOCKER IMAGE HASH MAP (Private → Public)
# ==================================================
# BJP-SARAL Custom Images → Public Alternatives
# ==================================================
declare -A IMAGE_MAP=(
  ["asia-south1-docker.pkg.dev/bjp-saral/custom-image/node:18"]="node:18-alpine"
  ["asia-south1-docker.pkg.dev/bjp-saral/custom-image/golang:1.25"]="golang:1.25-alpine"
  ["asia-south1-docker.pkg.dev/bjp-saral/custom-image/ubuntu:22.04"]="ubuntu:22.04"
  ["asia-south1-docker.pkg.dev/bjp-saral/custom-image/python:3.11"]="python:3.11-slim"
  ["asia-south1-docker.pkg.dev/bjp-saral/custom-image/distroless-base:debian12"]="distroless-base:debian12"
  ["asia-south1-docker.pkg.dev/bjp-saral/custom-image/node:16"]="node:16-alpine"
  ["asia-south1-docker.pkg.dev/bjp-saral/custom-image/alpine:3.18"]="alpine:3.18"
)

echo "🐳 Running Docker build validation..."

MESSAGE=$(git log -1 --pretty=%B)

# Skip build flag
if echo "$MESSAGE" | grep -Eq "\bskip[-_ ]?build\b"; then
  echo "⏭ Build skipped via commit message"
  exit 0
fi

DOCKERFILE="${DOCKERFILE_PATH:-Dockerfile}"
CRED_FILE="${DOCKER_CRED_FILE:-cred.yml}"
BUILD_ARGS=""

if [ ! -f "$DOCKERFILE" ]; then
  echo "❌ Dockerfile not found at '$DOCKERFILE'"
  exit 1
fi

# --------------------------------------------------
# Replace private images with public alternatives
# --------------------------------------------------
echo "🔄 Processing Docker image references..."

TEMP_DOCKERFILE=$(mktemp)
cp "$DOCKERFILE" "$TEMP_DOCKERFILE"

IMAGE_REPLACED=false

for PRIVATE_IMG in "${!IMAGE_MAP[@]}"; do
  PUBLIC_IMG="${IMAGE_MAP[$PRIVATE_IMG]}"
  
  if grep -q "$PRIVATE_IMG" "$TEMP_DOCKERFILE"; then
    echo "  🔄 Replacing: $PRIVATE_IMG"
    echo "     ➜ With:     $PUBLIC_IMG"
    sed -i "s|$PRIVATE_IMG|$PUBLIC_IMG|g" "$TEMP_DOCKERFILE"
    IMAGE_REPLACED=true
  fi
done

if [ "$IMAGE_REPLACED" = true ]; then
  echo "✔ Private images substituted"
fi

# --------------------------------------------------
# Verify substitutions
# --------------------------------------------------
echo ""
echo "📋 Verifying substitutions:"
echo "   FROM statements in temporary Dockerfile:"
grep -E "^FROM|^from" "$TEMP_DOCKERFILE" | sed 's/^/   /' || echo "   (No FROM statements found)"
echo ""

# --------------------------------------------------
# Extract ARG names declared in the Dockerfile
# --------------------------------------------------
DOCKERFILE_ARGS=$(grep -E "^ARG[[:space:]]+" "$TEMP_DOCKERFILE" \
  | sed 's/^ARG[[:space:]]*//' \
  | sed 's/=.*//' \
  | sed 's/[[:space:]]*$//' \
  | sort -u)

if [ -z "$DOCKERFILE_ARGS" ]; then
  echo "ℹ️  No ARG instructions found in Dockerfile — skipping cred.yml"
else
  echo "🔎 Dockerfile declares ARGs:"
  echo "$DOCKERFILE_ARGS" | sed 's/^/     /'

  if [ -f "$CRED_FILE" ]; then
    echo "📄 Matching build args from $CRED_FILE..."

    while IFS="=" read -r KEY VALUE; do
      [ -z "$KEY" ] && continue
      KEY=$(echo "$KEY" | tr -d ' ')
      VALUE=$(echo "$VALUE" | tr -d ' ')

      if echo "$DOCKERFILE_ARGS" | grep -qx "$KEY"; then
        if [ -z "$VALUE" ]; then
          echo "  ⚠️  Skipping $KEY — no value set in cred.yml"
          continue
        fi
        BUILD_ARGS="$BUILD_ARGS --build-arg $KEY=$VALUE"
        echo "  ✔ Injecting $KEY"
      else
        echo "  ⏭ Skipping $KEY — not declared as ARG in Dockerfile"
      fi
    done < <(grep -E "^\s*[^#[:space:]]" "$CRED_FILE" | sed 's/:[[:space:]]*/=/')

  else
    echo "⚠️  Dockerfile has ARGs but no cred.yml found at '$CRED_FILE'"
    echo "     Build will proceed — ARGs without --build-arg use their Dockerfile defaults"
  fi
fi

# --------------------------------------------------
# Run Docker build
# --------------------------------------------------
echo "🔨 Building Docker image..."
# shellcheck disable=SC2086
docker build $BUILD_ARGS -t precommit-check -f "$TEMP_DOCKERFILE" .

# Cleanup
rm -f "$TEMP_DOCKERFILE"

echo "✅ Docker build successful"
exit 0
EOF

chmod +x scripts/*.sh
echo "✔ Hook scripts created"

# --------------------------------------------------
# Write image-map.yml (Separate config file for easier maintenance)
# --------------------------------------------------
echo "📋 Creating image-map.yml for centralized image management..."
cat > image-map.yml <<'YAML'
# Docker Image Substitution Map - BJP-SARAL Project
# Format: private_image: public_image
# 
# Developers without access to asia-south1-docker.pkg.dev will use public alternatives
# This ensures CI/CD pipelines work across all team members

image_mappings:
  # Node.js images
  "asia-south1-docker.pkg.dev/bjp-saral/custom-image/node:18": "node:18-alpine"
  "asia-south1-docker.pkg.dev/bjp-saral/custom-image/node:16": "node:16-alpine"
  
  # Go images
  "asia-south1-docker.pkg.dev/bjp-saral/custom-image/golang:1.24": "golang:1.24-alpine"
  
  # Python images
  "asia-south1-docker.pkg.dev/bjp-saral/custom-image/python:3.11": "python:3.11-slim"
  "asia-south1-docker.pkg.dev/bjp-saral/custom-image/python:3.9": "python:3.9-slim"
  
  # Base OS images
  "asia-south1-docker.pkg.dev/bjp-saral/custom-image/ubuntu:22.04": "ubuntu:22.04"
  "asia-south1-docker.pkg.dev/bjp-saral/custom-image/alpine:3.18": "alpine:3.18"

# Usage in docker-build.sh:
# The associative array IMAGE_MAP is populated from the mappings above
YAML
echo "✔ image-map.yml created"

# --------------------------------------------------
# Update .gitignore
# --------------------------------------------------
echo "📝 Updating .gitignore..."
touch .gitignore

GITIGNORE_ENTRIES=(
  "scripts/"
  "cred.yml"
  ".pre-commit-config.yaml"
)

for ENTRY in "${GITIGNORE_ENTRIES[@]}"; do
  grep -qxF "$ENTRY" .gitignore || echo "$ENTRY" >> .gitignore
  echo "  ✔ $ENTRY"
done

echo "✔ .gitignore updated"

# --------------------------------------------------
# Install pre-commit hooks
# --------------------------------------------------
echo "🔗 Installing pre-commit hooks..."
pre-commit install --hook-type commit-msg || true
pre-commit install --hook-type pre-push || true
echo ""
echo "🎉 Pre-commit bootstrap complete!"
echo "✔ JIRA check enabled"
echo "✔ Docker build validation enabled"
echo "✔ Docker image substitution (asia-south1-docker.pkg.dev/bjp-saral/custom-image → public) enabled"
echo "✔ skip-build supported"
echo ""
echo "📖 Next steps:"
echo "   1. Review image-map.yml (shows your image mappings)"
echo "   2. Commit and push to test the hooks"
echo "   3. All developers can now build without bjp-saral registry access!"
