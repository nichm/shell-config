#!/usr/bin/env bash
# =============================================================================
# setup.sh - Git hooks installation and management script
# =============================================================================
# Manages git hooks for the shell-config repository. Supports installing,
# uninstalling, and checking the status of git hooks. Hooks are managed
# via symlinks to ~/.githooks for global availability.
# Dependencies:
#   - core/colors.sh - For color output
# Usage:
#   ./lib/git/setup.sh install   - Install all git hooks
#   ./lib/git/setup.sh uninstall - Uninstall all git hooks
#   ./lib/git/setup.sh status    - Check hook installation status
# Hooks Managed:
#   - pre-commit - Runs shellcheck, tests, and validations
#   - commit-msg - Validates commit message format
#   - post-commit - Runs post-commit operations
#   - pre-push - Validates before pushing to remote
# Architecture:
#   Hooks are symlinked from lib/git/hooks/ to ~/.githooks/
#   This allows git to find them globally via init.templatedir
# =============================================================================

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/hooks"
# Gitleaks config moved to validators during refactor
SECRETS_DIR="$SCRIPT_DIR/../validation/validators/security/config"
source "$SCRIPT_DIR/../core/colors.sh"
# shellcheck source=../../core/platform.sh
source "$SCRIPT_DIR/../core/platform.sh" || {
    echo "❌ ERROR: Failed to load platform detection" >&2
    return 1
}

_check_hook_status() {
    local hook_name="$1"
    local display_name="$2"
    local hook_path="$HOME/.githooks/$hook_name"

    if [[ -L "$hook_path" ]]; then
        local target
        target=$(readlink "$hook_path")
        echo -e "$display_name: ${GREEN}✓ Symlinked${NC} → $target"
    elif [[ -x "$hook_path" ]]; then
        echo -e "$display_name: ${YELLOW}✓ Installed (not symlinked)${NC}"
    else
        echo -e "$display_name: ${RED}✗ Not found${NC}"
    fi
}

install_hooks() {
    log_info "Installing git hooks (integration layer)..."

    # Check if integration layer hooks exist
    local integration_dir="$SCRIPT_DIR/../integrations/git"
    local use_integration=0

    if [[ -f "$integration_dir/pre-commit" ]] && [[ -f "$integration_dir/pre-push" ]]; then
        use_integration=1
        log_info "Using integration layer hooks (refactored, cleaner API)"
    elif [[ -f "$HOOKS_DIR/pre-commit" ]] && [[ -f "$HOOKS_DIR/pre-push" ]]; then
        log_info "Using legacy hooks (falling back to original implementation)"
    else
        log_error "No hooks found!"
        return 1
    fi

    local global_hooks_dir="$HOME/.githooks"
    mkdir -p "$global_hooks_dir"

    # Determine which hooks to install from each source
    local hooks_source_dir
    if [[ $use_integration -eq 1 ]]; then
        hooks_source_dir="$integration_dir"
    else
        hooks_source_dir="$HOOKS_DIR"
    fi

    # Symlink hooks using a loop (so repo changes auto-sync)
    # Note: Integration layer may not have all hooks (e.g., post-commit),
    # so we fall back to legacy hooks for missing ones
    # All 7 standard git hooks are installed for full lifecycle coverage
    for hook in pre-commit commit-msg prepare-commit-msg post-commit pre-push pre-merge-commit post-merge; do
        local hook_source=""

        # First check primary source
        if [[ -f "$hooks_source_dir/$hook" ]]; then
            hook_source="$hooks_source_dir/$hook"
        # Fall back to legacy hooks if not in integration dir
        elif [[ $use_integration -eq 1 ]] && [[ -f "$HOOKS_DIR/$hook" ]]; then
            hook_source="$HOOKS_DIR/$hook"
        fi

        if [[ -n "$hook_source" ]]; then
            rm -f "$global_hooks_dir/$hook"
            ln -sf "$hook_source" "$global_hooks_dir/$hook"
            log_success "Symlinked $hook hook"
        fi
    done

    # Configure git to use global hooks
    git config --global core.hooksPath "$global_hooks_dir"
    log_success "Configured git to use hooks from $global_hooks_dir"

    # Show which hooks were installed
    if [[ $use_integration -eq 1 ]]; then
        log_info "✨ Integration layer hooks installed (Phase 3)"
        log_info "   • Cleaner API via validation layer"
        log_info "   • CLI tool available: validate --help"
    fi
}

