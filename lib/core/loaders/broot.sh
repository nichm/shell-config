#!/usr/bin/env bash
# =============================================================================
# broot.sh - Broot file browser launcher
# =============================================================================
# Provides a launcher function for broot, an interactive file tree
# visualization and navigation tool.
# Dependencies:
#   - broot - Install: brew install broot
# Function:
#   br - Launch broot file browser
# Usage:
#   Source this file from shell init - br function available immediately
#   Use br to launch interactive file browser
# =============================================================================

# Load command cache for optimized tool checking
if [[ -f "$SHELL_CONFIG_DIR/lib/core/command-cache.sh" ]]; then
    source "$SHELL_CONFIG_DIR/lib/core/command-cache.sh"
fi

# Check if broot is installed
if ! command_exists "broot"; then
    [[ -z "${BROOT_WARNING_SHOWN:-}" ]] && {
        echo "⚠️  broot not found. Install: brew install broot" >&2
        export BROOT_WARNING_SHOWN=1
    }
    return 0
fi

# =============================================================================
# BROOT LAUNCHER FUNCTION
# =============================================================================
# Launches broot interactive file browser
# Usage: br [path]
br() {
    broot "$@"
}
