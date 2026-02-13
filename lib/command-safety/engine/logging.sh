#!/usr/bin/env bash
# =============================================================================
# logging.sh - Atomic violation logging for command safety engine
# =============================================================================
# Provides thread-safe logging of command safety violations to a log file.
# Uses atomic_append when available for safe concurrent writes, with fallback
# to standard file operations with directory creation.
# Dependencies:
#   - atomic_append (optional, from core/logging.sh)
# Environment Variables:
#   COMMAND_SAFETY_LOG_FILE - Path to violation log file
# Functions:
#   _log_violation <rule_id> <command> - Log a rule violation with timestamp
# Usage:
#   Source this file from command-safety engine
#   Call _log_violation to log safety violations
# =============================================================================

# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# where set -e would cause the shell to exit on any command failure.

_log_violation() {
    local rule_id="$1" command="$2" timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local entry="[$timestamp] Rule: $rule_id | Command: $command"
    local log_file="${COMMAND_SAFETY_LOG_FILE:-$HOME/.command-safety.log}"

    if type atomic_append &>/dev/null; then
        atomic_append "$entry" "$log_file" 2>/dev/null || {
            echo "❌ Log write failed" >&2
            return 1
        }
    else
        mkdir -p "$(dirname "$log_file")" 2>/dev/null || {
            echo "❌ Log dir creation failed" >&2
            return 1
        }
        echo "$entry" >>"$log_file" 2>/dev/null || {
            echo "❌ Log write failed" >&2
            return 1
        }
    fi
}
