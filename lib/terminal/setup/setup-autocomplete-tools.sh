#!/usr/bin/env bash
set -euo pipefail

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Script: setup-autocomplete-tools.sh
# Purpose: Install autocomplete tools for any terminal (works on macOS and Linux)
# Usage: ./setup-autocomplete-tools.sh [--skip-inshellisense] [--skip-zsh-plugins]
# This script installs and configures:
# - Inshellisense (IDE-style autocomplete)
# - zsh-autosuggestions (fish-like suggestions)
# - zsh-syntax-highlighting
# - fzf (fuzzy search)
# - Claude Code completion
# Compatible with: Ghostty, WezTerm, iTerm2, Alacritty, Kitty, and standard terminals
# Supported distributions: Ubuntu, Debian, Fedora, RHEL, Arch (via autocomplete tools only)
# Exit codes:
#   0 - Success
#   1 - General error
#   2 - Unsupported OS
#   3 - Missing dependencies
#   4 - Installation failed

# Source shared functions
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/terminal-setup-common.sh"

# Detect OS
OS_TYPE=$(detect_os)
if [[ "$OS_TYPE" == "unknown" ]]; then
    log_error "Unsupported operating system: $(uname)"
    exit 2
fi

# Parse arguments
SKIP_INSHELLISENSE=false
SKIP_ZSH_PLUGINS=false

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
        -h | --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --skip-inshellisense  Skip Inshellisense installation"
            echo "  --skip-zsh-plugins    Skip zsh plugin installation"
            echo "  -h, --help           Show this help message"
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

log_info "Starting autocomplete tools setup for $OS_TYPE..."
log_info "These tools work with any terminal emulator"

# Detect Linux distribution for package management
if [[ "$OS_TYPE" == "linux" ]]; then
    DISTRO=$(detect_linux_distro)
    PKG_MANAGER=$(detect_package_manager)
    log_info "Detected: $DISTRO (package manager: $PKG_MANAGER)"
fi

# Check for zsh
if ! command_exists "zsh"; then
    log_info "zsh not found. Installing..."
    if [[ "$OS_TYPE" == "macos" ]]; then
        if ! command_exists "brew"; then
            log_error "Homebrew not found. Please install Homebrew first"
            exit 3
        fi
        if ! brew install zsh; then
            log_error "Failed to install zsh"
            exit 4
        fi
    else
        case "$PKG_MANAGER" in
            apt)
                sudo apt-get update -q
                if ! sudo apt-get install -y zsh; then
                    log_error "Failed to install zsh"
                    exit 4
                fi
                ;;
            dnf)
                if ! sudo dnf install -y zsh; then
                    log_error "Failed to install zsh"
                    exit 4
                fi
                ;;
            pacman)
                if ! sudo pacman -S --noconfirm zsh; then
                    log_error "Failed to install zsh"
                    exit 4
                fi
                ;;
            *)
                log_error "Unsupported package manager: $PKG_MANAGER"
                log_info "Please install zsh manually and run this script again"
                exit 3
                ;;
        esac
    fi
    if ! command_exists "zsh"; then
        log_error "zsh installation verification failed"
        exit 4
    fi
    log_success "zsh installed"
    log_version "zsh" "zsh --version"
else
    log_success "zsh already installed"
    log_version "zsh" "zsh --version"
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

# Install Inshellisense
if [[ "$SKIP_INSHELLISENSE" = false ]]; then
    log_info "Installing Inshellisense (IDE-style autocomplete)..."

    # Check for Node.js
    if ! command_exists "node"; then
        log_info "Node.js not found. Installing..."

        if [[ "$OS_TYPE" == "macos" ]]; then
            if ! command_exists "brew"; then
                log_error "Homebrew not found. Please install Homebrew first"
                exit 1
            fi
            brew install node
        else
            _node_setup=$(mktemp)
            curl -fsSL https://deb.nodesource.com/setup_lts.x -o "$_node_setup"
            sudo -E bash "$_node_setup"
            rm -f "$_node_setup"
            sudo apt-get install -y nodejs
        fi
        log_success "Node.js installed"
    fi

    # Install or update Inshellisense
    # Note: Bun global binaries install to ~/.bun/bin, so we add it to PATH
    if command_exists "is" || "$HOME/.bun/bin/is" --version &>/dev/null; then
        log_info "Inshellisense already installed, updating..."
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
else
    log_info "Skipping Inshellisense installation (--skip-inshellisense flag)"
fi

