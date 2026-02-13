#!/usr/bin/env bash
# Shell-Config One-Command Installer
# Usage: ./install.sh [--skip-deps] [--skip-uv]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
trap ':' EXIT INT TERM
source "$SCRIPT_DIR/lib/core/colors.sh"
source "$SCRIPT_DIR/lib/core/platform.sh"
source "$SCRIPT_DIR/lib/core/command-cache.sh"
source "$SCRIPT_DIR/lib/setup/symlink-manager.sh"

# =============================================================================
# BASH VERSION CHECK
# =============================================================================
# Requires Bash 4.0+ (5.x recommended)
# See docs/decisions/BASH-5-UPGRADE.md for rationale
check_bash_version() {
    local version="${BASH_VERSINFO[0]}"

    if [[ "$version" -lt 4 ]]; then
        echo -e "${RED}❌ ERROR: Bash 4+ required, found bash $BASH_VERSION${NC}" >&2
        echo -e "${YELLOW}ℹ️  WHY: shell-config uses modern bash features (associative arrays, etc.)${NC}" >&2
        if [[ "$(uname)" == "Darwin" ]]; then
            echo -e "${GREEN}💡 FIX: brew install bash${NC}" >&2
            echo -e "${CYAN}     Then run: /opt/homebrew/bin/bash ./install.sh${NC}" >&2
        else
            echo -e "${GREEN}💡 FIX: Install bash 5.x from your package manager${NC}" >&2
        fi
        exit 1
    fi
}
check_bash_version

SC_SKIP_DEPS=false SC_SKIP_UV=false
for arg in "$@"; do
    case "$arg" in
        --skip-deps) SC_SKIP_DEPS=true ;;
        --skip-uv) SC_SKIP_UV=true ;;
        --help | -h)
            echo "Usage: $0 [--skip-deps] [--skip-uv]"
            exit 0
            ;;
    esac
done

# create_symlink and symlink_one are now provided by lib/setup/symlink-manager.sh
# (sc_symlink_create, sc_symlink_create_all)

