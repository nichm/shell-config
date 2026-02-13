#!/usr/bin/env bash
# =============================================================================
# rules.sh - Command safety rule aggregator
# =============================================================================
# Dynamically loads all safety rule files from the rules/ directory.
# Each file defines rules for a specific service (git, docker, etc.).
# Per-Service Disable:
#   Set COMMAND_SAFETY_DISABLE_<SERVICE>=true to skip loading a service.
#   The service name is auto-derived from the filename (uppercase, hyphens→underscores).
#   Example: COMMAND_SAFETY_DISABLE_DOCKER=true skips rules/docker.sh
# Dependencies:
#   - rules/settings.sh - Configuration and protected commands
#   - engine/rule-helpers.sh - _rule and _fix helpers
#   - rules/*.sh - Per-service rule definitions
# Usage:
#   Source this file from command-safety/engine.sh
#   Automatically loads all rule modules from rules/ directory
# =============================================================================

# Use the directory set by loader.sh, or compute it (zsh/bash compatible)
if [[ -z "${_COMMAND_SAFETY_DIR:-}" ]]; then
    if [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
        _COMMAND_SAFETY_DIR="$SHELL_CONFIG_DIR/lib/command-safety"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        # shellcheck disable=SC2296,SC2298
        _COMMAND_SAFETY_DIR="${${(%):-%x}:A:h}"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        _COMMAND_SAFETY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    else
        echo "⚠️  Cannot determine command-safety directory" >&2
        return 1
    fi
fi

# Load individual rule files dynamically
if [[ -d "$_COMMAND_SAFETY_DIR/rules" ]]; then
    # Load settings.sh first (contains configuration)
    if [[ -f "$_COMMAND_SAFETY_DIR/rules/settings.sh" ]]; then
        # shellcheck source=./rules/settings.sh
        source "$_COMMAND_SAFETY_DIR/rules/settings.sh"
    fi

    # Load rule helpers (_rule, _fix)
    # shellcheck source=./engine/rule-helpers.sh
    source "$_COMMAND_SAFETY_DIR/engine/rule-helpers.sh"

    # Load all rule files (rules self-register via _rule helper)
    # Each file = one service. Disable with COMMAND_SAFETY_DISABLE_<SERVICE>=true
    for _rule_file in "$_COMMAND_SAFETY_DIR/rules/"*.sh; do
        [[ -f "$_rule_file" ]] || continue

        # PERF: Use parameter expansion instead of basename subshells (~24 subshells saved)
        # Skip settings.sh (already loaded above)
        [[ "${_rule_file##*/}" == "settings.sh" ]] && continue

        # Derive service name from filename: docker.sh → DOCKER
        _cs_service="${_rule_file##*/}"
        _cs_service="${_cs_service%.sh}"
        # Cross-shell uppercase: bash uses ${var^^}, zsh uses ${(U)var}
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            # shellcheck disable=SC2296  # zsh-specific uppercase expansion
            _cs_service="${(U)_cs_service}"
        else
            _cs_service="${_cs_service^^}"
        fi
        _cs_service="${_cs_service//-/_}"
        _cs_disable_var="COMMAND_SAFETY_DISABLE_${_cs_service}"

        # Check per-service disable flag (cross-shell indirect expansion)
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            # shellcheck disable=SC2296  # zsh-specific indirect expansion
            if [[ "${(P)_cs_disable_var:-}" == "true" ]]; then
                continue
            fi
        else
            if [[ "${!_cs_disable_var:-}" == "true" ]]; then
                continue
            fi
        fi

        # shellcheck source=/dev/null
        if ! source "$_rule_file"; then
            echo "⚠️  Failed to load: $_rule_file" >&2
        fi
    done
    unset _rule_file _cs_service _cs_disable_var
else
    echo "⚠️  Rules directory not found: $_COMMAND_SAFETY_DIR/rules" >&2
    return 1
fi
