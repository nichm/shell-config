#!/usr/bin/env bash
# =============================================================================
# ⚙️  GIT HOOKS CONFIGURATION - Centralized Settings
# =============================================================================
# Single source of truth for all git hook environment variables.
# Source this file in all hook scripts to access configuration.
# Usage:
#   source "${SHARED_DIR}/config.sh"
#   # Then use variables like $GIT_SKIP_HOOKS, $MAX_FILE_SIZE, etc.
# User override file: ~/.git-hooks-config.sh (optional)
# =============================================================================
set -euo pipefail

# =============================================================================
# HOOK BYPASS FLAGS
# =============================================================================

# Skip all pre-commit checks (emergency use only)
# Default: unset (hooks run normally)
# Usage: GIT_SKIP_HOOKS=1 git commit -m "message"
GIT_SKIP_HOOKS="${GIT_SKIP_HOOKS:-0}"

# =============================================================================
# INDIVIDUAL CHECK BYPASSES
# =============================================================================

# Skip file length validation (>600 lines check)
# Default: unset (file length check runs)
# Usage: GIT_SKIP_FILE_LENGTH_CHECK=1 git commit -m "message"
GIT_SKIP_FILE_LENGTH_CHECK="${GIT_SKIP_FILE_LENGTH_CHECK:-0}"

# Skip TypeScript type checking (tsc --noEmit)
# Default: unset (tsc runs if tsconfig.json exists)
# Usage: GIT_SKIP_TSC_CHECK=1 git commit -m "message"
GIT_SKIP_TSC_CHECK="${GIT_SKIP_TSC_CHECK:-0}"

# Skip Python type checking (mypy)
# Default: unset (mypy runs if pyproject.toml or mypy.ini exists)
# Usage: GIT_SKIP_MYPY_CHECK=1 git commit -m "message"
GIT_SKIP_MYPY_CHECK="${GIT_SKIP_MYPY_CHECK:-0}"

# Skip circular dependency detection (dpdm)
# Default: unset (circular dep check runs)
# Usage: GIT_SKIP_CIRCULAR_DEPS=1 git commit -m "message"
GIT_SKIP_CIRCULAR_DEPS="${GIT_SKIP_CIRCULAR_DEPS:-0}"

# Skip infrastructure validation (Terraform, Kubernetes, Docker configs)
# Default: unset (infra validation runs)
# Usage: GIT_SKIP_INFRA_CHECK=1 git commit -m "message"
GIT_SKIP_INFRA_CHECK="${GIT_SKIP_INFRA_CHECK:-0}"

# =============================================================================
# AUTOMATED FIXES
# =============================================================================

# Auto-fix formatting errors and re-stage files
# Default: unset (formatting errors are warnings only)
# Usage: GIT_AUTO_FIX_FORMAT=1 git commit -m "message"
GIT_AUTO_FIX_FORMAT="${GIT_AUTO_FIX_FORMAT:-0}"

# =============================================================================
# COMMIT MESSAGE SETTINGS
# =============================================================================

# Auto-prepend conventional commit prefix based on branch name
# Default: 0 (disabled - commit messages are manual)
# Usage: GIT_AUTO_BRANCH_PREFIX=1 git commit
GIT_AUTO_BRANCH_PREFIX="${GIT_AUTO_BRANCH_PREFIX:-0}"

# Enforce conventional commits format (type(scope): subject)
# Default: 0 (disabled - conventional commits are optional)
# Usage: GIT_ENFORCE_CONVENTIONAL_COMMITS=1 git commit -m "feat: add feature"
GIT_ENFORCE_CONVENTIONAL_COMMITS="${GIT_ENFORCE_CONVENTIONAL_COMMITS:-0}"

# =============================================================================
# BLOCKING BEHAVIOR
# =============================================================================

# Block commit on formatting errors (instead of warning)
# Default: unset (formatting errors are warnings)
# Usage: GIT_BLOCK_FORMAT=1 git commit -m "message"
GIT_BLOCK_FORMAT="${GIT_BLOCK_FORMAT:-0}"

# Block commit on circular dependencies (instead of warning)
# Default: unset (circular deps are warnings)
# Usage: GIT_BLOCK_CIRCULAR_DEPS=1 git commit -m "message"
GIT_BLOCK_CIRCULAR_DEPS="${GIT_BLOCK_CIRCULAR_DEPS:-0}"

# =============================================================================
# FILE SIZE LIMITS
# =============================================================================

# Maximum file size in bytes (5MB default)
# Files larger than this are blocked from commit
# Usage: export MAX_FILE_SIZE=10485760  # 10MB
MAX_FILE_SIZE="${MAX_FILE_SIZE:-5242880}" # 5MB in bytes

# =============================================================================
# COMMIT SIZE THRESHOLDS
# =============================================================================

# Commit size tiers (files changed, lines changed)
# INFO: ≥15 files or ≥1000 lines (logged only)
# WARNING: ≥25 files or ≥3000 lines (warning displayed)
# EXTREME: ≥76 files or ≥5001 lines (BLOCKED - requires split)

COMMIT_SIZE_INFO_FILES="${COMMIT_SIZE_INFO_FILES:-15}"
COMMIT_SIZE_INFO_LINES="${COMMIT_SIZE_INFO_LINES:-1000}"

