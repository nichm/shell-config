#!/usr/bin/env bash
# =============================================================================
# 📂 File Scanner Utilities for Git Hooks
# =============================================================================
# Shared functions for scanning files in git repositories
# =============================================================================
set -euo pipefail

# Source canonical file operations (includes get_file_extension)
# shellcheck source=../../validation/shared/file-operations.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../validation/shared/file-operations.sh"

# =============================================================================
# Supported File Extensions (O(1) lookup using associative array)
# =============================================================================
# Optimized: Using Bash 5 associative array for constant-time extension matching
# instead of O(n) case statement with 20+ comparisons
declare -A _SUPPORTED_EXTENSIONS=(
    # JavaScript/TypeScript
    [js]=1 [ts]=1 [jsx]=1 [tsx]=1 [mjs]=1 [cjs]=1 [mts]=1 [cts]=1
    # Python
    [py]=1 [pyw]=1
    # Shell scripts
    [sh]=1 [bash]=1 [zsh]=1
    # Configuration
    [yml]=1 [yaml]=1 [json]=1
    # Other languages
    [rb]=1 [go]=1 [rs]=1 [java]=1 [kt]=1 [scala]=1
    [c]=1 [cpp]=1 [h]=1 [hpp]=1 [cs]=1 [php]=1 [swift]=1
)

# Get files changed in a commit range
# Usage: get_range_files "origin/main..HEAD"
get_range_files() {
    local range="$1"
    if [[ "$range" == "HEAD" ]]; then
        # First push - list all files in HEAD (--root needed for initial commit)
        # Filter to only files that exist in working directory
        git diff-tree --root --no-commit-id --name-only -r HEAD 2>/dev/null | while IFS= read -r file; do
            [[ -f "$file" ]] && echo "$file"
        done
    else
        # Normal case - diff between commits
        git diff --name-only "$range" 2>/dev/null
    fi
}

# Check if a file exists and is readable
# Usage: file_exists_and_readable "path/to/file"
file_exists_and_readable() {
    local file="$1"
    [[ -f "$file" && -r "$file" ]]
}

# Check if file is a supported type for scanning
# Usage: is_supported_file "path/to/file.ts"
is_supported_file() {
    local file="$1"
    local ext
    ext=$(get_file_extension "$file")
    [[ -z "$ext" ]] && return 1

    # O(1) associative array lookup when available, case-statement fallback
    # for subshells where declare -A doesn't transfer (e.g., bats run)
    if declare -p _SUPPORTED_EXTENSIONS &>/dev/null; then
        [[ -v "_SUPPORTED_EXTENSIONS[$ext]" ]]
    else
        case "$ext" in
            js|ts|jsx|tsx|mjs|cjs|mts|cts) return 0 ;;
            py|pyw) return 0 ;;
            sh|bash|zsh) return 0 ;;
            yml|yaml|json) return 0 ;;
            rb|go|rs|java|kt|scala) return 0 ;;
            c|cpp|h|hpp|cs|php|swift) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Filter files to only supported types
# Usage: filter_supported_files "${files[@]}"
filter_supported_files() {
    local files=("$@")
    local supported=()

    for file in "${files[@]}"; do
        if is_supported_file "$file" && file_exists_and_readable "$file"; then
            supported+=("$file")
        fi
    done

    printf '%s\n' "${supported[@]}"
}
