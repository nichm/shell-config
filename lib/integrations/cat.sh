#!/usr/bin/env bash
# =============================================================================
# cat.sh - Enhanced cat with syntax highlighting
# =============================================================================
# Provides an enhanced cat function that prefers syntax highlighting tools
# (bat, ccat, pygmentize) over standard cat, with graceful fallback.
# Dependencies:
#   - bat (preferred) - Install: brew install bat
#   - ccat (fallback) - Install: brew install ccat
#   - pygmentize (fallback) - Install: pip install pygments
#   - Standard cat (always available)
# Function:
#   cat - Enhanced cat with automatic syntax highlighting
# Usage:
#   Source this file from shell init - cat function is overridden automatically
#   Use cat normally - it will use bat/ccat/pygmentize if available
# =============================================================================

# Load command cache for optimized tool checking
if [[ -f "$SHELL_CONFIG_DIR/lib/core/command-cache.sh" ]]; then
    source "$SHELL_CONFIG_DIR/lib/core/command-cache.sh"
fi

# =============================================================================
# ENHANCED CAT FUNCTION
# =============================================================================
# Tries bat → ccat → pygmentize → standard cat
# Usage: cat [options] [file ...]
cat() {
    # Try bat first (best syntax highlighting)
    if command_exists "bat"; then
        bat "$@"
        return $?
    fi

    # Try ccat second (good syntax highlighting)
    if command_exists "ccat"; then
        ccat "$@"
        return $?
    fi

    # Try pygmentize third (basic syntax highlighting)
    if command_exists "pygmentize"; then
        # Check if file is readable
        if [[ $# -eq 1 && -r "$1" ]]; then
            pygmentize "$@" 2>/dev/null || command cat "$@"
        else
            # For multiple files or piped input, use standard cat
            command cat "$@"
        fi
        return $?
    fi

    # Fallback to standard cat (always available)
    command cat "$@"
}

# Export the cat function for subshells (bash only)
# NOTE: In zsh, `export -f` is interpreted as `typeset -gx -f` which PRINTS the
# function definition to stdout. The BASH_VERSION guard prevents this leak.
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f cat 2>/dev/null || true
fi
