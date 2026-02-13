#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# env-security-validator.sh - Environment variable security validation
# =============================================================================
# Checks for security issues in environment variable usage:
#   - NEXT_PUBLIC_ prefix on sensitive values (secrets leaked to client)
#   - Missing .env.example files
#   - Uncommitted .env.local files
#   - Server/client boundary violations
# Usage:
#   source env-security-validator.sh
#   validate_env_security [file1 file2 ...]
# =============================================================================

# Prevent double-sourcing
[[ -n "${_ENV_SECURITY_VALIDATOR_LOADED:-}" ]] && return 0
readonly _ENV_SECURITY_VALIDATOR_LOADED=1

# Determine validation lib directory
if [[ -n "${VALIDATION_LIB_DIR:-}" ]]; then
    _ENV_SECURITY_VALIDATOR_DIR="$VALIDATION_LIB_DIR"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _ENV_SECURITY_VALIDATOR_DIR="$SHELL_CONFIG_DIR/lib/validation"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _ENV_SECURITY_VALIDATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
    _ENV_SECURITY_VALIDATOR_DIR="${HOME}/.shell-config/lib/validation"
fi

# Source shared utilities
source "$_ENV_SECURITY_VALIDATOR_DIR/shared/reporters.sh"
source "$_ENV_SECURITY_VALIDATOR_DIR/shared/file-operations.sh"

# Source command cache for performance
if [[ -f "$_ENV_SECURITY_VALIDATOR_DIR/../../core/command-cache.sh" ]]; then
    source "$_ENV_SECURITY_VALIDATOR_DIR/../../core/command-cache.sh"
fi

_ENV_SECURITY_ERRORS=()
_ENV_SECURITY_WARNINGS=()
_ENV_SECURITY_ERROR_DETAILS=()

# Reset validator state
env_security_validator_reset() {
    _ENV_SECURITY_ERRORS=()
    _ENV_SECURITY_WARNINGS=()
    _ENV_SECURITY_ERROR_DETAILS=()
}

# Check if file contains environment variable references
# Usage: _check_env_vars_in_file <file>
_check_env_vars_in_file() {
    local file="$1"
    local errors=0
    local warnings=0

    # Check for NEXT_PUBLIC_ with suspicious patterns
    local suspicious_patterns=(
        "NEXT_PUBLIC_.*[Kk]ey"
        "NEXT_PUBLIC_.*[Ss]ecret"
        "NEXT_PUBLIC_.*[Pp]assword"
        "NEXT_PUBLIC_.*[Tt]oken"
        "NEXT_PUBLIC_.*[Aa]pi[_-]?[Kk]ey"
        "NEXT_PUBLIC_.*[Pp]rivate"
        "NEXT_PUBLIC_.*[Aa]uth"
        "NEXT_PUBLIC_.*[Cc]redential"
    )

    while IFS= read -r line; do
        local line_num="${line%%:*}"
        local content="${line#*:}"

        for pattern in "${suspicious_patterns[@]}"; do
            if [[ "$content" =~ $pattern ]]; then
                _ENV_SECURITY_ERRORS+=("$file:$line_num")
                _ENV_SECURITY_ERROR_DETAILS+=("$file:$line_num - Suspicious NEXT_PUBLIC_ variable detected. WHY: May leak secrets to client-side. FIX: Use server-side environment variables or remove sensitive prefix.")
                ((errors++))
            fi
        done
    done < <(grep -n "NEXT_PUBLIC_" "$file" 2>/dev/null || true)

    return $errors
}

# Check for .env files that should be gitignored
# Usage: _check_env_files <repo_root>
_check_env_files() {
    local repo_root="$1"
    local errors=0
    local warnings=0

    # Files that should typically be gitignored
    local protected_env_files=(
        ".env.local"
        ".env.*.local"
        ".env.development.local"
        ".env.test.local"
        ".env.production.local"
    )

    # Check .gitignore
    local gitignore="$repo_root/.gitignore"
    local gitignore_content=""
    [[ -f "$gitignore" ]] && gitignore_content=$(command cat "$gitignore" 2>/dev/null)

    for env_pattern in "${protected_env_files[@]}"; do
        # Expand glob pattern
        while IFS= read -r env_file; do
            [[ ! -f "$env_file" ]] && continue

            # Check if already in git (staged or committed)
            if git ls-files --error-unmatch "$env_file" >/dev/null 2>&1; then
                _ENV_SECURITY_ERRORS+=("$env_file")
                _ENV_SECURITY_ERROR_DETAILS+=("$env_file - Sensitive .env file committed to git. WHY: Exposes secrets in version control. FIX: Remove file from git history and add to .gitignore.")
                ((errors++))
            fi

            # Check if properly gitignored
            if [[ -n "$gitignore_content" ]]; then
                if ! grep -qE "(^|/)$env_pattern($|/)" "$gitignore" 2>/dev/null; then
                    _ENV_SECURITY_WARNINGS+=("$env_file")
                    _ENV_SECURITY_ERROR_DETAILS+=("$env_file - Not in .gitignore (should be: $env_pattern)")
                    ((warnings++))
                fi
            fi
        done < <(find "$repo_root" -maxdepth 1 -name "$env_pattern" 2>/dev/null)
    done

    return $errors
}

