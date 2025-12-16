#!/bin/bash

set -e

echo "🔍 Validating commit message for JIRA ticket..."

COMMIT_MSG_FILE="$1"
MESSAGE=$(cat "$COMMIT_MSG_FILE")

# # Allow commit if it contains "skip-build" anywhere
# if echo "$MESSAGE" | grep -Eiq "skip-build"; then
#   echo "⏭ Build skipping flag detected (skip-build)."
#   echo "✔ Commit allowed (skip build mode)"
#   exit 0
# fi

# Validate JIRA ticket at start: ABC-123
if ! echo "$MESSAGE" | grep -Eq "^[A-Z]+-[0-9]+"; then
  echo ""
  echo "❌ Commit rejected!"
  echo "👉 Please include a JIRA ticket number in the commit message"
  echo "   Example: ABC-123 - Added new feature"
  echo ""
  exit 1
fi

echo "✔ Commit message contains valid JIRA ticket"
exit 0
