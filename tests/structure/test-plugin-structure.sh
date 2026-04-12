#!/bin/bash
# --- Manifest validation ---
assert_json_valid "settings.json is valid JSON" ".claude/settings.json"

# --- File existence ---
assert_file_exists "Root CLAUDE.md" "CLAUDE.md"
assert_file_exists "ARCHITECTURE.md" "ARCHITECTURE.md"
assert_file_exists "docs/onboarding.md" "docs/onboarding.md"
assert_file_exists "docs/api-reference.md" "docs/api-reference.md"
assert_file_exists ".editorconfig" ".editorconfig"
assert_file_exists ".env.example" ".env.example"
assert_file_exists ".mcp.json" ".mcp.json"
assert_json_valid ".mcp.json is valid JSON" ".mcp.json"

# --- Script validation ---
assert_file_executable "setup.sh is executable" "scripts/setup.sh"
assert_bash_syntax "setup.sh valid bash" "scripts/setup.sh"
assert_file_executable "install-hooks.sh is executable" "scripts/install-hooks.sh"
assert_bash_syntax "install-hooks.sh valid bash" "scripts/install-hooks.sh"

# --- Command frontmatter ---
for cmd in review test-all deploy; do
    CMD_FILE=".claude/commands/$cmd.md"
    assert_file_exists "Command $cmd exists" "$CMD_FILE"
    CMD_CONTENT=$(cat "$CMD_FILE")
    assert_contains "Command $cmd: has frontmatter" "$CMD_CONTENT" "description:"
    assert_contains "Command $cmd: has allowed-tools" "$CMD_CONTENT" "allowed-tools:"
done

# --- Agent definitions ---
for agent in code-reviewer security-auditor; do
    assert_file_exists "Agent $agent exists" ".claude/agents/$agent.yml"
done

# --- CLAUDE.md content ---
SECTIONS=("Overview" "Tech Stack" "Project Structure" "Conventions" "Key Commands" "Auto-Sync Rules")
for section in "${SECTIONS[@]}"; do
    grep -qF "## $section" CLAUDE.md && pass "CLAUDE.md: has $section" || fail "CLAUDE.md: has $section" "not found"
done

# --- Module CLAUDE.md ---
MODULE_DIRS=(src/common src/api_server src/dispatcher src/price_watcher frontend helm/gpu-lotto)
for dir in "${MODULE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        assert_file_exists "$dir/CLAUDE.md" "$dir/CLAUDE.md"
    fi
done