COMMIT_SIZE_WARNING_FILES="${COMMIT_SIZE_WARNING_FILES:-25}"
COMMIT_SIZE_WARNING_LINES="${COMMIT_SIZE_WARNING_LINES:-3000}"

COMMIT_SIZE_EXTREME_FILES="${COMMIT_SIZE_EXTREME_FILES:-76}"
COMMIT_SIZE_EXTREME_LINES="${COMMIT_SIZE_EXTREME_LINES:-5001}"

# =============================================================================
# GITLEAKS SETTINGS
# =============================================================================

# Gitleaks scan timeout per file (in seconds)
# Default: 5 seconds per file
GITLEAKS_TIMEOUT="${GITLEAKS_TIMEOUT:-5}"

# =============================================================================
# USER CONFIGURATION OVERRIDE
# =============================================================================

# Load user-specific configuration if it exists
# Users can create ~/.git-hooks-config.sh to override defaults
# SECURITY: Validates file ownership and permissions before sourcing
_load_user_config() {
    local user_config="$HOME/.git-hooks-config.sh"

    if [[ ! -f "$user_config" ]]; then
        return 0
    fi

    # Security checks: Verify file ownership and permissions
    local file_owner file_perms
    file_owner=$(stat -c '%u' -- "$user_config" 2>/dev/null || stat -f '%u' -- "$user_config" 2>/dev/null || echo "0")
    file_perms=$(stat -c '%a' -- "$user_config" 2>/dev/null || stat -f '%A' -- "$user_config" 2>/dev/null || echo "0")

    # Only load if owned by current user and not world-writable
    local current_uid
    current_uid=$(id -u)

    if [[ "$file_owner" != "$current_uid" ]]; then
        echo "WARNING: Skipping user config - file not owned by current user" >&2
        echo "  File: $user_config" >&2
        echo "  Owner UID: $file_owner, Current UID: $current_uid" >&2
        return 1
    fi

    # Check for world-writable permissions (octal last digit >= 2)
    if [[ "${file_perms: -1}" -ge 2 ]] 2>/dev/null; then
        echo "⚠️  WARNING: Skipping user config - file is world-writable" >&2
        echo "  File: $user_config" >&2
        echo "  Permissions: $file_perms" >&2
        echo "💡 FIX: Run: chmod o-w ~/.git-hooks-config.sh" >&2
        return 1
    fi

    # shellcheck source=/dev/null
    source "$user_config"
}

# Load user config automatically when this file is sourced
_load_user_config

# =============================================================================
# CONFIGURATION DISPLAY (for debugging)
# =============================================================================

# Show current configuration (useful for debugging)
# Usage: show_git_hooks_config
show_git_hooks_config() {
    echo "🪝 Git Hooks Configuration"
    echo ""
    echo "Hook Bypass Flags:"
    echo "  GIT_SKIP_HOOKS=$GIT_SKIP_HOOKS"
    echo "  GIT_SKIP_FILE_LENGTH_CHECK=$GIT_SKIP_FILE_LENGTH_CHECK"
    echo "  GIT_SKIP_TSC_CHECK=$GIT_SKIP_TSC_CHECK"
    echo "  GIT_SKIP_MYPY_CHECK=$GIT_SKIP_MYPY_CHECK"
    echo "  GIT_SKIP_CIRCULAR_DEPS=$GIT_SKIP_CIRCULAR_DEPS"
    echo "  GIT_SKIP_INFRA_CHECK=$GIT_SKIP_INFRA_CHECK"
    echo ""
    echo "Automated Fixes:"
    echo "  GIT_AUTO_FIX_FORMAT=$GIT_AUTO_FIX_FORMAT"
    echo ""
    echo "Commit Message Settings:"
    echo "  GIT_AUTO_BRANCH_PREFIX=$GIT_AUTO_BRANCH_PREFIX"
    echo "  GIT_ENFORCE_CONVENTIONAL_COMMITS=$GIT_ENFORCE_CONVENTIONAL_COMMITS"
    echo ""
    echo "Blocking Behavior:"
    echo "  GIT_BLOCK_FORMAT=$GIT_BLOCK_FORMAT"
    echo "  GIT_BLOCK_CIRCULAR_DEPS=$GIT_BLOCK_CIRCULAR_DEPS"
    echo ""
    echo "File Size Limits:"
    echo "  MAX_FILE_SIZE=$MAX_FILE_SIZE ($((MAX_FILE_SIZE / 1024 / 1024))MB)"
    echo ""
    echo "Commit Size Thresholds:"
    echo "  INFO: ≥${COMMIT_SIZE_INFO_FILES} files, ≥${COMMIT_SIZE_INFO_LINES} lines"
    echo "  WARNING: ≥${COMMIT_SIZE_WARNING_FILES} files, ≥${COMMIT_SIZE_WARNING_LINES} lines"
    echo "  EXTREME: ≥${COMMIT_SIZE_EXTREME_FILES} files, ≥${COMMIT_SIZE_EXTREME_LINES} lines"
    echo ""
    echo "Gitleaks Settings:"
    echo "  GITLEAKS_TIMEOUT=${GITLEAKS_TIMEOUT}s per file"
    echo ""
}
