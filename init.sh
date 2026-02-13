#!/usr/bin/env bash
# Shell-Config Master Init - sources all modules with feature flags
# Usage: source "$HOME/.shell-config/init.sh"

# Track startup time (must be first thing for accurate measurement)
# Use perl for millisecond precision (always available on macOS/Linux)
export SHELL_CONFIG_START_TIME
if command -v perl >/dev/null 2>&1; then
    SHELL_CONFIG_START_TIME=$(perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000')
else
    # Fallback: seconds * 1000 (less precise but works)
    SHELL_CONFIG_START_TIME=$(($(date +%s) * 1000))
fi

# Get script directory (bash/zsh compatible)
if [[ -n "$ZSH_VERSION" ]]; then
    SHELL_CONFIG_DIR="${0:A:h}"
elif [[ -n "$BASH_VERSION" ]]; then
    SHELL_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Fallback to symlink location
    SHELL_CONFIG_DIR="$HOME/.shell-config"
fi

# Load configuration (env vars > YAML > simple config > defaults)
[[ -f "$SHELL_CONFIG_DIR/lib/core/config.sh" ]] && source "$SHELL_CONFIG_DIR/lib/core/config.sh"

# Load platform detection
[[ -f "$SHELL_CONFIG_DIR/lib/core/platform.sh" ]] && source "$SHELL_CONFIG_DIR/lib/core/platform.sh"

# Feature flags (set in ~/.zshrc.local or config file before sourcing)
: "${SHELL_CONFIG_WELCOME:=true}"
: "${SHELL_CONFIG_COMMAND_SAFETY:=true}"
: "${SHELL_CONFIG_GIT_WRAPPER:=true}"
: "${SHELL_CONFIG_GHLS:=true}"
: "${SHELL_CONFIG_EZA:=true}"
: "${SHELL_CONFIG_RIPGREP:=true}"
: "${SHELL_CONFIG_FZF:=true}"
: "${SHELL_CONFIG_CAT:=true}"
: "${SHELL_CONFIG_BROOT:=true}"
: "${SHELL_CONFIG_SECURITY:=true}"
: "${SHELL_CONFIG_1PASSWORD:=true}"
: "${SHELL_CONFIG_AUTOCOMPLETE:=false}"
: "${SHELL_CONFIG_LOG_ROTATION:=true}"

# Log rotation
if [[ -f "$SHELL_CONFIG_DIR/lib/core/logging.sh" ]]; then
    source "$SHELL_CONFIG_DIR/lib/core/logging.sh"
    _shell_config_rotate_logs
fi

# Ensure audit log symlink exists for easy access
if [[ -f "$SHELL_CONFIG_DIR/lib/core/ensure-audit-symlink.sh" ]]; then
    source "$SHELL_CONFIG_DIR/lib/core/ensure-audit-symlink.sh"
fi

# PATH & Environment (platform-aware)
if [[ -f "$SHELL_CONFIG_DIR/lib/core/paths.sh" ]]; then
    source "$SHELL_CONFIG_DIR/lib/core/paths.sh"
fi

# Core modules
[[ -f "$SHELL_CONFIG_DIR/lib/aliases/init.sh" ]] && source "$SHELL_CONFIG_DIR/lib/aliases/init.sh"
# Load core components
[[ -f "$SHELL_CONFIG_DIR/lib/core/loaders/ssh.sh" ]] && source "$SHELL_CONFIG_DIR/lib/core/loaders/ssh.sh"
[[ -f "$SHELL_CONFIG_DIR/lib/core/loaders/fnm.sh" ]] && source "$SHELL_CONFIG_DIR/lib/core/loaders/fnm.sh"
[[ -f "$SHELL_CONFIG_DIR/lib/core/loaders/completions.sh" ]] && source "$SHELL_CONFIG_DIR/lib/core/loaders/completions.sh"
[[ "$SHELL_CONFIG_BROOT" == "true" && -f "$SHELL_CONFIG_DIR/lib/core/loaders/broot.sh" ]] && source "$SHELL_CONFIG_DIR/lib/core/loaders/broot.sh"

# 1Password secrets (lazy-loaded by default — secrets load on first use)
# Set SHELL_CONFIG_1PASSWORD_EAGER=true to restore eager loading at startup
if [[ "$SHELL_CONFIG_1PASSWORD" == "true" && -f "$SHELL_CONFIG_DIR/lib/integrations/1password/secrets.sh" ]]; then
    source "$SHELL_CONFIG_DIR/lib/integrations/1password/secrets.sh"
fi

# Feature modules (conditional on feature flags)
[[ "$SHELL_CONFIG_GIT_WRAPPER" == "true" && -f "$SHELL_CONFIG_DIR/lib/git/wrapper.sh" ]] && source "$SHELL_CONFIG_DIR/lib/git/wrapper.sh"
[[ "$SHELL_CONFIG_COMMAND_SAFETY" == "true" && -f "$SHELL_CONFIG_DIR/lib/command-safety/init.sh" ]] && source "$SHELL_CONFIG_DIR/lib/command-safety/init.sh"
[[ "$SHELL_CONFIG_EZA" == "true" && -f "$SHELL_CONFIG_DIR/lib/integrations/eza.sh" ]] && source "$SHELL_CONFIG_DIR/lib/integrations/eza.sh"
[[ "$SHELL_CONFIG_RIPGREP" == "true" && -f "$SHELL_CONFIG_DIR/lib/integrations/ripgrep.sh" ]] && source "$SHELL_CONFIG_DIR/lib/integrations/ripgrep.sh"
[[ "$SHELL_CONFIG_FZF" == "true" && -f "$SHELL_CONFIG_DIR/lib/integrations/fzf.sh" ]] && source "$SHELL_CONFIG_DIR/lib/integrations/fzf.sh"
[[ "$SHELL_CONFIG_CAT" == "true" && -f "$SHELL_CONFIG_DIR/lib/integrations/cat.sh" ]] && source "$SHELL_CONFIG_DIR/lib/integrations/cat.sh"
[[ "$SHELL_CONFIG_AUTOCOMPLETE" == "true" && -f "$SHELL_CONFIG_DIR/lib/terminal/autocomplete.sh" ]] && source "$SHELL_CONFIG_DIR/lib/terminal/autocomplete.sh"
if [[ "$SHELL_CONFIG_WELCOME" == "true" && -f "$SHELL_CONFIG_DIR/lib/welcome/main.sh" ]]; then
    source "$SHELL_CONFIG_DIR/lib/welcome/main.sh"
fi

# GHLS (statusline)
if [[ "$SHELL_CONFIG_GHLS" == "true" ]]; then
    [[ -f "$SHELL_CONFIG_DIR/lib/integrations/ghls/statusline.sh" ]] && source "$SHELL_CONFIG_DIR/lib/integrations/ghls/statusline.sh"
    [[ -f "$SHELL_CONFIG_DIR/lib/integrations/ghls/auto.sh" ]] && source "$SHELL_CONFIG_DIR/lib/integrations/ghls/auto.sh"
fi

[[ "$SHELL_CONFIG_SECURITY" == "true" && -f "$SHELL_CONFIG_DIR/lib/security/init.sh" ]] && source "$SHELL_CONFIG_DIR/lib/security/init.sh"

# Claude CLI
if ! command -v claude >/dev/null 2>&1; then
    [[ -f "$HOME/.local/bin/claude" ]] && alias claude='$HOME/.local/bin/claude'
    [[ -f "$HOME/.bun/bin/claude" ]] && alias claude='$HOME/.bun/bin/claude'
fi

# Claude Code Mux (CCM)
if command -v ccm >/dev/null 2>&1; then
    pgrep -f "ccm start" >/dev/null 2>&1 || (ccm start >/dev/null 2>&1 &)
    export ANTHROPIC_BASE_URL="http://127.0.0.1:13456"
    export ANTHROPIC_AUTH_TOKEN="ccm-router"
    unset ANTHROPIC_API_KEY 2>/dev/null
fi

# Doctor command
[[ -f "$SHELL_CONFIG_DIR/lib/core/doctor.sh" ]] && source "$SHELL_CONFIG_DIR/lib/core/doctor.sh"

# shell-config command (version, help, etc.)
shell-config() {
    case "${1:-}" in
        --version | -v)
            if [[ -f "$SHELL_CONFIG_DIR/VERSION" ]]; then
                cat "$SHELL_CONFIG_DIR/VERSION"
            else
                echo "unknown"
            fi
            ;;
        --help | -h)
            if [[ -f "$SHELL_CONFIG_DIR/docs/USAGE.md" ]]; then
                cat "$SHELL_CONFIG_DIR/docs/USAGE.md"
            else
                echo "shell-config: Usage documentation not found"
            fi
            ;;
        init-config)
            echo "shell-config: Configuration files"
            echo ""
            echo "Config locations (in order of precedence):"
            echo "  1. ~/.config/shell-config/config.yml"
            echo "  2. ~/.config/shell-config/config"
            echo "  3. ~/.shell-config/config.yml"
            echo "  4. ~/.shell-config/config"
            echo ""
            echo "See docs/USAGE.md for configuration options."
            ;;
        uninstall)
            if [[ -f "$SHELL_CONFIG_DIR/uninstall.sh" ]]; then
                shift
                bash "$SHELL_CONFIG_DIR/uninstall.sh" "$@"
            else
                echo "shell-config: Uninstall script not found"
            fi
            ;;
        *)
            echo "Usage: shell-config [--version|-v] [--help|-h] [init-config] [uninstall] [--dry-run]"
            echo ""
            echo "Commands:"
            echo "  --version, -v    Show installed version"
            echo "  --help, -h       Show usage documentation"
            echo "  init-config      Show configuration file locations"
            echo "  uninstall        Remove shell-config (accepts --dry-run)"
            return 1
            ;;
    esac
}

