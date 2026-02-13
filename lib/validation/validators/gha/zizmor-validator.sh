#!/usr/bin/env bash
# =============================================================================
# Zizmor Validator
# =============================================================================
# Security-focused scanner for unpinned actions, template injection, credentials
# =============================================================================
set -euo pipefail

# shellcheck source=common-init.sh
source "$(dirname "${BASH_SOURCE[0]}")/common-init.sh"

_gha_run_zizmor() {
    local workflow_dir="$1"
    local repo_root="$2"
    local files=("${@:3}")

    if ! _wf_check_tool "zizmor"; then
        _gha_log_warning "zizmor not installed (brew install zizmor)"
        return 2
    fi

    local version
    version=$(_wf_get_version zizmor)
    _gha_log_scanner "🔐" "zizmor" "$version"

    local targets=()
    if [[ ${#files[@]} -gt 0 ]]; then
        targets=("${files[@]}")
    else
        [[ ! -d "$workflow_dir" ]] && return 0
        while IFS= read -r f; do
            targets+=("$f")
        done < <(find -- "$workflow_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null)
    fi

    [[ ${#targets[@]} -eq 0 ]] && return 0

    # Run zizmor on each target and aggregate results
    local total_findings=0
    local total_high=0
    local has_findings=0
    local all_output=""

    for target in "${targets[@]}"; do
        local findings=0
        local result

        # Use shared scanner
        local exit_code=0
        result=$(_wf_run_zizmor "$target" "$repo_root" findings 2>&1) || exit_code=$?

        if [[ $exit_code -ne 0 && $findings -gt 0 ]]; then
            has_findings=1
            total_findings=$((total_findings + findings))

            # Count high severity findings (Bash 5+ native regex, no grep fork)
            local high_count
            high_count=$([[ "$result" =~ "high severity" ]] && echo 1 || echo 0)
            total_high=$((total_high + high_count))

            all_output+="$result"$'\n'
        fi
    done

    # Report aggregate results
    if [[ $has_findings -eq 1 ]]; then
        if [[ $total_high -gt 0 ]]; then
            _gha_log_error "zizmor: Found $total_findings finding(s), $total_high HIGH severity"
            _GHA_TOTAL_ERRORS=$((_GHA_TOTAL_ERRORS + total_high))
        else
            _gha_log_warning "zizmor: Found $total_findings finding(s) (informational)"
            _GHA_TOTAL_WARNINGS=$((_GHA_TOTAL_WARNINGS + total_findings))
        fi

        echo ""
        grep -A5 "^error\[" <<<"$all_output" | head -40
        [[ $GHA_SCAN_VERBOSE -eq 1 ]] && echo "$all_output"
        echo ""
        return 1
    else
        _gha_log_success "zizmor: No security issues found"
        return 0
    fi
}
