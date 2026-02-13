#!/usr/bin/env bash
# =============================================================================
# COMMAND PARSER UTILITY
# =============================================================================
# Extracts the real git command from arguments, skipping wrapper flags.
# This prevents bypassing safety checks when wrapper flags precede the command.
# Example: "git --skip-secrets commit" should recognize "commit" as the command
# Security: Prevents Issue #85 - wrapper flag bypass attacks
# Also prevents bypass using standard git flags (e.g., git -c config=val push)
# NOTE: No set -euo pipefail — sourced by wrapper.sh into interactive shells
# =============================================================================

# Get the real git command, skipping all flags until we find the command
# Cross-shell: uses for-loop iteration to avoid zsh 1-based array indexing issues
_get_real_git_command() {
    local skip_next=false
    local arg

    for arg in "$@"; do
        # If previous flag consumed this arg as its value, skip it
        if [[ "$skip_next" == true ]]; then
            skip_next=false
            continue
        fi

        # Check if this argument is a flag (starts with -)
        if [[ "$arg" == -* ]]; then
            # Some flags take the next argument as their value
            case "$arg" in
                --skip-* | --force-* | --allow-* | --no-verify)
                    # Shell-config wrapper flags — boolean, no value to skip
                    ;;
                -C | --git-dir | --work-tree)
                    # These git flags take the next argument as a value
                    skip_next=true
                    ;;
                -c)
                    # Config flag: -c key=value (separate arg)
                    skip_next=true
                    ;;
                *=* | -c*)
                    # Flag with inline value (e.g., --git-dir=/path, -ckey=val) — no skip
                    ;;
                *)
                    # Unknown flag — don't skip next arg (could be the command)
                    ;;
            esac
            continue
        fi

        # Found the first non-flag argument - this is the git command
        printf '%s\n' "$arg"
        return 0
    done

    # No valid command found (only flags provided)
    return 1
}
