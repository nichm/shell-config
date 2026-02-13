#!/usr/bin/env bash
# =============================================================================
# 🚀 TERMINAL INSTALLATION ORCHESTRATOR
# =============================================================================
# Main entry point for terminal emulator installation
# Supports: Ghostty, iTerm2, Warp, Kitty, WezTerm, Alacritty
# Usage:
#   ./install-terminal.sh [terminal] [options]
# Examples:
#   ./install-terminal.sh ghostty        # Install Ghostty
#   ./install-terminal.sh iterm2         # Install iTerm2
#   ./install-terminal.sh warp           # Install Warp
#   ./install-terminal.sh kitty          # Install Kitty
#   ./install-terminal.sh --list         # List supported terminals
#   ./install-terminal.sh --detect       # Detect current terminal
# Options:
#   --list, -l      List all supported terminals
#   --detect, -d    Detect current terminal
#   --help, -h      Show help message
# =============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities directly from lib/terminal/common.sh
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# Installation modules directory
INSTALLATION_DIR="${SCRIPT_DIR}/installation"

# Supported terminals
declare -A SUPPORTED_TERMINALS=(
    ["ghostty"]="Modern, GPU-accelerated terminal (macOS, Linux)"
    ["iterm2"]="Feature-rich terminal for macOS only"
    ["warp"]="Rust-based terminal with AI integration (macOS, Linux)"
    ["kitty"]="Fast, feature-rich GPU terminal (macOS, Linux)"
    ["wezterm"]="Cross-platform terminal with Lua config"
    ["alacritty"]="Fast GPU terminal for X11/Wayland"
)

# =============================================================================
# DETECT CURRENT TERMINAL
# =============================================================================
detect_current_terminal() {
    # Check environment variables and processes

    # Ghostty
    if [[ -n "$GHOSTTY_RESOURCE_DIR" ]] || pgrep -q "ghostty"; then
        echo "ghostty"
        return 0
    fi

    # iTerm2
    if [[ -n "$ITERM_SESSION_ID" ]] || pgrep -q "iTerm2"; then
        echo "iterm2"
        return 0
    fi

    # Warp
    if [[ -n "$TERM_PROGRAM" && "$TERM_PROGRAM" == "WarpTerminal" ]] || pgrep -q "WarpTerminal"; then
        echo "warp"
        return 0
    fi

    # Kitty
    if [[ -n "$KITTY_WINDOW_ID" ]] || pgrep -q "kitty"; then
        echo "kitty"
        return 0
    fi

    # WezTerm
    if [[ -n "$WEZTERM_EXECUTABLE" ]] || pgrep -q "wezterm"; then
        echo "wezterm"
        return 0
    fi

    # Alacritty
    if [[ -n "$ALACRITTY_WINDOW_ID" ]] || pgrep -q "alacritty"; then
        echo "alacritty"
        return 0
    fi

    # Terminal.app (macOS default)
    if [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
        echo "terminal-app"
        return 0
    fi

    # Unknown terminal
    echo "unknown"
}

# =============================================================================
# LIST SUPPORTED TERMINALS
# =============================================================================
list_supported_terminals() {
    echo ""
    log_step "Supported Terminals"
    echo ""

    local terminal_name
    local description

    printf '%s\n' "${!SUPPORTED_TERMINALS[@]}" | sort | while IFS= read -r terminal_name; do
        description="${SUPPORTED_TERMINALS[$terminal_name]}"
        printf "  %-12s %s\n" "$terminal_name" "$description"
    done

    echo ""
    log_info "Install with: $0 <terminal-name>"
    echo ""
}

# =============================================================================
# INSTALL TERMINAL
# =============================================================================
install_terminal() {
    local terminal_name="$1"

    # Normalize terminal name (Bash 5 native lowercase)
    terminal_name="${terminal_name,,}"

    # Check if terminal is supported
    # Check if terminal is in supported list
    local supported=false
    for term in "${!SUPPORTED_TERMINALS[@]}"; do
        if [[ "$term" == "$terminal_name" ]]; then
            supported=true
            break
        fi
    done

    if [[ "$supported" == "false" ]]; then
        log_error "Unsupported terminal: $terminal_name"
        echo ""
        log_info "Run '$0 --list' to see supported terminals"
        return 1
    fi

    log_step "Installing $terminal_name"

    # Source and run the appropriate installer
    case "$terminal_name" in
        ghostty)
            source "${INSTALLATION_DIR}/ghostty.sh"
            install_ghostty
            ;;
        iterm2)
            source "${INSTALLATION_DIR}/iterm2.sh"
            install_iterm2
            ;;
        warp)
            source "${INSTALLATION_DIR}/warp.sh"
            install_warp
            ;;
        kitty)
            source "${INSTALLATION_DIR}/kitty.sh"
            install_kitty
            ;;
        wezterm)
            log_error "WezTerm installer not yet implemented"
            log_info "Please install manually from https://wezterm.org"
            return 1
            ;;
        alacritty)
            log_error "Alacritty installer not yet implemented"
            log_info "Please install manually from https://github.com/alacritty/alacritty"
            return 1
            ;;
        *)
            log_error "Unknown terminal: $terminal_name"
            return 1
            ;;
    esac
}

# =============================================================================
# PRINT USAGE
# =============================================================================
print_usage() {
    cat <<EOF
Usage: $0 [terminal] [options]

Terminal Installation Orchestrator - Install and configure terminal emulators

Arguments:
  terminal       Terminal to install (ghostty, iterm2, warp, kitty, etc.)

Options:
  --list, -l     List all supported terminals
  --detect, -d   Detect current terminal
  --help, -h     Show this help message

Examples:
  $0 ghostty              Install Ghostty terminal
  $0 iterm2               Install iTerm2
  $0 warp                 Install Warp terminal
  $0 kitty                Install Kitty terminal
  $0 --list               List all supported terminals
  $0 --detect             Detect current terminal

For more information, see:
  https://github.com/YOUR_GITHUB_ORG/shell-config

EOF
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    # Check if no arguments provided
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 0
    fi

    # Parse arguments - process options first, then terminal name
    local terminal=""

    # First pass: handle options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --list | -l)
                list_supported_terminals
                exit 0
                ;;
            --detect | -d)
                terminal=$(detect_current_terminal)
                log_info "Current terminal: $terminal"
                exit 0
                ;;
            --help | -h)
                print_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                echo ""
                print_usage
                exit 1
                ;;
            *)
                # Non-option argument: terminal name
                if [[ -z "$terminal" ]]; then
                    terminal="$1"
                fi
                ;;
        esac
        shift
    done

    # Install terminal if specified
    if [[ -n "$terminal" ]]; then
        if install_terminal "$terminal"; then
            echo ""
            log_success "=========================================="
            log_success "$terminal installation complete!"
            log_success "=========================================="
            echo ""
            list_installed_tools
            echo ""
            log_info "Next steps:"
            log_info "  1. Launch $terminal from Applications"
            log_info "  2. Configure your preferences"
            log_info "  3. Install autocomplete tools with: ./install.sh"
            echo ""
        else
            echo ""
            log_error "$terminal installation failed"
            echo ""
            list_installed_tools
            exit 1
        fi
    else
        print_usage
        exit 1
    fi
}

# Run main if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
