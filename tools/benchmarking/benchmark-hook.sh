#!/usr/bin/env bash
# =============================================================================
# BENCHMARK HOOK - Performance benchmarking for git hooks
# =============================================================================
# Provides timing utilities for measuring hook performance.
# Used by pre-commit and other hooks to track execution time.
# =============================================================================

# Sanitize name to be a valid bash variable name (replace hyphens with underscores)
_benchmark_sanitize_name() {
    echo "${1//-/_}"
}

# Check if date supports nanoseconds (%N)
# macOS BSD date outputs literal "N" instead of nanoseconds
_benchmark_has_nanoseconds() {
    local test_val
    test_val=$(date +%N 2>/dev/null || echo "N")
    [[ "$test_val" != "N" ]] && [[ "$test_val" =~ ^[0-9]+$ ]]
}

# Cache the result once
if _benchmark_has_nanoseconds; then
    _BENCHMARK_USE_NS=1
    _BENCHMARK_DATE_FMT="%s%N"
else
    _BENCHMARK_USE_NS=0
    _BENCHMARK_DATE_FMT="%s"
fi

# Start a benchmark timer
benchmark_start() {
    local name
    name=$(_benchmark_sanitize_name "$1")
    export "_BENCHMARK_START_${name}=$(date +"$_BENCHMARK_DATE_FMT")"
}

# End a benchmark timer and report duration
benchmark_end() {
    local name
    name=$(_benchmark_sanitize_name "$1")
    local start_var="_BENCHMARK_START_${name}"
    local start=""

    # Try to get the variable value using env
    start=$(env | grep "^${start_var}=" | cut -d= -f2 || echo "")

    if [[ -n "$start" ]]; then
        local end
        end=$(date +"$_BENCHMARK_DATE_FMT")
        local duration=$((end - start))

        if [[ "$_BENCHMARK_USE_NS" == "1" ]]; then
            echo "${name}: $((duration / 1000000))ms"
        else
            echo "${name}: ${duration}s"
        fi
    fi
}

# Run a command with benchmarking
benchmark_run() {
    local name="$1"
    shift

    benchmark_start "$name"
    "$@"
    local status=$?
    benchmark_end "$name"

    return $status
}