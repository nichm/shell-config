#!/usr/bin/env bash
# =============================================================================
# 🔄 ZSH INTEGRATION FOR TERMINALS
# =============================================================================
# Provides shell integration features for various terminals in Zsh
# Features: prompt tracking, command completion, title updates
# Usage: Source this file from your .zshrc
#   source "$SHELL_CONFIG_DIR/lib/terminal/integration/zsh-integration.sh"
# =============================================================================

# Exit if script is sourced more than once
[[ -n "${TERMINAL_ZSH_INTEGRATION_LOADED:-}" ]] && return 0
TERMINAL_ZSH_INTEGRATION_LOADED=1

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common integration utilities
source "${SCRIPT_DIR}/common.sh"

# TITLE UPDATES
update_title() {
    local title="$1"

    case "$(detect_terminal)" in
        iterm2 | ghostty | kitty | wezterm | alacritty)
            # ANSI escape sequence to set title
            print -Pn "\e]0;${title}\a"
            ;;
        warp)
            # Warp uses special title sequences
            print -Pn "\e]0;${title}\a"
            ;;
        *)
            # Generic xterm-style
            print -Pn "\e]0;${title}\a"
            ;;
    esac
}

# Auto-update title with current directory/command
autoload -U add-zsh-hook
add-zsh-hook precmd update_title_precmd
add-zsh-hook preexec update_title_preexec

update_title_precmd() {
    update_title "zsh: %~"
}

update_title_preexec() {
    local cmd="$1"
    update_title "$cmd"
}

# INTEGRATION FEATURES
enable_integration_features() {
    local terminal
    terminal="$(detect_terminal)"

    case "$terminal" in
        iterm2)
            # iTerm2 shell integration (if installed)
            if [[ -f "$HOME/.iterm2/shell_integration.zsh" ]]; then
                source "$HOME/.iterm2/shell_integration.zsh"
            fi
            ;;
        kitty)
            # Kitty shell integration
            # shellcheck disable=SC2154
            if (( $+commands[kitty] )); then
                # Kitty provides shell integration via kitty + kitten
                # This is handled automatically by kitty
                :
            fi
            ;;
        ghostty)
            # Ghostty supports shell integration automatically
            # No additional setup needed
            ;;
        warp)
            # Warp has built-in shell integration
            # No additional setup needed
            ;;
    esac
}

# KEYBINDINGS
setup_terminal_keybindings() {
    local terminal
    terminal="$(detect_terminal)"

    # Clear screen with Ctrl+L (standard)
    bindkey '^L' clear-screen

    # Terminal-specific keybindings
    case "$terminal" in
        iterm2)
            # iTerm2 shortcuts can be configured in iTerm2 preferences
            ;;
        kitty)
            # Kitty allows custom keybindings in kitty.conf
            ;;
        ghostty)
            # Ghostty allows custom keybindings in config
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
