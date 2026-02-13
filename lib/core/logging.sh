#!/usr/bin/env bash
# =============================================================================
# Logging and Atomic File Operations Library
# =============================================================================
# This is the canonical implementation of atomic file operations and log rotation.
# All other scripts should source this file instead of duplicating code.
# Usage: source "$SHELL_CONFIG_DIR/lib/core/logging.sh"
# Provides:
#   - atomic_write(): Safe atomic file writes
#   - atomic_append(): Safe atomic file appends
#   - atomic_append_from_stdin(): Pipe-safe atomic append
#   - _rotate_log(): Rotate logs when they exceed size limit
#   - _shell_config_rotate_logs(): Rotate all managed logs
#   - _log_rotation_status(): Show log rotation status
# Managed logs:
#   - ~/.rm_audit.log
#   - ~/.command-safety.log
#   - ~/.phantom-guard-audit.log
#   - ~/.security_violations.log
#   - ~/.shell-config-audit.log
# IMPORTANT: Uses 'command cat/mv/rm' to bypass command-safety wrappers
#   and prevent infinite recursion when called from wrapper logging code.
# =============================================================================

# Guard against multiple sourcing
[[ -n "${_SHELL_CONFIG_CORE_LOGGING_LOADED:-}" ]] && return 0
_SHELL_CONFIG_CORE_LOGGING_LOADED=1

