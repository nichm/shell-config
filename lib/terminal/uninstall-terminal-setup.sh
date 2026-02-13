#!/usr/bin/env bash
set -euo pipefail

# Script: uninstall-terminal-setup.sh
# Purpose: Remove all terminal autocomplete tools and configurations
# Usage: ./uninstall-terminal-setup.sh [--purge-backups]
# This script removes:
# - Inshellisense
# - zsh plugins (zsh-autosuggestions, zsh-syntax-highlighting, fzf, Claude Code)
# - Terminal emulator configs (Ghostty/WezTerm)
# - Oh My Zsh (optional)
# - Restores .zshrc from backup
# Exit codes:
#   0 - Success
#   1 - General error
#   2 - User cancelled
#   3 - Backup not found

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/setup/terminal-setup-common.sh"

# Parse arguments
PURGE_BACKUPS=false
UNINSTALL_OH_MY_ZSH=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --purge-backups)
            PURGE_BACKUPS=true
            shift
            ;;
        --uninstall-oh-my-zsh)
            UNINSTALL_OH_MY_ZSH=true
            shift
            ;;
        -h | --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --purge-backups       Remove all backup files"
            echo "  --uninstall-oh-my-zsh Also remove Oh My Zsh"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "This script removes all terminal autocomplete tools and configurations."
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Warning message
log_warning "=========================================="
log_warning "TERMINAL SETUP UNINSTALLATION"
log_warning "=========================================="
log_info ""
log_info "This will remove:"
log_info "  • Inshellisense"
log_info "  • zsh plugins (autosuggestions, syntax-highlighting, fzf, Claude)"
if [[ "$UNINSTALL_OH_MY_ZSH" = true ]]; then
    log_info "  • Oh My Zsh"
fi
log_info "  • Terminal configurations (Ghostty/WezTerm)"
log_info "  • .zshrc autocomplete configurations"
if [[ "$PURGE_BACKUPS" = true ]]; then
    log_info "  • All backup files"
fi
log_info ""
log_warning "Note: Your .zshrc will be restored from the most recent backup"

# Non-interactive confirmation via environment variable
if [[ "${UNINSTALL_TERMINAL_CONFIRM:-}" != "true" ]]; then
    log_error "Uninstall requires explicit confirmation"
    echo "ℹ️  WHY: Data loss prevention - this action removes terminal configurations" >&2
    echo "💡 FIX: Set UNINSTALL_TERMINAL_CONFIRM=true to proceed" >&2
    echo "     Command: UNINSTALL_TERMINAL_CONFIRM=true \"$0\"" >&2
    exit 1
fi

log_info "Starting uninstallation..."

# Track what we've uninstalled
track_installation "inshellisense" "pending"
track_installation "zsh-plugins" "pending"
track_installation "terminal-config" "pending"
track_installation "zshrc-restore" "pending"

# Find most recent .zshrc backup
find_backup() {
    local latest_backup

    latest_backup=$(ls -t ~/.zshrc.backup.* 2>/dev/null | head -n 1)

    if [[ -n "$latest_backup" ]]; then
        echo "$latest_backup"
    else
        echo ""
    fi
}

# Remove Inshellisense
log_info "Removing Inshellisense..."
if bun uninstall -g @microsoft/inshellisense 2>/dev/null; then
    # Remove PATH configuration from .zshrc
    if [[ -f "$HOME/.zshrc" ]]; then
        # OS-specific sed handling
        if [[ "$OS_TYPE" == "macos" ]]; then
            sed -i.bak '/is init zsh/d' "$HOME/.zshrc" 2>/dev/null || true
            rm -f "$HOME/.zshrc.bak"
            sed -i.bak '/Bun global binaries/d' "$HOME/.zshrc" 2>/dev/null || true
            rm -f "$HOME/.zshrc.bak"
        else
            sed -i '/is init zsh/d' "$HOME/.zshrc" 2>/dev/null || true
            sed -i '/Bun global binaries/d' "$HOME/.zshrc" 2>/dev/null || true
        fi
    fi
    track_installation "inshellisense" "success"
    log_success "Inshellisense removed"
else
    track_installation "inshellisense" "failed"
    log_warning "Inshellisense may not have been installed"
fi

# Remove zsh plugins
log_info "Removing zsh plugins..."

# zsh-autosuggestions
if [[ -d "$ZSH_AUTOSUGGESTIONS_DIR" ]]; then
    rm -rf "$ZSH_AUTOSUGGESTIONS_DIR"
    log_success "Removed zsh-autosuggestions"
fi

# zsh-syntax-highlighting
if [[ -d "$ZSH_SYNTAX_DIR" ]]; then
    rm -rf "$ZSH_SYNTAX_DIR"
    log_success "Removed zsh-syntax-highlighting"
fi

