#!/usr/bin/env bash
# =============================================================================
# autocomplete.sh - Shell autocomplete and enhancement tools setup
# =============================================================================
# Initializes various shell autocomplete and enhancement tools including
# fzf (fuzzy finder), zsh-autosuggestions, zsh-syntax-highlighting,
# and Claude Code completion. Provides intelligent command history,
# file search, and syntax validation.
# Dependencies:
#   - fzf (optional) - fuzzy finder for Ctrl+R/Ctrl+T
#   - zsh-autosuggestions (optional) - fish-like history suggestions
#   - zsh-syntax-highlighting (optional) - realtime syntax validation
#   - fd (optional) - faster file finding for fzf
# Environment Variables:
#   SHELL_CONFIG_DIR - Shell config installation directory
# Features:
#   - fzf: Ctrl+R (history search), Ctrl+T (file browser)
#   - Autosuggestions: gray suggestions based on command history
#   - Syntax highlighting: green=valid, red=invalid
#   - Claude completion: tab completion for Claude CLI
# Usage:
#   Source this file from shell init - automatically runs _init_autocomplete
#   Install tools via Homebrew: brew install fzf fd
# =============================================================================

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

[[ -z "$SHELL_CONFIG_DIR" ]] && { [[ -n "$ZSH_VERSION" ]] && SHELL_CONFIG_DIR="${0:A:h:h:h}" || SHELL_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; }

# Inshellisense - DISABLED (causes terminal flashing). Run `is` manually if needed
_setup_inshellisense() { return 0; }

# zsh-autosuggestions (fish-like history suggestions)
_setup_zsh_autosuggestions() {
    [[ -z "$ZSH_VERSION" ]] && return
    local brew="/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    local omz="$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
    [[ -f "$brew" ]] && source "$brew" 2>/dev/null || [[ -f "$omz" ]] && source "$omz" 2>/dev/null || return
    export ZSH_AUTOSUGGEST_STRATEGY=(history completion) ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#888888" ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
}

# zsh-syntax-highlighting (valid=green, invalid=red)
_setup_zsh_syntax_highlighting() {
    [[ -z "$ZSH_VERSION" ]] && return
    export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR="/opt/homebrew/share/zsh-syntax-highlighting/highlighters"
    local brew="/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    local omz="$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    [[ -f "$brew" ]] && source "$brew" 2>/dev/null || [[ -f "$omz" ]] && source "$omz" 2>/dev/null
}

# fzf (Ctrl+R history, Ctrl+T files)
_setup_fzf() {
    [[ -n "$ZSH_VERSION" ]] && { [[ -f "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh" ]] && source "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh" 2>/dev/null; [[ -f "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ]] && source "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh" 2>/dev/null; }
    [[ -n "$ZSH_VERSION" ]] && [[ -f "$HOME/.fzf.zsh" ]] && source "$HOME/.fzf.zsh" 2>/dev/null
    [[ -n "$BASH_VERSION" ]] && [[ -f "$HOME/.fzf.bash" ]] && source "$HOME/.fzf.bash" 2>/dev/null
    command_exists "fzf" && { export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"; command_exists "fd" && { export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"; export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"; }; }
}

# Claude Code completion
_setup_claude_completion() {
    [[ -z "$ZSH_VERSION" ]] && return
    local d="$HOME/.oh-my-zsh/custom/plugins/claudecode"
    [[ -d "$d" ]] && { [[ -f "$d/zsh-claudecode-completion.plugin.zsh" ]] && source "$d/zsh-claudecode-completion.plugin.zsh" 2>/dev/null || [[ -f "$d/claudecode.plugin.zsh" ]] && source "$d/claudecode.plugin.zsh" 2>/dev/null; [[ -f "$d/_claude" ]] && fpath=("$d" "${fpath[@]}"); }
}

_init_autocomplete() { _setup_fzf; _setup_zsh_autosuggestions; _setup_zsh_syntax_highlighting; _setup_claude_completion; _setup_inshellisense; }
_init_autocomplete
