#!/usr/bin/env bash
# =============================================================================
# 🛡️ COMMAND SAFETY ENGINE - UTILS MODULE
# =============================================================================
# Helper functions used by other modules
# Provides bypass flag detection, danger flag detection, and git repo checking
# =============================================================================

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# where set -e would cause the shell to exit on any command failure.

# Check if bypass flag exists in arguments
_has_bypass_flag() {
    local target_flag="$1"
    shift
    local args=("$@")

    for arg in "${args[@]}"; do
        if [[ "$arg" == "$target_flag" ]]; then
            return 0 # Found
        fi
    done
    return 1 # Not found
}

# Check if argument array contains dangerous flag combinations
_has_danger_flags() {
    local args=("$@")
    local has_recursive=false
    local has_force=false

    for arg in "${args[@]}"; do
        if [[ "$arg" == "-rf" ]] || [[ "$arg" == "-fr" ]]; then
            return 0 # Combined flag found
        elif [[ "$arg" == "-r" ]] || [[ "$arg" == "--recursive" ]]; then
            has_recursive=true
        elif [[ "$arg" == "-f" ]] || [[ "$arg" == "--force" ]]; then
            has_force=true
        fi
    done

    if [[ "$has_recursive" == true && "$has_force" == true ]]; then
        return 0
    fi
    return 1
}

# Git repo detection cache (performance optimization)
_GIT_REPO_CACHE=""
_GIT_REPO_CACHED_DIR=""

# Check if currently in a git repository (with caching for performance)
_in_git_repo() {
    # Check if git command exists first
    if ! command_exists "git"; then
        return 1
    fi

    local current_dir
    current_dir="$(pwd)"

    # Cache hit - same directory (avoid subprocess spawn)
    if [[ "$_GIT_REPO_CACHED_DIR" == "$current_dir" ]]; then
        [[ -n "$_GIT_REPO_CACHE" ]]
        return $?
    fi

    # Cache miss - check and update cache
    _GIT_REPO_CACHED_DIR="$current_dir"
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        _GIT_REPO_CACHE="1"
        return 0
    else
        _GIT_REPO_CACHE=""
        return 1
    fi
}
