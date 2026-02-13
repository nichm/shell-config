#!/usr/bin/env bash
# =============================================================================
# commit/prepare-commit-msg.sh - Prepare commit message stage
# =============================================================================
# Runs before commit message editor opens:
#   - Can modify commit message template
#   - Add branch information
#   - Enforce commit message format
# =============================================================================
set -euo pipefail

# Prepare commit message
prepare_commit_message() {
    local commit_msg_file="$1"
    local commit_source="$2"
    local commit_sha="$3" # SHA-1 of commit being amended (only for commit source)

    # Log debug info for commit SHA when available
    if [[ -n "$commit_sha" && "$SHELL_CONFIG_DEBUG" == "1" ]]; then
        echo "DEBUG: prepare-commit-msg: amending commit $commit_sha" >&2
    fi

    # Add branch name prefixing for certain commit sources
    case "$commit_source" in
        message | template | merge | squash)
            # Get current branch name
            local branch_name
            if branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); then
                # Skip prefixing for main/master branches
                if [[ "$branch_name" != "main" && "$branch_name" != "master" ]]; then
                    # Add branch prefix to commit message
                    # Sanitize branch name to prevent sed injection
                    # Only allow alphanumeric, dash, underscore, and forward slash
                    local safe_branch
                    safe_branch=$(printf '%s' "$branch_name" | tr -cd '[:alnum:]/_-')
                    local prefix="[$safe_branch] "
                    if ! grep -qF "$prefix" "$commit_msg_file" 2>/dev/null; then
                        # Prepend branch name to first line using temp file (safer than sed -i)
                        local first_line
                        first_line=$(head -n1 "$commit_msg_file" 2>/dev/null || echo "")
                        if [[ -n "$first_line" && "$first_line" != "#"* ]]; then
                            (
                                tmp_file=$(mktemp)
                                trap 'command rm -f "$tmp_file"' EXIT INT TERM
                                printf '%s%s\n' "$prefix" "$first_line" >"$tmp_file"
                                tail -n +2 "$commit_msg_file" >>"$tmp_file" 2>/dev/null || true
                                command mv "$tmp_file" "$commit_msg_file" 2>/dev/null || true
                            )
                        fi
                    fi
                fi
            fi
            ;;
        commit)
            # For amend commits, SHA is provided but we don't modify the message
            # Could potentially validate commit message format here
            ;;
    esac

    return 0
}