# shellcheck source=platform.sh
# Load platform detection for OS-specific stat commands
# Use SHELL_CONFIG_DIR (set by init.sh) for zsh compatibility
if [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    source "${SHELL_CONFIG_DIR}/lib/core/platform.sh"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/platform.sh"
else
    source "${HOME}/.shell-config/lib/core/platform.sh"
fi

# =============================================================================
# Log Rotation Configuration
# =============================================================================

: "${SHELL_CONFIG_LOG_MAX_SIZE_MB:=10}"
: "${SHELL_CONFIG_LOG_MAX_FILES:=5}"
_SHELL_CONFIG_LOG_MAX_BYTES=$((SHELL_CONFIG_LOG_MAX_SIZE_MB * 1024 * 1024))

# =============================================================================
# Atomic Write Operations
# =============================================================================

# Atomic write: temp file + rename pattern for safe writes
# Usage: atomic_write "content" "/path/to/file"
atomic_write() {
    local content="$1"
    local target_file="$2"
    local temp_file="${2}.tmp.$$"
    # Parameter expansion instead of dirname subshell for performance
    local target_dir="${target_file%/*}"

    # Create target directory if it doesn't exist
    [[ ! -d "$target_dir" ]] && {
        mkdir -p "$target_dir" 2>/dev/null || return 1
    }

    # Write to temp file, then rename atomically
    printf '%s\n' "$content" >"$temp_file" 2>/dev/null || {
        command rm -f "$temp_file"
        return 1
    }
    command mv "$temp_file" "$target_file" 2>/dev/null || {
        command rm -f "$temp_file"
        return 1
    }
}

# Atomic append: fast path for small content, full atomic for large
# Usage: atomic_append "content" "/path/to/file"
atomic_append() {
    local content="$1"
    local target_file="$2"
    # Parameter expansion instead of dirname subshell for performance
    local target_dir="${target_file%/*}"

    # Create target directory if it doesn't exist
    [[ ! -d "$target_dir" ]] && {
        mkdir -p "$target_dir" 2>/dev/null || return 1
    }

    # If file doesn't exist, just write
    [[ ! -f "$target_file" ]] && {
        atomic_write "$content" "$target_file"
        return $?
    }

    # Fast path: for small content (< PIPE_BUF = 4096 bytes), direct append
    # is atomic on POSIX systems and avoids temp file overhead (~12x faster)
    if [[ ${#content} -lt 4096 ]]; then
        printf '%s\n' "$content" >>"$target_file" 2>/dev/null
        return $?
    fi

    # Full atomic path: read existing + append + atomic rename (for large content)
    local temp_file="${2}.tmp.$$"
    if ! {
        command cat "$target_file" 2>/dev/null
        printf '%s\n' "$content"
    } >"$temp_file" 2>/dev/null; then
        command rm -f "$temp_file" 2>/dev/null
        return 1
    fi
    if ! command mv "$temp_file" "$target_file" 2>/dev/null; then
        command rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# Atomic append from stdin: pipe-safe atomic append
# Usage: echo "content" | atomic_append_from_stdin "/path/to/file"
atomic_append_from_stdin() {
    local target_file="$1"
    local temp_file="${1}.tmp.$$"
    # Parameter expansion instead of dirname subshell for performance
    local target_dir="${target_file%/*}"

    # Create target directory if it doesn't exist
    [[ ! -d "$target_dir" ]] && {
        mkdir -p "$target_dir" 2>/dev/null || return 1
    }

    # If file doesn't exist, just write stdin
    if [[ ! -f "$target_file" ]]; then
        command cat >"$temp_file" || return 1
        command mv "$temp_file" "$target_file" 2>/dev/null || return 1
        return 0
    fi

    # Write existing + stdin to temp file, avoiding loading it all into memory
    if ! {
        command cat "$target_file" 2>/dev/null
        command cat
    } >"$temp_file" 2>/dev/null; then
        command rm -f "$temp_file" 2>/dev/null
        return 1
    fi
    if ! command mv "$temp_file" "$target_file" 2>/dev/null; then
        command rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# =============================================================================
# Log Rotation
# =============================================================================

# Rotate log when it exceeds configured size (with mtime optimization)
# Usage: _rotate_log "/path/to/log" [max_bytes] [max_files]
_rotate_log() {
    local log_file="$1"
    local max_size="${2:-$_SHELL_CONFIG_LOG_MAX_BYTES}"
    local max_files="${3:-$SHELL_CONFIG_LOG_MAX_FILES}"

    [[ ! -f "$log_file" ]] && return 0

    # Optimization: Skip rotation if file hasn't been modified in 24 hours
    local -r ONE_DAY_IN_SECONDS=86400
    local mtime_seconds

    if is_macos; then
        mtime_seconds=$(stat -f%m -- "$log_file" 2>/dev/null) || return 0
    else
        mtime_seconds=$(stat -c%Y -- "$log_file" 2>/dev/null) || return 0
    fi

    local current_time age_seconds
    current_time=$(date +%s)
    age_seconds=$((current_time - mtime_seconds))

    # Only check rotation for files modified in the last 24 hours
    [[ $age_seconds -gt $ONE_DAY_IN_SECONDS ]] && return 0

    # Check file size
    local size
    if is_macos; then
        size=$(stat -f%z -- "$log_file" 2>/dev/null) || return 0
    else
        size=$(stat -c%s -- "$log_file" 2>/dev/null) || return 0
    fi

    # Rotate if size exceeds limit
    if [[ $size -gt $max_size ]]; then
        # Rotate existing backup files
        for ((i = max_files - 1; i >= 1; i--)); do
            [[ -f "${log_file}.$i" ]] && command mv "${log_file}.$i" "${log_file}.$((i + 1))" 2>/dev/null
        done

        # Remove oldest backup if it exists
        command rm -f "${log_file}.${max_files}" 2>/dev/null

        # Move current log to .1
        command mv "$log_file" "${log_file}.1" 2>/dev/null || return 1

        # Create new empty log file
        touch "$log_file" 2>/dev/null || return 1
    fi
}

# Rotate all managed logs on shell startup
# Usage: _shell_config_rotate_logs
_shell_config_rotate_logs() {
    [[ "${SHELL_CONFIG_LOG_ROTATION:-true}" != "true" ]] && return 0

    _rotate_log "$HOME/.rm_audit.log"
    _rotate_log "$HOME/.command-safety.log"
    _rotate_log "$HOME/.phantom-guard-audit.log"
    _rotate_log "$HOME/.security_violations.log"
    _rotate_log "$HOME/.shell-config-audit.log"
}

# Show log rotation status (for doctor command)
# Usage: _log_rotation_status
_log_rotation_status() {
    echo "Log Rotation: max ${SHELL_CONFIG_LOG_MAX_SIZE_MB}MB, keep ${SHELL_CONFIG_LOG_MAX_FILES} files"

    local logs=(
        "$HOME/.rm_audit.log"
        "$HOME/.command-safety.log"
        "$HOME/.phantom-guard-audit.log"
        "$HOME/.security_violations.log"
        "$HOME/.shell-config-audit.log"
    )

    # Declare loop variable BEFORE loop to prevent zsh re-declaration output
    local log size
    for log in "${logs[@]}"; do
        if [[ -f "$log" ]]; then
            if is_macos; then
                size=$(stat -f%z -- "$log" 2>/dev/null)
            else
                size=$(stat -c%s -- "$log" 2>/dev/null)
            fi
            echo "  ${log##*/}: $((size / 1024))KB"
        else
            echo "  ${log##*/}: (none)"
        fi
    done
}

# =============================================================================
# Export Functions
# =============================================================================

# Export functions for use in subshells (bash only)
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f atomic_write atomic_append atomic_append_from_stdin 2>/dev/null || true
    export -f _rotate_log _shell_config_rotate_logs _log_rotation_status 2>/dev/null || true
fi
