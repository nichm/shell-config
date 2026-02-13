#!/usr/bin/env bash
# =============================================================================
# aliases/servers.sh - Server/login shortcuts (loaded from config/personal.env)
# =============================================================================
# Server aliases are defined in config/personal.env as:
#   SERVER_N_ALIAS="name"
#   SERVER_N_TARGET="user@host"
# This script reads them and creates shell aliases automatically.
# =============================================================================

[[ -n "${_SHELL_CONFIG_ALIASES_SERVERS_LOADED:-}" ]] && return 0
_SHELL_CONFIG_ALIASES_SERVERS_LOADED=1

# NOTE: No set -euo pipefail — sourced into interactive shells

_sc_load_server_aliases() {
    local config_file="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/config/personal.env"
    [[ -f "$config_file" ]] || return 0

    # shellcheck disable=SC1090
    source "$config_file"

    local i=1
    while true; do
        local alias_var="SERVER_${i}_ALIAS"
        local target_var="SERVER_${i}_TARGET"

        # Cross-shell indirect variable expansion (bash + zsh compatible)
        local alias_name target
        # shellcheck disable=SC2296
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            # Zsh: use (P) flag for indirect expansion
            alias_name="${(P)alias_var:-}"
            target="${(P)target_var:-}"
        else
            # Bash 4+: use ${!var} for indirect expansion
            alias_name="${!alias_var:-}"
            target="${!target_var:-}"
        fi

        # Stop when we run out of entries
        [[ -z "$alias_name" ]] && break

        if [[ -n "$target" ]]; then
            # shellcheck disable=SC2139
            alias "${alias_name}"="ssh ${target}"
        fi

        ((i++))
    done
}

_sc_load_server_aliases

