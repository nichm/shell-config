#!/usr/bin/env bash
# =============================================================================
# audit.sh - Security audit log helpers
# =============================================================================
# Provides commands for viewing and clearing security violation logs.
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/security/audit.sh"
# =============================================================================
# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# where set -e would cause the shell to exit on any command failure.

# Prevent double-sourcing
[[ -n "${_SECURITY_AUDIT_LOADED:-}" ]] && return 0
_SECURITY_AUDIT_LOADED=1

# View security violations log
security-audit() {
    command cat ~/.security_violations.log 2>/dev/null || printf 'No violations.\n'
}

# Clear security violations log
clear-violations() {
    command rm -f ~/.security_violations.log && printf '✅ Cleared\n' >&2
}
