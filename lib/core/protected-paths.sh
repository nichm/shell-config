#!/usr/bin/env bash
# =============================================================================
# protected-paths.sh - Shared protected path definitions and validation
# =============================================================================
# Provides centralized protected path checking to prevent DRY violations.
# Used by both lib/bin/rm and lib/security/rm/wrapper.sh.
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/core/protected-paths.sh"
#   if is_protected "$path"; then
#     echo "Path is protected"
#   fi
# =============================================================================

# Prevent double-sourcing
[[ -n "${_CORE_PROTECTED_PATHS_LOADED:-}" ]] && return 0
_CORE_PROTECTED_PATHS_LOADED=1

# Protected path constants (can be referenced by other modules)
# shellcheck disable=SC2034
readonly PROTECTED_SSH_DIR="${HOME}/.ssh"
# shellcheck disable=SC2034
readonly PROTECTED_GNUPG_DIR="${HOME}/.gnupg"
# shellcheck disable=SC2034
readonly PROTECTED_SHELL_CONFIG_DIR="${HOME}/.shell-config"
# shellcheck disable=SC2034
readonly PROTECTED_CONFIG_DIR="${HOME}/.config"

# =============================================================================
# get_protected_path_type - Check if path is protected and get message type
# =============================================================================
# Uses case statement for O(1) matching - much faster than array iteration.
# Resolves symlinks to prevent bypass via symlink chains and ensures consistent
# message types regardless of whether the path is a symlink.
# This function combines the previous is_protected and get_protected_paths_message_type
# functions to eliminate DRY violation and fix symlink handling inconsistency.
# Args:
#   $1 - Path to check
# Returns:
#   0 (true) if path is protected
#   1 (false) if path is not protected
# Outputs:
#   Message type when protected: "protected-path", "config-file", "system-path", "macos-system-path"
#   Nothing when not protected
# =============================================================================
get_protected_path_type() {
    # Resolve symlinks - readlink -f handles loops and returns error on circular chains
    local resolved_path original_path="$1"
    resolved_path=$(readlink -f "$1" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        # If readlink fails on a path with '..', it's suspicious - block it to prevent bypass
        if [[ "$1" == *".."* ]]; then
            echo "protected-path"
            return 0
        fi
        # Otherwise, resolved = original (handles non-existent files)
        resolved_path="$1"
    fi

    # Check BOTH original path and resolved path against protected patterns.
    # Original path check catches e.g. ~/.shell-config (symlink to repo).
    # Resolved path check catches e.g. /tmp/evil -> ~/.ssh (symlink bypass).
    local path
    for path in "$original_path" "$resolved_path"; do
        case "$path" in
            # Skip flags
            -*) continue ;;
            # Home config directories
            "$HOME"/.ssh | "$HOME"/.ssh/* | \
                "$HOME"/.gnupg | "$HOME"/.gnupg/* | \
                "$HOME"/.shell-config | "$HOME"/.shell-config/* | \
                "$HOME"/.config | "$HOME"/.config/*)
                echo "protected-path"
                return 0
                ;;
            # Home config files (exact)
            "$HOME"/.zshrc | "$HOME"/.zshenv | "$HOME"/.bashrc | "$HOME"/.gitconfig)
                echo "config-file"
                return 0
                ;;
            # macOS system paths
            /System | /System/* | /Library | /Library/* | /Applications | /Applications/*)
                echo "macos-system-path"
                return 0
                ;;
            # macOS temp/cache directories - explicitly allowed (check BEFORE system paths)
            /var/folders/* | /private/var/folders/* | /tmp/* | /private/tmp/*)
                continue
                ;;
            # Unix system paths (including /private/* for macOS symlinks)
            / | /etc | /etc/* | /usr | /usr/* | /var | /var/* | /bin | /bin/* | /sbin | /sbin/* | \
                /private/etc | /private/etc/* | /private/var | /private/var/*)
                echo "system-path"
                return 0
                ;;
            # Relative paths that resolve to protected - check only if starts with .
            # Note: readlink -f should resolve relative paths to absolute ones,
            # but we keep this for edge cases where readlink fails
            .ssh | .ssh/* | .gnupg | .gnupg/* | .config | .config/*)
                if [[ "$PWD" == "$HOME" ]]; then
                    echo "protected-path"
                    return 0
                fi
                ;;
        esac
    done
    return 1
}

# =============================================================================
# is_protected - Check if a path is protected from deletion
# =============================================================================
# Convenience wrapper for get_protected_path_type when only the boolean
# result is needed. Returns exit code only, no output.
# Args:
#   $1 - Path to check
# Returns:
#   0 (true) if path is protected
#   1 (false) if path is not protected
# =============================================================================
is_protected() {
    get_protected_path_type "$1" >/dev/null
}
