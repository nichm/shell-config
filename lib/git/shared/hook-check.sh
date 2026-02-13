#!/usr/bin/env bash
# =============================================================================
# 🔗 Hook Check Utilities - Shared Git Hook Validation
# =============================================================================
# Provides consistent hook symlink checking across doctor.sh and git-hooks-status.sh
# Returns structured status codes for flexible output formatting by callers.
# Design:
#   - Returns structured status (valid/missing/wrong_target/file_not_symlink)
#   - Callers format output appropriately (doctor.sh: verbose, git-hooks-status.sh: icons)
#   - Single source of truth for hook validation logic
# Usage:
#   check_hook_symlink "pre-commit"  # Returns: valid, missing, wrong_target, or file_not_symlink
# NOTE: No set -euo pipefail — sourced by welcome/git-hooks-status.sh into interactive shells
# =============================================================================

# Prevent double-sourcing
[[ -n "${_HOOK_CHECK_LOADED:-}" ]] && return 0
readonly _HOOK_CHECK_LOADED=1

# =============================================================================
# Constants
# =============================================================================
readonly _HOOK_CHECK_INSTALL_DIR="${HOME}/.githooks"

# =============================================================================
# Check Hook Symlink Status
# =============================================================================
# Checks if a git hook is properly symlinked to shell-config
# Args:
#   $1 - Hook name (e.g., "pre-commit", "commit-msg", "pre-push")
# Returns (via echo):
#   "valid"         - Hook is a symlink pointing to shell-config
#   "missing"       - Hook file doesn't exist
#   "wrong_target"  - Hook is a symlink but not pointing to shell-config
#   "file_not_symlink" - Hook exists but is a regular file, not a symlink
# Usage:
#   status=$(check_hook_symlink "pre-commit")
#   case "$status" in
#       valid) echo "✅ Hook is properly configured" ;;
#       missing) echo "❌ Hook not installed" ;;
#       # ... etc
#   esac
check_hook_symlink() {
    local hook_name="$1"
    local hook_path="${_HOOK_CHECK_INSTALL_DIR}/${hook_name}"

    # Determine expected target based on SHELL_CONFIG_DIR
    local expected_target
    if [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
        expected_target="${SHELL_CONFIG_DIR}/lib/git/hooks/${hook_name}"
    elif [[ -d "${HOME}/.shell-config" ]]; then
        expected_target="${HOME}/.shell-config/lib/git/hooks/${hook_name}"
    else
        echo "missing"
        return 0
    fi

    # Check if hook exists
    if [[ ! -e "$hook_path" ]]; then
        echo "missing"
        return 0
    fi

    # Check if hook is a symlink
    if [[ ! -L "$hook_path" ]]; then
        echo "file_not_symlink"
        return 0
    fi

    # Check if symlink points to correct target
    local actual_target
    actual_target="$(readlink "$hook_path")"

    # Handle both relative and absolute symlinks
    if [[ "$actual_target" == *"shell-config"* ]] || [[ "$actual_target" == "$expected_target" ]]; then
        echo "valid"
        return 0
    else
        echo "wrong_target"
        return 0
    fi
}

# =============================================================================
# Check All Standard Hooks
# =============================================================================
# Returns array of hook names that should be installed
# Usage:
#   hooks=($(get_standard_hooks))
#   for hook in "${hooks[@]}"; do
#       check_hook_symlink "$hook"
#   done
get_standard_hooks() {
    echo "pre-commit"
    echo "commit-msg"
    echo "prepare-commit-msg"
    echo "post-commit"
    echo "pre-push"
    echo "pre-merge-commit"
    echo "post-merge"
}

# =============================================================================
# Batch Check Hooks
# =============================================================================
# Check multiple hooks and return summary
# Args:
#   $@ - Hook names to check (optional, defaults to standard hooks)
# Returns:
#   Number of hooks that are valid
# Usage:
#   valid_count=$(check_hooks_batch "pre-commit" "commit-msg")
check_hooks_batch() {
    local hooks=("$@")
    local valid_count=0

    # If no hooks specified, check all standard hooks
    if [[ ${#hooks[@]} -eq 0 ]]; then
        # Cross-shell: mapfile is bash-only, zsh uses ${(@f)...} for line splitting
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            # shellcheck disable=SC2296  # zsh-specific line splitting expansion
            hooks=("${(@f)$(get_standard_hooks)}")
        else
            mapfile -t hooks < <(get_standard_hooks)
        fi
    fi

    for hook in "${hooks[@]}"; do
        local status
        status=$(check_hook_symlink "$hook")
        if [[ "$status" == "valid" ]]; then
            ((valid_count++))
        fi
    done

    echo "$valid_count"
}
