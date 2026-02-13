#!/usr/bin/env bash
# =============================================================================
# core/paths.sh - PATH and environment setup
# =============================================================================
# Sets PATH entries for common tools and shell-config binaries.
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/core/paths.sh"
# =============================================================================

[[ -n "${_SHELL_CONFIG_CORE_PATHS_LOADED:-}" ]] && return 0
_SHELL_CONFIG_CORE_PATHS_LOADED=1

# Ensure SHELL_CONFIG_DIR is set for path calculations
if [[ -z "${SHELL_CONFIG_DIR:-}" ]]; then
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        SHELL_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    else
        SHELL_CONFIG_DIR="$HOME/.shell-config"
    fi
fi

# PATH & Environment (platform-aware)
if [[ -n "${SC_HOMEBREW_PREFIX:-}" ]] && [[ -d "$SC_HOMEBREW_PREFIX" ]] && [[ "${SC_OS:-}" == "macos" ]]; then
    export HOMEBREW_PREFIX="$SC_HOMEBREW_PREFIX"
    export HOMEBREW_CELLAR="$SC_HOMEBREW_PREFIX/Cellar"
    export HOMEBREW_REPOSITORY="$SC_HOMEBREW_PREFIX"
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
    export MANPATH="$HOMEBREW_PREFIX/share/man${MANPATH+:$MANPATH}:"
    export INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH:-}"
fi

# Common paths
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$HOME/.local/bin:$PATH"
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# macOS-specific Python framework (detect available versions)
if [[ "${SC_OS:-}" == "macos" ]]; then
    for py_ver in 3.13 3.12 3.11 3.10; do
        py_path="/Library/Frameworks/Python.framework/Versions/${py_ver}/bin"
        if [[ -d "$py_path" ]]; then
            export PATH="$py_path:$PATH"
            break
        fi
    done
fi

# Shell-config tools
SC_TOOLS_PATH="$SHELL_CONFIG_DIR/lib/integrations/ghls:$SHELL_CONFIG_DIR/lib/bin"
if [[ "${SC_OS:-}" == "macos" ]] && [[ -n "${SC_HOMEBREW_PREFIX:-}" ]] && [[ -d "$SC_HOMEBREW_PREFIX/opt/trash/bin" ]]; then
    export PATH="$SC_TOOLS_PATH:$SC_HOMEBREW_PREFIX/opt/trash/bin:$PATH"
else
    export PATH="$SC_TOOLS_PATH:$PATH"
fi
