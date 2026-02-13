#!/usr/bin/env bash
# =============================================================================
# aliases/1password.sh - 1Password & SSH shortcuts
# =============================================================================
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/aliases/1password.sh"
# =============================================================================

[[ -n "${_SHELL_CONFIG_ALIASES_1PASSWORD_LOADED:-}" ]] && return 0
_SHELL_CONFIG_ALIASES_1PASSWORD_LOADED=1

# 1Password & SSH
alias 1password-ssh-sync='bash "$HOME/.shell-config/lib/integrations/1password/ssh-sync.sh"'
alias op-diagnose='bash "$HOME/.shell-config/lib/integrations/1password/diagnose.sh"'
alias op-login='bash "$HOME/.shell-config/lib/integrations/1password/login.sh"'

alias ssh-status='echo "SSH_AUTH_SOCK: $SSH_AUTH_SOCK" && echo "Keys loaded:" && ssh-add -l 2>/dev/null || echo "No SSH agent running"'
alias ssh-test='ssh -T git@github.com 2>&1 && echo "✅ GitHub SSH working"'
alias ssh-reload='source "$HOME/.shell-config/lib/core/loaders/ssh.sh" && _load_ssh && echo "✅ SSH configuration reloaded"'
