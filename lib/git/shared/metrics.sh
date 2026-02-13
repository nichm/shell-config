#!/usr/bin/env bash
# =============================================================================
# 📊 GIT HOOKS METRICS - Performance Tracking
# =============================================================================
# Tracks git hook execution time for performance monitoring.
# Helps identify slow hooks and optimize developer experience.
# Usage:
#   source "${SHARED_DIR}/metrics.sh"
#   metrics_start "hook-name"
#   # ... do work ...
#   metrics_end "hook-name"
# Metrics logged to: ~/.git-hooks-metrics.log
# =============================================================================
set -euo pipefail

# Metrics log location
METRICS_LOG="${HOME}/.git-hooks-metrics.log"

# Ensure metrics log directory exists
ensure_metrics_log_dir() {
    local log_dir
    log_dir="$(dirname "$METRICS_LOG")"
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || true
    fi
}

# =============================================================================
# METRICS TIMING FUNCTIONS
# =============================================================================

# Associative array to store start times (requires bash 4)
declare -A METRICS_START_TIMES

# Start timing a hook
# Args:
#   $1 - Hook name (e.g., "pre-commit", "commit-msg")
# Returns:
#   0 on success, 1 on error
metrics_start() {
    local hook_name="$1"

    if [[ -z "$hook_name" ]]; then
        echo "❌ ERROR: metrics_start requires a hook name" >&2
        return 1
    fi

    # Get high-resolution start time (nanoseconds)
    # Falls back to seconds if %N not supported
    local start_time
    start_time=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")

    METRICS_START_TIMES["$hook_name"]=$start_time

    return 0
}

# End timing a hook and log the result
# Args:
#   $1 - Hook name (e.g., "pre-commit", "commit-msg")
#   $2 - Optional status (success/failure)
# Returns:
#   0 on success, 1 on error
metrics_end() {
    local hook_name="$1"
    local status="${2:-success}"

    if [[ -z "$hook_name" ]]; then
        echo "❌ ERROR: metrics_end requires a hook name" >&2
        return 1
    fi

    # Check if we have a start time for this hook
    if [[ -z "${METRICS_START_TIMES[$hook_name]:-}" ]]; then
        echo "WARNING: No start time found for hook: $hook_name" >&2
        return 1
    fi

    # Get end time
    local end_time
    end_time=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")

    # Calculate duration in milliseconds
    local start_time="${METRICS_START_TIMES[$hook_name]}"
    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))

    # Get current timestamp for logging
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Get repository name (if in a git repo)
    local repo_name=""
    if git rev-parse --git-dir >/dev/null 2>&1; then
        repo_name=$(git remote get-url origin 2>/dev/null | sed 's|.*/||' | sed 's|\.git$||' || echo "unknown")
    fi

    # Log the metric
    ensure_metrics_log_dir
    {
        echo "[$timestamp] hook=$hook_name repo=$repo_name status=$status duration=${duration_ms}ms"
    } >>"$METRICS_LOG"

    # Clean up the start time
    unset "METRICS_START_TIMES[$hook_name]"

    return 0
}

# =============================================================================
# METRICS REPORTING FUNCTIONS
# =============================================================================

# Show recent metrics for a specific hook or all hooks
# Args:
#   $1 - Optional hook name (shows all if not specified)
#   $2 - Optional number of entries (default: 10)
# Usage: metrics_show [hook-name] [count]
metrics_show() {
    local hook_name="${1:-}"
    local count="${2:-10}"

    if [[ ! -f "$METRICS_LOG" ]]; then
        echo "No metrics log found at: $METRICS_LOG"
        return 0
    fi

    echo "📊 Git Hooks Metrics (last $count entries)"
    echo ""

    if [[ -n "$hook_name" ]]; then
        # Show metrics for specific hook
        grep "hook=$hook_name" "$METRICS_LOG" | tail -n "$count"
    else
        # Show all metrics
        tail -n "$count" "$METRICS_LOG"
    fi
}

# Show summary statistics for a hook
# Args:
#   $1 - Hook name (e.g., "pre-commit")
# Usage: metrics_summary pre-commit
metrics_summary() {
    local hook_name="$1"

    if [[ -z "$hook_name" ]]; then
        echo "❌ ERROR: metrics_summary requires a hook name" >&2
        return 1
    fi

    if [[ ! -f "$METRICS_LOG" ]]; then
        echo "No metrics log found at: $METRICS_LOG"
        return 0
    fi

    # Extract metrics for this hook
    local metrics
    metrics=$(grep "hook=$hook_name" "$METRICS_LOG" 2>/dev/null || true)

    if [[ -z "$metrics" ]]; then
        echo "No metrics found for hook: $hook_name"
        return 0
    fi

    # Count total runs
    local total_runs
    read -r total_runs < <(echo "$metrics" | wc -l)
    total_runs=${total_runs:-0}

    # Calculate average duration and count using awk for efficiency
    local avg_duration=0
    local count=0
    if [[ -n "$metrics" ]]; then
        local awk_output
        awk_output=$(awk -F'duration=' '
            /duration=/ {
                split($2, a, "ms")
                sum += a[1]
                c++
            }
            END {
                print sum " " c
            }
        ' <<<"$metrics")
        read -r total_duration count <<<"$awk_output"

        if [[ $count -gt 0 ]]; then
            avg_duration=$((total_duration / count))
        fi
    fi

    # Count failures using bash native regex (no fork)
    local failures=0
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ status=failure ]] && ((++failures))
    done <<<"$metrics"

    # Display summary
    echo "📊 Metrics Summary: $hook_name"
    echo "Total runs: $total_runs"
    echo "Average duration: ${avg_duration}ms"
    echo "Failures: $failures"

    # Calculate success rate with guard against division by zero
    if [[ $total_runs -gt 0 ]]; then
        echo "Success rate: $(((total_runs - failures) * 100 / total_runs))%"
    else
        echo "Success rate: N/A"
    fi
    echo ""
}

# Clear old metrics (keep last N entries)
# Args:
#   $1 - Number of entries to keep (default: 1000)
# Usage: metrics_cleanup [keep-count]
metrics_cleanup() {
    local keep_count="${1:-1000}"

    if [[ ! -f "$METRICS_LOG" ]]; then
        return 0
    fi

    (
        temp_file=$(mktemp)
        trap 'command rm -f "$temp_file"' EXIT INT TERM

        # Keep last N entries
        tail -n "$keep_count" "$METRICS_LOG" >"$temp_file"
        command mv "$temp_file" "$METRICS_LOG"
    )

    echo "Metrics cleaned up (last $keep_count entries retained)"
}

# =============================================================================
# WRAPPER FOR AUTOMATIC TRACKING
# =============================================================================

# Run a command with automatic metrics tracking
# Args:
#   $1 - Hook name
#   $@ - Command to run
# Returns:
#   Exit code of the command
# Usage: metrics_run "pre-commit" some_command arg1 arg2
metrics_run() {
    local hook_name="$1"
    shift

    metrics_start "$hook_name"
    local exit_code=0

    # Run the command
    "$@" || exit_code=$?

    # End timing with success/failure status
    if [[ $exit_code -eq 0 ]]; then
        metrics_end "$hook_name" "success"
    else
        metrics_end "$hook_name" "failure"
    fi

    return $exit_code
}
