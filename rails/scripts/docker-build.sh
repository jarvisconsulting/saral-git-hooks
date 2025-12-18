#!/bin/bash
set -e

# 1. Load credentials
CRED_FILE="prepush-credentials.yml"

if [ ! -f "$CRED_FILE" ]; then
  echo "❌ Credentials file $CRED_FILE not found!"
  echo "👉 Please create it with the following format:"
  echo "rails_master_key: <your_rails_master_key>"
  echo "access_token: <your_access_token>"
  exit 1
fi

# Parse YAML (simple: key: value)
RAILS_MASTER_KEY=$(awk -F': ' '/rails_master_key/ {print $2}' "$CRED_FILE")
ACCESS_TOKEN=$(awk -F': ' '/access_token/ {print $2}' "$CRED_FILE")

if [ -z "$RAILS_MASTER_KEY" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Missing rails_master_key or access_token in $CRED_FILE"
  exit 1
fi


echo "🔐 Loaded credentials."
MESSAGE=$(git log -1 --pretty=%B)

# 3. Skip-build detection (regex)
# Matches: skip-build, skip build, skip_build
if echo "$MESSAGE" | grep -Eiq "skip[-_ ]?build"; then
  echo "⏭ Build skipped (matched skip-build regex)"
  exit 0
fi

# 4. Docker build
echo "🐳 Running Docker build..."

docker build \
  --build-arg _RAILS_MASTER_KEY="$RAILS_MASTER_KEY" \
  --build-arg _ACCESS_TOKEN="$ACCESS_TOKEN" \
  -t mlmp-app .

if [ $? -ne 0 ]; then
  echo "❌ Docker build failed — push blocked"
  exit 1
fi

echo "✅ Docker build success!"
exit 0