install_deps() {
    [[ "$SC_SKIP_DEPS" == true ]] && {
        log_warning "Skipping dependencies (--skip-deps)"
        return 0
    }
    log_step "Installing dependencies for $SC_OS"

    # Display platform info
    platform_info

    # Install UV (language-agnostic, works on all platforms)
    if [[ "$SC_SKIP_UV" == false ]] && ! command_exists "uv"; then
        log_info "Installing UV..."
        local tmp_script
        if ! tmp_script=$(mktemp); then
            log_warning "Failed to create temp file for UV installer - Python tooling will be limited"
        elif ! curl -LsSf https://astral.sh/uv/install.sh -o "$tmp_script"; then
            log_warning "Failed to download UV installer - Python tooling will be limited"
            rm -f "$tmp_script"
        else
            # Capture errors for better debugging
            local uv_output
            if ! uv_output=$(sh "$tmp_script" 2>&1); then
                log_warning "UV installation failed: ${uv_output:-No error output}"
                log_info "Python package management will use pip"
            else
                log_success "UV installed successfully"
            fi
            rm -f "$tmp_script"
            export PATH="$HOME/.local/bin:$PATH"
        fi
    fi

    # Install dependencies based on package manager
    case "$SC_PKG_MANAGER" in
        brew)
            log_info "Using Homebrew package manager"
            # Check if brew is available
            command_exists "brew" || {
                log_error "Homebrew not found"
                return 1
            }

            # Critical development tools (must succeed)
            # Note: bats-core package installs 'bats' binary, coreutils installs 'greadlink'/'grealpath'
            for pkg in coreutils shellcheck gitleaks bats; do
                # Map binary name to package name for brew
                local pkg_name="$pkg"
                local binary_name="$pkg"
                [[ "$pkg" == "bats" ]] && pkg_name="bats-core"
                [[ "$pkg" == "coreutils" ]] && binary_name="greadlink"
                command_exists "$binary_name" && log_success "$pkg installed" || {
                    log_info "Installing $pkg_name..."
                    if ! brew install "$pkg_name" >/dev/null 2>&1; then
                        case "$pkg" in
                            coreutils)
                                echo "❌ ERROR: Failed to install coreutils" >&2
                                echo "ℹ️  WHY: Required for GNU readlink/realpath on macOS" >&2
                                echo "💡 FIX: brew install coreutils" >&2
                                return 1
                                ;;
                            shellcheck)
                                echo "❌ ERROR: Failed to install shellcheck" >&2
                                echo "ℹ️  WHY: Required for pre-commit validation" >&2
                                echo "💡 FIX: brew install shellcheck" >&2
                                return 1
                                ;;
                            gitleaks)
                                echo "❌ ERROR: Failed to install gitleaks" >&2
                                echo "ℹ️  WHY: Required for secrets scanning in pre-commit hooks" >&2
                                echo "💡 FIX: brew install gitleaks" >&2
                                return 1
                                ;;
                            bats)
                                echo "❌ ERROR: Failed to install $pkg_name" >&2
                                echo "ℹ️  WHY: Required for running test suite" >&2
                                echo "💡 FIX: brew install $pkg_name" >&2
                                return 1
                                ;;
                        esac
                    fi
                }
            done

            # Semi-critical tools (warn but continue)
            for pkg in yamllint ruff; do
                command_exists "$pkg" && log_success "$pkg installed" || {
                    log_info "Installing $pkg..."
                    if ! brew install "$pkg" >/dev/null 2>&1; then
                        case "$pkg" in
                            yamllint)
                                log_warning "yamllint installation failed - YAML validation will be skipped"
                                ;;
                            ruff)
                                log_warning "ruff installation failed - Python linting will use fallback"
                                ;;
                        esac
                    fi
                }
            done

            # Optional tools (soft-fail OK)
            command_exists "eza" && log_success "eza installed" || {
                log_info "Installing eza..."
                brew install eza 2>/dev/null || log_warning "eza failed - falling back to standard tools"
            }

            # Optional tools
            command_exists "oxlint" || {
                log_info "Installing oxlint..."
                brew install oxlint 2>/dev/null || { command_exists "cargo" && cargo install oxlint 2>/dev/null; } || log_warning "oxlint failed"
            }
            command_exists "trash" && log_success "trash installed" || {
                log_info "Installing trash..."
                brew install trash 2>/dev/null && log_success "trash installed" || log_warning "trash failed"
            }
            command_exists "wrangler" && log_success "wrangler installed" || {
                log_info "Installing wrangler..."
                command_exists "bun" && bun add -g wrangler 2>/dev/null || npm install -g wrangler 2>/dev/null || log_warning "wrangler failed"
            }
            command_exists "supabase" && log_success "supabase installed" || {
                log_info "Installing supabase..."
                brew install supabase/tap/supabase 2>/dev/null || log_warning "supabase failed"
            }
            command_exists "claude" && log_success "claude installed" || {
                log_info "Installing claude..."
                if command_exists "bun"; then
                    bun add -g @anthropic-ai/claude-code 2>/dev/null || log_warning "claude install via bun failed"
                else
                    # SECURITY: Download to temp file before executing (no checksum available)
                    local claude_script
                    if ! claude_script=$(mktemp); then
                        log_warning "Failed to create temp file for claude installer"
                    else
                        trap 'rm -f "$claude_script"' EXIT INT TERM
                        if ! curl -fsSL https://claude.ai/install.sh -o "$claude_script"; then
                            log_warning "Failed to download claude installer"
                        else
                            sh "$claude_script" 2>/dev/null || log_warning "claude failed"
                        fi
                        rm -f "$claude_script"
                        trap - EXIT INT TERM
                    fi
                fi
            }
            command_exists "codex" && log_success "codex installed" || {
                log_info "Installing codex..."
                command_exists "bun" && bun add -g @openai/codex 2>/dev/null || log_warning "codex failed"
            }
            ;;

        apt)
            log_info "Using apt package manager (Ubuntu/Debian)"
            # Update package list
            sudo apt-get update -qq || {
                log_error "apt-get update failed"
                return 1
            }

            # Core tools available via apt
            local apt_packages=("shellcheck" "yamllint" "ripgrep" "fzf" "bat")
            for pkg in "${apt_packages[@]}"; do
                command_exists "$pkg" && log_success "$pkg installed" || {
                    log_info "Installing $pkg..."
                    sudo apt-get install -y "$pkg" 2>/dev/null || log_warning "Failed: $pkg"
                }
            done

            # eza is usually available as eza or requires cargo
            command_exists "eza" || {
                log_info "Installing eza..."
                sudo apt-get install -y eza 2>/dev/null || cargo install eza 2>/dev/null || log_warning "eza failed"
            }

            # trash-cli (Linux equivalent of macOS trash)
            command_exists "trash" || {
                log_info "Installing trash-cli..."
                sudo apt-get install -y trash-cli 2>/dev/null || log_warning "trash-cli failed"
            }

            # Node.js tools via bun
            command_exists "wrangler" || {
                log_info "Installing wrangler..."
                command_exists "bun" && bun add -g wrangler 2>/dev/null || npm install -g wrangler 2>/dev/null || log_warning "wrangler failed"
            }
            command_exists "claude" || {
                log_info "Installing claude..."
                if command_exists "bun"; then
                    bun add -g @anthropic-ai/claude-code 2>/dev/null || log_warning "claude failed"
                else
                    # SECURITY NOTE: Downloaded scripts should ideally be verified with checksums.
                    # TODO: Add checksum verification when claude.ai provides one.
                    # See CLAUDE.md "Don't Pipe curl to sh Without Verification" for guidance.
                    log_info "Downloading claude installer (no checksum available from source)"
                    local claude_script
                    if ! claude_script=$(mktemp); then
                        log_warning "Failed to create temp file for claude installer"
                    else
                        trap 'rm -f "$claude_script"' EXIT INT TERM
                        if ! curl -fsSL https://claude.ai/install.sh -o "$claude_script"; then
                            log_warning "Failed to download claude installer"
                        else
                            # Note: Executing without checksum verification - see security comment above
                            sh "$claude_script" 2>/dev/null || log_warning "claude failed"
                        fi
                        trap ':' EXIT INT TERM
                    fi
                fi
            }
            ;;

        dnf | yum)
            log_info "Using $SC_PKG_MANAGER package manager (Fedora/RHEL)"
            local rpm_packages=("shellcheck" "ripgrep" "fzf" "bat")
            for pkg in "${rpm_packages[@]}"; do
                command_exists "$pkg" && log_success "$pkg installed" || {
                    log_info "Installing $pkg..."
                    sudo "$SC_PKG_MANAGER" install -y "$pkg" 2>/dev/null || log_warning "Failed: $pkg"
                }
            done

            # trash-cli
            command_exists "trash" || {
                log_info "Installing trash-cli..."
                sudo "$SC_PKG_MANAGER" install -y trash-cli 2>/dev/null || log_warning "trash-cli failed"
            }

            # Install additional tools via cargo if available
            command_exists "eza" || { command_exists "cargo" && cargo install eza 2>/dev/null || log_warning "eza failed (requires cargo)"; }

            # Node.js tools via bun
            command_exists "wrangler" || {
                log_info "Installing wrangler..."
                command_exists "bun" && bun add -g wrangler 2>/dev/null || npm install -g wrangler 2>/dev/null || log_warning "wrangler failed"
            }
            command_exists "claude" || {
                log_info "Installing claude..."
                if command_exists "bun"; then
                    bun add -g @anthropic-ai/claude-code 2>/dev/null || log_warning "claude failed (bun)"
                else
                    # SECURITY: Download to temp file before executing (no checksum available)
                    local claude_script
                    if ! claude_script=$(mktemp); then
                        log_warning "Failed to create temp file for claude installer"
                    else
                        trap 'rm -f "$claude_script"' EXIT INT TERM
                        if ! curl -fsSL https://claude.ai/install.sh -o "$claude_script"; then
                            log_warning "Failed to download claude installer"
                        else
                            sh "$claude_script" 2>/dev/null || log_warning "claude failed"
                        fi
                        rm -f "$claude_script"
                        trap - EXIT INT TERM
                    fi
                fi
            }
            ;;

        pacman)
            log_info "Using pacman package manager (Arch Linux)"
            local pacman_packages=("shellcheck" "ripgrep" "fzf" "bat" "trash-cli")
            for pkg in "${pacman_packages[@]}"; do
                command_exists "$pkg" && log_success "$pkg installed" || {
                    log_info "Installing $pkg..."
                    sudo pacman -S --noconfirm "$pkg" 2>/dev/null || log_warning "Failed: $pkg"
                }
            done

            # Install additional tools via cargo if available
            command_exists "eza" || { command_exists "cargo" && cargo install eza 2>/dev/null || log_warning "eza failed (requires cargo)"; }

            # Node.js tools via bun
            command_exists "wrangler" || {
                log_info "Installing wrangler..."
                command_exists "bun" && bun add -g wrangler 2>/dev/null || npm install -g wrangler 2>/dev/null || log_warning "wrangler failed"
            }
            command_exists "claude" || {
                log_info "Installing claude..."
                if command_exists "bun"; then
                    bun add -g @anthropic-ai/claude-code 2>/dev/null || log_warning "claude failed (bun)"
                else
                    # SECURITY: Download to temp file before executing (no checksum available)
                    local claude_script
                    if ! claude_script=$(mktemp); then
                        log_warning "Failed to create temp file for claude installer"
                    else
                        trap 'rm -f "$claude_script"' EXIT INT TERM
                        if ! curl -fsSL https://claude.ai/install.sh -o "$claude_script"; then
                            log_warning "Failed to download claude installer"
                        else
                            sh "$claude_script" 2>/dev/null || log_warning "claude failed"
                        fi
                        rm -f "$claude_script"
                        trap - EXIT INT TERM
                    fi
                fi
            }
            ;;

        zypper)
            log_info "Using zypper package manager (openSUSE)"
            local zypper_packages=("shellcheck" "ripgrep" "fzf" "bat")
            for pkg in "${zypper_packages[@]}"; do
                command_exists "$pkg" && log_success "$pkg installed" || {
                    log_info "Installing $pkg..."
                    sudo zypper install -y "$pkg" 2>/dev/null || log_warning "Failed: $pkg"
                }
            done

            # trash-cli
            command_exists "trash" || {
                log_info "Installing trash-cli..."
                sudo zypper install -y trash-cli 2>/dev/null || log_warning "trash-cli failed"
            }

            # Install additional tools via cargo if available
            command_exists "eza" || { command_exists "cargo" && cargo install eza 2>/dev/null || log_warning "eza failed (requires cargo)"; }

            # Node.js tools via bun
            command_exists "wrangler" || {
                log_info "Installing wrangler..."
                command_exists "bun" && bun add -g wrangler 2>/dev/null || npm install -g wrangler 2>/dev/null || log_warning "wrangler failed"
            }
            command_exists "claude" || {
                log_info "Installing claude..."
                if command_exists "bun"; then
                    bun add -g @anthropic-ai/claude-code 2>/dev/null || log_warning "claude failed (bun)"
                else
                    # SECURITY: Download to temp file before executing (no checksum available)
                    local claude_script
                    if ! claude_script=$(mktemp); then
                        log_warning "Failed to create temp file for claude installer"
                    else
                        trap 'rm -f "$claude_script"' EXIT INT TERM
                        if ! curl -fsSL https://claude.ai/install.sh -o "$claude_script"; then
                            log_warning "Failed to download claude installer"
                        else
                            sh "$claude_script" 2>/dev/null || log_warning "claude failed"
                        fi
                        rm -f "$claude_script"
                        trap - EXIT INT TERM
                    fi
                fi
            }
            ;;

        none)
            log_warning "No package manager detected. Skipping dependency installation."
            log_info "Manual installation required for: shellcheck, yamllint, ripgrep, fzf, eza, trash-cli"
            ;;

        *)
            log_warning "Unsupported package manager: $SC_PKG_MANAGER"
            log_info "Dependencies must be installed manually"
            ;;
    esac
}

