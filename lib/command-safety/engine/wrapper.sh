#!/usr/bin/env bash
# =============================================================================
# 🛡️ COMMAND SAFETY ENGINE - WRAPPER MODULE
# =============================================================================
# Generates wrapper functions for protected commands
# =============================================================================

# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# where set -e would cause the shell to exit on any command failure.

# Get list of all commands that have rules defined
_get_all_protected_commands() {
    # Use pre-built list from rules/settings.sh (performance optimization)
    # This eliminates expensive `set | grep` on every shell init
    if [[ ${#COMMAND_SAFETY_PROTECTED_COMMANDS[@]} -gt 0 ]]; then
        printf '%s\n' "${COMMAND_SAFETY_PROTECTED_COMMANDS[@]}" | sort -u
        return 0
    fi

    # Fallback to registry if pre-built list is empty
    if [[ ${#COMMAND_SAFETY_RULE_COMMAND[@]} -gt 0 ]]; then
        printf '%s\n' "${COMMAND_SAFETY_RULE_COMMAND[@]}" | sort -u
    fi
}

# Auto-generate wrapper list from rules (data-driven approach)
_get_wrapper_commands() {
    # Use pre-built list from rules/settings.sh (performance optimization)
    # This is much faster than dynamic discovery via set | grep
    if [[ ${#COMMAND_SAFETY_PROTECTED_COMMANDS[@]} -gt 0 ]]; then
        printf '%s\n' "${COMMAND_SAFETY_PROTECTED_COMMANDS[@]}"
        return 0
    fi

    # Fallback: Get commands from rule definitions (data-driven)
    local commands_from_rules=()
    local cmd_output
    if ! cmd_output=$(_get_all_protected_commands 2>/dev/null) || [[ -z "$cmd_output" ]]; then
        echo "curl"
        return
    fi

    # Read command output into array properly
    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] && commands_from_rules+=("$cmd")
    done <<<"$cmd_output"

    # Ensure curl is included (even though it has no blocking rules)
    commands_from_rules+=("curl")

    # Output one command per line (CRITICAL: not space-separated!)
    printf '%s\n' "${commands_from_rules[@]}"
}

# Generate wrapper function for a command
_generate_wrapper() {
    local cmd="$1"

    # Validate cmd to prevent code injection
    # SAFE: cmd comes from hardcoded list in command_safety_init
    if [[ ! "$cmd" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "❌ ERROR: Invalid command name: $cmd" >&2
        echo "ℹ️  WHY: Command names must be alphanumeric to prevent code injection" >&2
        echo "💡 FIX: Ensure command names contain only letters, numbers, hyphens, and underscores" >&2
        return 1
    fi

    # Remove any existing alias (required in zsh before defining function)
    unalias "$cmd" 2>/dev/null || true

    # SAFE: cmd is validated above, $@ is properly quoted
    # _check_command_rules returns: 0=allow, 1=blocked, 2=no rules (allow)
    # Only return code 1 should block; 0 and 2 both allow the command through
    # NOTE: Uses "|| _cs_rc=$?" pattern to safely capture exit code under set -e.
    # Without this, set -e kills the function when _check_command_rules returns 2
    # (no rules matched), preventing the actual command from ever executing.
    # GUARD: If _check_command_rules is not loaded (partial init), fall through
    # to the real command instead of crashing with "command not found".
    eval "
    $cmd() {
        if typeset -f _check_command_rules >/dev/null 2>&1; then
            local _cs_rc=0
            _check_command_rules '$cmd' \"\$@\" || _cs_rc=\$?
            if [[ \$_cs_rc -eq 1 ]]; then
                return 1
            fi
        fi
        command $cmd \"\$@\"
    }
    "

    return 0
}
