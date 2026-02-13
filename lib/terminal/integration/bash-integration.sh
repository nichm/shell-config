#!/usr/bin/env bash
# =============================================================================
# 🔄 BASH INTEGRATION FOR TERMINALS
# =============================================================================
# Provides shell integration features for various terminals in Bash
# Features: prompt tracking, command completion, title updates
# Usage: Source this file from your .bashrc
#   source "$SHELL_CONFIG_DIR/lib/terminal/integration/bash-integration.sh"
# =============================================================================

# Exit if script is sourced more than once
[[ -n "${TERMINAL_BASH_INTEGRATION_LOADED:-}" ]] && return 0
TERMINAL_BASH_INTEGRATION_LOADED=1

# Ensure command_exists is available (sourced via init.sh/hook-bootstrap chain)
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common integration utilities
source "${SCRIPT_DIR}/common.sh"

# TITLE UPDATES
update_title() {
    local title="$1"

    case "$(detect_terminal)" in
        iterm2 | ghostty | kitty | wezterm | alacritty | warp)
            # ANSI escape sequence to set title
            printf '\e]0;%s\a' "$title"
            ;;
        *)
            # Generic xterm-style
            printf '\e]0;%s\a' "$title"
            ;;
    esac
}

# PROMPT COMMAND
if [[ -z "${PROMPT_COMMAND:-}" ]]; then
    PROMPT_COMMAND="update_title 'bash: \w'"
else
    PROMPT_COMMAND="$PROMPT_COMMAND; update_title 'bash: \w'"
fi

# INTEGRATION FEATURES
enable_integration_features() {
    local terminal
    terminal="$(detect_terminal)"

    case "$terminal" in
        iterm2)
            # iTerm2 shell integration (if installed)
            if [[ -f "$HOME/.iterm2/shell_integration.bash" ]]; then
                source "$HOME/.iterm2/shell_integration.bash"
            fi
            ;;
        kitty)
            # Kitty shell integration
            if command_exists "kitty"; then
                # Kitty provides shell integration via kitty + kitten
                :
            fi
            ;;
        ghostty)
            # Ghostty supports shell integration automatically
            ;;
        warp)
            # Warp has built-in shell integration
            ;;
    esac
}

# KEYBINDINGS
setup_terminal_keybindings() {
    local terminal
    terminal="$(detect_terminal)"

    # Clear screen with Ctrl+L (standard)
    bind -x '"\C-L": clear'

    # Terminal-specific keybindings can be added here
    case "$terminal" in
        iterm2 | kitty | ghostty | warp)
            # Terminal-specific keybindings if needed
            ;;
    esac
}

# PROMPT ENHANCEMENTS
setup_terminal_prompt() {
    local terminal
    terminal="$(detect_terminal)"

    # Terminal-specific prompt enhancements can be added here
    # This is a placeholder for future customizations
    :
}

# INITIALIZATION
enable_integration_features

# Setup keybindings
setup_terminal_keybindings

# Setup prompt enhancements
setup_terminal_prompt

# Export function for use in other scripts (bash only - zsh's export -f prints definitions to stdout)
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f detect_terminal update_title 2>/dev/null || true
fi

# Log initialization (if verbose mode is enabled)
if [[ "$TERMINAL_INTEGRATION_VERBOSE" == "true" ]]; then
    echo "Terminal integration loaded for: $(detect_terminal)"
fi
