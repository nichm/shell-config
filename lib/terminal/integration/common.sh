#!/usr/bin/env bash
# =============================================================================
# 🔧 COMMON INTEGRATION UTILITIES
# =============================================================================
# Shared functions for terminal shell integration
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# =============================================================================

# Exit if script is sourced more than once
[[ -n "${TERMINAL_INTEGRATION_COMMON_LOADED:-}" ]] && return 0
TERMINAL_INTEGRATION_COMMON_LOADED=1

# Ensure command_exists is available (sourced via init.sh/hook-bootstrap chain)
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# =============================================================================
# TERMINAL DETECTION
# =============================================================================
detect_terminal() {
    # Check environment variables first (most reliable)

    # Ghostty
    if [[ -n "$GHOSTTY_RESOURCE_DIR" ]]; then
        echo "ghostty"
        return 0
    fi

    # iTerm2
    if [[ -n "$ITERM_SESSION_ID" ]]; then
        echo "iterm2"
        return 0
    fi

    # Warp
    if [[ -n "$TERM_PROGRAM" && "$TERM_PROGRAM" == "WarpTerminal" ]]; then
        echo "warp"
        return 0
    fi

    # Kitty
    if [[ -n "$KITTY_WINDOW_ID" ]]; then
        echo "kitty"
        return 0
    fi

    # WezTerm
    if [[ -n "$WEZTERM_EXECUTABLE" ]]; then
        echo "wezterm"
        return 0
    fi

    # Alacritty
    if [[ -n "$ALACRITTY_WINDOW_ID" ]]; then
        echo "alacritty"
        return 0
    fi

    # Check running processes as fallback (if pgrep is available)
    if command_exists "pgrep"; then
        # Ghostty
        if pgrep -q "ghostty" 2>/dev/null; then
            echo "ghostty"
            return 0
        fi

        # iTerm2
        if pgrep -q "iTerm2" 2>/dev/null; then
            echo "iterm2"
            return 0
        fi

        # Warp
        if pgrep -q "WarpTerminal" 2>/dev/null; then
            echo "warp"
            return 0
        fi

        # Kitty
        if pgrep -q "kitty" 2>/dev/null; then
            echo "kitty"
            return 0
        fi

        # WezTerm
        if pgrep -q "wezterm" 2>/dev/null; then
            echo "wezterm"
            return 0
        fi

        # Alacritty
        if pgrep -q "alacritty" 2>/dev/null; then
            echo "alacritty"
            return 0
        fi
    fi

    # Terminal.app (macOS default)
    if [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
        echo "terminal-app"
        return 0
    fi

    # Unknown terminal
    echo "unknown"
}

# Export function (bash only - zsh's export -f prints definitions to stdout)
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f detect_terminal 2>/dev/null || true
fi
