#!/usr/bin/env bash
# =============================================================================
# BENCHMARK HOOK - Performance benchmarking for git hooks
# =============================================================================
# Provides timing utilities for measuring hook performance.
# Used by pre-commit and other hooks to track execution time.
# =============================================================================
set -euo pipefail

# Start a benchmark timer
benchmark_start() {
    local name="$1"
    export "_BENCHMARK_START_${name}=$(date +%s%N 2>/dev/null || date +%s)"
}

# End a benchmark timer and report duration
benchmark_end() {
    local name="$1"
    local start_var="_BENCHMARK_START_${name}"
    local start="${!start_var:-}"

    if [[ -n "$start" ]]; then
        local end
        end=$(date +%s%N 2>/dev/null || date +%s)
        local duration=$((end - start))

        if [[ $duration -gt 1000000000 ]]; then
            # Nanoseconds - convert to ms
            echo "${name}: $((duration / 1000000))ms"
        else
            # Seconds
            echo "${name}: ${duration}s"
        fi
    fi
}

# Run a command with benchmarking
benchmark_run() {
    local name="$1"
    shift

    benchmark_start "$name"
    local status=0
    "$@" || status=$?
    benchmark_end "$name"

    return $status
}
