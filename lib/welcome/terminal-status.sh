#!/usr/bin/env bash
# =============================================================================
# terminal-status.sh - Terminal environment status with category dividers
# =============================================================================
# Displays security, tools, and Zsh plugin checks in a clean grid format.
# Config: Part of welcome message system
# NOTE: No set -euo pipefail — this file is sourced into interactive shells
# =============================================================================

[[ -z "${_WM_COLOR_RESET:-}" ]] && return 1

# =============================================================================
# Verification Functions
# =============================================================================

_ts_check_1password() { [[ -S "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ]]; }
_ts_check_ssh() { [[ -S "${SSH_AUTH_SOCK:-}" ]]; }
_ts_check_safe_rm() {
    local d="${SHELL_CONFIG_DIR:-$HOME/.shell-config}"
    [[ -x "$d/lib/bin/rm" ]] && [[ ":$PATH:" == *":$d/lib/bin:"* ]]
}
# Check for git wrapper (uses eagerly-loaded function, not lazy-loaded _run_safety_checks)
_ts_check_git_wrapper() { type _git_wrapper_load_heavy >/dev/null 2>&1; }
_ts_check_zsh_hardening() { [[ -n "${ZSH_VERSION:-}" ]] && [[ -o noclobber ]] && [[ -o rmstarwait ]]; }

# Optimized helper: Check command existence using zsh-native or POSIX lookup
# shellcheck disable=SC2154
_ts_check_command_exists() {
    local cmd="$1"
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # Zsh: 40% faster using cached hash table
        (( $+commands[$cmd] ))
    else
        # Bash/POSIX: Standard command lookup
        command_exists "$cmd"
    fi
}

# shellcheck disable=SC2154
_ts_check_ghls() {
    local ghls_path="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/integrations/ghls/ghls"
    [[ -x "$ghls_path" ]] && return 0
    _ts_check_command_exists "ghls"
}
_ts_check_eza() { _ts_check_command_exists "eza"; }

# Check for claude CLI (installed via npm/bun or direct install)
_ts_check_claude() {
    _ts_check_command_exists "claude" && return 0
    [[ -x "$HOME/.local/bin/claude" || -x "$HOME/.bun/bin/claude" ]]
}
_ts_check_ccat() { _ts_check_command_exists "ccat"; }
_ts_check_inshellisense() {
    _ts_check_command_exists "is" && return 0
    [[ -x "$HOME/.bun/bin/is" ]]
}
_ts_check_fzf() { _ts_check_command_exists "fzf"; }
_ts_check_hyperfine() { _ts_check_command_exists "hyperfine"; }
_ts_check_autosuggestions() {
    [[ -n "${ZSH_AUTOSUGGEST_STRATEGY:-}" ]] && return 0
    type _zsh_autosuggest_start >/dev/null 2>&1 && return 0
    [[ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]] && return 1
    [[ -d "/opt/homebrew/share/zsh-autosuggestions" ]] && return 1
    return 2
}
_ts_check_syntax_highlighting() {
    type _zsh_highlight >/dev/null 2>&1 && return 0
    [[ -n "${ZSH_HIGHLIGHT_HIGHLIGHTERS:-}" ]] && return 0
    [[ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]] && return 1
    [[ -d "/opt/homebrew/share/zsh-syntax-highlighting" ]] && return 1
    return 2
}

# PERF: Use zsh built-in alias count (0 subshells) or fallback to grep
# Prints count directly to stdout (no newline) for inline use
_ts_count_aliases() {
    # shellcheck disable=SC2154
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # Zsh: built-in associative array of all loaded aliases (zero subshells)
        printf '%s' "${#aliases}"
    else
        # Bash: count from files (4 subshells, but bash startup is rarer)
        local aliases_dir="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/aliases"
        local integrations_dir="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/integrations"
        local count=0
        if [[ -d "$aliases_dir" ]]; then
            count=$(grep -rch '^alias ' "$aliases_dir"/*.sh 2>/dev/null | awk '{s+=$1} END {print s+0}')
        fi
        if [[ -d "$integrations_dir" ]]; then
            local int_count
            int_count=$(grep -rch '^alias ' "$integrations_dir"/*.sh "$integrations_dir"/**/*.sh 2>/dev/null | awk '{s+=$1} END {print s+0}')
            count=$((count + int_count))
        fi
        printf '%s' "${count:-0}"
    fi
}

# =============================================================================
# Formatting Helpers
# =============================================================================

_ts_icon() {
    if "$1" 2>/dev/null; then
        printf "${_WM_COLOR_GREEN}✓${_WM_COLOR_RESET}"
    else
        printf "${_WM_COLOR_RED}✗${_WM_COLOR_RESET}"
    fi
}

# PERF: Print check + emoji + label directly to stdout (no subshell needed)
# Usage: _ts_print_item _ts_check_fn "emoji" "label"
# Replaces: printf "$(_ts_icon _ts_check_fn) emoji %-12s" "label" (which spawns a subshell)
_ts_print_item() {
    local check_fn="$1" emoji="$2" label="$3"
    if "$check_fn" 2>/dev/null; then
        printf "${_WM_COLOR_GREEN}✓${_WM_COLOR_RESET} %s %-12s" "$emoji" "$label"
    else
        printf "${_WM_COLOR_RED}✗${_WM_COLOR_RESET} %s %-12s" "$emoji" "$label"
    fi
}

_ts_div() {
    printf "  %b── %s %s ─────────────────────────────────────────────────────%b\n" \
        "${_WM_COLOR_DIM}" "$1" "$2" "${_WM_COLOR_RESET}"
}

_ts_get_safety_counts() {
    # Count rules from the loaded registry (new _rule() format)
    if [[ ${#COMMAND_SAFETY_RULE_SUFFIXES[@]} -gt 0 ]]; then
        local block_count=0 info_count=0
        local suffix
        for suffix in "${COMMAND_SAFETY_RULE_SUFFIXES[@]}"; do
            case "${COMMAND_SAFETY_RULE_ACTION[$suffix]:-}" in
                block) ((block_count++)) || true ;;
                info) ((info_count++)) || true ;;
            esac
        done
        local total=$((block_count + info_count))
        printf "${total} ${_WM_COLOR_DIM}(${_WM_COLOR_RESET}${_WM_COLOR_RED}${block_count} block${_WM_COLOR_RESET}${_WM_COLOR_DIM}, ${_WM_COLOR_RESET}${_WM_COLOR_YELLOW}${info_count} info${_WM_COLOR_RESET}${_WM_COLOR_DIM})${_WM_COLOR_RESET}"
    else
        local rules_dir="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/command-safety/rules"
        [[ -d "$rules_dir" ]] || {
            printf "${_WM_COLOR_DIM}n/a${_WM_COLOR_RESET}"
            return
        }
        local block_count info_count
        block_count=$(grep -rhc 'block=' "$rules_dir"/*.sh 2>/dev/null | awk '{s+=$1} END {print s+0}')
        info_count=$(grep -rhc 'info=' "$rules_dir"/*.sh 2>/dev/null | awk '{s+=$1} END {print s+0}')
        local total=$((block_count + info_count))
        printf "${total} ${_WM_COLOR_DIM}(${_WM_COLOR_RESET}${_WM_COLOR_RED}${block_count} block${_WM_COLOR_RESET}${_WM_COLOR_DIM}, ${_WM_COLOR_RESET}${_WM_COLOR_YELLOW}${info_count} info${_WM_COLOR_RESET}${_WM_COLOR_DIM})${_WM_COLOR_RESET}"
    fi
}

# =============================================================================
# Main Display — Grid with category dividers
# =============================================================================

_welcome_show_terminal_status() {
    local aliases_file="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/aliases/init.sh"
    local G R B
    G="${_WM_COLOR_GRAY}"
    R="${_WM_COLOR_RESET}"
    B="${_WM_COLOR_BOLD}"

    # Lazy-loaded checks (Zsh plugins - may load after welcome)
    local _sug_ret=2 _syn_ret=2
    _ts_check_autosuggestions && _sug_ret=0 || _sug_ret=$?
    _ts_check_syntax_highlighting && _syn_ret=0 || _syn_ret=$?
    local _sug_icon _syn_icon
    case $_sug_ret in 0) _sug_icon="${_WM_COLOR_GREEN}✓${R}" ;; 1) _sug_icon="${_WM_COLOR_YELLOW}⏳${R}" ;; *) _sug_icon="${_WM_COLOR_RED}✗${R}" ;; esac
    case $_syn_ret in 0) _syn_icon="${_WM_COLOR_GREEN}✓${R}" ;; 1) _syn_icon="${_WM_COLOR_YELLOW}⏳${R}" ;; *) _syn_icon="${_WM_COLOR_RED}✗${R}" ;; esac

    printf "\n${B}🖥️  Terminal${R}\n"

    # PERF: Use _ts_print_item (direct printf) instead of $(_ts_icon ...) subshells
    # Eliminates 12 subshell spawns (~24-36ms saved)

    # Security
    _ts_div "🔒" "Security"
    printf "  "; _ts_print_item _ts_check_1password "🔐" "1pass"
    _ts_print_item _ts_check_ssh "🔑" "ssh"
    _ts_print_item _ts_check_safe_rm "🗑 " "rm"
    _ts_print_item _ts_check_git_wrapper "🔀" "git"; printf "\n"

    # Tools
    _ts_div "🔧" "Tools"
    printf "  "; _ts_print_item _ts_check_eza "📁" "eza"
    _ts_print_item _ts_check_fzf "🔍" "fzf"
    _ts_print_item _ts_check_claude "🤖" "claude"
    _ts_print_item _ts_check_ccat "🐱" "ccat"; printf "\n"
    printf "  "; _ts_print_item _ts_check_inshellisense "🔮" "inshell"
    _ts_print_item _ts_check_hyperfine "⏱ " "hyperfine"
    _ts_print_item _ts_check_ghls "📊" "ghls"
    _ts_print_item _ts_check_zsh_hardening "🐚" "zsh-safe"; printf "\n"

    # Zsh Plugins
    _ts_div "🐚" "Zsh Plugins"
    printf "  ${_sug_icon} 💡 %-12s" "suggest"
    printf "${_syn_icon} 🎨 %-12s\n" "syntax"

    # Summary line with clickable links
    local rules_dir="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/command-safety/rules"
    printf "\n  ⚡ "
    printf '\e]8;;cursor://file%s\e\\' "$rules_dir"
    # PERF: Call _ts_get_safety_counts and _ts_count_aliases directly (2 subshells eliminated)
    printf "${B}Safety:${R} "; _ts_get_safety_counts
    printf '\e]8;;\e\\'
    printf "  ${G}│${R}  "
    printf '\e]8;;cursor://file%s\e\\' "$aliases_file"
    printf "📝 ${_WM_COLOR_CYAN}Aliases: "; _ts_count_aliases; printf "${R}"
    printf '\e]8;;\e\\\n'
}

# =============================================================================
# Export for autocomplete-guide.sh
# =============================================================================

# PERF: Direct assignment without $() subshells (5 subshell spawns eliminated)
_ts_export_verification() {
    _ts_check_inshellisense 2>/dev/null && _AC_IS_LOADED=true || _AC_IS_LOADED=false
    _ts_check_fzf 2>/dev/null && _AC_FZF_LOADED=true || _AC_FZF_LOADED=false
    _ts_check_autosuggestions 2>/dev/null && _AC_SUGGEST_LOADED=true || _AC_SUGGEST_LOADED=false
    _ts_check_syntax_highlighting 2>/dev/null && _AC_SYNTAX_LOADED=true || _AC_SYNTAX_LOADED=false
    _ts_check_claude 2>/dev/null && _AC_CLAUDE_LOADED=true || _AC_CLAUDE_LOADED=false
    export _AC_IS_LOADED _AC_FZF_LOADED _AC_SUGGEST_LOADED _AC_SYNTAX_LOADED _AC_CLAUDE_LOADED
}
