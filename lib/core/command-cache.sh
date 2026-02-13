#!/usr/bin/env bash
# =============================================================================
# Command Cache - Optimized Command Existence Checking
# =============================================================================
# Caches command existence checks using Bash 4+ associative arrays to avoid
# repeated subshell spawns from `command -v` calls.
# Usage:
#   source "$SHELL_CONFIG_DIR/lib/core/command-cache.sh"
#   if command_exists "git"; then
#     echo "Git is available"
#   fi
# Requirements:
#   - Bash 4+ or Zsh 5+ (cross-shell associative arrays)
#   - Sourced after colors.sh (for logging functions)
# Performance Impact:
#   - First call: Same as `command -v` (one subshell spawn)
#   - Subsequent calls: Array lookup (0 subshell spawns)
#   - Example: In install.sh with 43 `command -v` calls, this reduces
#     subshell spawns from 43 to ~20 unique commands checked
# =============================================================================

# Guard against multiple sourcing
[[ -n "${_SHELL_CONFIG_COMMAND_CACHE_LOADED:-}" ]] && return 0
_SHELL_CONFIG_COMMAND_CACHE_LOADED=1

# =============================================================================
# CACHE STORAGE
# =============================================================================
# Associative array to cache command existence results
# Keys: command names
# Values: 1 (exists) or 0 (does not exist)
# Cross-shell: declare -gA works in bash 4+, typeset -gA works in zsh 5+
# Explicit =() initialization ensures clean empty state in both shells
if [[ -n "${ZSH_VERSION:-}" ]]; then
    typeset -gA _CMD_CACHE=()
else
    declare -gA _CMD_CACHE=()
fi

# =============================================================================
# API FUNCTIONS
# =============================================================================

# -----------------------------------------------------------------------------
# command_exists: Check if a command exists, using cache
# -----------------------------------------------------------------------------
# Arguments:
#   $1 - Command name to check
# Returns:
#   0 (true/success) if command exists
#   1 (false/failure) if command does not exist
# -----------------------------------------------------------------------------
# Usage:
#   if command_exists "git"; then
#     echo "Git is installed"
#   fi
# -----------------------------------------------------------------------------
command_exists() {
    # Validate arguments
    if [[ $# -ne 1 ]] || [[ -z "${1:-}" ]]; then
        echo "❌ ERROR: command_exists requires exactly 1 non-empty argument" >&2
        echo "ℹ️  WHY: Cannot check command existence without command name" >&2
        echo "💡 FIX: Use command_exists \"command_name\"" >&2
        return 2
    fi

    local cmd="$1"

    # Ensure _CMD_CACHE is an associative array (zsh compat)
    # If _CMD_CACHE was unset, re-declared as regular array, or never initialized,
    # ${(t)} won't contain "association" — re-declare to prevent
    # "assignment to invalid subscript range" errors.
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # shellcheck disable=SC2296  # ${(t)var} is zsh parameter type flag, not bash
        if [[ "${(t)_CMD_CACHE}" != *association* ]]; then
            typeset -gA _CMD_CACHE=()
        fi
    fi

    # Return cached result if available
    # Use ${+...} (parameter set check) instead of ${:-} for robustness
    if [[ -n "${_CMD_CACHE[$cmd]+x}" ]]; then
        [[ "${_CMD_CACHE[$cmd]}" -eq 1 ]]
        return $?
    fi

    # Check command existence and cache result
    if command -v "$cmd" >/dev/null 2>&1; then
        _CMD_CACHE[$cmd]=1
        return 0
    else
        _CMD_CACHE[$cmd]=0
        return 1
    fi
}

# -----------------------------------------------------------------------------
# command_cache_clear: Clear the command cache (for testing)
# -----------------------------------------------------------------------------
# Usage:
#   command_cache_clear
# -----------------------------------------------------------------------------
command_cache_clear() {
    # Cross-shell: re-declare to preserve associative type after clearing
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        typeset -gA _CMD_CACHE=()
    else
        _CMD_CACHE=()
    fi
}

# -----------------------------------------------------------------------------
# command_cache_stats: Show cache statistics (for debugging)
# -----------------------------------------------------------------------------
# Usage:
#   command_cache_stats
# -----------------------------------------------------------------------------
command_cache_stats() {
    local total=0
    local exists=0
    # Declare loop variable before loop (zsh compat - prevents re-declaration output)
    local result

    for result in "${_CMD_CACHE[@]}"; do
        ((total++))
        [[ "$result" -eq 1 ]] && ((exists++))
    done

    echo "⚡ Command Cache Stats:"
    echo "  Total cached: $total"
    echo "  Found: $exists"
    echo "  Not found: $((total - exists))"
}

# =============================================================================
# COMPATIBILITY SHIMS
# =============================================================================
# For scripts still using `command -v` directly, this is a drop-in
# replacement that caches results:
# Instead of:
#   command -v git >/dev/null 2>&1 && echo "found"
# Use:
#   command_exists "git" && echo "found"
# Both work identically, but command_exists caches results.
# =============================================================================

# Export functions for use in child subshells
# NOTE: The cache array (_CMD_CACHE) is NOT exported, so each subshell
# maintains its own cache. This is intentional for isolation.
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f command_exists command_cache_clear command_cache_stats 2>/dev/null || true
fi
