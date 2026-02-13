#!/usr/bin/env bash
# =============================================================================
# init.sh - Command safety system initialization
# =============================================================================
# Main entry point for the command safety system. Sources the engine
# and initializes command wrappers to protect against dangerous operations.
# Should be sourced from the main shell init script.
# Dependencies:
#   - command-safety/engine.sh - Main safety engine
# Environment Variables:
#   COMMAND_SAFETY_DIR - Path to command-safety module directory
#   SHELL_CONFIG_DIR - Shell config installation directory
# Features:
#   - Automatic path detection for bash/zsh
#   - Loads safety engine and rules
#   - Initializes command wrappers (git, rm, etc.)
# Usage:
#   Source this file from shell init: source ~/.shell-config/lib/command-safety/init.sh
#   Protection activates automatically after sourcing
# =============================================================================

# Prefer SHELL_CONFIG_DIR (set by main init.sh), fallback to path detection
if [[ -n "$SHELL_CONFIG_DIR" ]]; then
    COMMAND_SAFETY_DIR="$SHELL_CONFIG_DIR/lib/command-safety"
elif [[ -n "$ZSH_VERSION" ]]; then
    # zsh: use %x for sourced file path
    # shellcheck disable=SC2296,SC2298
    COMMAND_SAFETY_DIR="${${(%):-%x}:A:h}"
elif [[ -n "$BASH_VERSION" ]]; then
    COMMAND_SAFETY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    echo "❌ ERROR: Cannot determine command-safety directory" >&2
    echo "ℹ️  WHY: The command-safety feature cannot be initialized without its directory path" >&2
    echo "💡 FIX: Ensure this script is sourced from bash/zsh or that SHELL_CONFIG_DIR is set" >&2
    return 1
fi

[[ -f "$COMMAND_SAFETY_DIR/engine.sh" ]] && source "$COMMAND_SAFETY_DIR/engine.sh" || {
    echo "❌ ERROR: Command safety engine not found at $COMMAND_SAFETY_DIR/engine.sh" >&2
    echo "ℹ️  WHY: The engine.sh file is required to initialize command safety wrappers" >&2
    echo "💡 FIX: Verify shell-config is installed correctly or reinstall with ./install.sh" >&2
    return 1
}

# Initialize command wrappers
command_safety_init 2>/dev/null || true
