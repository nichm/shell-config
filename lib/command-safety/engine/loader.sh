#!/usr/bin/env bash
# =============================================================================
# loader.sh - Command safety rule loader and directory setup
# =============================================================================
# Initializes the command safety engine by setting up directory paths
# and loading all safety rules and registry. Must be loaded first
# before other command-safety modules.
# Dependencies:
#   - engine/registry.sh - Rule registration system
#   - rules.sh - Rule definitions aggregator
# Environment Variables:
#   _COMMAND_SAFETY_DIR - Internal engine directory path
#   COMMAND_SAFETY_DIR - External command-safety directory path
#   SHELL_CONFIG_DIR - Shell config installation directory
# Usage:
#   Source this file from command-safety/engine.sh
#   Automatically loads registry and rules modules
# =============================================================================

# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# where set -e would cause the shell to exit on any command failure.

# Use _COMMAND_SAFETY_DIR from parent, or compute it
if [[ -n "${_COMMAND_SAFETY_DIR:-}" ]]; then
    : # Already set by engine.sh
elif [[ -n "${COMMAND_SAFETY_DIR:-}" ]]; then
    _COMMAND_SAFETY_DIR="$COMMAND_SAFETY_DIR"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _COMMAND_SAFETY_DIR="$SHELL_CONFIG_DIR/lib/command-safety"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    # shellcheck disable=SC2296,SC2298
    _COMMAND_SAFETY_DIR="${${(%):-%x}:A:h:h}"
elif [[ -n "${BASH_VERSION:-}" ]]; then
    _COMMAND_SAFETY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
else
    echo "❌ ERROR: Cannot determine command-safety engine directory" >&2
    echo "ℹ️  WHY: Unsupported shell - neither BASH_VERSION nor ZSH_VERSION is set" >&2
    echo "💡 FIX: Source this file from bash or zsh shells only" >&2
    return 1
fi

# shellcheck source=./registry.sh
[[ -f "$_COMMAND_SAFETY_DIR/engine/registry.sh" ]] && source "$_COMMAND_SAFETY_DIR/engine/registry.sh" || {
    echo "❌ ERROR: registry.sh not found at $_COMMAND_SAFETY_DIR/engine/registry.sh" >&2
    echo "ℹ️  WHY: Command safety rule registration requires the registry module" >&2
    echo "💡 FIX: Reinstall shell-config or verify lib/command-safety/engine/registry.sh exists" >&2
    return 1
}

# shellcheck source=./rules.sh
[[ -f "$_COMMAND_SAFETY_DIR/rules.sh" ]] && source "$_COMMAND_SAFETY_DIR/rules.sh" || {
    echo "❌ ERROR: rules.sh not found at $_COMMAND_SAFETY_DIR/rules.sh" >&2
    echo "ℹ️  WHY: Command safety rules cannot be loaded without the rules aggregator" >&2
    echo "💡 FIX: Reinstall shell-config or verify lib/command-safety/rules.sh exists" >&2
    return 1
}
