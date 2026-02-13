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

if [[ -n "${VALIDATION_LIB_DIR:-}" ]]; then
    _SYNTAX_VALIDATOR_DIR="$VALIDATION_LIB_DIR"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _SYNTAX_VALIDATOR_DIR="$SHELL_CONFIG_DIR/lib/validation"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _SYNTAX_VALIDATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
else
    _SYNTAX_VALIDATOR_DIR="${HOME}/.shell-config/lib/validation"
fi

# shellcheck source=../../shared/file-operations.sh
# Source shared utilities - path depends on how _SYNTAX_VALIDATOR_DIR was set
# When using BASH_SOURCE, DIR = validators/, so need ../shared/
# When using SHELL_CONFIG_DIR, DIR = validation/, so need shared/
if [[ -n "${VALIDATION_LIB_DIR:-}" ]]; then
    source "$_SYNTAX_VALIDATOR_DIR/shared/file-operations.sh"
    source "$_SYNTAX_VALIDATOR_DIR/shared/reporters.sh"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    source "$_SYNTAX_VALIDATOR_DIR/shared/file-operations.sh"
    source "$_SYNTAX_VALIDATOR_DIR/shared/reporters.sh"
else
    # BASH_SOURCE path - validators/ dir, need to go up
    source "$_SYNTAX_VALIDATOR_DIR/../shared/file-operations.sh"
    source "$_SYNTAX_VALIDATOR_DIR/../shared/reporters.sh"
fi

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
        json) echo "biome:oxlint" ;;
        *) echo "" ;;
    esac
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
            oxlint "$file" 2>&1
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

# Batch validate files of a specific type
# Usage: _batch_validate "validator" file1 file2 ...
_batch_validate() {
    local validator="$1"
    shift
    local files=("$@")

    [[ ${#files[@]} -eq 0 ]] && return 0
    # Silent return: validator is optional, other validators may be available
    command_exists "$validator" || return 0

    [[ "$_SYNTAX_VERBOSE" == "1" ]] \
        && validation_verbose "Batch checking ${#files[@]} $validator file(s)..."

    local output exit_code matched

    case "$validator" in
        oxlint | ruff | shellcheck | yamllint)
            if [[ "$validator" == "shellcheck" ]]; then
                output=$("$validator" --severity=error "${files[@]}" 2>&1)
            elif [[ "$validator" == "ruff" ]]; then
                output=$("$validator" check --select E9,F63,F7,F82 "${files[@]}" 2>&1)
            else
                output=$("$validator" "${files[@]}" 2>&1)
            fi
            exit_code=$?

            if [[ $exit_code -ne 0 ]] && [[ -n "$output" ]]; then
                # Parse output to extract failing files
                matched=0
                while IFS= read -r line; do
                    if [[ "$line" =~ ^([^:]+):[0-9]+:[0-9]+: ]]; then
                        local failed_file="${BASH_REMATCH[1]}"
                        _SYNTAX_ERRORS+=("$failed_file")
                        _SYNTAX_ERROR_DETAILS+=("$(echo "$line" | head -1)")
                        matched=1
                    fi
                done <<<"$output"

                if [[ $matched -eq 0 ]]; then
                    local first_line
                    first_line=$(echo "$output" | head -1)
                    for file in "${files[@]}"; do
                        _SYNTAX_ERRORS+=("$file")
                        _SYNTAX_ERROR_DETAILS+=("$file ($validator): $first_line")
                    done
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
    [[ ${#json_files[@]} -gt 0 ]] && _batch_validate "oxlint" "${json_files[@]}"

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

    # Show up to 5 files with their first error
    local shown=0
    for i in "${!_SYNTAX_ERRORS[@]}"; do
        if [[ $shown -lt 5 ]]; then
            echo "  - ${_SYNTAX_ERRORS[$i]}" >&2
            [[ -n "${_SYNTAX_ERROR_DETAILS[$i]:-}" ]] \
                && echo "    ${_SYNTAX_ERROR_DETAILS[$i]}" >&2
            shown=$((shown + 1))
        fi
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
