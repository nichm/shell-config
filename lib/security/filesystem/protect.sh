#!/usr/bin/env bash
# =============================================================================
# filesystem/protect.sh - Platform-aware file/directory protection
# =============================================================================
# Uses chflags on macOS and chattr on Linux to set immutability.
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/security/filesystem/protect.sh"
# =============================================================================

# Prevent double-sourcing
[[ -n "${_SECURITY_FILESYSTEM_PROTECT_LOADED:-}" ]] && return 0
_SECURITY_FILESYSTEM_PROTECT_LOADED=1

# Ensure command_exists is available (sourced via init.sh/hook-bootstrap chain)
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Protect a single file (make immutable)
protect-file() {
    [[ -z "$1" ]] && {
        printf 'Usage: protect-file <path>\n' >&2
        return 1
    }
    [[ -e "$1" ]] || {
        printf '❌ Not found: %s\n' "$1" >&2
        return 1
    }

    case "${SC_OS:-$(uname -s)}" in
        macos | Darwin)
            sudo chflags schg -- "$1" && printf '🔒 Protected (macOS): %s\n' "$1" >&2
            ;;
        linux | Linux*)
            sudo chattr +i -- "$1" && printf '🔒 Protected (Linux): %s\n' "$1" >&2
            ;;
        *)
            printf '❌ Platform not supported for file protection\n' >&2
            return 1
            ;;
    esac
}

# Unprotect a single file (remove immutability)
unprotect-file() {
    [[ -z "$1" ]] && {
        printf 'Usage: unprotect-file <path>\n' >&2
        return 1
    }
    [[ -e "$1" ]] || {
        printf '❌ Not found: %s\n' "$1" >&2
        return 1
    }

    case "${SC_OS:-$(uname -s)}" in
        macos | Darwin)
            sudo chflags noschg -- "$1" && printf '🔓 Unprotected (macOS): %s\n' "$1" >&2
            ;;
        linux | Linux*)
            sudo chattr -i -- "$1" && printf '🔓 Unprotected (Linux): %s\n' "$1" >&2
            ;;
        *)
            printf '❌ Platform not supported for file protection\n' >&2
            return 1
            ;;
    esac
}

# Protect a directory recursively
protect-dir() {
    [[ -d "$1" ]] || {
        printf '❌ Not a directory: %s\n' "${1:-<none>}" >&2
        return 1
    }

    case "${SC_OS:-$(uname -s)}" in
        macos | Darwin)
            sudo chflags -R schg -- "$1" && printf '🔒 Protected recursive (macOS): %s\n' "$1" >&2
            ;;
        linux | Linux*)
            sudo chattr -R +i -- "$1" && printf '🔒 Protected recursive (Linux): %s\n' "$1" >&2
            ;;
        *)
            printf '❌ Platform not supported for directory protection\n' >&2
            return 1
            ;;
    esac
}

# Unprotect a directory recursively
unprotect-dir() {
    [[ -d "$1" ]] || {
        printf '❌ Not a directory: %s\n' "${1:-<none>}" >&2
        return 1
    }

    case "${SC_OS:-$(uname -s)}" in
        macos | Darwin)
            sudo chflags -R noschg -- "$1" && printf '🔓 Unprotected recursive (macOS): %s\n' "$1" >&2
            ;;
        linux | Linux*)
            sudo chattr -R -i -- "$1" && printf '🔓 Unprotected recursive (Linux): %s\n' "$1" >&2
            ;;
        *)
            printf '❌ Platform not supported for directory protection\n' >&2
            return 1
            ;;
    esac
}

# List protected files in a directory
list-protected() {
    local dir="${1:-.}" found=0

    # Sanitize directory path to prevent argument injection
    [[ "$dir" == -* ]] && {
        printf '❌ Invalid directory path\n' >&2
        return 1
    }

    case "${SC_OS:-$(uname -s)}" in
        macos | Darwin)
            while IFS= read -r -d '' file; do
                local flags
                flags=$(xattr -l "$file" 2>/dev/null | grep -E 'schg|uchg' || true)
                [[ -n "$flags" ]] && {
                    printf '%s\n' "$file"
                    found=1
                }
            done < <(find "./$dir" -print0 2>/dev/null)
            [[ $found -eq 0 ]] && find "./$dir" -exec stat -f '%Sf %N' -- {} \; 2>/dev/null | grep -E 'schg|uchg' || printf 'No protected files.\n'
            ;;
        linux | Linux*)
            printf 'Immutable files (Linux):\n'
            if command_exists "lsattr"; then
                find "./$dir" -type f -print0 2>/dev/null | while IFS= read -r -d '' file; do
                    local attrs
                    attrs=$(lsattr "$file" 2>/dev/null | cut -d' ' -f1)
                    if [[ "$attrs" == *i* ]]; then
                        printf '%s\n' "$file"
                        found=1
                    fi
                done
                [[ $found -eq 0 ]] && printf 'No protected files found.\n'
            else
                printf 'lsattr not available. Install: brew install e2fsprogs\n' >&2
            fi
            ;;
        *)
            printf '❌ Platform not supported for listing protected files\n' >&2
            return 1
            ;;
    esac
}
