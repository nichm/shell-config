#!/usr/bin/env bash
# =============================================================================
# secrets.sh - 1Password secrets loader and management
# =============================================================================
# Automatically loads environment variables from 1Password vault on shell
# startup. Uses a configuration file to map env vars to vault secrets.
# Provides commands to load, check status, and edit secrets configuration.
# Dependencies:
#   - op (1Password CLI) - Install: brew install 1password-cli
# Configuration:
#   ~/.config/shell-secrets.conf - Maps env vars to vault paths
#   Format: VAR_NAME=op://Vault/Item/field
# Environment Variables:
#   _OP_SECRETS_CONFIG - Path to secrets config file
#   _OP_LOADED_SECRETS - Array tracking loaded secret names
# Commands:
#   op-secrets-load - Force reload all secrets from vault
#   op-secrets-status - Show loaded secrets and auth status
#   op-secrets-edit - Open secrets config in $EDITOR
#   op-secrets-edit --no-prompt - Edit without reload prompt
#   op-secrets-edit --no-reload - Edit and skip auto-reload
# Features:
#   - Auto-load on shell startup if 1Password is authenticated
#   - Timeout protection (2s) to prevent shell hangs
#   - Session token caching for performance
#   - Clear error messages if auth fails
# Usage:
#   Source this file from shell init - auto-loads secrets
#   Manually load: op-secrets-load
# =============================================================================
# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# where set -e would cause the shell to exit on any command failure.

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

_OP_SECRETS_CONFIG="${_OP_SECRETS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/shell-secrets.conf}"
_OP_LOADED_SECRETS=()

# Check 1Password auth status (no prompts, with timeout to prevent hangs)
_op_check_auth() {
    # Silent return: internal helper, caller (op-secrets-load) provides WHAT/WHY/FIX error message
    command_exists "op" || return 1
    if command_exists "timeout"; then
        timeout "${SC_OP_TIMEOUT:-2}" op whoami &>/dev/null 2>&1
    else
        # Use single quotes and pass timeout as argument to prevent command injection
        perl -e 'alarm shift; exec @ARGV' "${SC_OP_TIMEOUT:-2}" op whoami &>/dev/null 2>&1
    fi
}

# Check for existing session token (no prompts)
_op_get_session() {
    # Silent return: internal helper, caller (op-secrets-load) provides WHAT/WHY/FIX error message
    command_exists "op" || return 1
    _op_check_auth && return 0

    local session_var="" session_token=""
    while IFS= read -r var || [[ -n "$var" ]]; do
        [[ -z "$var" ]] && continue
        session_var="$var"
        # Cross-shell indirect expansion: bash uses ${!var}, zsh uses ${(P)var}
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            # shellcheck disable=SC2296  # zsh-specific indirect expansion
            session_token="${(P)var:-}"
        else
            session_token="${!var:-}"
        fi
        [[ -n "$session_token" ]] && {
            export "$session_var=$session_token"
            _op_check_auth && return 0
            unset "$session_var"
        }
    done < <(env | grep -o '^OP_SESSION_[^=]*' 2>/dev/null || true)
    return 1
}

_op_is_ready() { command_exists "op" && _op_check_auth; }

