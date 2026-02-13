#!/usr/bin/env bash
# =============================================================================
# engine.sh - Command safety engine entry point
# =============================================================================
# Main entry point for the modular command safety system. Loads engine
# modules in dependency order: loader → utils → logging → display →
# matcher → wrapper. Requires Bash 5.x for modern features.
# Dependencies:
#   - engine/loader.sh - Directory setup and rule loading
#   - engine/utils.sh - Utility functions
#   - engine/logging.sh - Violation logging
#   - engine/display.sh - User feedback display
#   - engine/matcher.sh - Pattern matching engine
#   - engine/wrapper.sh - Command wrapper functions
# Environment Variables:
#   COMMAND_SAFETY_DIR - Path to command-safety module directory
#   SHELL_CONFIG_DIR - Shell config installation directory
#   _COMMAND_SAFETY_DIR - Internal engine directory path
# Architecture:
#   Modular design with each engine module handling a specific concern.
#   Modules must be loaded in dependency order.
# Usage:
#   Source this file from command-safety/init.sh
#   Engine initializes automatically and loads all submodules
# =============================================================================

# Prefer COMMAND_SAFETY_DIR from init.sh, fallback to path detection
if [[ -n "${COMMAND_SAFETY_DIR:-}" ]]; then
    _COMMAND_SAFETY_DIR="$COMMAND_SAFETY_DIR"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _COMMAND_SAFETY_DIR="$SHELL_CONFIG_DIR/lib/command-safety"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    # shellcheck disable=SC2296,SC2298
    _COMMAND_SAFETY_DIR="${${(%):-%x}:A:h}"
elif [[ -n "${BASH_VERSION:-}" ]]; then
    _COMMAND_SAFETY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    echo "⚠️  Command safety: Cannot determine directory" >&2
    return 1
fi

# Load modules in order (each depends on previous)
# shellcheck source=./engine/loader.sh
source "$_COMMAND_SAFETY_DIR/engine/loader.sh" || return 1
# shellcheck source=./engine/utils.sh
source "$_COMMAND_SAFETY_DIR/engine/utils.sh" || return 1
# shellcheck source=./engine/logging.sh
source "$_COMMAND_SAFETY_DIR/engine/logging.sh" || return 1
# shellcheck source=./engine/display.sh
source "$_COMMAND_SAFETY_DIR/engine/display.sh" || return 1
# shellcheck source=./engine/matcher.sh
source "$_COMMAND_SAFETY_DIR/engine/matcher.sh" || return 1
# shellcheck source=./engine/wrapper.sh
source "$_COMMAND_SAFETY_DIR/engine/wrapper.sh" || return 1

command_safety_init() {
    [[ "$COMMAND_SAFETY_ENABLED" != true ]] && return 0

    local commands=() cmd_output
    cmd_output=$(_get_wrapper_commands)
    while IFS= read -r cmd; do [[ -n "$cmd" ]] && commands+=("$cmd"); done <<<"$cmd_output"
    [[ ${#commands[@]} -eq 0 ]] && {
        echo "⚠️  No protected commands found" >&2
        return 0
    }

    for cmd in "${commands[@]}"; do
        _generate_wrapper "$cmd" || echo "⚠️  Failed wrapper: $cmd" >&2
    done
}