setup_git() {
    log_step "Setting up Git hooks & secrets"
    [[ -f "$SCRIPT_DIR/lib/git/setup.sh" ]] && bash "$SCRIPT_DIR/lib/git/setup.sh" install || log_warning "Git setup not found"
}

setup_phantom_guard() {
    log_step "Phantom Guard"

    if command_exists "phantom-guard"; then
        log_success "phantom-guard installed"
        return 0
    fi

    log_warning "phantom-guard not installed"
    log_info "WHY: Phantom Guard validator will be skipped for package validation"
    log_info "FIX: Install phantom-guard or set PHANTOM_CONFIG_FILE"
}

symlink_config_files() {
    log_step "Symlinking config files"
    sc_symlink_create_all "$SCRIPT_DIR"

    if [[ ! -f "$HOME/.zshrc.local" ]]; then
        cat >"$HOME/.zshrc.local" <<'EOF'
#!/bin/zsh
# =============================================================================
# 🔐 LOCAL SHELL CONFIGURATION (NOT TRACKED BY GIT)
# =============================================================================
# This file is for machine-specific configurations, API keys, and secrets.
# It is NOT tracked by git and should never be committed.
#
# Add your MCP server keys, API tokens, and other sensitive data here.
# =============================================================================

# Example MCP Server Keys (do not commit real keys)
# export EXA_API_KEY="your-key-here"
# export CEREBRAS_API_KEY="your-key-here"

# Example AI/LLM Keys
# export OPENAI_API_KEY="your-key-here"
# export ANTHROPIC_API_KEY="your-key-here"
EOF
        log_success "Created ~/.zshrc.local for your secrets"
    else
        log_info "$HOME/.zshrc.local already exists, skipping"
    fi
}