_op_load_secrets() {
    _OP_LOADED_SECRETS=()
    _op_is_ready || return 1
    [[ -f "$_OP_SECRETS_CONFIG" ]] || return 0

    local line var_name op_ref value loaded=0 failed=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        local clean_line
        clean_line=$(sed -e 's/[[:space:]]*#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"$line")
        [[ -z "$clean_line" ]] && continue

        if [[ "$clean_line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.+)$ ]]; then
            # Cross-shell regex match: bash uses BASH_REMATCH, zsh uses match
            if [[ -n "${ZSH_VERSION:-}" ]]; then
                # shellcheck disable=SC2154  # match is a zsh built-in variable set by =~
                var_name="${match[1]}"
                op_ref="${match[2]}"
            else
                var_name="${BASH_REMATCH[1]}"
                op_ref="${BASH_REMATCH[2]}"
            fi
            if command_exists "timeout"; then
                value=$(timeout "${SC_OP_READ_TIMEOUT:-3}" op read "$op_ref" 2>/dev/null) || value=""
            else
                # Use single quotes and pass timeout as argument to prevent command injection
                value=$(perl -e 'alarm shift; exec @ARGV' "${SC_OP_READ_TIMEOUT:-3}" op read "$op_ref" 2>/dev/null) || value=""
            fi
            if [[ -n "$value" ]]; then
                export "$var_name=$value"
                _OP_LOADED_SECRETS+=("$var_name")
                ((++loaded))
            else
                ((++failed))
            fi
        fi
    done <"$_OP_SECRETS_CONFIG"
    return 0
}

op-secrets-load() {
    if ! _op_is_ready; then
        echo "❌ ERROR: 1Password CLI not ready" >&2
        echo "ℹ️  WHY: Cannot load secrets without authenticated 1Password session" >&2
        echo "💡 FIX: Run 'op signin' then retry" >&2
        return 1
    fi
    echo "🔐 Loading secrets from 1Password..."
    _op_load_secrets
    [[ ${#_OP_LOADED_SECRETS[@]} -gt 0 ]] && echo "✅ Loaded ${#_OP_LOADED_SECRETS[@]} secret(s)" || echo "ℹ️  No secrets configured. Edit: $_OP_SECRETS_CONFIG"
}

op-secrets-status() {
    echo "🔐 1Password Secrets Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _op_is_ready && echo "✅ 1Password CLI: Ready" || echo "❌ 1Password CLI: Not ready (run: op signin)"

    if [[ -f "$_OP_SECRETS_CONFIG" ]]; then
        local count
        count=$(grep -cE '^[A-Za-z_]' "$_OP_SECRETS_CONFIG" 2>/dev/null || echo 0)
        echo "📋 Config file: $_OP_SECRETS_CONFIG ($count entries)"
    else
        echo "📋 Config file: Not found"
    fi

    echo -e "\n🔑 Loaded secrets:"
    if [[ ${#_OP_LOADED_SECRETS[@]} -gt 0 ]]; then
        for var in "${_OP_LOADED_SECRETS[@]}"; do
            # Cross-shell indirect expansion with substring
            local _val
            if [[ -n "${ZSH_VERSION:-}" ]]; then
                # shellcheck disable=SC2296  # zsh-specific indirect expansion
                _val="${(P)var:-}"
            else
                _val="${!var:-}"
            fi
            echo "  ✓ $var = ${_val:0:4}****"
        done
    else
        echo "  (none)"
    fi
}

op-secrets-edit() {
    local mode="${1:-interactive}"

    mkdir -p "$(dirname "$_OP_SECRETS_CONFIG")"
    if [[ ! -f "$_OP_SECRETS_CONFIG" ]]; then
        cat >"$_OP_SECRETS_CONFIG" <<'EOF'
# 1Password Shell Secrets - Format: VAR=op://Vault/Item/field
# Find refs: op item list | op item get "Name" --fields label=fieldname

# GITHUB_TOKEN=op://Personal/GitHub Token/credential
# OPENAI_API_KEY=op://Personal/OpenAI/api key
# ANTHROPIC_API_KEY=op://Personal/Anthropic/api key
EOF
        echo "✅ Created config template: $_OP_SECRETS_CONFIG"
    fi
    ${EDITOR:-vim} "$_OP_SECRETS_CONFIG"

    # Support non-interactive mode for automated contexts
    if [[ "$mode" == "--no-reload" ]]; then
        return 0
    fi

    # Auto-reload if env var is set, otherwise require explicit flag
    if [[ "${OP_SECRETS_RELOAD_CONFIRM:-}" == "true" ]] || [[ "$mode" == "--reload" ]]; then
        op-secrets-load || true
    else
        echo "ℹ️  Secrets config updated. To reload:"
        echo "💡 FIX: Run 'op-secrets-load', pass --reload flag, or set OP_SECRETS_RELOAD_CONFIRM=true"
    fi
}

# PERF: Lazy-load secrets on first use instead of blocking shell startup (~125ms saved).
# The op CLI calls (op whoami, op read) involve IPC/network and take 100-500ms+.
# Secrets are loaded on first call to op-secrets-load, op-secrets-status, or
# when any code explicitly calls _op_load_secrets.
#
# To force eager loading (old behavior), set SHELL_CONFIG_1PASSWORD_EAGER=true
if [[ "${SHELL_CONFIG_1PASSWORD_EAGER:-false}" == "true" ]]; then
    _op_check_auth 2>/dev/null && [[ -f "$_OP_SECRETS_CONFIG" ]] && _op_load_secrets 2>/dev/null || true
fi
