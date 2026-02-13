#!/usr/bin/env bash
# =============================================================================
# VALIDATION CHECKS UTILITY
# =============================================================================
# Fast validation checks for commit operations.
# Includes dependency changes, large file detection, and large commit detection.
# Requires Bash 5.x (see docs/decisions/BASH-5-UPGRADE.md)
# NOTE: No set -euo pipefail — sourced by wrapper.sh into interactive shells
# =============================================================================

# shellcheck source=../../core/platform.sh
# Use SHELL_CONFIG_DIR for zsh compatibility, fallback to BASH_SOURCE
if [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    source "${SHELL_CONFIG_DIR}/lib/core/platform.sh" || {
        echo "❌ ERROR: Failed to load platform detection" >&2
        exit 1
    }
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../../core/platform.sh" || {
        echo "❌ ERROR: Failed to load platform detection" >&2
        exit 1
    }
else
    source "${HOME}/.shell-config/lib/core/platform.sh" || {
        echo "❌ ERROR: Failed to load platform detection" >&2
        exit 1
    }
fi

# Check for dependency file changes (package.json, Cargo.toml, etc.)
_check_dependency_changes() {
    local dep_files=("package.json" "package-lock.json" "Cargo.toml")
    local changed_deps=()
    local file

    # Use while read loop for proper handling of filenames with spaces
    while IFS= read -r file; do
        for dep_file in "${dep_files[@]}"; do
            if [[ "$file" == "$dep_file" ]]; then
                changed_deps+=("$file")
                break
            fi
        done
    done < <(command git diff --cached --name-only 2>/dev/null)

    [[ ${#changed_deps[@]} -eq 0 ]] && return 0

    echo "" >&2
    local deps_emoji deps_desc deps_msg1 deps_msg2
    deps_emoji="$(_get_rule_value "deps_change" emoji)"
    deps_desc="$(_get_rule_value "deps_change" desc)"
    deps_msg1="$(_get_rule_value "deps_change" msg1)"
    deps_msg2="$(_get_rule_value "deps_change" msg2)"
    echo "$deps_emoji: $deps_desc" >&2
    echo "" >&2
    echo "Changed dependency files:" >&2
    printf "  • %s\n" "${changed_deps[@]}" >&2
    echo "" >&2
    echo "$deps_msg1" >&2
    echo "$deps_msg2" >&2
    echo "" >&2
    echo "Use '$(_get_rule_value "deps_change" bypass)' to proceed anyway" >&2
    return 1
}

# Check for large files in staging area
# Uses SC_FILE_SIZE_LIMIT environment variable (default: 5MB)
_check_large_files() {
    local large_files=()
    local size_threshold="${SC_FILE_SIZE_LIMIT:-$((5 * 1024 * 1024))}" # Default 5MB, configurable via env

    while IFS= read -r file; do
        [[ ! -f "$file" ]] && continue
        local file_size=0

        # Use a function to avoid command substitution debug output
        _get_file_size() {
            local f="$1"
            if is_macos; then
                stat -f%z -- "$f" 2>/dev/null || echo 0
            else
                stat -c%s -- "$f" 2>/dev/null || echo 0
            fi
        }

        file_size=$(_get_file_size "$file")
        [[ $file_size -gt $size_threshold ]] && large_files+=("$file ($((file_size / 1024 / 1024))MB)")
    done < <(command git diff --cached --name-only 2>/dev/null)

    [[ ${#large_files[@]} -eq 0 ]] && return 0

    echo "" >&2
    local lf_emoji lf_desc lf_msg1 lf_msg2 lf_msg3
    lf_emoji="$(_get_rule_value "large_file" emoji)"
    lf_desc="$(_get_rule_value "large_file" desc)"
    lf_msg1="$(_get_rule_value "large_file" msg1)"
    lf_msg2="$(_get_rule_value "large_file" msg2)"
    lf_msg3="$(_get_rule_value "large_file" msg3)"
    echo "$lf_emoji: $lf_desc" >&2
    echo "" >&2
    echo "Large files detected:" >&2
    printf "  • %s\n" "${large_files[@]}" >&2
    echo "" >&2
    echo "$lf_msg1" >&2
    echo "$lf_msg2" >&2
    echo "$lf_msg3" >&2
    echo "" >&2
    echo "Use '$(_get_rule_value "large_file" bypass)' to proceed anyway" >&2
    return 1
}

# Check for large commits (too many files or lines changed)
_check_large_commit() {
    # Helper function for tier messages
    _show_tier_message() {
        local tier=$1 files=$2 lines=$3
        case "$tier" in
            extreme)
                echo "" >&2
                echo "❌ Extremely large commit blocked ($files files, $lines lines)" >&2
                echo "" >&2
                echo "Research shows:" >&2
                echo "  - Defect detection drops to 28% at this size (vs 87% for small PRs)" >&2
                echo "  - Each +100 lines adds ~25 min review time" >&2
                echo "  - Historically produces 3-5x more post-review defects" >&2
                echo "" >&2
                echo "Strongly recommend splitting into 3-5 focused commits" >&2
                echo "" >&2
                echo "Use '--allow-large-commit' to bypass (highly discouraged)" >&2
                echo "" >&2
                ;;
            warning)
                echo "" >&2
                echo "⚠️  Medium-large commit blocked ($files files, $lines lines)" >&2
                echo "" >&2
                echo "Research shows 40% more defects in PRs >400 lines vs smaller ones" >&2
                echo "Meaningful comments decrease ~30% due to reviewer fatigue" >&2
                echo "" >&2
                echo "Consider breaking into 2-3 logical commits" >&2
                echo "" >&2
                echo "Use '--allow-large-commit' to bypass" >&2
                echo "" >&2
                ;;
            info)
                echo "" >&2
                echo "ℹ️  Large commit blocked ($files files, $lines lines)" >&2
                echo "" >&2
                echo "Use '--allow-large-commit' to bypass" >&2
                echo "" >&2
                ;;
        esac
    }

    # Parse git diff --stat output (single awk pass for efficiency)
    # Handles both singular "1 file changed" and plural "N files changed"
    local stats file_count insertions deletions total_lines
    stats=$(command git diff --cached --stat 2>/dev/null | tail -1)
    read -r file_count insertions deletions <<<"$(awk '{
        for(i=1;i<=NF;i++) {
            if($i ~ /files?/) files=$(i-1);
            if($i ~ /insertions?/) { gsub(/[^0-9]/, "", $(i-1)); insertions=$(i-1); }
            if($i ~ /deletions?/) { gsub(/[^0-9]/, "", $(i-1)); deletions=$(i-1); }
        }
        print (files?files:0)" "(insertions?insertions:0)" "(deletions?deletions:0)
    }' <<<"$stats")"
    total_lines=$((insertions + deletions))

    # Two-layer validation system:
    # Layer 1: Per-file size limits (enforced separately, see docs/PER-FILE-LINE-LIMITS.md)
    # Layer 2: PR diff size (this function) - measures actual changes, not total file size
    # Why diff-based (not file-size based):
    # - Measures cognitive load: "how much to review", not "how big files are"
    # - git diff --stat counts insertions + deletions (actual changes)
    # - Research-backed: optimal PR size is ~400 lines across all languages
    # Why file-type agnostic:
    # - Cognitive load scales with change size, not programming language
    # - Per-file limits already handle file-type specific constraints
    # - File count dimension catches "many simple files" scenarios
    # Tier thresholds (must match pre-commit hook):
    # - File count: ideal <10, large PRs >20-30, extreme >75
    # - Diff size: info 1000, warning 3000, extreme 5000 lines changed
    local tier_info_lines=1000 tier_info_files=15
    local tier_warning_lines=3000 tier_warning_files=25
    local tier_extreme_lines=5001 tier_extreme_files=76

    # Three-tier blocking system (all tiers block)
    # Each tier triggers if EITHER files OR lines threshold is met (OR logic)
    # Note: Thresholds duplicated from pre-commit hook for git wrapper integration
    # Rationale: Wrapper needs standalone validation for `git commit --no-verify` scenarios
    if [[ ${file_count:-0} -ge $tier_extreme_files ]] || [[ ${total_lines:-0} -ge $tier_extreme_lines ]]; then
        _show_tier_message "extreme" "$file_count" "$total_lines"
        return 1
    elif [[ ${file_count:-0} -ge $tier_warning_files ]] || [[ ${total_lines:-0} -ge $tier_warning_lines ]]; then
        _show_tier_message "warning" "$file_count" "$total_lines"
        return 1
    elif [[ ${file_count:-0} -ge $tier_info_files ]] || [[ ${total_lines:-0} -ge $tier_info_lines ]]; then
        _show_tier_message "info" "$file_count" "$total_lines"
        return 1
    fi

    return 0
}
