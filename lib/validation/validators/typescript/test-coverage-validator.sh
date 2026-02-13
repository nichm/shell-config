#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# test-coverage-validator.sh - Test coverage validation
# =============================================================================
# Checks for test file existence and coverage:
#   - Test files exist for new source files
#   - Test coverage thresholds met (if configured)
#   - Critical paths have tests
# Usage:
#   source test-coverage-validator.sh
#   validate_test_coverage [file1 file2 ...]
# =============================================================================

# Prevent double-sourcing
[[ -n "${_TEST_COVERAGE_VALIDATOR_LOADED:-}" ]] && return 0
readonly _TEST_COVERAGE_VALIDATOR_LOADED=1

# Determine validation lib directory
if [[ -n "${VALIDATION_LIB_DIR:-}" ]]; then
    _TEST_COVERAGE_VALIDATOR_DIR="$VALIDATION_LIB_DIR"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _TEST_COVERAGE_VALIDATOR_DIR="$SHELL_CONFIG_DIR/lib/validation"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _TEST_COVERAGE_VALIDATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
    _TEST_COVERAGE_VALIDATOR_DIR="${HOME}/.shell-config/lib/validation"
fi

# Source shared utilities
source "$_TEST_COVERAGE_VALIDATOR_DIR/shared/reporters.sh"
source "$_TEST_COVERAGE_VALIDATOR_DIR/shared/file-operations.sh"

# Source command cache for performance
if [[ -f "$_TEST_COVERAGE_VALIDATOR_DIR/../../core/command-cache.sh" ]]; then
    source "$_TEST_COVERAGE_VALIDATOR_DIR/../../core/command-cache.sh"
fi

_TEST_COVERAGE_MISSING=()
_TEST_COVERAGE_DETAILS=()
_TEST_COVERAGE_WARNINGS=()

# Reset validator state
test_coverage_validator_reset() {
    _TEST_COVERAGE_MISSING=()
    _TEST_COVERAGE_DETAILS=()
    _TEST_COVERAGE_WARNINGS=()
}

# Check if test file exists for source file
# Usage: _check_test_file <source_file>
_check_test_file() {
    local source_file="$1"
    local source_dir
    local source_basename
    local source_ext

    source_dir=$(dirname "$source_file")
    source_basename=$(basename "$source_file")
    source_ext="${source_basename##*.}"
    source_name="${source_basename%.*}"

    # Common test file patterns
    local test_patterns=(
        "$source_dir/${source_name}.test.${source_ext}"
        "$source_dir/${source_name}.spec.${source_ext}"
        "$source_dir/${source_name}.${source_ext}.test"
        "$source_dir/${source_name}.${source_ext}.spec"
        "$source_dir/__tests__/${source_name}.${source_ext}"
        "$source_dir/tests/${source_name}.${source_ext}"
        "$source_dir/test/${source_name}.${source_ext}"
    )

    # Check src/ -> tests/ mapping
    if [[ "$source_dir" =~ src/ ]]; then
        local test_dir="${source_dir//src\//tests\//}"
        test_patterns+=("$test_dir/${source_name}.test.${source_ext}")
        test_patterns+=("$test_dir/${source_name}.spec.${source_ext}")
    fi

    # Check lib/ -> __tests__/ mapping
    if [[ "$source_dir" =~ lib/ ]]; then
        local test_dir="${source_dir//lib\//__tests__\/}"
        test_patterns+=("$test_dir/${source_name}.test.${source_ext}")
        test_patterns+=("$test_dir/${source_name}.spec.${source_ext}")
    fi

    # Check if any test file exists
    for test_file in "${test_patterns[@]}"; do
        if [[ -f "$test_file" ]]; then
            return 0
        fi
    done

    return 1
}

# Check if file should have tests
# Usage: _should_have_tests <file>
_should_have_tests() {
    local file="$1"
    local ext
    ext="${file##*.}"

    # Only check certain file types
    case "$ext" in
        js | ts | jsx | tsx | py | go | rs) ;;
        *) return 1 ;;
    esac

    # Skip certain paths
    local skip_patterns=(
        "node_modules/*"
        "dist/*"
        "build/*"
        ".next/*"
        "out/*"
        "coverage/*"
        "*.config.js"
        "*.config.ts"
        "*.d.ts"
        "*/types/*"
        "*/interface/*"
        "*/constants/*"
    )

    for pattern in "${skip_patterns[@]}"; do
        # Use glob matching intentionally
        # shellcheck disable=SC2053
        if [[ "$file" == $pattern ]]; then
            return 1
        fi
    done

    return 0
}

# Validate single file for test coverage
# Usage: validate_test_coverage_file <file>
validate_test_coverage_file() {
    local file="$1"
    [[ ! -f "$file" ]] && return 0

    if ! _should_have_tests "$file"; then
        return 0
    fi

    if ! _check_test_file "$file"; then
        _TEST_COVERAGE_MISSING+=("$file")
        _TEST_COVERAGE_DETAILS+=("$file - Missing test file. WHY: Ensures code quality and prevents regressions. FIX: Create test file at ${file%.*}.test.${file##*.} or similar pattern in same or tests directory.")
    fi

    return 0
}

