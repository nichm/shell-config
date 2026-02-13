#!/usr/bin/env bash
# =============================================================================
# Actionlint Validator
# =============================================================================
# GitHub Actions syntax, shellcheck, and expression validation
# =============================================================================
set -euo pipefail

# shellcheck source=common-init.sh
source "$(dirname "${BASH_SOURCE[0]}")/common-init.sh"

_gha_run_actionlint() {
    local workflow_dir="$1"
    local repo_root="$2"
    local files=("${@:3}")

    if ! _wf_check_tool "actionlint"; then
        _gha_log_warning "actionlint not installed (brew install actionlint)"
        return 2
    fi

    local version
    version=$(_wf_get_version actionlint)
    _gha_log_scanner "🔍" "actionlint" "$version"

    local targets=()
    if [[ ${#files[@]} -gt 0 ]]; then
        targets=("${files[@]}")
    else
        # Scan all yml files in workflow dir
        [[ ! -d "$workflow_dir" ]] && return 0
        while IFS= read -r f; do
            targets+=("$f")
        done < <(find -- "$workflow_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null)
    fi

    [[ ${#targets[@]} -eq 0 ]] && return 0

    # Run actionlint on each target and aggregate results
    local total_errors=0
    local total_ignored=0
    local has_errors=0
    local all_errors=""

    for target in "${targets[@]}"; do
        local error_count=0
        local filtered_result

        # Use shared scanner
        local exit_code=0
        filtered_result=$(_wf_run_actionlint "$target" "$repo_root" error_count 2>&1) || exit_code=$?

        # Count ignored style suggestions (approximate)
        local ignored_count
        ignored_count=$(grep -cE 'SC[0-9]*:(info|style):' <<<"$filtered_result") || ignored_count=0

        total_errors=$((total_errors + error_count))
        total_ignored=$((total_ignored + ignored_count))

        if [[ $exit_code -ne 0 && $error_count -gt 0 ]]; then
            has_errors=1
            # Aggregate error output for display
            all_errors+="$filtered_result"$'\n'
        fi
    done

    # Report aggregate results
    if [[ $has_errors -eq 1 ]]; then
        _gha_log_error "actionlint: Found $total_errors error(s)"
        _GHA_TOTAL_ERRORS=$((_GHA_TOTAL_ERRORS + total_errors))
        echo ""

        # Show aggregated errors (limited output)
        grep -E ':[0-9]+:[0-9]+:' <<<"$all_errors" | head -20

        echo ""
        return 1
    elif [[ $total_ignored -gt 0 ]]; then
        _gha_log_success "actionlint: No errors (${total_ignored} style suggestions ignored)"
        return 0
    else
        _gha_log_success "actionlint: No issues found"
        return 0
    fi
}
