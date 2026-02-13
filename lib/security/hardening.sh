#!/usr/bin/env bash
# =============================================================================
# hardening.sh - Secure defaults and safety aliases
# =============================================================================
# Sets umask, temp directory, and safe shell defaults.
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/security/hardening.sh"
# =============================================================================
# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# where set -e would cause the shell to exit on any command failure.

# Prevent double-sourcing
[[ -n "${_SECURITY_HARDENING_LOADED:-}" ]] && return 0
_SECURITY_HARDENING_LOADED=1

# ZSH safety options
[[ -n "${ZSH_VERSION:-}" ]] && {
    setopt NOCLOBBER RM_STAR_WAIT NO_BEEP
    unsetopt RM_STAR_SILENT FLOW_CONTROL
}

# RM protection config (for lib/bin/rm wrapper)
export RM_AUDIT_LOG="${RM_AUDIT_LOG:-$HOME/.rm_audit.log}"
export RM_AUDIT_ENABLED="${RM_AUDIT_ENABLED:-1}"
export RM_PROTECT_ENABLED="${RM_PROTECT_ENABLED:-1}"
export RM_FORCE_CONFIRM="${RM_FORCE_CONFIRM:-0}"

# Secure defaults - restrictive umask
umask 077

# Create secure temp directory
[[ -d "$HOME/.tmp" ]] || {
    mkdir -p "$HOME/.tmp"
    chmod 700 "$HOME/.tmp"
}
export TMPDIR="$HOME/.tmp"

# Safety aliases - prompt before overwriting
alias ln='ln -i'
alias chmod='chmod -v'
alias chown='chown -v'
alias wget='wget -nc'

# Homebrew verification
brew-verify() {
    [[ -z "$1" ]] && {
        echo "❌ ERROR: Missing package name" >&2
        echo "ℹ️  WHY: brew-verify needs a package to inspect" >&2
        echo "💡 FIX: Run 'brew-verify <package>'" >&2
        return 1
    }
    brew info "$1" | grep -E '(From:|Installed|Built)'
    local prefix bin
    prefix="$(brew --prefix)"
    bin="$prefix/bin/$1"
    [[ -f "$bin" ]] && {
        printf '📋 %s\n' "$bin" >&2
        codesign -dv "$bin" |& grep -E '(Authority|TeamIdentifier)' || printf 'No signature\n'
        printf '🔒 SHA256: %s\n' "$(shasum -a 256 "$bin" | cut -d' ' -f1)" >&2
    }
}
