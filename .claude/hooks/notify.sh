#!/bin/bash
# Send notifications via webhook on Claude Code events.
# Triggered by Notification events.
# Configure WEBHOOK_URL in .env or export it before use.

WEBHOOK_URL="${CLAUDE_NOTIFY_WEBHOOK:-}"
[ -z "$WEBHOOK_URL" ] && exit 0

EVENT="${1:-unknown}"
MESSAGE="${2:-Claude Code event occurred}"

# Build payload (use jq for safe JSON escaping, fall back to printf)
if command -v jq &>/dev/null; then
  PAYLOAD=$(jq -n \
    --arg text "[$EVENT] $MESSAGE" \
    --arg project "$(basename "$(pwd)")" \
    --arg branch "$(git branch --show-current 2>/dev/null || echo 'unknown')" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{text: $text, project: $project, branch: $branch, timestamp: $ts}')
else
  # Escape double quotes in variables for safe JSON
  SAFE_EVENT="${EVENT//\"/\\\"}"
  SAFE_MESSAGE="${MESSAGE//\"/\\\"}"
  PAYLOAD="{\"text\":\"[${SAFE_EVENT}] ${SAFE_MESSAGE}\",\"project\":\"$(basename "$(pwd)")\",\"branch\":\"$(git branch --show-current 2>/dev/null || echo unknown)\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
fi

# Send notification (non-blocking)
curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" > /dev/null 2>&1 &
