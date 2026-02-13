#!/usr/bin/env bash
# =============================================================================
# commit/pre-commit.sh - Pre-commit validation stage
# =============================================================================
# Runs comprehensive validation checks before commits:
#   - File length validation
#   - Syntax validation (shell, JS/TS, Python, YAML)
#   - Code formatting checks
#   - Dependency change warnings
#   - Large file detection
#   - Commit size analysis
#   - Security scanning (OpenGrep)
#   - Secrets scanning (Gitleaks)
#   - Unit tests (bun test)
#   - Type checking (TSC, mypy)
#   - Circular dependency detection
#   - Infrastructure validation
# PARALLEL EXECUTION (15 concurrent checks):
# All validation checks run concurrently using Bash background processes (&).
# See lines 82-254 for parallel implementation. This provides ~200-400ms savings
# vs sequential execution. See docs/decisions/PARALLEL-ARCHITECTURE.md for details.
# =============================================================================
set -euo pipefail

# This file contains the core pre-commit validation logic
# extracted from the original monolithic pre-commit hook

# Thresholds (shared with hook wrapper, used by pre-commit-checks.sh)
# shellcheck disable=SC2034 # Used in pre-commit-checks.sh
MAX_FILE_SIZE=$((5 * 1024 * 1024)) # 5MB
# shellcheck disable=SC2034
SECRETS_TIMEOUT=5 # seconds per file

# Tier thresholds for commit size analysis (used by pre-commit-checks.sh)
# shellcheck disable=SC2034
TIER_INFO_LINES=1000
# shellcheck disable=SC2034
TIER_INFO_FILES=15
# shellcheck disable=SC2034
TIER_WARNING_LINES=3000
# shellcheck disable=SC2034
TIER_WARNING_FILES=25
# shellcheck disable=SC2034
TIER_EXTREME_LINES=5001
# shellcheck disable=SC2034
TIER_EXTREME_FILES=76

# Dependency files to warn about (used by pre-commit-checks.sh)
# shellcheck disable=SC2034
DEP_FILES=("package.json" "package-lock.json" "Cargo.toml" "bun.lockb" "pnpm-lock.yaml")

PRE_COMMIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=pre-commit-checks.sh
source "$PRE_COMMIT_DIR/pre-commit-checks.sh"
# shellcheck source=pre-commit-display.sh
source "$PRE_COMMIT_DIR/pre-commit-display.sh"

