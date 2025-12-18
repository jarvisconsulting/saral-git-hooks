#!/bin/bash
set -e

echo "🔍 Validating commit message for JIRA ticket..."

COMMIT_MSG_FILE="$1"
MESSAGE=$(cat "$COMMIT_MSG_FILE")

# Validate JIRA ticket anywhere in the message
if ! echo "$MESSAGE" | grep -Eq "[A-Z]+-[0-9]+"; then
  echo ""
  echo "❌ Commit rejected!"
  echo "👉 Please include a JIRA ticket number in the commit message"
  echo "   Example: Added new feature (ABC-123)"
  echo ""
  exit 1
fi

echo "✔ Commit message contains valid JIRA ticket"
exit 0
