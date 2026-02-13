#!/usr/bin/env bash
# =============================================================================
# 🚀 TERMINAL AUTOCOMPLETE TOOLS INSTALLER
# =============================================================================
# Installs and configures:
#   - Oh My Zsh (if not present)
#   - Inshellisense (IDE-style autocomplete for 600+ tools)
#   - zsh-autosuggestions (fish-like suggestions)
#   - zsh-syntax-highlighting
#   - fzf (fuzzy search)
#   - Claude Code completion
# Usage:
#   ./install.sh [options]
# Options:
#   --skip-inshellisense  Skip Inshellisense installation
#   --skip-zsh-plugins    Skip zsh plugin installation
#   --skip-fzf            Skip fzf installation
#   -h, --help            Show this help message
# Compatible with: Ghostty, WezTerm, iTerm2, Alacritty, Kitty, Terminal.app
# Supported OS: macOS, Ubuntu, Debian, Fedora, Arch
# Exit codes:
#   0 - Success
#   1 - General error
#   2 - Unsupported OS
#   3 - Missing dependencies
#   4 - Installation failed
# =============================================================================

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "$SCRIPT_DIR/common.sh"
# shellcheck source=install-extras.sh
source "$SCRIPT_DIR/install-extras.sh"

# =============================================================================
# ARGUMENT PARSING
# =============================================================================
SKIP_INSHELLISENSE=false
SKIP_ZSH_PLUGINS=false
SKIP_FZF=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-inshellisense)
            SKIP_INSHELLISENSE=true
            shift
            ;;
        --skip-zsh-plugins)
            SKIP_ZSH_PLUGINS=true
            shift
            ;;
        --skip-fzf)
            SKIP_FZF=true
            shift
            ;;
        -h | --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --skip-inshellisense  Skip Inshellisense installation"
            echo "  --skip-zsh-plugins    Skip zsh plugin installation"
            echo "  --skip-fzf            Skip fzf installation"
            echo "  -h, --help            Show this help message"
            echo ""
            echo "This script sets up autocomplete tools that work with any terminal:"
            echo "  • Ghostty, WezTerm, iTerm2, Alacritty, Kitty, Terminal.app, etc."
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# =============================================================================
# OS DETECTION
# =============================================================================
OS_TYPE=$(detect_os)
if [[ "$OS_TYPE" == "unknown" ]]; then
    log_error "Unsupported operating system: $(uname)"
    exit 2
fi

log_step "Terminal Autocomplete Setup ($OS_TYPE)"
log_info "These tools work with any terminal emulator"

if [[ "$OS_TYPE" == "linux" ]]; then
    DISTRO=$(detect_linux_distro)
    PKG_MANAGER=$(detect_package_manager)
    log_info "Detected: $DISTRO (package manager: $PKG_MANAGER)"
fi

# =============================================================================
# INSTALL ZSH (if needed)
# =============================================================================
install_zsh() {
    if command_exists "zsh"; then
        log_success "zsh already installed"
        log_version "zsh" "zsh --version | head -n 1"
        return 0
    fi

    log_info "Installing zsh..."

    if [[ "$OS_TYPE" == "macos" ]]; then
        if ! command_exists "brew"; then
            log_error "Homebrew not found. Please install Homebrew first."
            exit 3
        fi
        brew install zsh || {
            log_error "Failed to install zsh"
            exit 4
        }
    else
        case "$PKG_MANAGER" in
            apt)
                sudo apt-get update -q
                sudo apt-get install -y zsh || {
                    log_error "Failed to install zsh"
                    exit 4
                }
                ;;
            dnf)
                sudo dnf install -y zsh || {
                    log_error "Failed to install zsh"
                    exit 4
                }
                ;;
            pacman)
                sudo pacman -S --noconfirm zsh || {
                    log_error "Failed to install zsh"
                    exit 4
                }
                ;;
            *)
                log_error "Unsupported package manager: $PKG_MANAGER"
                log_info "Please install zsh manually and run this script again"
                exit 3
                ;;
        esac
    fi

    # Verify zsh installation using command -v instead of verify_command
    if ! command_exists "zsh"; then
        log_error "zsh installation verification failed"
        exit 4
    fi
    log_success "zsh installed"
    track_installation "zsh" "success"
}

