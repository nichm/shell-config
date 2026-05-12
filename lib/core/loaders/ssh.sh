#!/usr/bin/env bash
# =============================================================================
# core/loaders/ssh.sh - SSH Agent Loader
# =============================================================================
# Configures SSH_AUTH_SOCK and silently loads keys from macOS Keychain.
#
# Supports two auth modes (auto-detected):
#   1Password: sets SSH_AUTH_SOCK to 1Password socket
#   macOS Keychain: uses system launchd agent + UseKeychain yes in ssh-config
#
# Either way, ssh-add --apple-load-keychain runs on macOS so the agent is
# never empty — prevents terminal passphrase prompts in TUI tools (Claude
# Code, vim, etc.) when git subprocesses trigger SSH auth.
#
# Opt-out of 1Password mode: export SHELL_CONFIG_1PASSWORD_SSH=false
# =============================================================================
# NOTE: No set -euo pipefail — this file is sourced into interactive shells.

# 1Password SSH agent socket path
_1P_SSH_AGENT_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

_load_ssh() {
    local debug=${SHELL_DEBUG:-0}
    local use_1p="${SHELL_CONFIG_1PASSWORD_SSH:-auto}"

    # --- Step 1: Configure SSH_AUTH_SOCK ---
    if [[ "$use_1p" != "false" ]] && [[ -S "$_1P_SSH_AGENT_SOCK" ]]; then
        export SSH_AUTH_SOCK="$_1P_SSH_AGENT_SOCK"
        [[ $debug -eq 1 ]] && echo "🔑 SSH: 1Password agent configured"
    elif [[ "$use_1p" == "true" ]]; then
        echo "⚠️  WARNING: 1Password SSH agent socket not found" >&2
        echo "ℹ️  WHY: SSH keys will not be available for git/ssh operations" >&2
        echo "💡 FIX: Enable the SSH agent in 1Password and ensure the app is running" >&2
        echo "💡 FIX: Expected socket: $_1P_SSH_AGENT_SOCK" >&2
    else
        [[ $debug -eq 1 ]] && echo "🔑 SSH: using macOS system agent"
    fi

    # --- Step 2: Load keys from macOS Keychain into agent (macOS only) ---
    # Silently pre-loads all keychain-stored passphrases so the agent is never
    # empty. Without this, TUI tools (Claude Code, etc.) get a passphrase prompt
    # mid-render when their git subprocesses trigger SSH auth.
    if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
        ssh-add --apple-load-keychain 2>/dev/null || true
        [[ $debug -eq 1 ]] && {
            local count
            count=$(ssh-add -l 2>/dev/null | wc -l | tr -d ' ')
            echo "🔑 SSH: ${count} keychain identit(ies) loaded"
        }
    fi
}

_load_ssh
