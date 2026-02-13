#!/usr/bin/env bash
# =============================================================================
# pre-commit-display.sh - Pre-commit output helpers
# =============================================================================
# Rendering helpers for pre-commit validation output and blocking messages.
# Usage:
#   source "${BASH_SOURCE[0]}"
# =============================================================================
set -euo pipefail

# Display validation results
display_validation_results() {
    local tmpdir="$1"

    # Display syntax errors (only if file has content, not just created empty)
    if [[ -f "$tmpdir/syntax-errors" ]] && [[ -s "$tmpdir/syntax-errors" ]]; then
        log_error "Syntax validation failed:"
        while IFS= read -r file; do
            [[ -n "$file" ]] && echo "   - $file" >&2
        done <"$tmpdir/syntax-errors"
        echo "" >&2
    fi

    # Display formatting issues
    if [[ -f "$tmpdir/format-errors" ]]; then
        local format_error_count
        format_error_count=$(command cat "$tmpdir/format-error-count" 2>/dev/null || echo "0")
        if [[ $format_error_count -gt 0 ]]; then
            if [[ "${GIT_BLOCK_FORMAT:-}" == "1" ]]; then
                log_error "Code formatting errors detected ($format_error_count file(s)):"
            else
                log_warning "Code formatting issues found ($format_error_count file(s)):"
            fi
            while IFS= read -r file; do
                [[ -n "$file" ]] && echo "   - $file" >&2
            done <"$tmpdir/format-errors"
            echo "" >&2
            echo "   💡 Auto-fix: GIT_AUTO_FIX_FORMAT=1 git commit -m \"message\"" >&2
            echo "   💡 Format JS/TS/JSON/YAML: prettier --write <file>" >&2
            if [[ "${GIT_BLOCK_FORMAT:-}" != "1" ]]; then
                echo "   💡 Block on format errors: GIT_BLOCK_FORMAT=1 git commit -m \"message\"" >&2
            fi
            echo "" >&2
        fi
    fi

    # Display large files (only if file has content)
    if [[ -f "$tmpdir/large-files" ]] && [[ -s "$tmpdir/large-files" ]]; then
        log_error "Large files detected (>5MB):"
        while IFS=: read -r file size; do
            echo "   - $file (${size} bytes)" >&2
        done <"$tmpdir/large-files"
        echo "" >&2
    fi

    # Display commit stats
    if [[ -f "$tmpdir/commit-stats" ]]; then
        local stats_tier
        local stats_files
        local stats_lines
        stats_tier=$(cut -d: -f1 <"$tmpdir/commit-stats")
        stats_files=$(cut -d: -f2 <"$tmpdir/commit-stats")
        stats_lines=$(cut -d: -f3 <"$tmpdir/commit-stats")

        case "$stats_tier" in
            info)
                log_info "Commit size: $stats_files files, $stats_lines lines (moderate)"
                ;;
            warning)
                log_warning "Large commit detected: $stats_files files, $stats_lines lines"
                echo "   💡 Consider splitting into smaller commits" >&2
                ;;
            extreme)
                log_error "Extremely large commit: $stats_files files, $stats_lines lines"
                echo "   💡 This commit is very large and may be difficult to review" >&2
                ;;
        esac
        echo "" >&2
    fi

    # Display OpenGrep findings (only if there are actual findings, not just scan summary)
    if [[ -f "$tmpdir/opengrep-output" ]] && [[ -f "$tmpdir/opengrep-exit-code" ]]; then
        local exit_code
        exit_code=$(command cat "$tmpdir/opengrep-exit-code")
        # exit_code 1 = findings found, 0 = clean scan, >1 = error
        if [[ $exit_code -eq 1 ]]; then
            local output
            output=$(command cat "$tmpdir/opengrep-output")
            if [[ -n "$output" ]]; then
                log_error "Security issues found by OpenGrep:"
                echo "$output" >&2
                echo "" >&2
            fi
        fi
    fi

    # Display secrets findings
    if [[ -f "$tmpdir/gitleaks-errors" ]]; then
        log_error "Secrets detected"
        echo "   Run: gitleaks detect --source . for details" >&2
    fi

    # Display test failures
    if [[ -f "$tmpdir/test-errors" ]]; then
        log_error "Unit tests failed"
        [[ -f "$tmpdir/test-output" ]] && tail -20 "$tmpdir/test-output" >&2
        echo "   💡 Run: bun test for details" >&2
    fi

    # Display TypeScript errors
    if [[ -f "$tmpdir/tsc-errors" ]]; then
        log_error "TypeScript type errors detected"
        [[ -f "$tmpdir/tsc-output" ]] && command cat "$tmpdir/tsc-output" >&2
        echo "   💡 Run: tsc --noEmit for details" >&2
    fi

    # Display mypy errors
    if [[ -f "$tmpdir/mypy-timeout" ]]; then
        log_error "Python type check timed out after 60s"
        echo "   💡 Run: GIT_SKIP_MYPY_CHECK=1 git commit to bypass" >&2
    elif [[ -f "$tmpdir/mypy-errors" ]]; then
        log_error "Python type errors found"
        if [[ -f "$tmpdir/mypy-output" ]] && [[ -s "$tmpdir/mypy-output" ]]; then
            tail -20 "$tmpdir/mypy-output" >&2
        else
            echo "   No output available - run mypy manually for details" >&2
        fi
        echo "   💡 Run: GIT_SKIP_MYPY_CHECK=1 git commit to bypass" >&2
    fi

    # Display dependency warnings
    if [[ -f "$tmpdir/dependency-warnings" ]]; then
        log_warning "Committing dependency changes"
        echo "   💡 Run: bun audit" >&2
    fi

    # Display circular dependency warnings/timeouts
    if [[ -f "$tmpdir/circular-timeout" ]]; then
        log_warning "🔗 Circular dependency check timed out after 30s"
        echo "   💡 Try: GIT_SKIP_CIRCULAR_DEPS=1 git commit -m \"message\"" >&2
    fi
    if [[ -f "$tmpdir/circular-deps" ]] && [[ -s "$tmpdir/circular-deps" ]]; then
        if [[ "${GIT_BLOCK_CIRCULAR_DEPS:-}" == "1" ]]; then
            log_error "🔗 Circular dependencies detected:"
            command cat "$tmpdir/circular-deps" >&2
            echo "" >&2
            echo "   💡 Run: GIT_SKIP_CIRCULAR_DEPS=1 git commit -m \"message\" to skip" >&2
        else
            log_warning "🔗 Circular dependencies detected in staged files:"
            command cat "$tmpdir/circular-deps" >&2
            echo "" >&2
            echo "   💡 Fix circular dependencies or run: GIT_SKIP_CIRCULAR_DEPS=1 git commit -m \"message\"" >&2
        fi
    fi
}

# Display blocked commit message
display_blocked_message() {
    local failed_checks=("$@")

    echo "" >&2
    log_error "🛑 Commit blocked — fix these first"
    echo "" >&2
    echo "❌ Failed checks:" >&2
    for check in "${failed_checks[@]}"; do
        echo "   - $check" >&2
    done
    echo "" >&2
    echo "💡 Fix the issues above or use bypass flags:" >&2
    echo "   --no-verify          Skip all pre-commit hooks" >&2
    echo "   GIT_SKIP_HOOKS=1     Skip all validation" >&2
    echo "" >&2
}
