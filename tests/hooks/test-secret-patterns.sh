#!/bin/bash
# True positive tests — patterns that MUST match
assert_grep_match "TP: AWS Access Key ID" 'AKIA[0-9A-Z]{16}' "AKIAIOSFODNN7EXAMPLE"

# Runtime-constructed tokens (avoid GitHub Push Protection)
SLACK_PREFIX="xoxb-"
SLACK_BODY="123456789012-1234567890123-abcdef"
assert_grep_match "TP: Slack Bot Token" 'xoxb-[0-9]+-[A-Za-z0-9]+' "${SLACK_PREFIX}${SLACK_BODY}"

GH_PREFIX="ghp_"
GH_BODY="abcdefghijklmnopqrstuvwxyz1234567890"
assert_grep_match "TP: GitHub PAT" 'ghp_[A-Za-z0-9]{36}' "${GH_PREFIX}${GH_BODY}"

STRIPE_PREFIX="sk_live_"
STRIPE_BODY="abcdefghijklmnopqrstuvwx"
assert_grep_match "TP: Stripe Secret Key" 'sk_live_[A-Za-z0-9]{24,}' "${STRIPE_PREFIX}${STRIPE_BODY}"

GOOGLE_PREFIX="AIza"
GOOGLE_BODY="SyA1234567890abcdefghijklmnopqrstuv"
assert_grep_match "TP: Google API Key" 'AIza[A-Za-z0-9_-]{35}' "${GOOGLE_PREFIX}${GOOGLE_BODY}"

# False positive tests — patterns that must NOT match
assert_grep_no_match "FP: Normal base64" 'AKIA[0-9A-Z]{16}' "dGhpcyBpcyBhIHRlc3Q="
assert_grep_no_match "FP: Empty password" 'password\s*[:=]\s*["\x27][^"\x27]{8,}' 'password = ""'
assert_grep_no_match "FP: Short api key" 'api[_-]?key\s*[:=]\s*["\x27][^"\x27]{8,}' 'api_key = "short"'
