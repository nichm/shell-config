#!/usr/bin/env bash
# =============================================================================
# auto.sh - GHLS auto-runner for GitHub directory navigation
# =============================================================================
# Automatically runs ghls (GitHub ls) when changing into ~/github directories.
# Uses zsh's chpwd_functions hook to detect directory changes and displays
# repository status in fast mode (without PR counts for performance).
# Dependencies:
#   - ghls - GitHub ls tool (must be in PATH)
#   - zsh - Uses chpwd_functions hook (bash not supported)
# Environment Variables:
#   _LAST_GHLS_DIR - Tracks last directory to avoid redundant runs
# Features:
#   - Auto-runs ghls when cd'ing into ~/github or ~/github/*
#   - Fast mode (--fast flag) skips PR counting for better performance
#   - Deduplication prevents running twice in same directory
# Usage:
#   Source this file from shell init - automatically hooks into chpwd
#   Manually run: ghls . --fast
# =============================================================================

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

_LAST_GHLS_DIR=""

_run_ghls_if_in_github() {
    # Silent return: ghls is optional feature, called from prompt hook
    command_exists "ghls" || return 0
    case "$PWD" in
        ~/github | ~/github/*)
            [[ "$_LAST_GHLS_DIR" == "$PWD" ]] && return 0
            ghls . --fast 2>/dev/null
            _LAST_GHLS_DIR="$PWD"
            ;;
        *) _LAST_GHLS_DIR="" ;;
    esac
}

# Use ${chpwd_functions[@]:-} to avoid "parameter not set" errors with set -u
# shellcheck disable=SC2206  # Zsh-specific array assignment syntax
[[ -n "${ZSH_VERSION:-}" ]] && chpwd_functions=(${chpwd_functions[@]:-} _run_ghls_if_in_github)
