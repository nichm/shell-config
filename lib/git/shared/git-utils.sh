#!/usr/bin/env bash
# =============================================================================
# Git Hooks Shared Library
# =============================================================================
# Common functions and constants for all git hooks.
# Eliminates code duplication and ensures consistency across hooks.
# Usage: source "$SCRIPT_DIR/shared/git-hooks-common.sh"
# Provides:
#   - Color definitions (sources lib/core/colors.sh)
#   - Logging functions (log_info, log_success, log_warning, log_error)
#   - Conventional commit types validation
#   - Package manager detection helpers
# =============================================================================
set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_GIT_HOOKS_COMMON_LOADED:-}" ]] && return 0
_GIT_HOOKS_COMMON_LOADED=1

# Source canonical colors library
# shellcheck source=../../core/colors.sh
source "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/core/colors.sh"

# Source command cache for optimized command existence checks
# shellcheck source=../../core/command-cache.sh
COMMAND_CACHE="$(dirname "${BASH_SOURCE[0]}")/../../core/command-cache.sh"
if [[ -f "$COMMAND_CACHE" ]]; then
    source "$COMMAND_CACHE"
fi

# Fallback: command_exists if sourcing failed
if ! declare -f command_exists >/dev/null; then
    command_exists() {
        command -v "$1" >/dev/null 2>&1
    }
fi

# =============================================================================
# Conventional Commit Types
# =============================================================================
# Standard conventional commits types with descriptions
# Used by commit-msg and prepare-commit-msg hooks
# =============================================================================

# Readonly array of valid conventional commit types
readonly CONVENTIONAL_TYPES=(
    "feat"     # New feature
    "fix"      # Bug fix
    "docs"     # Documentation changes
    "style"    # Code style changes (formatting, etc.)
    "refactor" # Code refactoring
    "perf"     # Performance improvements
    "test"     # Test changes
    "chore"    # Build process, tooling, dependencies
    "ci"       # CI/CD changes
    "build"    # Build system changes
    "revert"   # Revert previous commit
)

# Check if a type is a valid conventional commit type
# Usage: is_valid_conventional_type "feat"
is_valid_conventional_type() {
    local type="$1"
    for valid_type in "${CONVENTIONAL_TYPES[@]}"; do
        [[ "$type" == "$valid_type" ]] && return 0
    done
    return 1
}

# Get list of valid types as comma-separated string
# Usage: get_conventional_types_list # Returns: "feat, fix, docs, ..."
get_conventional_types_list() {
    local result=""
    local type
    for type in "${CONVENTIONAL_TYPES[@]}"; do
        [[ -n "$result" ]] && result+=", "
        result+="$type"
    done
    echo "$result"
}

# =============================================================================
# Package Manager Detection
# =============================================================================
# Helpers for detecting which package manager to use for dependency installation
# Used by post-merge hook
# =============================================================================

# Detect Node.js package manager based on lock files and available commands
# Returns: "bun" | "pnpm" | "yarn" | "npm" | ""
detect_nodejs_package_manager() {
    if command_exists "bun"; then
        echo "bun"
    elif [[ -f "pnpm-lock.yaml" ]] && command_exists "pnpm"; then
        echo "pnpm"
    elif [[ -f "yarn.lock" ]] && command_exists "yarn"; then
        echo "yarn"
    elif command_exists "npm"; then
        echo "npm"
    else
        echo ""
    fi
}

# =============================================================================
# Commit Message Validation
# =============================================================================
# Common validation functions for commit messages
# Used by commit-msg hook
# =============================================================================

# Note: command_exists is sourced from lib/core/command-cache.sh

# Check if subject line has proper blank line before body
# Usage: has_blank_line_after_subject "$commit_msg"
# Returns: 0 (true) if blank line exists, 1 (false) otherwise
has_blank_line_after_subject() {
    local commit_msg="$1"
    local second_line=""

    # Get the actual second line (not comments)
    # Use bash native filtering to avoid fork overhead
    local line_num=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comment lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        ((++line_num))
        if [[ $line_num -eq 2 ]]; then
            second_line="$line"
            break
        fi
    done <<<"$commit_msg"

    # If second line is empty or whitespace only, blank line exists
    [[ -z "$second_line" ]] || [[ "$second_line" =~ ^[[:space:]]*$ ]]
}

# Strip comments and empty lines from commit message
# Usage: strip_commit_comments "$commit_msg"
strip_commit_comments() {
    # Use bash native filtering to avoid fork overhead
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comment lines and empty lines (combined check for efficiency)
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
        printf '%s\n' "$line"
    done <<<"$1"
}

# =============================================================================
# Export Functions
# =============================================================================

if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f is_valid_conventional_type get_conventional_types_list 2>/dev/null || true
    export -f detect_nodejs_package_manager command_exists 2>/dev/null || true
    export -f has_blank_line_after_subject strip_commit_comments 2>/dev/null || true
fi
