#!/bin/bash
set -euo pipefail

# Load Claude AI instructions from repository file into GitHub Actions environment variables
# Version: 1.0.1 - Repo-agnostic script with version bump and documentation
#
# This script loads the entire .github/prompts/claude-auto.txt file
# and sets it as the system prompt for Claude code review
#
# RELATED FILES (Repo-Agnostic Template):
# - .github/scripts/load-claude-instructions.sh (this file)
# - .github/workflows/claude-code-review2.yml (calls this script)
# - .github/prompts/claude-auto.txt (primary instructions file)
# - .github/prompts/claude-auto.md (fallback)
# - .github/claude-instructions.md (fallback)
#
# This script is designed to work in any repository. It:
# - Automatically finds instruction files using fallback paths
# - Loads content into GitHub Actions environment variables
# - Uses heredoc syntax for safe multiline content handling
# - Gracefully handles missing files (doesn't fail workflow)
#
# IMPORTANT: This script writes content directly to GITHUB_ENV using heredoc syntax.
# Variables written to GITHUB_ENV are only available in SUBSEQUENT steps.

# Check if instructions file exists (prefer text format, then markdown fallback)
INSTRUCTIONS_FILE=".github/prompts/claude-auto.txt"
if [[ ! -f "$INSTRUCTIONS_FILE" ]]; then
    INSTRUCTIONS_FILE=".github/prompts/claude-auto.md"
    if [[ ! -f "$INSTRUCTIONS_FILE" ]]; then
        INSTRUCTIONS_FILE=".github/claude-instructions.md"
    fi
fi

if [[ ! -f "$INSTRUCTIONS_FILE" ]]; then
    echo "⚠️ No Claude instructions file found (checked: .github/prompts/claude-auto.txt, .md, .github/claude-instructions.md)"
    echo "ℹ️ Claude will use default instructions"
    exit 0  # Don't fail, just use defaults
fi

echo "📖 Loading Claude AI instructions from: $INSTRUCTIONS_FILE"

# Load entire file content
INSTRUCTIONS=$(cat "$INSTRUCTIONS_FILE")

# Validate that content was loaded
if [[ -z "$INSTRUCTIONS" ]]; then
    echo "⚠️ Instructions file is empty"
    exit 0  # Don't fail, just use defaults
fi

# Set as GitHub Actions environment variable
if [[ -n "${GITHUB_ENV:-}" ]]; then
    # Running in GitHub Actions
    # Use heredoc syntax for multiline content (handles special characters safely)
    {
        echo "CLAUDE_SYSTEM_PROMPT<<CLAUDE_EOF"
        echo "$INSTRUCTIONS"
        echo "CLAUDE_EOF"
    } >> "$GITHUB_ENV"

    echo "✅ Instructions loaded directly (no base64 encoding needed)"
    echo "   - File: $INSTRUCTIONS_FILE"
    echo "   - Content: ${#INSTRUCTIONS} characters"
else
    # Running locally - just display the content
    echo "🔧 Running locally - would set environment variables in GitHub Actions:"
    echo "--- CLAUDE INSTRUCTIONS ---"
    echo "$INSTRUCTIONS"
    echo "--- END INSTRUCTIONS ---"
fi

echo "✅ Loaded Claude AI instructions:"
echo "   - Total content: ${#INSTRUCTIONS} characters"
echo "   - Environment variable set for Claude AI job"

