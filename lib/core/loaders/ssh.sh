#!/usr/bin/env bash
# =============================================================================
# core/loaders/ssh.sh - SSH Agent Loader
# =============================================================================
# Configures SSH_AUTH_SOCK for the 1Password SSH agent.
# Usage:
#   source "$SHELL_CONFIG_DIR/lib/core/loaders/ssh.sh"
# =============================================================================

# 1Password SSH agent socket
_1P_SSH_AGENT_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

_load_ssh() {
    local debug=${SHELL_DEBUG:-0}

    # Opt out: export SHELL_CONFIG_1PASSWORD_SSH=false in ~/.zshenv or before init
    local use_1p="${SHELL_CONFIG_1PASSWORD_SSH:-auto}"
    [[ "$use_1p" == "false" ]] && return 0

    if [[ -S "$_1P_SSH_AGENT_SOCK" ]]; then
        export SSH_AUTH_SOCK="$_1P_SSH_AGENT_SOCK"
        [[ $debug -eq 1 ]] && echo "1Password SSH agent configured"
        return 0
    fi

    # Only warn if user explicitly enabled 1Password SSH (auto = silent skip)
    if [[ "$use_1p" == "true" ]]; then
        echo "⚠️  WARNING: 1Password SSH agent socket not found" >&2
        echo "ℹ️  WHY: SSH keys will not be available for git/ssh operations" >&2
        echo "💡 FIX: Enable the SSH agent in 1Password and ensure the app is running" >&2
        echo "💡 FIX: Expected socket: $_1P_SSH_AGENT_SOCK" >&2
    fi
    return 0
}

_load_ssh