# Install zsh plugins
if [[ "$SKIP_ZSH_PLUGINS" = false ]]; then
    log_info "Setting up zsh plugins..."

    # zsh-autosuggestions
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

    # zsh-syntax-highlighting
    if [[ ! -d "$ZSH_SYNTAX_DIR" ]]; then
        log_info "Installing zsh-syntax-highlighting..."
        if ! git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_SYNTAX_DIR" 2>/dev/null; then
            log_error "Failed to clone zsh-syntax-highlighting"
            exit 4
        fi
        log_success "zsh-syntax-highlighting installed"
        track_installation "zsh-syntax-highlighting" "success"
    fi

    # fzf
    if command_exists "fzf"; then
        log_info "fzf already installed"
        log_version "fzf" "fzf --version"
    else
        log_info "Installing fzf (fuzzy search)..."
        if [[ "$OS_TYPE" == "macos" ]]; then
            if command_exists "brew"; then
                if ! brew install fzf; then
                    log_error "Failed to install fzf"
                    exit 4
                fi
                if ! "$(brew --prefix)/opt/fzf/install" --all; then
                    log_error "Failed to configure fzf"
                    exit 4
                fi
            else
                log_warning "Homebrew not found. Installing fzf from source..."
                if ! git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf 2>/dev/null; then
                    log_error "Failed to clone fzf"
                    exit 4
                fi
                if ! ~/.fzf/install --all; then
                    log_error "Failed to configure fzf"
                    exit 4
                fi
            fi
        else
            if ! git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf 2>/dev/null; then
                log_error "Failed to clone fzf"
                exit 4
            fi
            if ! ~/.fzf/install --all; then
                log_error "Failed to configure fzf"
                exit 4
            fi
        fi
        log_success "fzf installed"
        log_version "fzf" "fzf --version"
        track_installation "fzf" "success"
    fi

    # Claude Code completion
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

    log_success "zsh plugins configured"
else
    log_info "Skipping zsh plugins installation (--skip-zsh-plugins flag)"
fi

# Backup and configure .zshrc
ZSHRC="$HOME/.zshrc"
if [[ -f "$ZSHRC" ]]; then
    BACKUP_ZSHRC="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$ZSHRC" "$BACKUP_ZSHRC"
    log_info "Backed up existing .zshrc to $BACKUP_ZSHRC"
fi

log_info "Configuring .zshrc..."

# Add Inshellisense init if not present
if [[ "$SKIP_INSHELLISENSE" = false ]] && ! grep -q 'is init zsh' "$ZSHRC" 2>/dev/null; then
    cat >>"$ZSHRC" <<'EOF'

# === Terminal Autocomplete Configuration ===
# Bun global binaries
export PATH="$HOME/.bun/bin:$PATH"
# Inshellisense - IDE-style autocomplete for 600+ tools
eval "$(is init zsh)"
EOF
    log_success "Added Inshellisense configuration"
fi

# Update plugins line if needed
if [[ "$SKIP_ZSH_PLUGINS" = false ]] && [[ -f "$ZSHRC" ]]; then
    if grep -q '^plugins=' "$ZSHRC"; then
        # Backup before modifying
        cp "$ZSHRC" "${ZSHRC}.pre-plugin-update"

        # Add new plugins to existing plugins list
        if [[ "$OS_TYPE" == "macos" ]]; then
            # macOS sed handles this differently
            if ! sed -i.bak 's/^plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting claudecode fzf)/' "$ZSHRC" 2>/dev/null; then
                log_warning "Failed to update plugins line in .zshrc for macOS. Please check manually."
            fi
        else
            # Linux sed
            if ! sed -i 's/^plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting claudecode fzf)/' "$ZSHRC" 2>/dev/null; then
                log_warning "Failed to update plugins line in .zshrc for Linux. Please check manually."
            fi
        fi

        # Clean up backup files
        rm -f "${ZSHRC}.bak"
        rm -f "${ZSHRC}.pre-plugin-update"

        log_success "Updated zsh plugins"
    else
        # If plugins line doesn't exist, add it
        echo "plugins=(git zsh-autosuggestions zsh-syntax-highlighting claudecode fzf)" >>"$ZSHRC"
        log_success "Added plugins to .zshrc"
    fi
fi

# Print summary
log_success "=========================================="
log_success "Autocomplete tools setup complete!"
log_success "=========================================="
print_installation_summary
log_info ""
log_info "Installed tools:"
if [[ "$SKIP_INSHELLISENSE" = false ]]; then
    log_info "  ✓ Inshellisense - IDE-style autocomplete"
fi
if [[ "$SKIP_ZSH_PLUGINS" = false ]]; then
    log_info "  ✓ zsh-autosuggestions - Fish-like suggestions"
    log_info "  ✓ zsh-syntax-highlighting - Syntax highlighting"
    log_info "  ✓ fzf - Fuzzy history search"
    log_info "  ✓ Claude Code completion"
fi
log_info ""
log_info "Usage:"
log_info "  • TAB: Trigger autocomplete (Inshellisense)"
log_info "  • Ctrl+R: Fuzzy history search (fzf)"
log_info "  • Right arrow: Accept autosuggestion (zsh-autosuggestions)"
log_info "  • Type 'claude' + TAB: Claude Code commands"
log_info ""
log_warning "Important: Restart your terminal or run 'exec zsh' to apply changes"
log_info ""
log_info "This setup works with any terminal emulator:"
log_info "  Ghostty, WezTerm, iTerm2, Alacritty, Kitty, Terminal.app, etc."
