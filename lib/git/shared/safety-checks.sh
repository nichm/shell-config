#!/usr/bin/env bash
# =============================================================================
# DANGEROUS COMMANDS SAFETY CHECKS
# =============================================================================
# Safety checks for dangerous git operations that can cause data loss or
# rewrite history in destructive ways.
# Protected commands:
# - git reset --hard: Warns about permanent data loss
# - git push --force: Warns about overwriting collaborators' work
# - git rebase: Warns about history rewriting and conflicts
# All checks can be bypassed with --force-danger or --force-allow flags
# NOTE: No set -euo pipefail — sourced by wrapper.sh into interactive shells
# =============================================================================

# Note: This file is sourced by core.sh which sets $_GIT_WRAPPER_DIR
# and already sources utils/security-rules.sh for _show_warning function

# Run safety checks for dangerous commands
_run_safety_checks() {
    # Early return if no arguments
    [[ $# -eq 0 ]] && return 0

    local cmd="$1"
    shift

    # Check bypass flags first
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "--force-danger" ]] || [[ "$arg" == "--force-allow" ]]; then
            return 0
        fi
    done

    case "$cmd" in
        reset)
            for arg in "$@"; do
                if [[ "$arg" == "--hard" ]]; then
                    _show_warning "reset_hard"
                    return 1
                fi
            done
            ;;
        push)
            local has_force=false has_force_with_lease=false
            for arg in "$@"; do
                [[ "$arg" == "--force" || "$arg" == "-f" ]] && has_force=true
                [[ "$arg" == "--force-with-lease" ]] && has_force_with_lease=true
            done
            if [[ "$has_force" == "true" ]] && [[ "$has_force_with_lease" == "false" ]]; then
                _show_warning "push_force"
                return 1
            fi
            ;;
        rebase)
            _show_warning "rebase"
            return 1
            ;;
    esac
    return 0
}