install_gitleaks() {
    log_info "Setting up Gitleaks..."

    # Check if gitleaks is installed
    if ! command_exists "gitleaks"; then
        log_warning "Gitleaks not installed"
        if is_macos; then
            log_info "Install with: brew install gitleaks"
        else
            log_info "Install with: go install github.com/zricethezav/gitleaks/v8/cmd/gitleaks@latest"
        fi
        return 1
    fi

    # Verify custom config exists
    if [[ -f "$SECRETS_DIR/gitleaks.toml" ]]; then
        log_success "Custom Gitleaks config found: $SECRETS_DIR/gitleaks.toml"

        # Count custom rules
        local rule_count
        rule_count=$(grep -c '^\[\[rules\]\]' "$SECRETS_DIR/gitleaks.toml" 2>/dev/null || echo "0")
        log_info "Config contains $rule_count custom rules (+ 600+ built-in rules)"
    else
        log_warning "Custom Gitleaks config not found"
        log_info "Using built-in Gitleaks rules only"
    fi

    # Verify gitleaks works
    if gitleaks version >/dev/null 2>&1; then
        local version
        version=$(gitleaks version 2>&1 | head -1)
        log_success "Gitleaks version: $version"
    fi

    log_success "Gitleaks configured"
}

install() {
    echo ""
    echo "⚡ Git Security Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    install_hooks
    install_gitleaks

    echo ""
    log_success "Setup complete!"
    echo ""
    echo "⚙️  What's configured:"
    echo "  • Pre-commit hook: filename check, syntax, size, secrets (Gitleaks on staged)"
    echo "  • Post-commit hook: dependency audit logging"
    echo "  • Pre-push hook: workflow validation, tests, secrets (Gitleaks on push)"
    echo "  • Pre-merge-commit hook: conflict markers, tests"
    echo "  • Gitleaks: fast secret detection (5x faster than git-secrets)"
    echo "  • Filename patterns: blocks .env, .pem, credentials.json, etc."
    echo ""
    echo "🪝 Hooks location: $HOME/.githooks"
    echo "🔐 Gitleaks config: $SECRETS_DIR/gitleaks.toml"
    echo ""
}

uninstall() {
    log_info "Removing git hooks configuration..."

    git config --global --unset core.hooksPath 2>/dev/null || true

    # Clean up old git-secrets files if they exist
    rm -f "$HOME/.git-secrets-prohibited" 2>/dev/null || true
    rm -f "$HOME/.git-secrets-allowed" 2>/dev/null || true
    git config --global --remove-section secrets 2>/dev/null || true

    log_success "Uninstalled"
    log_info "Note: Hook files in ~/.githooks were NOT deleted"
    log_info "Note: Gitleaks binary was NOT removed (brew uninstall gitleaks)"
}

status() {
    echo ""
    echo "🔎 Git Security Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check hooks path
    local hooks_path
    hooks_path=$(git config --global --get core.hooksPath 2>/dev/null || echo "")
    if [[ -n "$hooks_path" ]]; then
        echo -e "Hooks path: ${GREEN}$hooks_path${NC}"
    else
        echo -e "Hooks path: ${YELLOW}Not configured${NC}"
    fi

    # Check all 7 hooks using helper function
    _check_hook_status "pre-commit" "Pre-commit"
    _check_hook_status "commit-msg" "Commit-msg"
    _check_hook_status "prepare-commit-msg" "Prepare-commit-msg"
    _check_hook_status "post-commit" "Post-commit"
    _check_hook_status "pre-push" "Pre-push"
    _check_hook_status "pre-merge-commit" "Pre-merge-commit"
    _check_hook_status "post-merge" "Post-merge"

    # Check Gitleaks installation
    if command_exists "gitleaks"; then
        local version
        version=$(gitleaks version 2>&1 | head -1)
        echo -e "Gitleaks: ${GREEN}✓ Installed ($version)${NC}"
    else
        echo -e "Gitleaks: ${YELLOW}Not installed (brew install gitleaks)${NC}"
    fi

    # Check custom config
    if [[ -f "$SECRETS_DIR/gitleaks.toml" ]]; then
        local rule_count
        rule_count=$(grep -c '^\[\[rules\]\]' "$SECRETS_DIR/gitleaks.toml" 2>/dev/null || echo "0")
        echo -e "Gitleaks config: ${GREEN}✓ Custom config ($rule_count rules + 600+ built-in)${NC}"
    else
        echo -e "Gitleaks config: ${YELLOW}Using built-in rules only${NC}"
    fi

    echo ""

    # Show quick test
    if command_exists "gitleaks"; then
        echo "🧪 Quick test: gitleaks version"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        gitleaks version 2>&1 || echo "(error)"
        echo ""
    fi
}

main() {
    local cmd="${1:-install}"

    case "$cmd" in
        install) install ;;
        uninstall) uninstall ;;
        status) status ;;
        *)
            echo "Usage: $0 [install|uninstall|status]"
            echo ""
            echo "Commands:"
            echo "  install      Full setup: hooks + Gitleaks configuration"
            echo "  status       Show current configuration"
            echo "  uninstall    Remove all configuration"
            exit 1
            ;;
    esac
}

main "$@"