# =============================================================================
# 7. MAKE SCRIPTS EXECUTABLE
# =============================================================================

make_executable() {
    log_step "Making scripts executable"

    chmod +x "$SCRIPT_DIR/init.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/install.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/uninstall.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/lib/git/setup.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/lib/git/hooks/pre-commit" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/lib/git/hooks/post-commit" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/lib/integrations/ghls/ghls" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/lib/bin/rm" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/lib/bin/gha-scan" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/lib/bin/shell-config" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/lib/bin/shell-config-init" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/lib/bin/validate" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/lib/bin/command-enforce" 2>/dev/null || true

    # Command safety PATH enforcement symlinks (busybox pattern — one script, multiple names)
    # Each symlink causes command-enforce to be found first in PATH.
    # It sources the command-safety engine and checks rules before passing through.
    # NOTE: rm and git have their own specialized wrappers (not included here)
    for cmd in \
        npm npx yarn pnpm composer pip pip3 python python3 go cargo brew bun \
        chmod sudo dd mkfs \
        gh mv \
        docker kubectl \
        terraform ansible-playbook \
        supabase next pg_dump \
        sed find truncate \
        nginx prettier wrangler; do
        ln -sf command-enforce "$SCRIPT_DIR/lib/bin/$cmd" 2>/dev/null || true
    done

    log_success "Scripts are executable"
}

