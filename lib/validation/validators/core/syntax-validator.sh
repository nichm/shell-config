#!/usr/bin/env bash
# Syntax validation: shell/yaml/json/python/js/ts/sql via external tools

# Prevent double-sourcing
[[ -n "${_SYNTAX_VALIDATOR_LOADED:-}" ]] && return 0
readonly _SYNTAX_VALIDATOR_LOADED=1

# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# via git wrapper -> validation chain. set -e would cause the shell to exit on
# any command failure. Strict mode is inherited from hook scripts.

# Ensure command_exists is available (sourced via init.sh/hook-bootstrap chain)
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Resolve the validation "shared" directory directly (avoids fragile ../ math).
# Order: explicit env dirs > BASH_SOURCE-derived > canonical fallback. Each
# candidate is then validated below, so an unreliable $0/BASH_SOURCE can't break
# sourcing.
if [[ -n "${VALIDATION_LIB_DIR:-}" ]]; then
    _SYNTAX_SHARED_DIR="$VALIDATION_LIB_DIR/shared"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _SYNTAX_SHARED_DIR="$SHELL_CONFIG_DIR/lib/validation/shared"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    # This file lives at .../lib/validation/validators/core/, so shared is ../../shared
    _SYNTAX_SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../shared" 2>/dev/null && pwd)"
else
    _SYNTAX_SHARED_DIR="${HOME}/.shell-config/lib/validation/shared"
fi

# Validate: the shared dir must contain file-operations.sh. If not, fall back to
# the canonical install location.
if [[ -z "$_SYNTAX_SHARED_DIR" || ! -f "$_SYNTAX_SHARED_DIR/file-operations.sh" ]]; then
    _SYNTAX_SHARED_DIR="${HOME}/.shell-config/lib/validation/shared"
fi

# shellcheck source=../../shared/file-operations.sh
source "$_SYNTAX_SHARED_DIR/file-operations.sh"
# shellcheck source=../../shared/reporters.sh
source "$_SYNTAX_SHARED_DIR/reporters.sh"

_SYNTAX_VERBOSE="${VALIDATION_VERBOSE:-0}"

_is_verbose() {
    [[ "${VERBOSE_MODE:-0}" == "1" ]]
}

# Returns validators for file type (colon-separated, priority order)
_get_validators_for_file() {
    local file="$1"
    local ext
    ext=$(get_file_extension "$file")

    # Special case: GitHub Actions workflow files
    if is_github_workflow "$file"; then
        echo "actionlint:yamllint"
        return
    fi

    case "$ext" in
        js | ts | jsx | tsx | mjs | cjs | mts | cts) echo "oxlint:biome:eslint" ;;
        py) echo "ruff:flake8" ;;
        sql) echo "sqruff:sqlfluff" ;;
        sh | bash | zsh) echo "shellcheck" ;;
        yml | yaml) echo "yamllint" ;;
        json) echo "jq:biome" ;;
        *) echo "" ;;
    esac
}

# Cross-shell: capture file path from "path:line:col: message" lint output.
_syntax_lint_capture_path() {
    local line="$1"
    if [[ -n "${BASH_VERSION:-}" ]]; then
        [[ "$line" =~ ^([^:]+):[0-9]+:[0-9]+: ]] && printf '%s' "${BASH_REMATCH[1]}"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        if [[ "$line" =~ '^([^:]+):[0-9]+:[0-9]+:' ]]; then
            printf '%s' "${match[1]}"
        fi
    fi
}

# Tool exited non-zero but did not lint anything — not a syntax failure.
_is_ignorable_validator_output() {
    local validator="$1"
    local output="$2"
    case "$validator" in
        oxlint)
            [[ "$output" == *"No files found to lint"* ]] && return 0
            ;;
        biome)
            [[ "$output" == *"No files were processed"* ]] && return 0
            ;;
    esac
    return 1
}

