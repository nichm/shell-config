#!/usr/bin/env bash
# =============================================================================
# core/loaders/completions.sh - Optional Shell Completions
# =============================================================================
# Loads opt-in completions for Bun and UV.
# Usage:
#   source "$SHELL_CONFIG_DIR/lib/core/loaders/completions.sh"
# =============================================================================

# Bun completions (zsh only, opt-in via feature flag)
if [[ "${SHELL_CONFIG_BUN_COMPLETIONS:-false}" == "true" ]] \
    && [[ -n "$ZSH_VERSION" ]] && [[ -s "$HOME/.bun/_bun" ]]; then
    source "$HOME/.bun/_bun" 2>/dev/null
fi

# UV completions (zsh only, opt-in via feature flag)
_load_uv_completions() {
    local uv_comp_dir="$HOME/.shell-cache/completions"
    local uv_comp_file="$uv_comp_dir/_uv"
    if [[ ! -f "$uv_comp_file" ]]; then
        mkdir -p "$uv_comp_dir" 2>/dev/null
        uv --generate-shell-completion zsh >"$uv_comp_file" 2>/dev/null || command rm -f "$uv_comp_file"
    fi
    # shellcheck source=/dev/null
    [[ -s "$uv_comp_file" ]] && source "$uv_comp_file" 2>/dev/null
}

# shellcheck disable=SC2154
if [[ "${SHELL_CONFIG_UV_COMPLETIONS:-false}" == "true" ]] \
    && [[ -n "${ZSH_VERSION:-}" ]] && (( $+commands[uv] )); then
    _load_uv_completions
fi

return 0
