#!/usr/bin/env bash
# =============================================================================
# core/personal.sh - Load personal configuration variables
# =============================================================================
# Loads user-specific configuration from config/personal.env
# This provides centralized personal values (name, email, GitHub username, etc.)
# that other modules can reference instead of hardcoding.
#
# Usage:
#   source "$SHELL_CONFIG_DIR/lib/core/personal.sh"
#   echo "$GITHUB_USERNAME"
#
# NOTE: No set -euo pipefail here — this file is sourced into interactive shells.
# =============================================================================

[[ -n "${_SHELL_CONFIG_PERSONAL_LOADED:-}" ]] && return 0
_SHELL_CONFIG_PERSONAL_LOADED=1

# =============================================================================
# LOAD PERSONAL CONFIG
# =============================================================================

_sc_load_personal_config() {
    local config_file="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/config/personal.env"

    if [[ -f "$config_file" ]]; then
        # Source the config file (only exports simple KEY=VALUE lines)
        # shellcheck disable=SC1090
        source "$config_file"
        return 0
    fi

    # Fallback: try to infer from git config if personal.env doesn't exist
    if command -v git >/dev/null 2>&1; then
        : "${GIT_USER_NAME:=$(git config --global user.name 2>/dev/null || echo "")}"
        : "${GIT_USER_EMAIL:=$(git config --global user.email 2>/dev/null || echo "")}"
    fi

    # Fallback: try to infer GitHub username from gh CLI
    if command -v gh >/dev/null 2>&1; then
        : "${GITHUB_USERNAME:=$(gh api user -q .login 2>/dev/null || echo "")}"
    fi

    # Fallback: infer org from remote origin if in a git repo
    if [[ -z "${GITHUB_ORG:-}" ]] && command -v git >/dev/null 2>&1; then
        local remote_url
        remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
        if [[ "$remote_url" =~ github\.com[:/]([^/]+)/ ]]; then
            GITHUB_ORG="${BASH_REMATCH[1]}"
        fi
    fi

    # Default empty values for anything still unset
    : "${GIT_USER_NAME:=}"
    : "${GIT_USER_EMAIL:=}"
    : "${GITHUB_USERNAME:=}"
    : "${GITHUB_ORG:=}"
}

_sc_load_personal_config

# Export for child processes
export GIT_USER_NAME GITHUB_USERNAME GITHUB_ORG
# Note: GIT_USER_EMAIL not exported to avoid overriding git's own config
