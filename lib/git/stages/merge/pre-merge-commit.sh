#!/usr/bin/env bash
# =============================================================================
# merge/pre-merge-commit.sh - Pre-merge validation stage
# =============================================================================
# Runs before merge commits are created:
#   - Validate merge conditions
#   - Check for conflicts
#   - Verify merge prerequisites
# =============================================================================
set -euo pipefail

# Validate merge commit conditions
validate_merge_commit() {
    # Check if we're in a merge state
    if [[ -f .git/MERGE_HEAD ]]; then
        log_info "🔀 Validating merge commit..."

        # Check for unresolved conflicts
        if git diff --name-only --diff-filter=U | grep -q .; then
            log_error "Cannot create merge commit with unresolved conflicts"
            echo "   Resolve conflicts and stage changes first" >&2
            return 1
        fi

        # Additional merge validations can be added here
        # - Check merge commit message format
        # - Validate merged changes
        # - Check for breaking changes

        log_success "✅ Merge validation passed"
    fi

    return 0
}