# Staged paths from git are repo-relative; resolve for consistent tool behavior.
_syntax_resolve_file_path() {
    local file="$1"
    [[ "$file" == /* ]] && printf '%s' "$file" && return 0
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null) || root=""
    if [[ -n "$root" && -f "$root/$file" ]]; then
        printf '%s' "$root/$file"
    else
        printf '%s' "$file"
    fi
}

# Run validator tool
# Usage: _run_validator "tool" "file"
# Returns: exit code from tool, output on stdout
_run_validator() {
    local tool="$1"
    local file="$2"

    # Defensive check: already verified by caller, but fail fast if tool missing
    command_exists "$tool" || return 1

    case "$tool" in
        oxlint)
            local out status=0
            out=$(oxlint "$file" 2>&1) || status=$?
            if [[ $status -ne 0 ]]; then
                if _is_ignorable_validator_output "oxlint" "$out"; then
                    return 0
                fi
                printf '%s' "$out"
                return 1
            fi
            ;;
        ruff)
            # Syntax-focused rules only (avoid style/lint noise)
            ruff check --select E9,F63,F7,F82 "$file" 2>&1
            ;;
        sqruff)
            sqruff check "$file" 2>&1
            ;;
        shellcheck)
            local output
            output=$(shellcheck --severity=warning "$file" 2>&1)
            if [[ -z "$output" ]]; then
                return 0
            else
                echo "$output"
                return 1
            fi
            ;;
        yamllint)
            yamllint "$file" 2>&1
            ;;
        biome)
            biome check "$file" 2>&1
            ;;
        jq)
            if jq -e . "$file" >/dev/null 2>&1; then
                return 0
            fi
            echo "invalid JSON"
            return 1
            ;;
        eslint)
            eslint "$file" 2>&1
            ;;
        flake8)
            flake8 --select E9,F63,F7,F82 "$file" 2>&1
            ;;
        actionlint)
            local repo_root config_args=()
            repo_root=$(find_repo_root "$(dirname "$file")")
            [[ -f "$repo_root/.github/actionlint.yaml" ]] \
                && config_args+=("-config-file" "$repo_root/.github/actionlint.yaml")

            local al_output al_exit=0
            al_output=$(actionlint "${config_args[@]}" "$file" 2>&1) || al_exit=$?

            if [[ $al_exit -eq 0 ]]; then
                return 0
            else
                # Filter out shellcheck info/style issues using bash native regex
                local errors=""
                local line
                while IFS= read -r line || [[ -n "$line" ]]; do
                    # Skip info/style messages
                    [[ "$line" =~ SC[0-9]*:(info|style): ]] && continue
                    # Keep lines with line:col format
                    [[ "$line" =~ :[0-9]+:[0-9]+: ]] && errors+="$line"$'\n'
                done <<<"$al_output"

                if [[ -n "$errors" ]]; then
                    printf '%s' "$errors"
                    return 1
                fi
                return 0
            fi
            ;;
        *)
            "$tool" "$file" 2>&1
            ;;
    esac
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Track errors
_SYNTAX_ERRORS=()
_SYNTAX_ERROR_DETAILS=()

syntax_validator_reset() {
    _SYNTAX_ERRORS=()
    _SYNTAX_ERROR_DETAILS=()
}

# Validate a single file's syntax
# Usage: validate_syntax "/path/to/file"
# Returns: 0 if valid, 1 if errors found
validate_syntax() {
    local file="$1"

    [[ -f "$file" ]] || return 0

    local tools
    tools=$(_get_validators_for_file "$file")
    [[ -z "$tools" ]] && return 0

    [[ "$_SYNTAX_VERBOSE" == "1" ]] && validation_verbose "Checking: $file"

    # Split tools by ':' (local IFS in read to avoid global mutation)
    local tool_array
    IFS=':' read -ra tool_array <<<"$tools"

    for tool in "${tool_array[@]}"; do
        if command_exists "$tool"; then
            local output status=0
            output=$(_run_validator "$tool" "$file") || status=$?

            if [[ $status -ne 0 ]] && [[ -n "$output" ]]; then
                _SYNTAX_ERRORS+=("$file")
                _SYNTAX_ERROR_DETAILS+=("$file ($tool): $(echo "$output" | head -1)")
                return 1
            fi

            [[ "$_SYNTAX_VERBOSE" == "1" ]] && validation_verbose "  ✅ $tool: OK"
            return 0
        fi
    done

    return 0
}

# Validate multiple files
# Usage: validate_files_syntax file1.py file2.js ...
validate_files_syntax() {
    syntax_validator_reset
    for file in "$@"; do
        validate_syntax "$file"
    done
}

# =============================================================================
# BATCH VALIDATION (Optimized for multiple files of same type)
# =============================================================================

# Record one unparsed validator failure (never blame every staged file).
_syntax_record_batch_failure() {
    local validator="$1"
    local summary="$2"
    _SYNTAX_ERRORS+=("($validator batch)")
    _SYNTAX_ERROR_DETAILS+=("$summary")
}

# Batch validate JSON via jq (oxlint does not lint JSON and false-positives).
_batch_validate_json() {
    local files=("$@")
    [[ ${#files[@]} -eq 0 ]] && return 0
    command_exists jq || return 0

    local file resolved
    for file in "${files[@]}"; do
        resolved=$(_syntax_resolve_file_path "$file")
        if ! jq -e . "$resolved" >/dev/null 2>&1; then
            _SYNTAX_ERRORS+=("$file")
            _SYNTAX_ERROR_DETAILS+=("$file (jq): invalid JSON")
        fi
    done
}

# Batch validate files of a specific type
# Usage: _batch_validate "validator" file1 file2 ...
_batch_validate() {
    local validator="$1"
    shift
    local files=("$@")

    [[ ${#files[@]} -eq 0 ]] && return 0
    command_exists "$validator" || return 0

    [[ "$_SYNTAX_VERBOSE" == "1" ]] \
        && validation_verbose "Batch checking ${#files[@]} $validator file(s)..."

    local output exit_code matched resolved_files=() file resolved

    for file in "${files[@]}"; do
        resolved=$(_syntax_resolve_file_path "$file")
        resolved_files+=("$resolved")
    done

    case "$validator" in
        oxlint | ruff | shellcheck | yamllint | biome)
            if [[ "$validator" == "shellcheck" ]]; then
                output=$("$validator" --severity=error "${resolved_files[@]}" 2>&1)
            elif [[ "$validator" == "ruff" ]]; then
                output=$("$validator" check --select E9,F63,F7,F82 "${resolved_files[@]}" 2>&1)
            elif [[ "$validator" == "biome" ]]; then
                output=$("$validator" check "${resolved_files[@]}" 2>&1)
            else
                output=$("$validator" "${resolved_files[@]}" 2>&1)
            fi
            exit_code=$?

            if [[ $exit_code -ne 0 ]] && [[ -n "$output" ]]; then
                if _is_ignorable_validator_output "$validator" "$output"; then
                    [[ "$_SYNTAX_VERBOSE" == "1" ]] \
                        && validation_verbose "  ↷ $validator: no applicable files (skipped)"
                    return 0
                fi

                matched=0
                local line failed_file
                while IFS= read -r line; do
                    failed_file=$(_syntax_lint_capture_path "$line")
                    if [[ -n "$failed_file" ]]; then
                        _SYNTAX_ERRORS+=("$failed_file")
                        _SYNTAX_ERROR_DETAILS+=("$line")
                        matched=1
                    fi
                done <<<"$output"

                if [[ $matched -eq 0 ]]; then
                    _syntax_record_batch_failure "$validator" "$(echo "$output" | head -3 | tr '\n' ' ')"
                fi
            fi
            ;;
    esac
}

# Batch validate all staged files by type
# Usage: validate_staged_syntax
validate_staged_syntax() {
    syntax_validator_reset

    local js_files=() py_files=() sh_files=() yaml_files=() json_files=()
    local file ext

    while IFS= read -r file; do
        [[ ! -f "$file" ]] && continue
        ext=$(get_file_extension "$file")

        case "$ext" in
            js | ts | jsx | tsx | mjs | cjs | mts | cts) js_files+=("$file") ;;
            py) py_files+=("$file") ;;
            sh | bash | zsh) sh_files+=("$file") ;;
            yml | yaml) yaml_files+=("$file") ;;
            json) json_files+=("$file") ;;
        esac
    done < <(get_staged_files)

    # Run batch validation for each file type (only if array has elements)
    # Empty array expansion causes errors with set -u, so check first
    [[ ${#js_files[@]} -gt 0 ]] && _batch_validate "oxlint" "${js_files[@]}"
    [[ ${#py_files[@]} -gt 0 ]] && _batch_validate "ruff" "${py_files[@]}"
    [[ ${#sh_files[@]} -gt 0 ]] && _batch_validate "shellcheck" "${sh_files[@]}"
    [[ ${#yaml_files[@]} -gt 0 ]] && _batch_validate "yamllint" "${yaml_files[@]}"
    [[ ${#json_files[@]} -gt 0 ]] && _batch_validate_json "${json_files[@]}"

    syntax_validator_has_errors && return 1
    return 0
}

# =============================================================================
# REPORTING
# =============================================================================

syntax_validator_has_errors() {
    [[ ${#_SYNTAX_ERRORS[@]} -gt 0 ]]
}

syntax_validator_error_count() {
    echo ${#_SYNTAX_ERRORS[@]}
}

# Show errors with formatted output
syntax_validator_show_errors() {
    if ! syntax_validator_has_errors; then
        validation_log_success "All files passed syntax validation"
        return 0
    fi

    local count=${#_SYNTAX_ERRORS[@]}
    echo "" >&2
    validation_log_error "Syntax errors in $count file(s):"
    echo "" >&2

    # Show up to 5 files with their first error (bash + zsh compatible indexing)
    local shown=0 i=0
    while [[ $i -lt ${#_SYNTAX_ERRORS[@]} && $shown -lt 5 ]]; do
        echo "  - ${_SYNTAX_ERRORS[$i]}" >&2
        [[ -n "${_SYNTAX_ERROR_DETAILS[$i]:-}" ]] \
            && echo "    ${_SYNTAX_ERROR_DETAILS[$i]}" >&2
        shown=$((shown + 1))
        i=$((i + 1))
    done
    [[ $count -gt 5 ]] && echo "  ... and $((count - 5)) more" >&2
    echo "" >&2
    validation_bypass_hint "GIT_SKIP_SYNTAX_CHECK" "Fix errors or use --skip-syntax-check to bypass"
    return 1
}

# =============================================================================
# CONVENIENCE FUNCTIONS
# =============================================================================

# Validate and report in one call
validate_and_report_syntax() {
    validate_files_syntax "$@"
    syntax_validator_show_errors
}

# Export functions (bash only)
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f syntax_validator_reset 2>/dev/null || true
    export -f validate_syntax 2>/dev/null || true
    export -f validate_files_syntax 2>/dev/null || true
    export -f validate_staged_syntax 2>/dev/null || true
    export -f syntax_validator_has_errors 2>/dev/null || true
    export -f syntax_validator_show_errors 2>/dev/null || true
    export -f validate_and_report_syntax 2>/dev/null || true
fi
