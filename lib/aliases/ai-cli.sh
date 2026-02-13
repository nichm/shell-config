#!/usr/bin/env bash
# =============================================================================
# aliases/ai-cli.sh - AI CLI shortcuts
# =============================================================================
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/aliases/ai-cli.sh"
# =============================================================================

[[ -n "${_SHELL_CONFIG_ALIASES_AI_CLI_LOADED:-}" ]] && return 0
_SHELL_CONFIG_ALIASES_AI_CLI_LOADED=1

alias clauded='claude --dangerously-skip-permissions'
alias cl='claude'
alias clc='claude chat'
alias clr='claude run'

alias cx='codex'
alias cxr='codex run'