# Validate multiple files for test coverage
# Usage: validate_test_coverage [file1 file2 ...]
validate_test_coverage() {
    test_coverage_validator_reset

    local files=("$@")

    # Check each file
    for file in "${files[@]}"; do
        validate_test_coverage_file "$file"
    done

    # Check coverage thresholds if configured
    local repo_root
    repo_root=$(find_repo_root "." 2>/dev/null || echo ".")

    # Check for vitest config (check config file existence, not tool installation)
    if [[ -f "$repo_root/vitest.config.ts" ]] || [[ -f "$repo_root/vitest.config.js" ]]; then
        _check_vitest_coverage_config "$repo_root"
    fi

    # Check for jest config (check config file existence, not tool installation)
    if [[ -f "$repo_root/jest.config.js" ]] || [[ -f "$repo_root/jest.config.ts" ]]; then
        _check_jest_coverage_config "$repo_root"
    fi
}

# Check vitest coverage configuration
# Usage: _check_vitest_coverage_config <repo_root>
_check_vitest_coverage_config() {
    local repo_root="$1"

    local config_files=(
        "vitest.config.ts"
        "vitest.config.js"
    )

    for config_file in "${config_files[@]}"; do
        local config_path="$repo_root/$config_file"
        [[ ! -f "$config_path" ]] && continue

        # Check if coverage is configured
        if grep -q "coverage" "$config_path" 2>/dev/null; then
            # Check for thresholds
            if grep -q "thresholds" "$config_path" 2>/dev/null; then
                # Coverage thresholds configured - this is good
                return 0
            fi
        fi
    done

    _TEST_COVERAGE_WARNINGS+=("coverage-config")
    _TEST_COVERAGE_DETAILS+=("vitest coverage thresholds not configured (add test.coverage.thresholds to vitest.config)")
}

# Check jest coverage configuration
# Usage: _check_jest_coverage_config <repo_root>
_check_jest_coverage_config() {
    local repo_root="$1"

    local config_files=(
        "jest.config.js"
        "jest.config.ts"
        "package.json"
    )

    for config_file in "${config_files[@]}"; do
        local config_path="$repo_root/$config_file"
        [[ ! -f "$config_path" ]] && continue

        # Check if coverage is configured
        if grep -q "collectCoverage" "$config_path" 2>/dev/null; then
            # Check for thresholds
            if grep -q "coverageThreshold" "$config_path" 2>/dev/null; then
                # Coverage thresholds configured - this is good
                return 0
            fi
        fi
    done

    _TEST_COVERAGE_WARNINGS+=("coverage-config")
    _TEST_COVERAGE_DETAILS+=("jest coverage thresholds not configured (add coverageThreshold to jest config)")
}

# =============================================================================
# REPORTING
# =============================================================================

test_coverage_validator_has_errors() {
    [[ ${#_TEST_COVERAGE_MISSING[@]} -gt 0 ]]
}

test_coverage_validator_has_warnings() {
    [[ ${#_TEST_COVERAGE_WARNINGS[@]} -gt 0 ]]
}

test_coverage_validator_error_count() {
    echo "${#_TEST_COVERAGE_MISSING[@]}"
}

test_coverage_validator_warning_count() {
    echo "${#_TEST_COVERAGE_WARNINGS[@]}"
}

# Show errors with formatted output
test_coverage_validator_show_errors() {
    if ! test_coverage_validator_has_errors && ! test_coverage_validator_has_warnings; then
        validation_log_success "Test coverage check passed"
        return 0
    fi

    local exit_code=0

    # Show errors (blocking by default, can be made warning via env var)
    if test_coverage_validator_has_errors; then
        local count=${#_TEST_COVERAGE_MISSING[@]}
        echo "" >&2

        # Check if test coverage should be blocking
        if [[ "${GIT_BLOCK_MISSING_TESTS:-}" != "1" ]]; then
            validation_log_warning "Missing test files ($count file(s)):"
            exit_code=0 # Non-blocking by default
        else
            validation_log_error "Missing test files ($count file(s)):"
            exit_code=1
        fi

        echo "" >&2

        for i in "${!_TEST_COVERAGE_MISSING[@]}"; do
            echo "  ⚠️  ${_TEST_COVERAGE_MISSING[$i]}" >&2
            [[ -n "${_TEST_COVERAGE_DETAILS[$i]:-}" ]] \
                && echo "     ${_TEST_COVERAGE_DETAILS[$i]}" >&2
        done

        echo "" >&2
        validation_bypass_hint "GIT_SKIP_TEST_COVERAGE_CHECK" "Add tests or bypass"
        echo "" >&2
    fi

    # Show warnings (non-blocking)
    if test_coverage_validator_has_warnings; then
        local count=${#_TEST_COVERAGE_WARNINGS[@]}
        echo "" >&2
        validation_log_warning "Test coverage warnings ($count issue(s)):"
        echo "" >&2

        # Deduplicate warnings
        local seen=()
        for i in "${!_TEST_COVERAGE_WARNINGS[@]}"; do
            local warning="${_TEST_COVERAGE_WARNINGS[$i]}"
            local detail="${_TEST_COVERAGE_DETAILS[$i]:-}"

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
    export -f test_coverage_validator_reset 2>/dev/null || true
    export -f validate_test_coverage_file 2>/dev/null || true
    export -f validate_test_coverage 2>/dev/null || true
    export -f test_coverage_validator_has_errors 2>/dev/null || true
    export -f test_coverage_validator_has_warnings 2>/dev/null || true
    export -f test_coverage_validator_error_count 2>/dev/null || true
    export -f test_coverage_validator_warning_count 2>/dev/null || true
    export -f test_coverage_validator_show_errors 2>/dev/null || true
fi
