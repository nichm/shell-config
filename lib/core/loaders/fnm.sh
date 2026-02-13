#!/usr/bin/env bash
# =============================================================================
# core/loaders/fnm.sh - Fast Node Manager Loader
# =============================================================================
# Lazily initializes fnm for faster shell startup.
# Usage:
#   source "$SHELL_CONFIG_DIR/lib/core/loaders/fnm.sh"
# =============================================================================

# fnm - lazy loaded for fast startup (26ms to 1-2ms)
FNM_PATH="$HOME/Library/Application Support/fnm"
if [[ -d "$FNM_PATH" ]]; then
    export PATH="$FNM_PATH:$PATH"
    _fnm_load() { [[ -z "${FNM_ENV_LOADED:-}" ]] && {
        unset -f fnm node npm npx corepack _fnm_load
        eval "$(fnm env 2>/dev/null)" || true
        export FNM_ENV_LOADED=1
    }; }
    fnm() {
        _fnm_load
        fnm "$@"
    }
    node() {
        _fnm_load
        node "$@"
    }
    npm() {
        _fnm_load
        npm "$@"
    }
    npx() {
        _fnm_load
        npx "$@"
    }
    corepack() {
        _fnm_load
        corepack "$@"
    }
fi
