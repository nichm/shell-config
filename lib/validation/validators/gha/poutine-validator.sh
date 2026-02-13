#!/usr/bin/env bash
# =============================================================================
# Poutine Validator
# =============================================================================
# CI/CD supply chain security (injection, verified creators)
# =============================================================================
set -euo pipefail

_gha_run_poutine() {
    local repo_root="$2"

    local poutine_cmd=""
    if _gha_check_tool "poutine"; then
        poutine_cmd=$(_gha_get_tool_path poutine)
    else
        _gha_log_warning "poutine not installed (download from github.com/boostsecurityio/poutine)"
        return 2
    fi

    local version
    version=$(_gha_get_version poutine)
    _gha_log_scanner "🔗" "poutine" "$version"

    local args=("analyze_local" "$repo_root" "--format" "pretty")
    local poutine_config
    poutine_config=$(_gha_find_config ".poutine.yml" "$repo_root")
    [[ -n "$poutine_config" ]] && args+=("--config" "$poutine_config")

    local result
    result=$("$poutine_cmd" "${args[@]}" 2>&1)

    # Count failed rules using bash native regex (no fork)
    local failed_rules=0
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ Failed ]] && ((failed_rules++))
    done <<<"$result"

    if [[ "$failed_rules" -eq 0 ]]; then
        _gha_log_success "poutine: All supply chain checks passed"
        return 0
    else
        _gha_log_warning "poutine: Found $failed_rules rule(s) with findings"
        _GHA_TOTAL_WARNINGS=$((_GHA_TOTAL_WARNINGS + failed_rules))

        # Show summary table
        echo ""
        grep -E "(Rule:|Failed|FAILED)" <<<"$result" | head -20
        [[ $GHA_SCAN_VERBOSE -eq 1 ]] && echo "$result"
        echo ""
        return 1
    fi
}