track_version() {
    log_step "Tracking installed version"

    if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
        local version
        version=$(cat "$SCRIPT_DIR/VERSION")
        echo "$version" >"$HOME/.shell-config-version"
        log_success "Version $version installed"
    else
        log_warning "VERSION file not found"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo ""
    echo -e "${BOLD}${CYAN}🚀 Shell-Config Installer${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    symlink_config_files
    if ! install_deps; then
        echo ""
        echo -e "${RED}❌ ERROR: Dependency installation failed${NC}" >&2
        echo -e "${YELLOW}ℹ️  WHY: Critical tools are required for shell-config to function properly${NC}" >&2
        echo -e "${GREEN}💡 FIX: Address the errors above and re-run ./install.sh${NC}" >&2
        exit 1
    fi
    make_executable
    setup_git
    setup_phantom_guard
    track_version

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${GREEN}🚀 Installation Complete!${NC}"
    echo ""
    echo "🔗 Symlinks created:"
    echo "  • ~/.shell-config → $SCRIPT_DIR"
    echo "  • ~/.zshrc → config/zshrc"
    echo "  • ~/.zshenv → config/zshenv"
    echo "  • ~/.zprofile → config/zprofile"
    echo "  • ~/.bashrc → config/bashrc"
    echo "  • ~/.gitconfig → config/gitconfig"
    echo "  • ~/.ssh/config → config/ssh-config (from .example template)"
    echo "  • ~/.ripgreprc → config/ripgreprc"
    echo "  • ~/.zshrc.local → Created (NOT symlinked - for secrets)"
    echo ""
    echo "⚡ Features enabled:"
    echo "  🛡️  Package blockers (npm/pnpm/yarn → bun)"
    echo "  🪝 Git safety wrapper & hooks"
    echo "  🗑️  RM protection (PATH-based wrapper, trash, chflags helpers)"
    echo "  📁 Eza (modern ls) & GHLS"
    echo "  ☁️  Cloudflare CLI (wrangler) & Supabase CLI"
    echo "  👋 Welcome message"
    echo ""
    echo "💻 Commands:"
    echo "  • shell-config --version    Show installed version"
    echo "  • shell-config --help       Show usage documentation"
    echo "  • shell-config uninstall    Remove shell-config"
    echo ""
    echo -e "${YELLOW}👉 Next step:${NC}"
    echo "  Edit config/zshrc.local for API keys, then: source ~/.zshrc"
    echo ""
}

main "$@"
