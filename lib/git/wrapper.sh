#!/usr/bin/env bash
# =============================================================================
# wrapper.sh - Git command wrapper with safety checks and validation
# =============================================================================
# Intercepts git commands to provide safety checks including secrets scanning,
# syntax validation, and dangerous operation protection. Supports bypass flags
# for emergency situations and logs all bypass attempts for audit.
# Dependencies:
#   - core/logging.sh - Atomic write operations
#   - shared/security-rules.sh - Security rule definitions
#   - shared/command-parser.sh - Command argument parsing
#   - shared/audit-logging.sh - Bypass logging
#   - shared/validation-checks.sh - Syntax and format validation
#   - shared/safety-checks.sh - Dangerous operation checks
#   - shared/clone-check.sh - Repository clone validation
#   - shared/secrets-check.sh - Gitleaks secrets scanning
# Bypass Flags:
#   --skip-secrets - Skip secrets scanning
#   --skip-validation - Skip syntax/format validation
#   --allow-large-files - Skip file size checks
#   --force-* - Various force operation flags
# Environment Variables:
#   SHELL_CONFIG_DIR - Shell config installation directory
# Usage:
#   Source this file to override git command - automatic interception
#   Use bypass flags when necessary (logged to audit log)
# =============================================================================

# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# where set -e would cause the shell to exit on any command failure.

# Get script directory (bash/zsh compatible)
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _GIT_WRAPPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    _GIT_WRAPPER_DIR="${0:A:h}"
else
    _GIT_WRAPPER_DIR="${HOME}/.shell-config/lib/git"
fi

# PERF: Only load logging.sh (needed for atomic_write fallback) and the command
# parser (needed for fast-path detection). Heavy modules like syntax-validator,
# secrets-check, and validation-checks are deferred to first non-fast-path use.
if [[ -f "$_GIT_WRAPPER_DIR/../core/logging.sh" ]]; then
    source "$_GIT_WRAPPER_DIR/../core/logging.sh"
fi

# Fallback atomic_write if logging.sh isn't available
if ! type atomic_write >/dev/null 2>&1; then
    atomic_write() {
        local content="$1" target_file="$2"
        [[ -z "$target_file" ]] && return 1
        printf '%s\n' "$content" >"$target_file" 2>/dev/null
    }
fi

# Eagerly load only what's needed for the fast-path and basic operation
source "$_GIT_WRAPPER_DIR/shared/command-parser.sh"
source "$_GIT_WRAPPER_DIR/shared/security-rules.sh"
source "$_GIT_WRAPPER_DIR/shared/audit-logging.sh"

# Lazy-load heavy modules on first non-fast-path git command (~50ms saved at startup)
_GIT_WRAPPER_HEAVY_LOADED=0
_git_wrapper_load_heavy() {
    [[ $_GIT_WRAPPER_HEAVY_LOADED -eq 1 ]] && return 0
    _GIT_WRAPPER_HEAVY_LOADED=1

    # Syntax validator
    if [[ -f "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/validation/validators/core/syntax-validator.sh" ]]; then
        source "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/validation/validators/core/syntax-validator.sh"
    fi
    if ! type validate_staged_syntax >/dev/null 2>&1; then
        validate_staged_syntax() {
            echo "Warning: Syntax validation not available" >&2
            return 0
        }
    fi

    source "$_GIT_WRAPPER_DIR/shared/validation-checks.sh"
    source "$_GIT_WRAPPER_DIR/shared/safety-checks.sh"
    source "$_GIT_WRAPPER_DIR/shared/clone-check.sh"
    source "$_GIT_WRAPPER_DIR/shared/secrets-check.sh"
}

