#!/usr/bin/env bash
# =============================================================================
# CLONE DUPLICATE CHECK
# =============================================================================
# Prevents accidental duplicate clones by checking if a repository already
# exists in ~/github before cloning.
# This helps avoid:
# - Multiple copies of the same repository
# - Confusion about which repository is active
# - Unnecessary disk space usage
# Bypass: Use --force-allow to override and clone anyway
# NOTE: No set -euo pipefail — sourced by wrapper.sh into interactive shells
# =============================================================================

# Note: This file is sourced by core.sh which sets $_GIT_WRAPPER_DIR
# and already sources utils/security-rules.sh for _get_rule_value function

# Check if repository already exists in ~/github
_check_existing_repo() {
    local args=("$@")
    local repo_name=""
    for arg in "${args[@]}"; do
        if [[ "$arg" == "https://"* ]] || [[ "$arg" == "git@"* ]]; then
            repo_name=$(basename "$arg" .git)
            break
        fi
    done
    if [[ -n "$repo_name" && -d "$HOME/github" ]]; then
        find "$HOME/github" -maxdepth 3 -type d -name "$repo_name" 2>/dev/null | head -1
    fi
}

# Run clone duplicate check
_run_clone_check() {
    local cmd="$1"
    shift
    local args=("$@")

    # Only check for clone commands
    [[ "$cmd" != "clone" ]] && return 0

    # Check if bypass flag is present
    for arg in "${args[@]}"; do
        if [[ "$arg" == "--force-allow" ]]; then
            return 0
        fi
    done

    local existing_repo
    existing_repo=$(_check_existing_repo "${args[@]}")
    if [[ -n "$existing_repo" ]]; then
        echo "" >&2
        echo "$(_get_rule_value "clone_dup" emoji): $(_get_rule_value "clone_dup" desc)" >&2
        echo "" >&2
        echo "Found at: $existing_repo" >&2
        echo "" >&2
        _get_rule_value "clone_dup" msg1 >&2
        local msg2_template
        msg2_template="$(_get_rule_value "clone_dup" msg2)"
        echo "${msg2_template//<repo_path>/$existing_repo}" >&2
        _get_rule_value "clone_dup" msg3 >&2
        _get_rule_value "clone_dup" msg4 >&2
        echo "" >&2
        echo "Use '$(_get_rule_value "clone_dup" bypass)' to override and clone anyway" >&2
        return 1
    fi

    return 0
}
