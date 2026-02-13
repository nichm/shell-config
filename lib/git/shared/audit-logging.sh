#!/usr/bin/env bash
# =============================================================================
# AUDIT LOGGING UTILITY
# =============================================================================
# Logs bypass usage for security monitoring and compliance.
# All bypass flags are logged with timestamp, command, and working directory.
# Audit log location: ~/.shell-config-audit.log
# Symlink: shell-config/logs/audit.log (for convenient access)
# Issue #149: Bypass audit logging for security monitoring
# NOTE: No set -euo pipefail — sourced by wrapper.sh into interactive shells
# =============================================================================

# Log bypass usage to audit file
_log_bypass() {
    local bypass_flag="$1" git_cmd="$2"
    local timestamp cwd
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    cwd="$(pwd)"

    local audit_log="${HOME}/.shell-config-audit.log"
    local entry="[$timestamp] BYPASS: $bypass_flag | Command: git $git_cmd | CWD: $cwd"

    # Use atomic_append if available (from logging.sh), otherwise simple append
    if type atomic_append >/dev/null 2>&1; then
        atomic_append "$entry" "$audit_log" 2>/dev/null
    else
        mkdir -p "$(dirname "$audit_log")" 2>/dev/null
        echo "$entry" >>"$audit_log" 2>/dev/null
    fi
}
