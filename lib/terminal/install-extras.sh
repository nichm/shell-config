#!/usr/bin/env bash
# =============================================================================
# install-extras.sh - Optional terminal install helpers
# =============================================================================
# Extra installers used by lib/terminal/install.sh
# Usage:
#   source "${BASH_SOURCE[0]}"
# =============================================================================
set -euo pipefail

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# =============================================================================
# INSTALL ZSH PLUGINS
# =============================================================================
install_zsh_plugins() {
    if [[ "$SKIP_ZSH_PLUGINS" == true ]]; then
        log_info "Skipping zsh plugins installation (--skip-zsh-plugins)"
        track_installation "zsh-plugins" "skipped"
        return 0
    fi

    log_step "Installing zsh plugins"

    # zsh-autosuggestions
    if [[ ! -d "$ZSH_AUTOSUGGESTIONS_DIR" ]]; then
        log_info "Installing zsh-autosuggestions..."
        if git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGESTIONS_DIR" 2>/dev/null; then
            log_success "zsh-autosuggestions installed"
            track_installation "zsh-autosuggestions" "success"
        else
            log_error "Failed to clone zsh-autosuggestions"
            exit 4
        fi
    else
        log_info "Updating zsh-autosuggestions..."
        git -C "$ZSH_AUTOSUGGESTIONS_DIR" pull 2>/dev/null || log_warning "Failed to update"
        log_success "zsh-autosuggestions up to date"
    fi

    # zsh-syntax-highlighting
    if [[ ! -d "$ZSH_SYNTAX_DIR" ]]; then
        log_info "Installing zsh-syntax-highlighting..."
        if git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_SYNTAX_DIR" 2>/dev/null; then
            log_success "zsh-syntax-highlighting installed"
            track_installation "zsh-syntax-highlighting" "success"
        else
            log_error "Failed to clone zsh-syntax-highlighting"
            exit 4
        fi
    else
        log_info "Updating zsh-syntax-highlighting..."
        git -C "$ZSH_SYNTAX_DIR" pull 2>/dev/null || log_warning "Failed to update"
        log_success "zsh-syntax-highlighting up to date"
    fi

    # Claude Code completion
    if [[ ! -d "$CLAUDE_COMPLETION_DIR" ]]; then
        log_info "Installing Claude Code completion..."
        if git clone https://github.com/wbingli/zsh-claudecode-completion "$CLAUDE_COMPLETION_DIR" 2>/dev/null; then
            log_success "Claude Code completion installed"
            track_installation "claude-completion" "success"
        else
            log_error "Failed to clone Claude Code completion"
            exit 4
        fi
    else
        log_info "Updating Claude Code completion..."
        git -C "$CLAUDE_COMPLETION_DIR" pull 2>/dev/null || log_warning "Failed to update"
        log_success "Claude Code completion up to date"
    fi
}

# =============================================================================
# INSTALL FZF
# =============================================================================
install_fzf() {
    if [[ "$SKIP_FZF" == true ]]; then
        log_info "Skipping fzf installation (--skip-fzf)"
        track_installation "fzf" "skipped"
        return 0
    fi

    if command_exists "fzf"; then
        log_success "fzf already installed"
        log_version "fzf" "fzf --version"
        return 0
    fi

    log_info "Installing fzf (fuzzy search)..."

    if [[ "$OS_TYPE" == "macos" ]]; then
        if command_exists "brew"; then
            if ! brew install fzf; then
                log_error "Failed to install fzf"
                exit 4
            fi
            # Set up key bindings and completions
            "$(brew --prefix)/opt/fzf/install" --all --no-update-rc 2>/dev/null || true
        else
            # Fallback to git installation
            git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf 2>/dev/null || {
                log_error "Failed to clone fzf"
                exit 4
            }
            ~/.fzf/install --all --no-update-rc 2>/dev/null || {
                log_error "Failed to configure fzf"
                exit 4
            }
        fi
    else
        # Linux installation via git
        if [[ ! -d "$HOME/.fzf" ]]; then
            git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf 2>/dev/null || {
                log_error "Failed to clone fzf"
                exit 4
            }
        fi
        ~/.fzf/install --all --no-update-rc 2>/dev/null || {
            log_error "Failed to configure fzf"
            exit 4
        }
    fi

    log_success "fzf installed"
    log_version "fzf" "fzf --version"
    track_installation "fzf" "success"
}

# =============================================================================
# PRINT SUMMARY
# =============================================================================
print_summary() {
    echo ""
    log_step "Installation Complete"

    list_installed_tools

    echo ""
    log_info "Installed tools:"

    if [[ "$SKIP_INSHELLISENSE" != true ]]; then
        log_info "  ✓ Inshellisense - IDE-style autocomplete for 600+ tools"
    fi
    if [[ "$SKIP_ZSH_PLUGINS" != true ]]; then
        log_info "  ✓ zsh-autosuggestions - Fish-like suggestions"
        log_info "  ✓ zsh-syntax-highlighting - Syntax highlighting"
        log_info "  ✓ Claude Code completion"
    fi
    if [[ "$SKIP_FZF" != true ]]; then
        log_info "  ✓ fzf - Fuzzy history search"
    fi

    echo ""
    log_info "Usage:"
    log_info "  • TAB: Trigger autocomplete (Inshellisense)"
    log_info "  • Ctrl+R: Fuzzy history search (fzf)"
    log_info "  • Right arrow: Accept autosuggestion (zsh-autosuggestions)"
    log_info "  • Type 'claude' + TAB: Claude Code commands"
    echo ""
}
