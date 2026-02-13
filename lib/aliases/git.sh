#!/usr/bin/env bash
# =============================================================================
# aliases/git.sh - Git shortcuts
# =============================================================================
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/aliases/git.sh"
# =============================================================================

[[ -n "${_SHELL_CONFIG_ALIASES_GIT_LOADED:-}" ]] && return 0
_SHELL_CONFIG_ALIASES_GIT_LOADED=1

alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -10'
alias gd='git diff'