# MAIN GIT WRAPPER
git() {
    # Guard: If dependencies weren't loaded (partial init), fall through
    # to the real git command instead of crashing with "command not found".
    if ! typeset -f _get_real_git_command >/dev/null 2>&1; then
        command git "$@"
        return $?
    fi

    local skip_secrets=0
    local skip_syntax=0
    local original_args=("$@")
    local cmd
    cmd="$(_get_real_git_command "$@")"

    # Filter wrapper flags first (before fast path)
    local new_args=()
    for arg in "$@"; do
        # Filter out wrapper-specific flags (don't pass to git)
        if [[ "$arg" == "--skip-secrets" ]]; then
            skip_secrets=1
            _log_bypass "--skip-secrets" "$cmd"
        elif [[ "$arg" == "--skip-syntax-check" ]]; then
            skip_syntax=1
            _log_bypass "--skip-syntax-check" "$cmd"
        elif [[ "$arg" == "--skip-deps-check" ]]; then
            # Handled in commit section below
            :
        elif [[ "$arg" == "--allow-large-commit" ]]; then
            # Handled in commit section below
            :
        elif [[ "$arg" == "--allow-large-files" ]]; then
            # Handled in commit section below
            :
        elif [[ "$arg" == "--force-danger" ]]; then
            _log_bypass "--force-danger" "$cmd"
            # Used by safety checks, don't pass to git
            :
        elif [[ "$arg" == "--force-allow" ]]; then
            _log_bypass "--force-allow" "$cmd"
            # Used by safety checks, don't pass to git
            :
        elif [[ "$arg" == --force-* ]]; then
            # Strip bypass flags (--force-clean, --force-init, --force-stash, --force-allow)
            # BUT preserve legitimate Git push flags (--force-with-lease, --force-if-includes)
            case "$arg" in
                --force-with-lease|--force-if-includes)
                    # These are Git's native safety features - pass them through
                    new_args+=("$arg")
                    ;;
                *)
                    # Strip bypass flags (logged for audit)
                    _log_bypass "$arg" "$cmd"
                    ;;
            esac
        else
            # Not a wrapper flag, add to new_args for git
            new_args+=("$arg")
        fi
    done

    # FAST PATH: Skip wrapper for safe read-only commands (use filtered args)
    # NOTE: branch, cherry-pick are NOT in the fast-path because they have
    # command-safety rules that would be bypassed (e.g., git branch -D, git cherry-pick --abort)
    case "$cmd" in
        config | status | diff | log | show | remote | fetch | ls-files | ls-tree | rev-parse | describe | cat-file | for-each-ref | symbolic-ref | rev-list | name-rev | shortlog | blame | annotate | tag | reflog | fsck | count-objects | gc | prune | worktree | notes | bisect | archive | bundle | format-patch | request-pull | send-email | am | cherry | revert | grep | help | version | --version | -h | --help)
            command git "${new_args[@]}"
            return $?
            ;;
    esac

    # Help check: Use original first argument (includes wrapper flags for help output)
    local first_arg="$1"
    [[ -z "$first_arg" || "$first_arg" == "--help" || "$first_arg" == "-h" ]] && {
        command git "${original_args[@]}"
        return $?
    }

    # PERF: Load heavy modules on first non-fast-path use
    _git_wrapper_load_heavy

    # Run safety checks (dangerous commands)
    if ! _run_safety_checks "$@"; then
        return 1
    fi

    # Run command-safety engine rules (git-specific rules like git clean, git init, etc.)
    # This integrates the generic command-safety engine with the git wrapper,
    # ensuring rules defined in lib/command-safety/rules/git.sh are evaluated.
    if type _check_command_rules >/dev/null 2>&1; then
        local _cs_rc=0
        _check_command_rules "git" "${original_args[@]}" || _cs_rc=$?
        if [[ $_cs_rc -eq 1 ]]; then
            return 1
        fi
    fi

    # Run clone duplicate check (pass original_args so bypass flags are visible)
    if ! _run_clone_check "$cmd" "${original_args[@]}"; then
        return 1
    fi

    # Dependency & size validation (for commit commands)
    if [[ "$cmd" == "commit" ]] || [[ "$cmd" == "ci" ]]; then
        local skip_deps=0 skip_large_files=0
        # Check original_args (not new_args) since flags were filtered out
        for arg in "${original_args[@]}"; do
            if [[ "$arg" == "--no-verify" ]]; then
                _log_bypass "--no-verify" "$cmd"
            fi
            if [[ "$arg" == "--skip-deps-check" ]]; then
                skip_deps=1
                _log_bypass "--skip-deps-check" "$cmd"
            fi
            if [[ "$arg" == "--allow-large-files" ]]; then
                skip_large_files=1
                _log_bypass "--allow-large-files" "$cmd"
            fi
        done

        local skip_large=0
        for arg in "${original_args[@]}"; do
            if [[ "$arg" == "--allow-large-commit" ]]; then
                skip_large=1
                _log_bypass "--allow-large-commit" "$cmd"
            fi
        done

        [[ $skip_deps -eq 0 ]] && { _check_dependency_changes || return 1; }
        [[ $skip_large_files -eq 0 ]] && { _check_large_files || return 1; }
        [[ $skip_large -eq 0 ]] && { _check_large_commit || return 1; }
    fi

    # Syntax validation
    if [[ $skip_syntax -eq 0 ]] && type validate_staged_syntax >/dev/null 2>&1; then
        if [[ "$cmd" == "commit" ]] || [[ "$cmd" == "ci" ]]; then
            validate_staged_syntax || return 1
            syntax_validator_show_errors || return 1
        elif [[ "$cmd" == "push" ]]; then
            validate_staged_syntax || return 1
            syntax_validator_show_errors || return 1
        fi
    fi

    # Secrets check (using Gitleaks - 5x faster than git-secrets)
    if ! _run_secrets_check "$cmd" "$skip_secrets"; then
        return 1
    fi

    # Execute git command
    # NOTE: Uses "|| exit_code=$?" to safely capture exit code under set -e
    local exit_code=0
    command git "${new_args[@]}" || exit_code=$?

    # Success feedback
    case "$cmd" in
        commit | ci) [[ $exit_code -eq 0 ]] && {
            echo "✅ Commit successful" >&2
            command rm -f "$SECRETS_CACHE_FILE"
        } ;;
        push) [[ $exit_code -eq 0 ]] && echo "✅ Push successful" >&2 ;;
        add) [[ $exit_code -eq 0 ]] && {
            local file_count
            read -r file_count < <(command git diff --cached --name-only | wc -l)
            echo "✅ Added ${file_count:-0} file(s) to staging" >&2
        } ;;
    esac

    return $exit_code
}

# ZSH completion support
# Note: ${ZSH_VERSION:-} prevents unbound variable error in bash with set -u (nounset)
# We check for ZSH and compdef availability before attempting completion registration
if [[ -n "${ZSH_VERSION:-}" ]] && compdef git=git 2>/dev/null; then
    # Completion registered successfully - no action needed
    :
fi

# Clean up old cache files (conditional, only if cache dir exists)
# NOTE: Not backgrounded — zsh shows job notifications for background jobs.
# The find is <2ms for a typical cache directory so no need to background.
[[ -d "${GIT_WRAPPER_CACHE_DIR:-$HOME/.cache/git-wrapper}" ]] \
    && find "${GIT_WRAPPER_CACHE_DIR:-$HOME/.cache/git-wrapper}" -type f -mtime +1 -delete 2>/dev/null || true
