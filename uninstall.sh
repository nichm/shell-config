#!/usr/bin/env bash
# =============================================================================
# 🗑️  SHELL-CONFIG UNINSTALLER
# =============================================================================
# Safely removes shell-config symlinks and configuration
# Usage: ./uninstall.sh [--dry-run]
#
# Safety Features:
#   - Removes symlinks pointing to shell-config
#   - Removes regular files containing shell-config references
#   - Checks symlink targets before deletion
#   - Preserves .zshrc.local (user secrets)
#   - Offers backup restoration
#   - Dry-run mode for safe preview
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --help | -h)
            echo "Usage: $0 [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Preview what would be removed without making changes"
            echo "  --help,-h    Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Source colors if available
if [[ -f "$SCRIPT_DIR/lib/core/colors.sh" ]]; then
    source "$SCRIPT_DIR/lib/core/colors.sh"
else
    # Fallback colors if running outside shell-config context
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
fi

# Source symlink manager if available (provides sc_symlink_remove_all, sc_check_remaining_artifacts)
if [[ -f "$SCRIPT_DIR/lib/setup/symlink-manager.sh" ]]; then
    source "$SCRIPT_DIR/lib/setup/symlink-manager.sh"
fi

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log_info() { echo -e "${CYAN}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}"; }
log_dry() { echo -e "${YELLOW}[DRY RUN]${NC} $*"; }

# =============================================================================
# UNINSTALL FUNCTIONS
# =============================================================================

uninstall_symlinks() {
    echo ""
    log_info "Removing shell-config symlinks..."
    echo ""

    sc_symlink_remove_all "$SCRIPT_DIR" "$DRY_RUN"

    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Symlink removal complete (dry run)"
    else
        log_success "Symlink removal complete"
    fi
}

uninstall_git_config() {
    echo ""
    log_info "Removing git configuration..."
    echo ""

    # Remove hooks path
    local hooks_path
    hooks_path=$(git config --global --get core.hooksPath 2>/dev/null || echo "")

    if [[ -n "$hooks_path" ]]; then
        if [[ "$hooks_path" == "$HOME/.githooks" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_dry "Would remove git hooks path: core.hooksPath"
            else
                git config --global --unset core.hooksPath
                log_success "Removed git hooks path"
            fi
        else
            log_warning "Skipping git hooks path (custom value: $hooks_path)"
        fi
    else
        log_info "Git hooks path not configured"
    fi

    # Remove secrets configuration
    if git config --global --get-regexp secrets >/dev/null 2>&1; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dry "Would remove git secrets configuration"
        else
            git config --global --remove-section secrets 2>/dev/null || true
            log_success "Removed git secrets configuration"
        fi
    fi

    # Clean up old git-secrets files
    if [[ -f "$HOME/.git-secrets-prohibited" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dry "Would remove: ~/.git-secrets-prohibited"
        else
            rm -f "$HOME/.git-secrets-prohibited"
            log_success "Removed ~/.git-secrets-prohibited"
        fi
    fi

    if [[ -f "$HOME/.git-secrets-allowed" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dry "Would remove: ~/.git-secrets-allowed"
        else
            rm -f "$HOME/.git-secrets-allowed"
            log_success "Removed ~/.git-secrets-allowed"
        fi
    fi

    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Git configuration cleanup complete (dry run)"
    else
        log_success "Git configuration cleanup complete"
    fi
}

clean_cache() {
    echo ""
    log_info "Cleaning cache files..."
    echo ""

    local cache_dirs=(
        "$HOME/.cache/git-wrapper"
        "$HOME/.cache/welcome-message"
    )

    local cache_files=(
        "$HOME/.shell-config-audit.log"
    )

    for dir in "${cache_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_dry "Would remove cache directory: $dir"
            else
                rm -rf "$dir"
                log_success "Removed cache directory: $dir"
            fi
        fi
    done

    for file in "${cache_files[@]}"; do
        if [[ -f "$file" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_dry "Would remove cache file: $file"
            else
                rm -f "$file"
                log_success "Removed cache file: $file"
            fi
        fi
    done

    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Cache cleanup complete (dry run)"
    else
        log_success "Cache cleanup complete"
    fi
}

restore_backups() {
    echo ""
    log_info "Checking for backup files..."
    echo ""

    # Find latest .zshrc backup
    local latest_backup
    latest_backup=$(ls -t "$HOME/.zshrc.backup."* 2>/dev/null | head -1 || echo "")

    if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
        log_info "Found backup: $latest_backup"

        # Check if .zshrc still exists
        if [[ -f "$HOME/.zshrc" ]]; then
            log_warning "$HOME/.zshrc already exists, skipping restore"
            log_info "Manual restore: cp '$latest_backup' ~/.zshrc"
        else
            if [[ "$DRY_RUN" == true ]]; then
                log_dry "Would restore backup: $latest_backup → ~/.zshrc"
            else
                cp "$latest_backup" "$HOME/.zshrc"
                log_success "Restored backup to ~/.zshrc"
            fi
        fi
    else
        log_info "No .zshrc backups found"
    fi

    echo ""
}

check_remaining_artifacts() {
    echo ""
    log_info "Checking for remaining shell-config artifacts..."
    echo ""

    sc_check_remaining_artifacts "$SCRIPT_DIR"

    echo ""
}

# =============================================================================
# CONFIRMATION
# =============================================================================

confirm_uninstall() {
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo -e "${BOLD}${CYAN}🔍 DRY RUN MODE${NC}"
        echo -e "${CYAN}No changes will be made${NC}"
        echo ""
        return 0
    fi

    echo ""
    echo -e "${BOLD}${YELLOW}⚠️  WARNING: This will remove shell-config from your system${NC}"
    echo ""
    echo "This will:"
    echo "  • Remove symlinks created by install.sh"
    echo "  • Remove git hooks path configuration"
    echo "  • Clean up cache files"
    echo "  • Offer to restore .zshrc from backup if available"
    echo ""
    echo "This will NOT:"
    echo "  • Delete .zshrc.local (your secrets file)"
    echo "  • Delete files not created by shell-config"
    echo "  • Remove the shell-config repository directory"
    echo "  • Uninstall dependencies (brew packages, etc.)"
    echo ""

    # Non-interactive confirmation via environment variable
    if [[ "${UNINSTALL_CONFIRM:-}" != "true" ]]; then
        echo "❌ ERROR: Uninstall requires explicit confirmation" >&2
        echo "ℹ️  WHY: Data loss prevention - this action removes configuration files" >&2
        echo "💡 FIX: Set UNINSTALL_CONFIRM=true to proceed" >&2
        echo "     Command: UNINSTALL_CONFIRM=true \"$0\"" >&2
        exit 1
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo ""
    echo -e "${BOLD}${CYAN}🗑️  Shell-Config Uninstaller${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    confirm_uninstall

    uninstall_symlinks
    uninstall_git_config
    clean_cache
    restore_backups
    check_remaining_artifacts

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BOLD}${YELLOW}Dry run complete${NC}"
        echo ""
        echo "To actually uninstall, run:"
        echo "  ./uninstall.sh"
    else
        echo -e "${BOLD}${GREEN}👋 Uninstall Complete!${NC}"
        echo ""
        echo "👉 What's next:"
        echo "  • Restart your terminal or run: exec zsh"
        echo "  • Your shell will revert to its default configuration"
        echo "  • 🔐 .zshrc.local was preserved (contains your secrets)"
        echo ""
        echo "ℹ️  Note: The shell-config repository directory was NOT removed:"
        echo "  $SCRIPT_DIR"
        echo ""
    fi
    echo ""
}

main "$@"
