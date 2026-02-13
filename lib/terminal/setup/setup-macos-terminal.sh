#!/usr/bin/env bash
set -euo pipefail

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Script: setup-macos-terminal.sh
# Purpose: Automated setup of Ghostty terminal with autocomplete on macOS
# Usage: ./setup-macos-terminal.sh [--skip-terminal] [--skip-autocomplete]
# This script installs and configures:
# - Ghostty terminal emulator
# - Inshellisense (IDE-style autocomplete)
# - zsh-autosuggestions (fish-like suggestions)
# - fzf (fuzzy search)
# - Claude Code completion
# Exit codes:
#   0 - Success
#   1 - General error
#   2 - Wrong OS (not macOS)
#   3 - Missing dependencies
#   4 - Installation failed

# Source shared functions
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/terminal-setup-common.sh"

# Check if running on macOS
if [[ "$(detect_os)" != "macos" ]]; then
    log_error "This script is designed for macOS only. Use setup-ubuntu-terminal.sh for Ubuntu."
    exit 2
fi

# Parse arguments
SKIP_TERMINAL=false
SKIP_AUTOCOMPLETE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-terminal)
            SKIP_TERMINAL=true
            shift
            ;;
        --skip-autocomplete)
            SKIP_AUTOCOMPLETE=true
            shift
            ;;
        -h | --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --skip-terminal      Skip Ghostty installation"
            echo "  --skip-autocomplete  Skip autocomplete tools installation"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "Starting macOS terminal setup..."

# Check for Homebrew
if ! command_exists "brew"; then
    log_info "Installing Homebrew..."
    _brew_installer=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$_brew_installer"
    /bin/bash "$_brew_installer"
    rm -f "$_brew_installer"

    # Add Homebrew to PATH for Apple Silicon
    if [[ "$(uname -m)" == "arm64" ]]; then
        if ! grep -q 'eval "$(/opt/homebrew/bin/brew shellenv)"' ~/.zprofile 2>/dev/null; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
        fi
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    if ! command_exists "brew"; then
        log_error "Homebrew installation failed"
        exit 4
    fi
    log_success "Homebrew installed"
    log_version "Homebrew" "brew --version | head -n 1"
else
    log_success "Homebrew already installed"
    log_version "Homebrew" "brew --version | head -n 1"
fi

# Install Ghostty terminal
if [[ "$SKIP_TERMINAL" = false ]]; then
    log_info "Installing Ghostty terminal..."

    if brew list --cask ghostty &>/dev/null; then
        log_warning "Ghostty already installed, skipping..."
    else
        if ! brew install --cask ghostty; then
            log_error "Failed to install Ghostty"
            exit 4
        fi
        if ! command_exists "ghostty"; then
            log_error "Ghostty installation verification failed"
            exit 4
        fi
        log_success "Ghostty installed"
        track_installation "ghostty" "success"

        # Create Ghostty config directory
        GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
        mkdir -p "$GHOSTTY_CONFIG_DIR"

        # Create optimized Ghostty config
        cat >"$GHOSTTY_CONFIG_DIR/config" <<'EOF'
# Ghostty Configuration
# Optimized for performance and integration with autocomplete tools

# Font configuration
font-family = JetBrains Mono
font-size = 14
font-feature = ss01
font-feature = ss02

# Theme (adjust to preference)
theme = light

# Performance optimizations
resize-increment = 50
scrollback-limit = 10000

# Key bindings
# Cmd+Enter for fullscreen (macOS standard)
keybind = cmd+enter=toggle_fullscreen

# Copy/paste improvements
keybind = cmd+c=copy_to_clipboard
keybind = cmd+v=paste_from_clipboard

# Shell integration
shell-integration = detect

# Mouse
mouse-hide-while-typing = true
copy-on-select = false

# Window
window-padding-x = 8
window-padding-y = 8
window-decoration = true
window-theme = auto
window-width = 140
window-height = 40

# Tabs
tab-width = 200

# Background opacity (optional, adjust to preference)
# background-opacity = 0.95
EOF

        log_success "Ghostty configuration created at $GHOSTTY_CONFIG_DIR/config"
    fi
else
    log_info "Skipping Ghostty installation (--skip-terminal flag)"
fi

