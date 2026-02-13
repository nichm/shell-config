#!/usr/bin/env bash
# =============================================================================
# Colors and Logging Library
# =============================================================================
# This is the canonical implementation of color definitions and logging functions.
# All other scripts should source this file instead of duplicating code.
# Usage: source "$SHELL_CONFIG_DIR/lib/core/colors.sh"
# Provides:
#   - ANSI color definitions (RED, GREEN, YELLOW, BLUE, etc.)
#   - Extended 256-color palette for git and UI elements
#   - Logging functions (log_info, log_success, log_warning, log_error, log_step)
# =============================================================================

# Guard against multiple sourcing
[[ -n "${_SHELL_CONFIG_CORE_COLORS_LOADED:-}" ]] && return 0
_SHELL_CONFIG_CORE_COLORS_LOADED=1

# =============================================================================
# Basic ANSI Colors
# =============================================================================

readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_DIM='\033[2m'
readonly COLOR_RESET='\033[0m'

export COLOR_RED COLOR_GREEN COLOR_YELLOW COLOR_BLUE COLOR_CYAN COLOR_BOLD COLOR_DIM COLOR_RESET

# =============================================================================
# Compatibility Aliases
# =============================================================================
# Used by other scripts via sourcing
readonly RED="$COLOR_RED"
readonly GREEN="$COLOR_GREEN"
readonly YELLOW="$COLOR_YELLOW"
readonly BLUE="$COLOR_BLUE"
readonly CYAN="$COLOR_CYAN"
readonly BOLD="$COLOR_BOLD"
readonly DIM="$COLOR_DIM"
readonly NC="$COLOR_RESET"
export RED GREEN YELLOW BLUE CYAN BOLD DIM NC

# =============================================================================
# Logging Functions
# =============================================================================

log_info() {
    printf '%bℹ️  %s%b\n' "${COLOR_BLUE}" "$1" "${COLOR_RESET}" >&2
}

log_success() {
    printf '%b✅ %s%b\n' "${COLOR_GREEN}" "$1" "${COLOR_RESET}" >&2
}

log_warning() {
    printf '%b⚠️  %s%b\n' "${COLOR_YELLOW}" "$1" "${COLOR_RESET}" >&2
}

log_error() {
    printf '%b❌ %s%b\n' "${COLOR_RED}" "$1" "${COLOR_RESET}" >&2
}

log_step() {
    printf '%b🔧 ━━━ %s ━━━%b\n' "${COLOR_CYAN}" "$1" "${COLOR_RESET}" >&2
}

# =============================================================================
# Export Functions
# =============================================================================

# Export logging functions for use in subshells (bash only)
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f log_info log_success log_warning log_error log_step 2>/dev/null || true
fi
