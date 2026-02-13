#!/usr/bin/env bash
# =============================================================================
# shell-startup-time.sh - Shell initialization performance tracker
# =============================================================================
# Measures and displays shell startup time with performance grading.
# Uses millisecond-precision timing (via perl or date) to show how long
# the shell took to initialize, with color-coded performance indicators.
# Dependencies:
#   - perl (optional, for millisecond precision)
#   - welcome/colors.sh (for color variables)
# Environment Variables:
#   WELCOME_SHELL_STARTUP_TIME - Enable/disable display (default: true)
#   SHELL_CONFIG_START_TIME     - Start time set by init.sh
# Performance Thresholds:
#   <200ms  = Excellent (green, ⚡)
#   <400ms  = Good (yellow, 🚀)
#   ≥400ms  = Slow (red, 🟠)
# Usage:
#   Source this file from welcome/main.sh - no direct usage needed
#   Controlled by WELCOME_SHELL_STARTUP_TIME environment variable
# =============================================================================

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

: "${WELCOME_SHELL_STARTUP_TIME:=true}"
[[ -z "${_WM_COLOR_RESET:-}" ]] && return 1

_welcome_show_shell_startup_time() {
    [[ "$WELCOME_SHELL_STARTUP_TIME" != "true" ]] && return 0
    [[ -z "${SHELL_CONFIG_START_TIME:-}" ]] && return 0

    # Calculate elapsed time in milliseconds
    # Use perl for millisecond precision (matches init.sh)
    local end_time elapsed_ms
    # shellcheck disable=SC2154
    if { [[ -n "${ZSH_VERSION:-}" ]] && (( $+commands[perl] )); } || command_exists "perl"; then
        end_time=$(perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000')
    else
        end_time=$(($(date +%s) * 1000))
    fi

    local start_time="${SHELL_CONFIG_START_TIME:-0}"

    # Validate we have numeric values
    [[ ! "$end_time" =~ ^[0-9]+$ ]] && return 0
    [[ ! "$start_time" =~ ^[0-9]+$ ]] && return 0

    elapsed_ms=$((end_time - start_time))

    # Sanity check - if elapsed_ms is negative or huge, skip display
    [[ $elapsed_ms -lt 0 || $elapsed_ms -gt 60000 ]] && return 0

    # Format timing display
    local timing_color timing_label icon

    if [[ $elapsed_ms -lt 200 ]]; then
        # Target met: <200ms
        timing_color="$_WM_COLOR_GREEN"
        timing_label="Excellent"
        icon="⚡"
    elif [[ $elapsed_ms -lt 400 ]]; then
        # Acceptable: <400ms
        timing_color="$_WM_COLOR_YELLOW"
        timing_label="Good"
        icon="🚀"
    else
        # Needs optimization: ≥400ms
        timing_color="$_WM_COLOR_RED"
        timing_label="Slow"
        icon="🟠"
    fi

    # Display shell startup time
    printf "\n${timing_color}  ${icon}  Shell startup: ${elapsed_ms}ms${_WM_COLOR_RESET} ${_WM_COLOR_DIM}(${timing_label})${_WM_COLOR_RESET}\n"

    # Show hint if slow
    if [[ $elapsed_ms -ge 400 ]]; then
        printf "${_WM_COLOR_DIM}     Run 'hyperfine --warmup 3 --runs 10 \"zsh -i -c exit\"' for details${_WM_COLOR_RESET}\n"
    fi
}