# ZSH specific
if [[ -n "$ZSH_VERSION" ]]; then
    # Use cached compinit for faster startup (7ms savings)
    # Only rebuild if cache older than 24h
    autoload -Uz compinit
    # Check if cache exists and is fresh (newer than 24h)
    # Use portable stat-based age check instead of zsh glob qualifiers
    if [[ -f ~/.zcompdump ]]; then
        # Note: Not using 'local' here since this is top-level zsh code
        # PERF: Use $SC_OS (already set by platform.sh) instead of $(uname) subshell
        if [[ "${SC_OS:-}" == "macos" ]]; then
            _zc_mtime=$(stat -f %m ~/.zcompdump 2>/dev/null || echo 0)
        else
            _zc_mtime=$(stat -c %Y ~/.zcompdump 2>/dev/null || echo 0)
        fi
        _zc_age=$(($(date +%s) - _zc_mtime))
        if ((_zc_age < 86400)); then
            compinit -C # Use cache (exists and fresh)
        else
            compinit # Rebuild cache (stale)
        fi
        unset _zc_mtime _zc_age
    else
        compinit # Rebuild cache (missing)
    fi
    setopt PROMPT_SUBST
    __shell_statusline() {
        [[ -f "$SHELL_CONFIG_DIR/lib/integrations/ghls/statusline.sh" ]] && command -v git_statusline >/dev/null 2>&1 \
            && [[ -n "$PS1" ]] && git rev-parse --git-dir >/dev/null 2>&1 && git_statusline 2>/dev/null
    }
fi
