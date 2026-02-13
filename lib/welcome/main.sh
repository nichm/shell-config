#!/usr/bin/env bash
# =============================================================================
# 👋 WELCOME - Terminal Welcome Message
# =============================================================================
# Full welcome with terminal status, git hooks, autocomplete guide, shortcuts.
# CONFIGURATION (set in ~/.zshrc before sourcing init.sh):
#   export WELCOME_MESSAGE_ENABLED=true|false    # Default: true
#   export WELCOME_AUTOCOMPLETE_GUIDE=true|false # Default: true
#   export WELCOME_SHORTCUTS=true|false          # Default: true
# MODULES:
#   - terminal-status.sh    - Tool availability checks (✓/✗ display)
#   - git-hooks-status.sh   - Git hooks and validators status
#   - autocomplete-guide.sh - Keybinding help for fzf, autosuggestions, etc.
#   - shortcuts.sh          - Custom alias quick reference
#   - shell-startup-time.sh - Startup performance display
# =============================================================================

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Configuration (mapped from SHELL_CONFIG_* for backwards compatibility)
: "${WELCOME_MESSAGE_ENABLED:=${SHELL_CONFIG_WELCOME:-true}}"
: "${WELCOME_AUTOCOMPLETE_GUIDE:=${SHELL_CONFIG_AUTOCOMPLETE_GUIDE:-true}}"
: "${WELCOME_SHORTCUTS:=${SHELL_CONFIG_SHORTCUTS:-true}}"

# Get the directory where this script lives (bash/zsh compatible)
if [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _WELCOME_DIR="$SHELL_CONFIG_DIR/lib/welcome"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _WELCOME_DIR="${BASH_SOURCE[0]%/*}"
    [[ "$_WELCOME_DIR" == "${BASH_SOURCE[0]}" ]] && _WELCOME_DIR="."
else
    _WELCOME_DIR="${HOME}/.shell-config/lib/welcome"
fi

# Source shared colors library (MANDATORY per CLAUDE.md)
source "${_WELCOME_DIR}/../core/colors.sh"

# Map to welcome module color names for compatibility
_WM_COLOR_RESET="$COLOR_RESET"
_WM_COLOR_BOLD="$COLOR_BOLD"
_WM_COLOR_DIM="$COLOR_DIM"
_WM_COLOR_GREEN="$COLOR_GREEN"
_WM_COLOR_BLUE="$COLOR_BLUE"
_WM_COLOR_YELLOW="$COLOR_YELLOW"
_WM_COLOR_CYAN="$COLOR_CYAN"
_WM_COLOR_GRAY="$COLOR_DIM"
_WM_COLOR_RED="$COLOR_RED"

# Load Modules
source "$_WELCOME_DIR/terminal-status.sh"
source "$_WELCOME_DIR/git-hooks-status.sh"
source "$_WELCOME_DIR/autocomplete-guide.sh"
source "$_WELCOME_DIR/shortcuts.sh"
source "$_WELCOME_DIR/shell-startup-time.sh"

# Terminal Link Support

_welcome_terminal_supports_links() {
    [[ "${TERM_PROGRAM:-}" == "vscode" ]] && return 0
    [[ "${TERM_PROGRAM:-}" == "cursor" ]] && return 0
    [[ "${VTE_VERSION:-}" != "" ]] && return 0
    [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]] && return 0
    return 1
}

_welcome_print_link() {
    local file_path="$1"
    local text="$2"
    local line_number="${3:-}"

    if _welcome_terminal_supports_links; then
        if [[ -n "$line_number" ]]; then
            printf '\e]8;;cursor://file%s:%s\e\\%s\e]8;;\e\\' "$file_path" "$line_number" "$text"
        else
            printf '\e]8;;cursor://file%s\e\\%s\e]8;;\e\\' "$file_path" "$text"
        fi
    else
        printf "%s" "$text"
    fi
}

_welcome_get_datetime() {
    local format="${1:-%A, %B %d, %Y}"
    date +"$format" 2>/dev/null || echo ""
}

# Main

welcome_message() {
    # Check if enabled
    [[ "$WELCOME_MESSAGE_ENABLED" != "true" ]] && return 0
    [[ "$WELCOME_MESSAGE_ENABLED" == "false" ]] && return 0
    # Skip if already shown in this session
    [[ -n "${WELCOME_MESSAGE_SHOWN:-}" ]] && return 0

    local datetime user_name
    datetime=$(_welcome_get_datetime "%A, %B %d at %I:%M %p")
    user_name="${USER:-$(whoami)}"

    echo ""
    printf "${_WM_COLOR_BOLD}👋 Hey %s${_WM_COLOR_RESET} ${_WM_COLOR_DIM}• %s${_WM_COLOR_RESET}\n" "$user_name" "$datetime"

    # Show terminal status (runs verification and exports results)
    _ts_export_verification
    _welcome_show_terminal_status

    # Show git hooks and validators status
    _welcome_show_git_hooks_status

    # Show autocomplete guide (uses exported verification results)
    _welcome_show_autocomplete_guide

    # Show shortcuts
    _welcome_show_shortcuts

    # Show shell startup time
    _welcome_show_shell_startup_time
    echo ""

    # Mark shown and export for session tracking
    export WELCOME_MESSAGE_SHOWN=true
}

# Auto-run when sourced from shell RC file
if [[ "${WELCOME_MESSAGE_AUTORUN:-true}" == "true" ]]; then
    welcome_message
fi
