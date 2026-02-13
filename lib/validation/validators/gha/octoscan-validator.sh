#!/usr/bin/env bash
# =============================================================================
# Octoscan Validator
# =============================================================================
# Expression injection, dangerous checkouts, credential leaks
# =============================================================================
set -euo pipefail

_gha_run_octoscan() {
    local workflow_dir="$1"
    local repo_root="$2"
    local files=("${@:3}")

    if ! _gha_check_tool "octoscan"; then
        _gha_log_warning "octoscan not installed (build from github.com/synacktiv/octoscan)"
        return 2
    fi

    local cmd
    cmd=$(_gha_get_tool_path octoscan)
    _gha_log_scanner "🔎" "octoscan" "latest"

    # Run from repo root so config is found
    local result
    if [[ ${#files[@]} -gt 0 ]]; then
        # Scan each file individually
        for target in "${files[@]}"; do
            result+=$(cd -- "$repo_root" && "$cmd" scan -- "$target" 2>&1)$'\n'
        done
    else
        result=$(cd -- "$repo_root" && "$cmd" scan -- "$workflow_dir" 2>&1)
    fi
    if [[ -z "$result" ]]; then
        _gha_log_success "octoscan: No expression injection or dangerous patterns found"
        return 0
    else
        # Count issues - octoscan prefixes issues with filename:line:col pattern
        local issue_count
        issue_count=$(grep -cE ':[0-9]+:[0-9]+:' <<<"$result") || issue_count=0

        if [[ "$issue_count" -gt 0 ]]; then
            _gha_log_warning "octoscan: Found $issue_count finding(s)"
            _GHA_TOTAL_WARNINGS=$((_GHA_TOTAL_WARNINGS + issue_count))
            echo ""
            echo "$result" | head -30
            echo ""
        else
            _gha_log_success "octoscan: Scan complete"
        fi
        return 0
    fi
}