# =============================================================================
# INSTALL OH MY ZSH
# =============================================================================
install_oh_my_zsh() {
    if [[ -d "$OH_MY_ZSH_DIR" ]]; then
        log_success "Oh My Zsh already installed"
        return 0
    fi

    log_info "Installing Oh My Zsh..."

    # SECURITY: Download to temp file before executing
    local omz_installer
    if ! omz_installer=$(mktemp); then
        log_error "Failed to create temp file for Oh My Zsh installer"
        exit 4
    fi
    trap 'rm -f "$omz_installer"' EXIT INT TERM
    if ! curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$omz_installer"; then
        log_error "Failed to download Oh My Zsh installer"
        exit 4
    fi
    if ! sh "$omz_installer" "" --unattended; then
        log_error "Failed to install Oh My Zsh"
        exit 4
    fi
    trap ':' EXIT INT TERM

    log_success "Oh My Zsh installed"
    track_installation "oh-my-zsh" "success"
}

# =============================================================================
# INSTALL INSHELLISENSE
# =============================================================================
install_inshellisense() {
    if [[ "$SKIP_INSHELLISENSE" == true ]]; then
        log_info "Skipping Inshellisense installation (--skip-inshellisense)"
        track_installation "inshellisense" "skipped"
        return 0
    fi

    log_info "Installing Inshellisense (IDE-style autocomplete)..."

    # Check if already installed
    if command_exists "is" || [[ -x "$HOME/.bun/bin/is" ]]; then
        log_info "Inshellisense already installed, updating..."

        if command_exists "bun"; then
            bun update -g @microsoft/inshellisense 2>/dev/null || log_warning "Failed to update via bun"
        elif command_exists "pnpm"; then
            pnpm update -g @microsoft/inshellisense 2>/dev/null || log_warning "Failed to update via pnpm"
        fi

        log_success "Inshellisense updated"
        track_installation "inshellisense" "success"
        return 0
    fi

    # Install using bun (preferred) or pnpm
    if command_exists "bun"; then
        log_info "Installing via bun..."
        if ! bun install -g @microsoft/inshellisense; then
            log_error "Failed to install Inshellisense"
            exit 4
        fi
    elif command_exists "pnpm"; then
        log_info "Installing via pnpm..."
        if ! pnpm add -g @microsoft/inshellisense; then
            log_error "Failed to install Inshellisense"
            exit 4
        fi
    else
        log_warning "Neither bun nor pnpm found. Please install bun first."
        log_info "  brew install oven-sh/bun/bun"
        track_installation "inshellisense" "skipped"
        return 1
    fi

    # Verify installation
    if ! command_exists "is" && ! [[ -x "$HOME/.bun/bin/is" ]]; then
        log_error "Inshellisense installation verification failed"
        exit 4
    fi

    log_success "Inshellisense installed"
    log_version "Inshellisense" "is --version 2>&1 | head -n 1 || $HOME/.bun/bin/is --version 2>&1 | head -n 1"
    track_installation "inshellisense" "success"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    echo ""
    echo -e "${BOLD}${CYAN}🔮 Terminal Autocomplete Installer${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    install_zsh
    install_oh_my_zsh
    install_inshellisense

    if [[ "$SKIP_ZSH_PLUGINS" != true ]]; then
        install_zsh_plugins
    else
        log_info "Skipping zsh plugins installation (--skip-zsh-plugins)"
        track_installation "zsh-plugins" "skipped"
    fi

    if [[ "$SKIP_FZF" != true ]]; then
        install_fzf
    else
        log_info "Skipping fzf installation (--skip-fzf)"
        track_installation "fzf" "skipped"
    fi

    print_summary
}

# Run main only if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
