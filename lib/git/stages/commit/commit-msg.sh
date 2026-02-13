#!/usr/bin/env bash
# =============================================================================
# commit/commit-msg.sh - Commit message validation stage
# =============================================================================
# Validates commit message format and content after editing:
#   - Check for minimum length
#   - Enforce conventional commit format
#   - Check for sensitive information
# =============================================================================
set -euo pipefail

# Validate commit message
validate_commit_message() {
    local commit_msg_file="$1"

    # Read commit message
    local commit_msg
    commit_msg=$(command cat "$commit_msg_file")

    # Skip validation for merge commits, etc.
    if [[ "$commit_msg" =~ ^(Merge|Revert|fixup!|squash!) ]]; then
        return 0
    fi

    local failed=0

    # Check minimum length
    if [[ ${#commit_msg} -lt 10 ]]; then
        log_error "Commit message too short (minimum 10 characters)"
        failed=1
    fi

    # Check for conventional commit format (optional)
    if [[ "${GIT_ENFORCE_CONVENTIONAL_COMMITS:-}" == "1" ]]; then
        if ! [[ "$commit_msg" =~ ^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: ]]; then
            log_error "Commit message should follow conventional commit format:"
            echo "   <type>(<scope>): <description>" >&2
            echo "   Types: feat, fix, docs, style, refactor, test, chore" >&2
            failed=1
        fi
    fi

    # Check for sensitive keywords
    if [[ "$commit_msg" =~ (password|secret|key|token) ]]; then
        log_warning "Commit message contains sensitive keywords"
    fi

    if [[ $failed -eq 1 ]]; then
        echo "" >&2
        echo "To bypass commit message validation:" >&2
        echo "   git commit --no-verify -m \"message\"" >&2
        return 1
    fi

    return 0
}