# Run pre-commit validation checks
run_pre_commit_checks() {
    local files=("$@")
    local tmpdir
    local failed_checks=()
    local failed=0

    # Create temp directory for parallel job results
    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    # Intentional expansion: capture value while variable is in scope
    trap "command rm -rf '$tmpdir'" EXIT INT TERM

    log_info "🪝 Checking ${#files[@]} staged file(s)..."

    # Source benchmark hook for timing
    source "$SHELL_CONFIG_DIR/tools/benchmarking/benchmark-hook.sh"
    benchmark_start "pre-commit-validation"

    # === FILE LENGTH CHECK (blocking) ===
    if [[ "${GIT_SKIP_FILE_LENGTH_CHECK:-}" != "1" ]]; then
        if ! run_file_length_check "$tmpdir" "${files[@]}"; then
            failed_checks+=("file-length")
            failed=1
        fi
    else
        echo -e "${YELLOW}⚠️  File length check skipped (GIT_SKIP_FILE_LENGTH_CHECK=1)${NC}" >&2
    fi

    # === PARALLEL VALIDATION CHECKS ===
    log_info "Running parallel validation checks..."

    # Start all parallel jobs
    run_sensitive_files_check "$tmpdir" "${files[@]}" &
    local sensitive_pid=$!

    run_syntax_validation "$tmpdir" "${files[@]}" &
    local syntax_pid=$!

    run_code_formatting_check "$tmpdir" "${files[@]}" &
    local format_pid=$!

    run_dependency_check "$tmpdir" "${files[@]}" &
    local dependency_pid=$!

    run_large_files_check "$tmpdir" "${files[@]}" &
    local largefiles_pid=$!

    run_commit_size_check "$tmpdir" &
    local stats_pid=$!

    run_opengrep_security_check "$tmpdir" "${files[@]}" &
    local opengrep_pid=$!

    run_gitleaks_secrets_check "$tmpdir" &
    local gitleaks_pid=$!

    run_unit_tests "$tmpdir" &
    local tests_pid=$!

    run_typescript_check "$tmpdir" "${files[@]}" &
    local tsc_pid=$!

    run_circular_dependency_check "$tmpdir" "${files[@]}" &
    local circular_pid=$!

    run_python_type_check "$tmpdir" "${files[@]}" &
    local mypy_pid=$!

    # TypeScript/Vite/Next.js specific checks
    run_env_security_check "$tmpdir" "${files[@]}" &
    local env_security_pid=$!

    run_test_coverage_check "$tmpdir" "${files[@]}" &
    local test_coverage_pid=$!

    run_framework_config_check "$tmpdir" "${files[@]}" &
    local framework_config_pid=$!

    # Wait for all jobs and collect results
    wait $sensitive_pid
    if [[ -f "$tmpdir/sensitive-files-check" ]]; then
        failed_checks+=("sensitive-filenames")
        failed=1
    fi

    wait $syntax_pid
    if [[ -f "$tmpdir/syntax-errors" ]]; then
        failed_checks+=("syntax-validation")
        failed=1
    fi

    wait $format_pid
    # Formatting errors are warnings unless GIT_BLOCK_FORMAT=1

    wait $dependency_pid
    if [[ -f "$tmpdir/dependency-warnings" ]]; then
        failed_checks+=("dependency-warnings")
        # Dependency warnings are not blocking by default
        # failed=1  # Uncomment to make dependency warnings blocking
    fi

    wait $largefiles_pid
    if [[ -f "$tmpdir/large-files" ]]; then
        failed_checks+=("large-files")
        failed=1
    fi

    wait $stats_pid
    if [[ -f "$tmpdir/commit-stats" ]]; then
        local stats_tier
        stats_tier=$(cut -d: -f1 <"$tmpdir/commit-stats")
        if [[ "$stats_tier" == "warning" ]] || [[ "$stats_tier" == "extreme" ]]; then
            failed_checks+=("commit-size-$stats_tier")
            failed=1
        fi
    fi

    wait $opengrep_pid
    if [[ -f "$tmpdir/opengrep-exit-code" ]]; then
        local exit_code
        exit_code=$(command cat "$tmpdir/opengrep-exit-code")
        if [[ $exit_code -ne 0 ]]; then
            local output
            output=$(command cat "$tmpdir/opengrep-output")
            local error_findings
            error_findings=$(grep -E "Severity: ERROR" <<<"$output" || echo "")
            if [[ -n "$error_findings" ]]; then
                failed_checks+=("opengrep-security")
                failed=1
            fi
        fi
    fi

    wait $gitleaks_pid
    if [[ -f "$tmpdir/gitleaks-errors" ]]; then
        failed_checks+=("gitleaks-secrets")
        failed=1
    fi

    wait $tests_pid
    if [[ -f "$tmpdir/test-errors" ]]; then
        failed_checks+=("unit-tests")
        failed=1
    fi

    if [[ -n "${tsc_pid:-}" ]]; then
        wait $tsc_pid
        if [[ -f "$tmpdir/tsc-errors" ]]; then
            failed_checks+=("typescript-types")
            failed=1
        fi
    fi

    if [[ -n "${circular_pid:-}" ]]; then
        wait $circular_pid
        if [[ -f "$tmpdir/circular-deps" ]]; then
            if [[ "${GIT_BLOCK_CIRCULAR_DEPS:-}" == "1" ]]; then
                failed_checks+=("circular-dependencies")
                failed=1
            fi
        fi
    fi

    if [[ -n "${mypy_pid:-}" ]]; then
        wait $mypy_pid
        if [[ -f "$tmpdir/mypy-errors" ]]; then
            failed_checks+=("mypy-type-check")
            failed=1
        fi
    fi

    # TypeScript/Vite/Next.js checks results
    if [[ -n "${env_security_pid:-}" ]]; then
        wait $env_security_pid
        if [[ -f "$tmpdir/env-security-errors" ]]; then
            failed_checks+=("env-security")
            failed=1
        fi
    fi

    if [[ -n "${test_coverage_pid:-}" ]]; then
        wait $test_coverage_pid
        # Test coverage warnings are not blocking by default
        if [[ -f "$tmpdir/test-coverage-warning" ]]; then
            failed_checks+=("test-coverage-warning")
            # Don't set failed=1 - warnings only
        fi
        # Test coverage errors are blocking if GIT_BLOCK_MISSING_TESTS=1
        if [[ -f "$tmpdir/test-coverage-errors" ]]; then
            failed_checks+=("test-coverage")
            failed=1
        fi
    fi

    if [[ -n "${framework_config_pid:-}" ]]; then
        wait $framework_config_pid
        if [[ -f "$tmpdir/framework-config-errors" ]]; then
            failed_checks+=("framework-config")
            failed=1
        fi
    fi

    # === DISPLAY RESULTS ===
    display_validation_results "$tmpdir"

    # Run infrastructure validation if available (only when staged files contain infra configs)
    # Skip: GIT_SKIP_INFRA_CHECK=1 git commit -m "message"
    if [[ "${GIT_SKIP_INFRA_CHECK:-}" != "1" ]] && [[ -f "$SHELL_CONFIG_DIR/lib/validation/validators/infra/infra-validator.sh" ]]; then
        # Only run infra validation if staged files include infra-related files
        local has_infra_files=0
        for file in "${files[@]}"; do
            case "$file" in
                nginx.conf|nginx/*.conf) has_infra_files=1; break ;;
                *.tf|terraform/*) has_infra_files=1; break ;;
                docker-compose.yml|docker-compose.yaml|compose.yml|compose.yaml) has_infra_files=1; break ;;
                k8s/*|kubernetes/*) has_infra_files=1; break ;;
                ansible/*|playbook.yml|playbook.yaml) has_infra_files=1; break ;;
                *.pkr.hcl) has_infra_files=1; break ;;
                Dockerfile|Dockerfile.*) has_infra_files=1; break ;;
            esac
        done

        if [[ $has_infra_files -eq 1 ]]; then
            source "$SHELL_CONFIG_DIR/lib/validation/validators/infra/infra-validator.sh"
            if ! validate_infra_configs; then
                if ! infra_validator_show_errors; then
                    failed=1
                fi
            fi
        fi
    fi

    # Benchmark reporting
    benchmark_end "pre-commit-validation" | while read -r line; do
        log_info "⏱️  $line"
    done

    if [[ $failed -eq 1 ]]; then
        display_blocked_message "${failed_checks[@]}"
        return 1
    else
        log_success "🚀 All checks passed — ship it!"
        return 0
    fi
}
