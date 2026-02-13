#!/usr/bin/env bash
# =============================================================================
# pre-commit-checks.sh - Pre-commit validation helpers
# =============================================================================
# Contains individual validation functions used by run_pre_commit_checks.
# Usage:
#   source "${BASH_SOURCE[0]}"
# =============================================================================
set -euo pipefail

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

CHECKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=pre-commit-checks-extended.sh
source "$CHECKS_DIR/pre-commit-checks-extended.sh"
# Source platform detection from lib/core/
# shellcheck source=../../../core/platform.sh
if [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    source "$SHELL_CONFIG_DIR/lib/core/platform.sh" || {
        echo "❌ ERROR: Failed to load platform detection" >&2
        echo "ℹ️  WHY: Platform-specific functions required for pre-commit checks" >&2
        echo "💡 FIX: Ensure SHELL_CONFIG_DIR is set correctly" >&2
        exit 1
    }
else
    source "$CHECKS_DIR/../../../core/platform.sh" || {
        echo "❌ ERROR: Failed to load platform detection" >&2
        echo "ℹ️  WHY: Platform-specific functions required for pre-commit checks" >&2
        echo "💡 FIX: Set SHELL_CONFIG_DIR or verify lib/core/platform.sh exists" >&2
        exit 1
    }
fi

# File length validation (blocking)
run_file_length_check() {
    local tmpdir="$1"
    shift
    local files=("$@")

    if [[ -f "$SHELL_CONFIG_DIR/lib/validation/validators/core/file-validator.sh" ]]; then
        source "$SHELL_CONFIG_DIR/lib/validation/validators/core/file-validator.sh"
        file_validator_reset
        for file in "${files[@]}"; do
            validate_file_length "$file"
        done
        if ! file_validator_show_violations; then
            return 1
        fi
    fi
    echo -e "${GREEN}✓${NC} 📐 File length check complete" >&2
    return 0
}

# Sensitive filenames check (operates on staged files only, uses allowlists)
run_sensitive_files_check() {
    local tmpdir="$1"
    shift
    local files=("$@")

    if [[ ${#files[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} 🔐 Sensitive files check complete (no files)" >&2
        return 0
    fi

    if [[ -f "$SHELL_CONFIG_DIR/lib/validation/validators/security/security-validator.sh" ]]; then
        source "$SHELL_CONFIG_DIR/lib/validation/validators/security/security-validator.sh"
        security_validator_reset
        for file in "${files[@]}"; do
            validate_sensitive_filename "$file" || true
        done
        if security_validator_has_violations; then
            security_validator_show_violations >"$tmpdir/sensitive-files-output" 2>&1
            echo "failed" >"$tmpdir/sensitive-files-check"
        fi
    fi
    echo -e "${GREEN}✓${NC} 🔐 Sensitive files check complete" >&2
}

# Syntax validation for multiple languages
run_syntax_validation() {
    local tmpdir="$1"
    shift
    local files=("$@")

    for file in "${files[@]}"; do
        [[ ! -f "$file" ]] && continue
        local ext
        ext="${file##*.}"

        case "$ext" in
            js | ts | jsx | tsx | mjs | cjs | mts | cts)
                if command_exists "oxlint"; then
                    if ! oxlint "$file" >/dev/null 2>&1; then
                        echo "$file" >>"$tmpdir/syntax-errors"
                    fi
                fi
                ;;
            py)
                if command_exists "ruff"; then
                    if ! ruff check "$file" >/dev/null 2>&1; then
                        echo "$file" >>"$tmpdir/syntax-errors"
                    fi
                fi
                ;;
            sh | bash | zsh)
                if command_exists "shellcheck"; then
                    if ! shellcheck --severity=error "$file" >/dev/null 2>&1; then
                        echo "$file" >>"$tmpdir/syntax-errors"
                    fi
                fi
                ;;
            yml | yaml)
                if command_exists "yamllint"; then
                    if ! yamllint "$file" >/dev/null 2>&1; then
                        echo "$file" >>"$tmpdir/syntax-errors"
                    fi
                fi
                # GitHub Actions workflows
                if [[ "$file" == .github/workflows/*.yml ]] || [[ "$file" == .github/workflows/*.yaml ]]; then
                    if command_exists "actionlint"; then
                        local actionlint_args=()
                        [[ -f ".github/actionlint.yaml" ]] && actionlint_args+=("-config-file" ".github/actionlint.yaml")
                        local al_output al_exit=0
                        al_output=$(actionlint "${actionlint_args[@]}" "$file" 2>&1) || al_exit=$?
                        if [[ $al_exit -ne 0 ]]; then
                            local al_errors
                            al_errors=$(grep -vE 'SC[0-9]+:(info|style):' <<<"$al_output")
                            if [[ -n "$al_errors" ]]; then
                                echo "$file" >>"$tmpdir/syntax-errors"
                            fi
                        fi
                    fi
                fi
                ;;
        esac
    done
    echo -e "${GREEN}✓${NC} 🔍 Syntax validation complete" >&2
}

# Code formatting check
run_code_formatting_check() {
    local tmpdir="$1"
    shift
    local files=("$@")

    local format_errors=0
    local format_fixed=0

    for file in "${files[@]}"; do
        [[ ! -f "$file" ]] && continue
        local ext
        ext="${file##*.}"

        case "$ext" in
            js | jsx | ts | tsx | json | yml | yaml)
                if command_exists "prettier"; then
                    if ! prettier --check "$file" >/dev/null 2>&1; then
                        echo "$file" >>"$tmpdir/format-errors"
                        ((++format_errors))
                        if [[ "${GIT_AUTO_FIX_FORMAT:-}" == "1" ]]; then
                            if prettier --write "$file" >/dev/null 2>&1; then
                                git add "$file" 2>/dev/null || true
                                echo "$file" >>"$tmpdir/format-fixed"
                                ((++format_fixed))
                            fi
                        fi
                    fi
                fi
                ;;
        esac
    done

    if [[ $format_errors -gt 0 ]]; then
        echo "$format_errors" >"$tmpdir/format-error-count"
    fi
    if [[ $format_fixed -gt 0 ]]; then
        echo "$format_fixed" >"$tmpdir/format-fixed-count"
    fi

    if [[ $format_errors -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Formatting check found $format_errors file(s) needing formatting${NC}" >&2
    else
        echo -e "${GREEN}✓${NC} 🎨 Formatting check complete" >&2
    fi
}

# Dependency change warnings
run_dependency_check() {
    local tmpdir="$1"
    shift
    local files=("$@")

    local dep_warned=0
    for file in "${files[@]}"; do
        for dep_file in "${DEP_FILES[@]}"; do
            if [[ "$file" == "$dep_file" ]] && [[ $dep_warned -eq 0 ]]; then
                echo "warning" >"$tmpdir/dependency-warnings"
                dep_warned=1
                break
            fi
        done
    done
    echo -e "${GREEN}✓${NC} 📋 Dependency check complete" >&2
}

# Large file detection
run_large_files_check() {
    local tmpdir="$1"
    shift
    local files=("$@")

    for file in "${files[@]}"; do
        [[ ! -f "$file" ]] && continue

        local size
        if is_macos; then
            size=$(stat -f%z -- "$file" 2>/dev/null || echo 0)
        else
            size=$(stat -c%s -- "$file" 2>/dev/null || echo 0)
        fi

        if [[ $size -gt $MAX_FILE_SIZE ]]; then
            echo "$file:$size" >>"$tmpdir/large-files"
        fi
    done
    echo -e "${GREEN}✓${NC} 📦 Large file check complete" >&2
}

# Commit size analysis
run_commit_size_check() {
    local tmpdir="$1"

    local stats
    stats=$(git diff --cached --numstat 2>/dev/null)
    local code_files=0
    local insertions=0
    local deletions=0

    while IFS=$'\t' read -r ins del file; do
        [[ -z "$file" ]] && continue
        ((++code_files))
        ((insertions += ins)) || true
        ((deletions += del)) || true
    done <<<"$stats"

    local total_lines=$((insertions + deletions))

    if [[ ${code_files:-0} -ge $TIER_EXTREME_FILES ]] || [[ ${total_lines:-0} -ge $TIER_EXTREME_LINES ]]; then
        echo "extreme:$code_files:$total_lines" >"$tmpdir/commit-stats"
    elif [[ ${code_files:-0} -ge $TIER_WARNING_FILES ]] || [[ ${total_lines:-0} -ge $TIER_WARNING_LINES ]]; then
        echo "warning:$code_files:$total_lines" >"$tmpdir/commit-stats"
    elif [[ ${code_files:-0} -ge $TIER_INFO_FILES ]] || [[ ${total_lines:-0} -ge $TIER_INFO_LINES ]]; then
        echo "info:$code_files:$total_lines" >"$tmpdir/commit-stats"
    fi

    echo -e "${GREEN}✓${NC} 📊 Commit size check complete" >&2
}

# OpenGrep security scanning
run_opengrep_security_check() {
    local tmpdir="$1"
    shift
    local files=("$@")

    if command_exists "opengrep"; then
        local opengrep_files=()
        for file in "${files[@]}"; do
            [[ ! -f "$file" ]] && continue
            local ext
            ext="${file##*.}"
            case "$ext" in
                js | ts | jsx | tsx | py | rb | go | java | c | cpp | h | cs | php | scala | swift | kt | rs | sh | bash | yml | yaml)
                    opengrep_files+=("$file")
                    ;;
            esac
        done

        if [[ ${#opengrep_files[@]} -gt 0 ]]; then
            local opengrep_cmd=(opengrep scan --config auto)
            opengrep_cmd+=("${opengrep_files[@]}")

            local output exit_code=0
            output=$("${opengrep_cmd[@]}" 2>&1) || exit_code=$?
            echo "$exit_code" >"$tmpdir/opengrep-exit-code"
            echo "$output" >"$tmpdir/opengrep-output"
            if [[ $exit_code -gt 1 ]]; then
                echo -e "${YELLOW}⚠️  OpenGrep exited with code $exit_code (unexpected error)${NC}" >&2
            fi
        fi
    fi
    echo -e "${GREEN}✓${NC} 🔎 OpenGrep security scan complete" >&2
}

# Gitleaks secrets scanning
run_gitleaks_secrets_check() {
    local tmpdir="$1"

    if command_exists "gitleaks"; then
        local gitleaks_config="$SHELL_CONFIG_DIR/lib/validation/validators/security/config/gitleaks.toml"
        local gitleaks_cmd=(gitleaks protect --staged)
        if [[ -f "$gitleaks_config" ]]; then
            gitleaks_cmd+=(--config "$gitleaks_config")
        fi

        # Check for timeout command (try both timeout and gtimeout for macOS coreutils)
        local timeout_cmd=""
        if command_exists "timeout"; then
            timeout_cmd="timeout"
        elif command_exists "gtimeout"; then
            timeout_cmd="gtimeout"
        fi

        if [[ -n "$timeout_cmd" ]]; then
            local exit_code=0
            "$timeout_cmd" "$SECRETS_TIMEOUT" "${gitleaks_cmd[@]}" >/dev/null 2>&1 || exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                if [[ $exit_code -eq 124 ]]; then
                    echo -e "${YELLOW}⚠️  Gitleaks scan timed out after ${SECRETS_TIMEOUT}s${NC}" >&2
                fi
                echo "error" >"$tmpdir/gitleaks-errors"
            fi
        else
            echo -e "${YELLOW}⚠️  Timeout command not found, running Gitleaks scan without timeout. Install with 'brew install coreutils'.${NC}" >&2
            if ! "${gitleaks_cmd[@]}" >/dev/null 2>&1; then
                echo "error" >"$tmpdir/gitleaks-errors"
            fi
        fi
    fi
    echo -e "${GREEN}✓${NC} 🕵️  Gitleaks secrets scan complete" >&2
}

# =============================================================================
# TypeScript/Vite/Next.js Validators
# =============================================================================

# Check if this is a JavaScript/TypeScript project
_is_js_ts_project() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

    # Must have package.json to be a JS/TS project
    [[ -f "$repo_root/package.json" ]]
}

# Environment variable security check
run_env_security_check() {
    local tmpdir="$1"
    shift
    local files=("$@")

    # Skip for non-JS/TS projects
    if ! _is_js_ts_project; then
        echo -e "${BLUE}ℹ${NC}  🔐 Environment security check skipped (not a JS/TS project)" >&2
        return 0
    fi

    if [[ -f "$SHELL_CONFIG_DIR/lib/validation/validators/typescript/env-security-validator.sh" ]]; then
        source "$SHELL_CONFIG_DIR/lib/validation/validators/typescript/env-security-validator.sh"
        validate_env_security "${files[@]}"
        if ! env_security_validator_show_errors; then
            echo "error" >"$tmpdir/env-security-errors"
            return 1
        fi
    fi
    echo -e "${GREEN}✓${NC} 🔐 Environment security check complete" >&2
    return 0
}

# Test coverage check
run_test_coverage_check() {
    local tmpdir="$1"
    shift
    local files=("$@")

    # Skip for non-JS/TS projects
    if ! _is_js_ts_project; then
        echo -e "${BLUE}ℹ${NC}  🧪 Test coverage check skipped (not a JS/TS project)" >&2
        return 0
    fi

    if [[ -f "$SHELL_CONFIG_DIR/lib/validation/validators/typescript/test-coverage-validator.sh" ]]; then
        source "$SHELL_CONFIG_DIR/lib/validation/validators/typescript/test-coverage-validator.sh"
        validate_test_coverage "${files[@]}"
        # This function prints the errors/warnings to the console
        test_coverage_validator_show_errors

        # Now, create the correct marker file based on the result
        if test_coverage_validator_has_errors; then
            if [[ "${GIT_BLOCK_MISSING_TESTS:-}" == "1" ]]; then
                echo "error" >"$tmpdir/test-coverage-errors"
            else
                echo "warning" >"$tmpdir/test-coverage-warning"
            fi
        fi
    fi
    echo -e "${GREEN}✓${NC} 🧪 Test coverage check complete" >&2
    return 0
}

# Framework configuration check (only runs if config files are staged)
run_framework_config_check() {
    local tmpdir="$1"
    shift
    local files=("$@")

    # Skip for non-JS/TS projects
    if ! _is_js_ts_project; then
        echo -e "${BLUE}ℹ${NC}  ⚙️  Framework config check skipped (not a JS/TS project)" >&2
        return 0
    fi

    # Only run if staged files include framework config files
    local has_config_file=0
    for file in "${files[@]}"; do
        case "$file" in
            tsconfig.json|tsconfig.*.json) has_config_file=1; break ;;
            vite.config.*|next.config.*) has_config_file=1; break ;;
            eslint.config.*|.eslintrc.*) has_config_file=1; break ;;
            package.json) has_config_file=1; break ;;
        esac
    done

    if [[ $has_config_file -eq 0 ]]; then
        echo -e "${BLUE}ℹ${NC}  ⚙️  Framework config check skipped (no config files staged)" >&2
        return 0
    fi

    if [[ -f "$SHELL_CONFIG_DIR/lib/validation/validators/typescript/framework-config-validator.sh" ]]; then
        source "$SHELL_CONFIG_DIR/lib/validation/validators/typescript/framework-config-validator.sh"
        local repo_root
        repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
        validate_framework_config "$repo_root"
        if ! framework_config_validator_show_errors; then
            echo "error" >"$tmpdir/framework-config-errors"
            return 1
        fi
    fi
    echo -e "${GREEN}✓${NC} ⚙️  Framework config check complete" >&2
    return 0
}
