#!/usr/bin/env bash
# =============================================================================
# aliases/core.sh - Navigation and safety aliases
# =============================================================================
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/aliases/core.sh"
# =============================================================================

[[ -n "${_SHELL_CONFIG_ALIASES_CORE_LOADED:-}" ]] && return 0
_SHELL_CONFIG_ALIASES_CORE_LOADED=1

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Safety (rm uses PATH wrapper in lib/bin/rm with protected paths & audit logging)
alias mv='mv -i'
alias cp='cp -i'

# Safety aliases - prompt before overwriting
alias ln='ln -i'
alias chmod='chmod -v'
alias chown='chown -v'
alias wget='wget -nc'