# Install autocomplete tools
if [[ "$SKIP_AUTOCOMPLETE" = false ]]; then
    log_info "Setting up autocomplete tools..."

    # Check for zsh
    if ! command_exists "zsh"; then
        log_warning "zsh not found. Installing..."
        brew install zsh
    fi

    # Check for Oh My Zsh
    OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
    if [[ ! -d "$OH_MY_ZSH_DIR" ]]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        log_success "Oh My Zsh installed"
    else
        log_success "Oh My Zsh already installed"
    fi

    # Install Node.js (required for Inshellisense)
    if ! command_exists "node"; then
        log_info "Installing Node.js..."
        if ! brew install node; then
            log_error "Failed to install Node.js"
            exit 4
        fi
        if ! command_exists "node"; then
            log_error "Node.js installation verification failed"
            exit 4
        fi
        log_success "Node.js installed"
        log_version "Node.js" "node --version"
    fi

    # Install Inshellisense
    # Note: Bun global binaries install to ~/.bun/bin, so we add it to PATH
    log_info "Installing Inshellisense (IDE-style autocomplete)..."
    if command_exists "is" || "$HOME/.bun/bin/is" --version &>/dev/null; then
        log_warning "Inshellisense already installed, updating..."
        if ! bun update -g @microsoft/inshellisense; then
            log_error "Failed to update Inshellisense"
            exit 4
        fi
    else
        if ! bun install -g @microsoft/inshellisense; then
            log_error "Failed to install Inshellisense"
            exit 4
        fi
    fi
    if ! command_exists "is" && ! "$HOME/.bun/bin/is" --version &>/dev/null; then
        log_error "Inshellisense installation verification failed"
        exit 4
    fi
    log_success "Inshellisense installed"
    log_version "Inshellisense" "is --version 2>&1 | head -n 1 || $HOME/.bun/bin/is --version 2>&1 | head -n 1"
    track_installation "inshellisense" "success"

    # Install zsh-autosuggestions
    ZSH_AUTOSUGGESTIONS_DIR="$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    if [[ ! -d "$ZSH_AUTOSUGGESTIONS_DIR" ]]; then
        log_info "Installing zsh-autosuggestions..."
        if ! git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGESTIONS_DIR" 2>/dev/null; then
            log_error "Failed to clone zsh-autosuggestions"
            exit 4
        fi
        log_success "zsh-autosuggestions installed"
        track_installation "zsh-autosuggestions" "success"
    else
        log_info "Updating zsh-autosuggestions..."
        if ! git -C "$ZSH_AUTOSUGGESTIONS_DIR" pull 2>/dev/null; then
            log_error "Failed to update zsh-autosuggestions"
            exit 4
        fi
    fi

    # Install fzf
    if command_exists "fzf"; then
        log_info "fzf already installed"
        log_version "fzf" "fzf --version"
    else
        log_info "Installing fzf (fuzzy search)..."
        if ! brew install fzf; then
            log_error "Failed to install fzf"
            exit 4
        fi
        if ! "$(brew --prefix)/opt/fzf/install" --all; then
            log_error "Failed to configure fzf"
            exit 4
        fi
        log_success "fzf installed"
        log_version "fzf" "fzf --version"
        track_installation "fzf" "success"
    fi

    # Install zsh-syntax-highlighting
    if [[ ! -d "$ZSH_SYNTAX_DIR" ]]; then
        log_info "Installing zsh-syntax-highlighting..."
        if ! git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_SYNTAX_DIR" 2>/dev/null; then
            log_error "Failed to clone zsh-syntax-highlighting"
            exit 4
        fi
        log_success "zsh-syntax-highlighting installed"
        track_installation "zsh-syntax-highlighting" "success"
    fi

    # Install Claude Code completion
    if [[ ! -d "$CLAUDE_COMPLETION_DIR" ]]; then
        log_info "Installing Claude Code completion..."
        if ! git clone https://github.com/wbingli/zsh-claudecode-completion "$CLAUDE_COMPLETION_DIR" 2>/dev/null; then
            log_error "Failed to clone Claude Code completion"
            exit 4
        fi
        log_success "Claude Code completion installed"
        track_installation "claude-completion" "success"
    else
        log_info "Updating Claude Code completion..."
        if ! git -C "$CLAUDE_COMPLETION_DIR" pull 2>/dev/null; then
            log_error "Failed to update Claude Code completion"
            exit 4
        fi
    fi

    # Backup existing .zshrc
    ZSHRC="$HOME/.zshrc"
    if [[ -f "$ZSHRC" ]]; then
        BACKUP_ZSHRC="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ZSHRC" "$BACKUP_ZSHRC"
        log_info "Backed up existing .zshrc to $BACKUP_ZSHRC"
    fi

    # Configure .zshrc
    log_info "Configuring .zshrc..."

    # Check if Inshellisense init is already in .zshrc
    if ! grep -q 'is init zsh' "$ZSHRC" 2>/dev/null; then
        cat >>"$ZSHRC" <<'EOF'

# === Terminal Autocomplete Configuration ===
# Bun global binaries
export PATH="$HOME/.bun/bin:$PATH"
# Inshellisense - IDE-style autocomplete
eval "$(is init zsh)"
EOF
    fi

    # Update plugins in .zshrc if needed
    if [[ -f "$ZSHRC" ]]; then
        if grep -q '^plugins=' "$ZSHRC"; then
            # Update plugins line
            if ! sed -i.bak 's/^plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting claudecode fzf)/' "$ZSHRC" 2>/dev/null; then
                log_warning "Failed to update plugins line in .zshrc for macOS. Please check manually."
            fi

            # Remove backup file created by sed
            rm -f "${ZSHRC}.bak"
        else
            # If plugins line doesn't exist, add it
            echo "plugins=(git zsh-autosuggestions zsh-syntax-highlighting claudecode fzf)" >>"$ZSHRC"
            log_success "Added plugins to .zshrc"
        fi
    fi

    log_success "Autocomplete tools configured"
else
    log_info "Skipping autocomplete installation (--skip-autocomplete flag)"
fi

# Print summary
log_success "=========================================="
log_success "macOS terminal setup complete!"
log_success "=========================================="
print_installation_summary
log_info ""
log_info "Next steps:"
log_info "1. Open Ghostty from Applications"
log_info "2. Your shell will have autocomplete enabled"
log_info "3. Try typing commands and use TAB for suggestions"
log_info ""
log_info "Autocomplete features:"
log_info "  • Inshellisense: IDE-style autocomplete for 600+ tools"
log_info "  • zsh-autosuggestions: Fish-like autosuggestions (gray text)"
log_info "  • fzf: Ctrl+R for fuzzy history search"
log_info "  • Claude Code completion: Type 'claude' + TAB for commands"
log_info ""
log_warning "Note: Restart your shell or run 'exec zsh' to apply changes"