# Check for .env.example file
# Usage: _check_env_example <repo_root>
_check_env_example() {
    local repo_root="$1"

    # If .env exists, .env.example should exist
    if [[ -f "$repo_root/.env" ]] || [[ -f "$repo_root/.env.local" ]]; then
        if [[ ! -f "$repo_root/.env.example" ]] && [[ ! -f "$repo_root/.env.sample" ]] && [[ ! -f "$repo_root/.env.template" ]]; then
            _ENV_SECURITY_WARNINGS+=(".env.example")
            _ENV_SECURITY_ERROR_DETAILS+=(".env.example missing. WHY: Documentation needed for environment variables. FIX: Create .env.example with required variable names (no values).")
            return 1
        fi
    fi

    return 0
}

# Validate single file for env security issues
# Usage: validate_env_security_file <file>
validate_env_security_file() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0

    # Only check certain file types
    local ext
    ext="${file##*.}"

    case "$ext" in
        js | ts | jsx | tsx | json | yml | yaml)
            _check_env_vars_in_file "$file"
            ;;
        env)
            # .env files should typically be gitignored
            local repo_root
            repo_root=$(find_repo_root "$(dirname "$file")")
            if [[ -f "$repo_root/.gitignore" ]]; then
                local basename
                basename=$(basename "$file")
                if ! grep -qE "(^|/)$basename($|/)" "$repo_root/.gitignore" 2>/dev/null; then
                    _ENV_SECURITY_WARNINGS+=("$file")
                    _ENV_SECURITY_ERROR_DETAILS+=("$file - .env file not in .gitignore")
                fi
            fi
            ;;
    esac

    return 0
}

# Validate multiple files
# Usage: validate_env_security [file1 file2 ...]
validate_env_security() {
    env_security_validator_reset

    local files=("$@")
    local repo_root=""

    # Get repo root once
    if [[ ${#files[@]} -gt 0 ]]; then
        repo_root=$(find_repo_root "$(dirname "${files[0]}")")
    fi

    # Check each file
    for file in "${files[@]}"; do
        validate_env_security_file "$file"
    done

    # Check for .env files in repo root
    if [[ -n "$repo_root" ]]; then
        _check_env_files "$repo_root"
        _check_env_example "$repo_root"
    fi
}

# =============================================================================
# REPORTING
# =============================================================================

env_security_validator_has_errors() {
    [[ ${#_ENV_SECURITY_ERRORS[@]} -gt 0 ]]
}

env_security_validator_has_warnings() {
    [[ ${#_ENV_SECURITY_WARNINGS[@]} -gt 0 ]]
}

env_security_validator_error_count() {
    echo "${#_ENV_SECURITY_ERRORS[@]}"
}

env_security_validator_warning_count() {
    echo "${#_ENV_SECURITY_WARNINGS[@]}"
}

# Show errors with formatted output
env_security_validator_show_errors() {
    if ! env_security_validator_has_errors && ! env_security_validator_has_warnings; then
        validation_log_success "Environment variable security check passed"
        return 0
    fi

    local exit_code=0

    # Show errors (blocking)
    if env_security_validator_has_errors; then
        local count=${#_ENV_SECURITY_ERRORS[@]}
        echo "" >&2
        validation_log_error "Environment variable security issues ($count error(s)):"
        echo "" >&2

        for i in "${!_ENV_SECURITY_ERRORS[@]}"; do
            echo "  ❌ ${_ENV_SECURITY_ERRORS[$i]}" >&2
            [[ -n "${_ENV_SECURITY_ERROR_DETAILS[$i]:-}" ]] \
                && echo "     ${_ENV_SECURITY_ERROR_DETAILS[$i]}" >&2
        done

        echo "" >&2
        validation_bypass_hint "GIT_SKIP_ENV_SECURITY_CHECK" "Fix issues or bypass"
        echo "" >&2
        exit_code=1
    fi

    # Show warnings (non-blocking)
    if env_security_validator_has_warnings; then
        local count=${#_ENV_SECURITY_WARNINGS[@]}
        echo "" >&2
        validation_log_warning "Environment variable security warnings ($count issue(s)):"
        echo "" >&2

        # Deduplicate warnings
        local seen=()
        for i in "${!_ENV_SECURITY_WARNINGS[@]}"; do
            local warning="${_ENV_SECURITY_WARNINGS[$i]}"
            local detail="${_ENV_SECURITY_ERROR_DETAILS[$i]:-}"

            # Check if we've seen this warning
            local duplicate=0
            for s in "${seen[@]}"; do
                [[ "$s" == "$warning" ]] && duplicate=1 && break
            done

            [[ $duplicate -eq 0 ]] && echo "  ⚠️  $warning" >&2
            [[ -n "$detail" ]] && [[ $duplicate -eq 0 ]] && echo "     $detail" >&2

            seen+=("$warning")
        done

        echo "" >&2
    fi

    return $exit_code
}

# =============================================================================
# EXPORTS
# =============================================================================

if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f env_security_validator_reset 2>/dev/null || true
    export -f validate_env_security_file 2>/dev/null || true
    export -f validate_env_security 2>/dev/null || true
    export -f env_security_validator_has_errors 2>/dev/null || true
    export -f env_security_validator_has_warnings 2>/dev/null || true
    export -f env_security_validator_error_count 2>/dev/null || true
    export -f env_security_validator_warning_count 2>/dev/null || true
    export -f env_security_validator_show_errors 2>/dev/null || true
fi
