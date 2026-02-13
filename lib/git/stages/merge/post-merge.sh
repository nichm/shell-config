#!/usr/bin/env bash
# =============================================================================
# merge/post-merge.sh - Post-merge cleanup stage
# =============================================================================
# Runs after successful merge:
#   - Clean up merge state
#   - Update dependencies if needed
#   - Run post-merge tasks
# =============================================================================
set -euo pipefail

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Post-merge cleanup and tasks
run_post_merge_tasks() {
    local is_squash_merge="$1"

    if [[ -f .git/MERGE_HEAD ]]; then
        log_info "🔀 Merge completed successfully"

        # Clean up merge state files
        # (git automatically cleans up most files)

        # Run post-merge tasks
        if [[ -f "package.json" ]] && [[ "$is_squash_merge" != "1" ]]; then
            # Only run for regular merges, not squashes
            if command_exists "bun" && [[ -f "bun.lockb" ]]; then
                log_info "📦 Updating dependencies after merge..."
                bun install >/dev/null 2>&1 &
            fi
        fi
    fi

    return 0
}
