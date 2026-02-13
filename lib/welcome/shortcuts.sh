#!/usr/bin/env bash
# =============================================================================
# shortcuts.sh - Interactive alias quick reference with clickable links
# =============================================================================
# Displays a curated list of shell aliases with clickable links that open
# directly to their definition in the aliases module. Supports terminal
# hyperlink escape sequences for editors like Cursor/VSCode.
# Dependencies:
#   - welcome/colors.sh (for color variables)
#   - aliases/init.sh (for alias definitions)
# Environment Variables:
#   WELCOME_SHORTCUTS - Enable/disable shortcuts display (default: true)
#   SHELL_CONFIG_DIR  - Shell config installation directory
# Features:
#   - Clickable shortcuts (opens file at line number in supported terminals)
#   - Pinned shortcuts (always shown, cyan)
#   - Random shortcuts (rotating sample, yellow)
#   - Dynamic server aliases from personal.env (only shows configured servers)
# Usage:
#   Source this file from welcome/main.sh - no direct usage needed
#   Controlled by WELCOME_SHORTCUTS environment variable
# =============================================================================

: "${WELCOME_SHORTCUTS:=${SHELL_CONFIG_SHORTCUTS:-true}}"
[[ -z "${_WM_COLOR_RESET:-}" ]] && return 1

_shortcuts_get_server_aliases() {
    # Return server aliases defined in personal.env (SERVER_N_ALIAS/TARGET pairs)
    local config_file="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/config/personal.env"
    [[ -f "$config_file" ]] || return 0
    # shellcheck disable=SC1090
    local _env_content
    _env_content=$(grep -E '^SERVER_[0-9]+_(ALIAS|TARGET)=' "$config_file" 2>/dev/null) || return 0
    echo "$_env_content"
}

# Print a clickable shortcut that opens the aliases module at the line where it's defined
# Usage: _print_shortcut "name" "description" "color"
_print_shortcut() {
    local name="$1" desc="$2" color="${3:-$_WM_COLOR_YELLOW}"
    local aliases_dir="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/aliases"
    local aliases_file=""
    local line_num=""
    local file

    # Find line number of this alias across alias modules
    for file in "$aliases_dir"/*.sh; do
        [[ "$file" == */init.sh ]] && continue
        line_num=$(grep -n "^alias ${name}=" "$file" 2>/dev/null | cut -d: -f1 | head -1)
        if [[ -n "$line_num" ]]; then
            aliases_file="$file"
            break
        fi
    done

    if [[ -n "$line_num" && -n "$aliases_file" ]]; then
        # Clickable link to specific line in Cursor
        # SAFETY: Use printf %s to prevent format string injection
        if _welcome_terminal_supports_links; then
            printf '\e]8;;cursor://file%s:%s\e\\' "$aliases_file" "$line_num"
            printf "${color}  %-12s${_WM_COLOR_RESET}" "$name"
            printf '\e]8;;\e\\'
        else
            printf "${color}  %-12s${_WM_COLOR_RESET}" "$name"
        fi
    else
        # SAFETY: Use printf %s to prevent format string injection
        printf "${color}  %-12s${_WM_COLOR_RESET}" "$name"
    fi
    # SAFETY: Use printf %s to prevent format string injection
    printf " %s\n" "$desc"
}

_welcome_show_shortcuts() {
    [[ "$WELCOME_SHORTCUTS" != "true" ]] && return 0
    local config_dir="${SHELL_CONFIG_DIR:-$HOME/.shell-config}"
    local aliases_dir="$config_dir/lib/aliases"
    local aliases_index="$aliases_dir/init.sh"

    printf "\n${_WM_COLOR_BOLD}⌨️  Shortcuts${_WM_COLOR_RESET} ${_WM_COLOR_DIM}→${_WM_COLOR_RESET} "
    # Link to aliases directory
    # NOTE: Colors MUST be in printf format string, not %s args.
    # %s does NOT interpret \033 escapes, so colors would print literally.
    printf '\e]8;;cursor://file%s\e\\' "$aliases_index"
    printf "${_WM_COLOR_CYAN}%s${_WM_COLOR_RESET}" "aliases/"
    printf '\e]8;;\e\\\n'
    printf "${_WM_COLOR_GRAY}────────────────────────────────────────────${_WM_COLOR_RESET}\n"

    # Pinned shortcuts (cyan) - always shown, clickable
    _print_shortcut "clauded" "Claude (skip perms)" "$_WM_COLOR_CYAN"
    _print_shortcut "cl" "Claude CLI" "$_WM_COLOR_CYAN"

    # Dynamic server aliases from personal.env (only shows real, configured servers)
    local _srv_env _srv_i _srv_alias _srv_target
    _srv_env=$(_shortcuts_get_server_aliases)
    if [[ -n "$_srv_env" ]]; then
        _srv_i=1
        while true; do
            _srv_alias=$(echo "$_srv_env" | grep "^SERVER_${_srv_i}_ALIAS=" | head -1 | sed 's/^[^=]*="//' | sed 's/"$//')
            _srv_target=$(echo "$_srv_env" | grep "^SERVER_${_srv_i}_TARGET=" | head -1 | sed 's/^[^=]*="//' | sed 's/"$//')
            [[ -z "$_srv_alias" ]] && break

            # Only show if alias is actually defined in the shell
            if alias "$_srv_alias" >/dev/null 2>&1; then
                _print_shortcut "$_srv_alias" "ssh ${_srv_target}" "$_WM_COLOR_CYAN"
            fi
            ((_srv_i++))
        done
    fi

    printf "${_WM_COLOR_GRAY}  ············${_WM_COLOR_RESET}\n"

    # Random shortcuts (yellow) - clickable links to their definition
    if [[ -d "$aliases_dir" ]]; then
        grep -nE "^alias [a-zA-Z0-9._-]+=" "$aliases_dir"/*.sh 2>/dev/null \
            | grep -v "/init.sh:" \
            | grep -v "clauded\\|alias cl=" | sort -R | head -5 \
            | while IFS=: read -r file line_num rest; do
                # Extract alias name and command
                # Note: No 'local' here — zsh prints typeset output on re-declaration in loops
                # Variables are already scoped to the pipe subshell
                name=$(sed -E "s/^alias ([^=]+)=.*/\1/" <<<"$rest")
                cmd=$(sed -E "s/^alias [^=]+=['\"]?([^'\"#]+)['\"]?.*/\1/" <<<"$rest")
                [[ -z "$name" ]] && continue
                [[ ${#cmd} -gt 30 ]] && cmd="${cmd:0:27}..."

                # Print clickable shortcut
                # SAFETY: Use printf %s to prevent format string injection
                if _welcome_terminal_supports_links; then
                    printf '\e]8;;cursor://file%s:%s\e\\' "$file" "$line_num"
                    printf "${_WM_COLOR_YELLOW}  %-12s${_WM_COLOR_RESET}" "$name"
                    printf '\e]8;;\e\\'
                else
                    printf "${_WM_COLOR_YELLOW}  %-12s${_WM_COLOR_RESET}" "$name"
                fi
                printf " %s\n" "$cmd"
            done
    fi
}
