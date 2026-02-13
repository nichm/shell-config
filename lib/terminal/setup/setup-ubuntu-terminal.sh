#!/usr/bin/env bash
set -euo pipefail

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Script: setup-ubuntu-terminal.sh
# Purpose: Automated setup of WezTerm with autocomplete on Ubuntu/Debian
# Usage: ./setup-ubuntu-terminal.sh [--skip-terminal] [--skip-autocomplete]
# This script installs and configures:
# - WezTerm terminal emulator (cross-platform, Ghostty alternative for Linux)
# - Inshellisense (IDE-style autocomplete)
# - zsh-autosuggestions (fish-like suggestions)
# - fzf (fuzzy search)
# - Claude Code completion
# Supported architectures: x86_64, arm64
# Supported distributions: Ubuntu, Debian
# Exit codes:
#   0 - Success
#   1 - General error
#   2 - Wrong OS (not Linux)
#   3 - Missing dependencies
#   4 - Installation failed

# Source shared functions
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/terminal-setup-common.sh"

# Check if running on Linux
if [[ "$(detect_os)" != "linux" ]]; then
    log_error "This script is designed for Ubuntu/Debian Linux only. Use setup-macos-terminal.sh for macOS."
    exit 2
fi

# Detect Linux distribution
DISTRO=$(detect_linux_distro)
if [[ "$DISTRO" != "ubuntu" && "$DISTRO" != "debian" ]]; then
    log_error "Unsupported Linux distribution: $DISTRO"
    log_info "This script supports Ubuntu and Debian."
    log_info "For Fedora/RHEL, consider using setup-autocomplete-tools.sh instead."
    exit 2
fi

# Detect architecture
ARCH=$(detect_architecture)
if [[ "$ARCH" == "unknown" ]]; then
    log_error "Unsupported architecture: $(uname -m)"
    log_info "WezTerm supports x86_64 and arm64."
    exit 4
fi

log_info "Detected: $DISTRO on $ARCH"

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
            echo "  --skip-terminal      Skip WezTerm installation"
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

log_info "Starting Ubuntu terminal setup..."

# Update package lists
log_info "Updating package lists..."
sudo apt-get update -q

# Install basic dependencies
log_info "Installing basic dependencies..."
sudo apt-get install -y curl git wget build-essential cmake pkg-config libssh-dev libx11-dev libxtst-dev libxext-dev libxrender-dev libxkbcommon-dev libxkbcommon-x11-dev

