#!/usr/bin/env bash
# =============================================================================
# benchmark-validator.sh - Performance benchmarking validator
# =============================================================================
# Measures and validates performance metrics for various operations.
# Uses hyperfine when available for accurate statistical benchmarking,
# falls back to simple timing otherwise.
#
# Usage:
#   source "${SHELL_CONFIG_DIR}/tools/benchmarking/benchmark-validator.sh"
#   benchmark_run "my_command" arg1 arg2
#   benchmark_validate_run "name" 5000 my_command arg1 arg2
# =============================================================================

# Prevent double-sourcing
[[ -n "${_BENCHMARK_VALIDATOR_LOADED:-}" ]] && return 0
readonly _BENCHMARK_VALIDATOR_LOADED=1

# Performance thresholds (in milliseconds)
readonly PERF_WARNING_THRESHOLD=5000   # 5 seconds
readonly PERF_ERROR_THRESHOLD=30000    # 30 seconds

# Check if hyperfine is available
_has_hyperfine() {
    command -v hyperfine >/dev/null 2>&1
}

# =============================================================================
# SIMPLE TIMING (fallback when hyperfine not available)
# =============================================================================

# Start a benchmark timer
benchmark_start() {
    local name="$1"
    local timestamp
    
    # Use perl for millisecond precision if available, else seconds
    if command -v perl >/dev/null 2>&1; then
        timestamp=$(perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000')
    else
        timestamp=$(($(date +%s) * 1000))
    fi
    
    export "_BENCHMARK_START_${name}=${timestamp}"
}

# End a benchmark timer and return duration in ms
benchmark_end() {
    local name="$1"
    local format="${2:-human}"  # "human" or "raw"
    local start_var="_BENCHMARK_START_${name}"
    local start=""

    # Get start time from environment
    start=$(printenv "$start_var" 2>/dev/null || echo "")

    if [[ -n "$start" ]]; then
        local end_time
        if command -v perl >/dev/null 2>&1; then
            end_time=$(perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000')
        else
            end_time=$(($(date +%s) * 1000))
        fi
        
        local duration_ms=$((end_time - start))

        # Clean up
        unset "$start_var"

        if [[ "$format" == "raw" ]]; then
            echo "$duration_ms"
        else
            echo "${name}: ${duration_ms}ms"
        fi

        return 0
    fi
    return 1
}

# =============================================================================
# HYPERFINE-BASED BENCHMARKING
# =============================================================================

# Run a command with hyperfine and return JSON stats
benchmark_hyperfine() {
    local name="$1"
    shift
    
    if ! _has_hyperfine; then
        echo "ERROR: hyperfine not installed (brew install hyperfine)" >&2
        return 1
    fi
    
    local tmpfile
    tmpfile=$(mktemp)
    trap 'rm -f "$tmpfile"' RETURN
    
    # Run hyperfine with JSON output
    if hyperfine --warmup 1 --min-runs 3 --export-json "$tmpfile" "$*" >/dev/null 2>&1; then
        # Extract mean time in seconds from JSON
        if command -v jq >/dev/null 2>&1; then
            local mean_s mean_ms
            mean_s=$(jq -r '.results[0].mean' "$tmpfile")
            mean_ms=$(printf "%.0f" "$(echo "$mean_s * 1000" | bc)")
            echo "${name}: ${mean_ms}ms (hyperfine mean)"
        else
            # Fallback: grep for mean value
            grep -o '"mean":[0-9.]*' "$tmpfile" | head -1 | cut -d: -f2
        fi
        return 0
    else
        return 1
    fi
}

# Run a quick benchmark (single run, no hyperfine)
benchmark_run() {
    local name="$1"
    shift
    
    benchmark_start "$name"
    "$@"
    local status=$?
    benchmark_end "$name"
    
    return $status
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Validate performance metrics against thresholds
validate_performance_metrics() {
    local operation="$1"
    local duration_ms="$2"

    if [[ $duration_ms -gt $PERF_ERROR_THRESHOLD ]]; then
        benchmark_validator_show_error "Operation '$operation' took too long (${duration_ms}ms > ${PERF_ERROR_THRESHOLD}ms)"
        return 1
    elif [[ $duration_ms -gt $PERF_WARNING_THRESHOLD ]]; then
        benchmark_validator_show_warning "Operation '$operation' is slow (${duration_ms}ms > ${PERF_WARNING_THRESHOLD}ms)"
    fi

    return 0
}

# Run a command with performance validation
benchmark_validate_run() {
    local name="$1"
    local max_duration_ms="$2"
    shift 2

    benchmark_start "$name"
    "$@"
    local cmd_status=$?
    local duration_ms
    duration_ms=$(benchmark_end "$name" "raw")

    if [[ $cmd_status -eq 0 ]] && [[ ${duration_ms:-0} -gt ${max_duration_ms:-$PERF_ERROR_THRESHOLD} ]]; then
        benchmark_validator_show_error "Command '$name' exceeded time limit (${duration_ms}ms > ${max_duration_ms}ms)"
        return 1
    fi

    return $cmd_status
}

# =============================================================================
# HOOK INTEGRATION
# =============================================================================

# For use in git hooks - start timing a hook
benchmark_hook_start() {
    local hook_name="$1"
    benchmark_start "hook_${hook_name}"
}

# For use in git hooks - end timing and report
benchmark_hook_end() {
    local hook_name="$1"
    local max_ms="${2:-$PERF_WARNING_THRESHOLD}"
    
    local duration_ms
    duration_ms=$(benchmark_end "hook_${hook_name}" "raw")
    
    if [[ ${duration_ms:-0} -gt $max_ms ]]; then
        echo "⚠️  Hook '$hook_name' took ${duration_ms}ms (threshold: ${max_ms}ms)" >&2
    fi
    
    return 0
}

# =============================================================================
# VALIDATOR INTERFACE
# =============================================================================

benchmark_validator_reset() {
    # Clean up any benchmark variables
    while IFS= read -r var; do
        unset "$var"
    done < <(env | grep '^_BENCHMARK_START_' | cut -d= -f1)
    return 0
}

benchmark_validator_show_errors() {
    # This validator handles its own error display
    return 0
}

benchmark_validator_show_warning() {
    echo "WARNING: Benchmark: $1" >&2
}

benchmark_validator_show_error() {
    echo "ERROR: Benchmark: $1" >&2
}
