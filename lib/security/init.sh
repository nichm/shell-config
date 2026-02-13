#!/usr/bin/env bash
# =============================================================================
# init.sh - Security module loader
# =============================================================================
# Loads all security submodules (hardening, trash, filesystem, rm, audit).
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/security/init.sh"
# =============================================================================
# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# where set -e would cause the shell to exit on any command failure.

# Prevent double-sourcing
[[ -n "${_SECURITY_INIT_LOADED:-}" ]] && return 0
_SECURITY_INIT_LOADED=1

# Get script directory
if [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _SECURITY_DIR="$SHELL_CONFIG_DIR/lib/security"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _SECURITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    _SECURITY_DIR="${HOME}/.shell-config/lib/security"
fi

# shellcheck source=../core/platform.sh
# Load platform detection if available (zsh compatible)
if [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    source "${SHELL_CONFIG_DIR}/lib/core/platform.sh" 2>/dev/null || true
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../core/platform.sh" 2>/dev/null || true
else
    source "${HOME}/.shell-config/lib/core/platform.sh" 2>/dev/null || true
fi

# Source security submodules
source "$_SECURITY_DIR/hardening.sh"
source "$_SECURITY_DIR/trash/trash.sh"
source "$_SECURITY_DIR/filesystem/protect.sh"
source "$_SECURITY_DIR/rm/wrapper.sh"
source "$_SECURITY_DIR/rm/audit.sh"
source "$_SECURITY_DIR/audit.sh"

# Cleanup
unset _SECURITY_DIR