# Claude Code completion
if [[ -d "$CLAUDE_COMPLETION_DIR" ]]; then
    rm -rf "$CLAUDE_COMPLETION_DIR"
    log_success "Removed Claude Code completion"
fi

# fzf
if [[ -d "$FZF_DIR" ]]; then
    rm -rf "$FZF_DIR"
    log_success "Removed fzf"
fi

track_installation "zsh-plugins" "success"

# Remove Oh My Zsh if requested
if [[ "$UNINSTALL_OH_MY_ZSH" = true ]]; then
    log_info "Removing Oh My Zsh..."
    if [[ -d "$OH_MY_ZSH_DIR" ]]; then
        rm -rf "$OH_MY_ZSH_DIR"
        log_success "Oh My Zsh removed"
    else
        log_warning "Oh My Zsh directory not found"
    fi
fi

# Detect OS and remove terminal configs
OS_TYPE=$(detect_os)

if [[ "$OS_TYPE" == "macos" ]]; then
    # Remove Ghostty config
    log_info "Removing Ghostty configuration..."
    GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
    if [[ -d "$GHOSTTY_CONFIG_DIR" ]]; then
        rm -f "$GHOSTTY_CONFIG_DIR/config"
        log_success "Removed Ghostty configuration"
    fi
elif [[ "$OS_TYPE" == "linux" ]]; then
    # Remove WezTerm config
    log_info "Removing WezTerm configuration..."
    WEZTERM_CONFIG_DIR="$HOME/.wezterm"
    if [[ -d "$WEZTERM_CONFIG_DIR" ]]; then
        rm -f "$WEZTERM_CONFIG_DIR/wezterm.lua"
        log_success "Removed WezTerm configuration"
    fi
fi

track_installation "terminal-config" "success"

# Restore .zshrc from backup
log_info "Restoring .zshrc from backup..."

BACKUP_FILE=$(find_backup)

if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
    cp "$BACKUP_FILE" "$HOME/.zshrc"
    log_success "Restored .zshrc from $(basename "$BACKUP_FILE")"

    # Clean up autocomplete configuration additions
    if [[ -f "$HOME/.zshrc" ]]; then
        # Remove our configuration block (OS-specific sed)
        if [[ "$OS_TYPE" == "macos" ]]; then
            sed -i.bak '/# === Terminal Autocomplete Configuration ===/,/^EOF$/d' "$HOME/.zshrc" 2>/dev/null || true
            rm -f "$HOME/.zshrc.bak"
        else
            sed -i '/# === Terminal Autocomplete Configuration ===/,/^EOF$/d' "$HOME/.zshrc" 2>/dev/null || true
        fi
    fi

    track_installation "zshrc-restore" "success"
else
    log_warning "No .zshrc backup found"
    log_info "Cleaning autocomplete configuration from current .zshrc..."

    if [[ -f "$HOME/.zshrc" ]]; then
        # Remove plugins that we added (use word boundaries for exact matching)
        for plugin in zsh-autosuggestions zsh-syntax-highlighting claudecode fzf; do
            if [[ "$OS_TYPE" == "macos" ]]; then
                sed -i.bak "s/\b${plugin}\b//g" "$HOME/.zshrc" 2>/dev/null || true
            else
                sed -i "s/\b${plugin}\b//g" "$HOME/.zshrc" 2>/dev/null || true
            fi
        done
        # Clean up backup files from loop
        if [[ "$OS_TYPE" == "macos" ]]; then
            rm -f "$HOME/.zshrc.bak"
        fi

        # Remove our configuration block (OS-specific sed)
        if [[ "$OS_TYPE" == "macos" ]]; then
            sed -i.bak '/# === Terminal Autocomplete Configuration ===/,/# EOF$/d' "$HOME/.zshrc" 2>/dev/null || true
            rm -f "$HOME/.zshrc.bak"
        else
            sed -i '/# === Terminal Autocomplete Configuration ===/,/# EOF$/d' "$HOME/.zshrc" 2>/dev/null || true
        fi
    fi

    track_installation "zshrc-restore" "success"
fi

# Remove backups if requested
if [[ "$PURGE_BACKUPS" = true ]]; then
    log_info "Removing backup files..."
    rm -f ~/.zshrc.backup.*
    log_success "Backup files removed"
fi

# Print summary
log_success "=========================================="
log_success "Uninstallation complete!"
log_success "=========================================="
log_info ""
print_installation_summary
log_info ""
log_warning "Note: Terminal emulators (Ghostty/WezTerm) apps are not removed"
log_info "      To remove them:"
if [[ "$OS_TYPE" == "macos" ]]; then
    log_info "      macOS: brew uninstall --cask ghostty"
else
    log_info "      Ubuntu: sudo apt remove wezterm"
fi
log_info ""
log_warning "Important: Restart your terminal or run 'exec zsh' to apply changes"