# Install WezTerm
if [[ "$SKIP_TERMINAL" = false ]]; then
    log_info "Installing WezTerm terminal..."

    if command_exists "wezterm"; then
        log_warning "WezTerm already installed, skipping..."
    else
        # Download latest WezTerm release
        # Fetch latest release tag from GitHub API
        log_info "Fetching latest WezTerm version..."
        WEZTERM_LATEST=$(curl -s https://api.github.com/repos/wez/wezterm/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' || echo "")
        if [[ -z "$WEZTERM_LATEST" ]]; then
            log_error "Failed to fetch latest WezTerm version from GitHub API"
            exit 4
        fi
        log_info "Using WezTerm version: ${WEZTERM_LATEST}"

        # Determine URL based on architecture
        if [[ "$ARCH" == "x86_64" ]]; then
            WEZTERM_URL="https://github.com/wez/wezterm/releases/download/${WEZTERM_LATEST}/wezterm-${WEZTERM_LATEST}.Ubuntu22.04.deb"
        elif [[ "$ARCH" == "arm64" ]]; then
            # ARM64 builds are available but may have different naming
            WEZTERM_URL="https://github.com/wez/wezterm/releases/download/${WEZTERM_LATEST}/wezterm-${WEZTERM_LATEST}.Ubuntu22.04.aarch64.deb"
        else
            log_error "Unsupported architecture: $ARCH"
            log_info "WezTerm supports x86_64 and arm64."
            log_info "Please install manually from https://wezterm.org"
            exit 4
        fi

        log_info "Downloading WezTerm..."
        cd /tmp
        if ! wget -O wezterm.deb "$WEZTERM_URL"; then
            log_error "Failed to download WezTerm"
            exit 4
        fi

        log_info "Installing WezTerm..."
        if ! sudo dpkg -i wezterm.deb; then
            log_error "Failed to install WezTerm package, attempting to fix dependencies..."
            if ! sudo apt-get install -f -y; then
                log_error "Failed to install WezTerm dependencies"
                exit 4
            fi
        fi

        rm -f wezterm.deb

        if ! command_exists "wezterm"; then
            log_error "WezTerm installation verification failed"
            exit 4
        fi
        log_success "WezTerm installed"
        log_version "WezTerm" "wezterm --version"
        track_installation "wezterm" "success"

        # Create WezTerm config directory
        WEZTERM_CONFIG_DIR="$HOME/.wezterm"
        mkdir -p "$WEZTERM_CONFIG_DIR"

        # Create optimized WezTerm config
        if [[ -f "${SCRIPT_DIR}/wezterm-config-ubuntu.lua" ]]; then
            cat "${SCRIPT_DIR}/wezterm-config-ubuntu.lua" >"$WEZTERM_CONFIG_DIR/wezterm.lua"
        else
            log_error "WezTerm config template missing: ${SCRIPT_DIR}/wezterm-config-ubuntu.lua"
            exit 4
        fi

        log_success "WezTerm configuration created at $WEZTERM_CONFIG_DIR/wezterm.lua"
    fi
else
    log_info "Skipping WezTerm installation (--skip-terminal flag)"
fi

# Install autocomplete tools
if [[ "$SKIP_AUTOCOMPLETE" = false ]]; then
    log_info "Setting up autocomplete tools..."

    # Check for zsh
    if ! command_exists "zsh"; then
        log_info "Installing zsh..."
        if ! sudo apt-get install -y zsh; then
            log_error "Failed to install zsh"
            exit 4
        fi
        if ! command_exists "zsh"; then
            log_error "zsh installation verification failed"
            exit 4
        fi
        log_success "zsh installed"
    fi

    # Check for Oh My Zsh
    OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
    if [[ ! -d "$OH_MY_ZSH_DIR" ]]; then
        log_info "Installing Oh My Zsh..."
        # SECURITY: Download to temp file before executing
        OMZ_INSTALLER=$(mktemp) || {
            log_error "Failed to create temp file for Oh My Zsh installer"
            exit 4
        }
        trap 'rm -f "$OMZ_INSTALLER"' EXIT INT TERM
        if ! curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$OMZ_INSTALLER"; then
            log_error "Failed to download Oh My Zsh installer"
            exit 4
        fi
        if ! sh "$OMZ_INSTALLER" "" --unattended; then
            log_error "Failed to install Oh My Zsh"
            exit 4
        fi
        trap ':' EXIT INT TERM
        log_success "Oh My Zsh installed"
    else
        log_success "Oh My Zsh already installed"
    fi

    # Install Node.js (required for Inshellisense)
    if ! command_exists "node"; then
        log_info "Installing Node.js..."
        _node_setup=$(mktemp)
        curl -fsSL https://deb.nodesource.com/setup_lts.x -o "$_node_setup"
        sudo -E bash "$_node_setup"
        rm -f "$_node_setup"
        if ! sudo apt-get install -y nodejs; then
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
        if ! git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf 2>/dev/null; then
            log_error "Failed to clone fzf"
            exit 4
        fi
        if ! ~/.fzf/install --all; then
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
            # Update plugins line using sed
            if ! sed -i.bak 's/^plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting claudecode fzf)/' "$ZSHRC" 2>/dev/null; then
                log_warning "Failed to update plugins line in .zshrc for Linux. Please check manually."
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
log_success "Ubuntu terminal setup complete!"
log_success "=========================================="
print_installation_summary
log_info ""
log_info "Next steps:"
log_info "1. Launch WezTerm from your application menu"
log_info "2. Your shell will have autocomplete enabled"
log_info "3. Try typing commands and use TAB for suggestions"
log_info ""
log_info "Autocomplete features:"
log_info "  • Inshellisense: IDE-style autocomplete for 600+ tools"
log_info "  • zsh-autosuggestions: Fish-like autosuggestions (gray text)"
log_info "  • fzf: Ctrl+R for fuzzy history search"
log_info "  • Claude Code completion: Type 'claude' + TAB for commands"
log_info ""
log_info "WezTerm key bindings:"
log_info "  • Ctrl+Shift+C/V: Copy/Paste"
log_info "  • Ctrl+Shift+-: Split horizontal"
log_info "  • Ctrl+Shift+=: Split vertical"
log_info "  • Ctrl+Shift+W: Close pane"
log_info ""
log_warning "Note: Restart your shell or run 'exec zsh' to apply changes"
