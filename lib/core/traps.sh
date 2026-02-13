#!/usr/bin/env bash
# =============================================================================
# 🔧 Shared Trap Handlers Library
# =============================================================================
# Common cleanup functions and trap handlers for temporary files
# Usage:
#   temp_file=$(mktemp)
#   trap_add_cleanup "$temp_file"
#   trap_set_standard
# =============================================================================
# Guard against multiple sourcing
[[ -n "${_SHELL_CONFIG_CORE_TRAPS_LOADED:-}" ]] && return 0
readonly _SHELL_CONFIG_CORE_TRAPS_LOADED=1

# =============================================================================
# CLEANUP TRACKING
# =============================================================================
declare -a _TRAP_CLEANUP_FILES=()
declare -a _TRAP_CLEANUP_DIRS=()

# Add a file to cleanup on exit
# Usage: trap_add_cleanup "/tmp/myfile"
trap_add_cleanup() {
    _TRAP_CLEANUP_FILES+=("$1")
}

# Add a directory to cleanup on exit
# Usage: trap_add_cleanup_dir "/tmp/mydir"
trap_add_cleanup_dir() {
    _TRAP_CLEANUP_DIRS+=("$1")
}

# =============================================================================
# CLEANUP FUNCTION
# =============================================================================
_trap_cleanup_handler() {
    # Clean up files
    for file in "${_TRAP_CLEANUP_FILES[@]}"; do
        [[ -f "$file" ]] && command rm -f "$file" 2>/dev/null || true
    done

    # Clean up directories
    for dir in "${_TRAP_CLEANUP_DIRS[@]}"; do
        [[ -d "$dir" ]] && command rm -rf "$dir" 2>/dev/null || true
    done

    # Reset arrays
    _TRAP_CLEANUP_FILES=()
    _TRAP_CLEANUP_DIRS=()
}

# =============================================================================
# STANDARD TRAP SETUP
# =============================================================================
# Set standard traps for EXIT, INT, TERM
# Usage: trap_set_standard
trap_set_standard() {
    trap _trap_cleanup_handler EXIT INT TERM
}

# =============================================================================
# SINGLE TEMP FILE PATTERN (Common case)
# =============================================================================
# Create a temp file with automatic cleanup
# Usage: temp_file=$(mktemp_with_cleanup)
mktemp_with_cleanup() {
    local temp_file
    temp_file=$(mktemp)
    trap_add_cleanup "$temp_file"
    trap_set_standard
    echo "$temp_file"
}

# Create a temp directory with automatic cleanup
# Usage: temp_dir=$(mktemp_dir_with_cleanup)
mktemp_dir_with_cleanup() {
    local temp_dir
    temp_dir=$(mktemp -d)
    trap_add_cleanup_dir "$temp_dir"
    trap_set_standard
    echo "$temp_dir"
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f trap_add_cleanup 2>/dev/null || true
    export -f trap_add_cleanup_dir 2>/dev/null || true
    export -f _trap_cleanup_handler 2>/dev/null || true
    export -f trap_set_standard 2>/dev/null || true
    export -f mktemp_with_cleanup 2>/dev/null || true
    export -f mktemp_dir_with_cleanup 2>/dev/null || true
fi
