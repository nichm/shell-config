#!/usr/bin/env bash
# =============================================================================
# autocomplete-guide.sh - Shell autocomplete tools guide and status
# =============================================================================
# Displays status and usage information for shell autocomplete tools
# including fzf, zsh-autosuggestions, zsh-syntax-highlighting, and
# inshellisense. Shows what's installed and provides quick reference
# for keyboard shortcuts.
# Dependencies:
#   - welcome/colors.sh - For color variables
#   - welcome/terminal-status.sh - For tool status checks
# Environment Variables:
#   WELCOME_AUTOCOMPLETE_GUIDE - Enable/disable display (default: true)
#   SHELL_CONFIG_DIR - Shell config installation directory
#   _AC_*_LOADED - Tool status flags (from terminal-status.sh)
# Features:
#   - Shows installation status of autocomplete tools
#   - Displays keyboard shortcuts (Ctrl+R, Ctrl+T, Tab)
#   - Links to full documentation (clickable in supported terminals)
#   - Color-coded status indicators
# Usage:
#   Source this file from welcome/main.sh - no direct usage needed
#   Controlled by WELCOME_AUTOCOMPLETE_GUIDE environment variable
# =============================================================================

: "${WELCOME_AUTOCOMPLETE_GUIDE:=${SHELL_CONFIG_AUTOCOMPLETE_GUIDE:-true}}"
[[ -z "${_WM_COLOR_RESET:-}" ]] && return 1

_welcome_show_autocomplete_guide() {
    [[ "$WELCOME_AUTOCOMPLETE_GUIDE" != "true" ]] && return 0

    local config_dir="${SHELL_CONFIG_DIR:-$HOME/.shell-config}"
    local docs_dir="$config_dir/docs"
    local autocomplete_doc="$docs_dir/AUTOCOMPLETE-GUIDE.md"
    local terminal_doc="$docs_dir/TERMINAL-SETUP.md"

    # Header with link to full docs
    printf "\n${_WM_COLOR_BOLD}🔮 Autocomplete Guide${_WM_COLOR_RESET}"
    if [[ -f "$autocomplete_doc" ]]; then
        printf " "
        printf '\e]8;;cursor://file%s\e\\' "$autocomplete_doc"
        printf "📖"
        printf '\e]8;;\e\\'
    fi
    printf "\n"
    printf "${_WM_COLOR_GRAY}────────────────────────────────────────────${_WM_COLOR_RESET}\n"

    # Use exported verification results from terminal-status.sh
    local has_is="${_AC_IS_LOADED:-false}"
    local has_fzf="${_AC_FZF_LOADED:-false}"
    local has_suggest="${_AC_SUGGEST_LOADED:-false}"
    local has_syntax="${_AC_SYNTAX_LOADED:-false}"
    local has_claude="${_AC_CLAUDE_LOADED:-false}"

    local shown_any=false

    # IDE-style autocomplete (Inshellisense)
    if [[ "$has_is" == "true" ]]; then
        printf "${_WM_COLOR_GREEN}✓${_WM_COLOR_RESET} ${_WM_COLOR_BOLD}Inshellisense${_WM_COLOR_RESET} ${_WM_COLOR_DIM}(IDE-style completions for 600+ tools)${_WM_COLOR_RESET}\n"
        printf "    ${_WM_COLOR_GREEN}TAB${_WM_COLOR_RESET}         Show completions with descriptions\n"
        printf "    ${_WM_COLOR_GREEN}↑/↓${_WM_COLOR_RESET}         Navigate options\n"
        printf "    ${_WM_COLOR_GREEN}Enter${_WM_COLOR_RESET}       Select option\n"
        printf "    ${_WM_COLOR_GREEN}Esc${_WM_COLOR_RESET}         Close menu\n"
        printf "    ${_WM_COLOR_DIM}Try: git checkout ${_WM_COLOR_CYAN}<TAB>${_WM_COLOR_RESET}${_WM_COLOR_DIM}, docker run ${_WM_COLOR_CYAN}<TAB>${_WM_COLOR_RESET}${_WM_COLOR_DIM}, bun add ${_WM_COLOR_CYAN}<TAB>${_WM_COLOR_RESET}\n"
        printf "\n"
        shown_any=true
    fi

    # Fuzzy search (fzf)
    if [[ "$has_fzf" == "true" ]]; then
        printf "${_WM_COLOR_GREEN}✓${_WM_COLOR_RESET} "
        printf "${_WM_COLOR_BOLD}fzf${_WM_COLOR_RESET}"
        printf " ${_WM_COLOR_DIM}(fuzzy finder)${_WM_COLOR_RESET}\n"
        printf "    ${_WM_COLOR_GREEN}Ctrl+R${_WM_COLOR_RESET}      Search command history ${_WM_COLOR_DIM}(type to filter)${_WM_COLOR_RESET}\n"
        printf "    ${_WM_COLOR_GREEN}Ctrl+T${_WM_COLOR_RESET}      Search files ${_WM_COLOR_DIM}(inserts path)${_WM_COLOR_RESET}\n"
        printf "    ${_WM_COLOR_GREEN}Alt+C${_WM_COLOR_RESET}       Search & cd to directory\n"
        printf "    ${_WM_COLOR_DIM}In fzf: ↑/↓ navigate, Enter select, Esc cancel${_WM_COLOR_RESET}\n"
        printf "\n"
        shown_any=true
    fi

    # Autosuggestions
    local suggest_dir="$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    local suggest_readme="$suggest_dir/README.md"
    if [[ "$has_suggest" == "true" ]]; then
        printf "${_WM_COLOR_GREEN}✓${_WM_COLOR_RESET} "
        printf '\e]8;;cursor://file%s\e\\' "$suggest_dir"
        printf "${_WM_COLOR_BOLD}Autosuggestions${_WM_COLOR_RESET}"
        printf '\e]8;;\e\\'
        if [[ -f "$suggest_readme" ]]; then
            printf " "
            printf '\e]8;;cursor://file%s\e\\' "$suggest_readme"
            printf "📖"
            printf '\e]8;;\e\\'
        fi
        printf " ${_WM_COLOR_DIM}(fish-like suggestions)${_WM_COLOR_RESET}\n"
        printf "    ${_WM_COLOR_GREEN}→${_WM_COLOR_RESET}           Accept full suggestion ${_WM_COLOR_DIM}(gray text)${_WM_COLOR_RESET}\n"
        printf "    ${_WM_COLOR_GREEN}Ctrl+→${_WM_COLOR_RESET}      Accept next word\n"
        printf "    ${_WM_COLOR_GREEN}Ctrl+E${_WM_COLOR_RESET}      Accept to end of line\n"
        printf "\n"
        shown_any=true
    elif [[ -d "$suggest_dir" ]]; then
        printf "${_WM_COLOR_YELLOW}?${_WM_COLOR_RESET} ${_WM_COLOR_BOLD}Autosuggestions${_WM_COLOR_RESET} ${_WM_COLOR_DIM}(installed, verify with new terminal)${_WM_COLOR_RESET}\n"
        printf "    ${_WM_COLOR_GREEN}→${_WM_COLOR_RESET}           Accept full suggestion ${_WM_COLOR_DIM}(gray text)${_WM_COLOR_RESET}\n"
        printf "    ${_WM_COLOR_GREEN}Ctrl+→${_WM_COLOR_RESET}      Accept next word\n"
        printf "    ${_WM_COLOR_GREEN}Ctrl+E${_WM_COLOR_RESET}      Accept to end of line\n"
        printf "\n"
        shown_any=true
    fi

    # Syntax highlighting
    local syntax_dir="$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    local syntax_readme="$syntax_dir/README.md"
    if [[ "$has_syntax" == "true" ]]; then
        printf "${_WM_COLOR_GREEN}✓${_WM_COLOR_RESET} "
        printf '\e]8;;cursor://file%s\e\\' "$syntax_dir"
        printf "${_WM_COLOR_BOLD}Syntax Highlighting${_WM_COLOR_RESET}"
        printf '\e]8;;\e\\'
        if [[ -f "$syntax_readme" ]]; then
            printf " "
            printf '\e]8;;cursor://file%s\e\\' "$syntax_readme"
            printf "📖"
            printf '\e]8;;\e\\'
        fi
        printf "\n"
        printf "    ${_WM_COLOR_GREEN}green${_WM_COLOR_RESET}       Valid command/path\n"
        printf "    ${_WM_COLOR_RED}red${_WM_COLOR_RESET}         Invalid/unknown command\n"
        printf "    ${_WM_COLOR_YELLOW}yellow${_WM_COLOR_RESET}      Alias or builtin\n"
        printf "    ${_WM_COLOR_CYAN}cyan${_WM_COLOR_RESET}        Quoted string\n"
        printf "\n"
        shown_any=true
    elif [[ -d "$syntax_dir" ]]; then
        printf "${_WM_COLOR_YELLOW}?${_WM_COLOR_RESET} ${_WM_COLOR_BOLD}Syntax Highlighting${_WM_COLOR_RESET} ${_WM_COLOR_DIM}(installed, verify with new terminal)${_WM_COLOR_RESET}\n"
        printf "    ${_WM_COLOR_GREEN}green${_WM_COLOR_RESET}       Valid command/path\n"
        printf "    ${_WM_COLOR_RED}red${_WM_COLOR_RESET}         Invalid/unknown command\n"
        printf "    ${_WM_COLOR_YELLOW}yellow${_WM_COLOR_RESET}      Alias or builtin\n"
        printf "\n"
        shown_any=true
    fi

    # Claude completion
    if [[ "$has_claude" == "true" ]]; then
        printf "${_WM_COLOR_GREEN}✓${_WM_COLOR_RESET} ${_WM_COLOR_BOLD}Claude CLI${_WM_COLOR_RESET}\n"
        printf "    ${_WM_COLOR_CYAN}claude ${_WM_COLOR_GREEN}<TAB>${_WM_COLOR_RESET}  Show subcommands\n"
        printf "    ${_WM_COLOR_DIM}clauded = claude --dangerously-skip-permissions${_WM_COLOR_RESET}\n"
        printf "\n"
        shown_any=true
    elif [[ -d "$HOME/.oh-my-zsh/custom/plugins/claudecode" ]]; then
        printf "${_WM_COLOR_YELLOW}?${_WM_COLOR_RESET} ${_WM_COLOR_BOLD}Claude CLI${_WM_COLOR_RESET} ${_WM_COLOR_DIM}(installed, not loaded)${_WM_COLOR_RESET}\n"
        printf "    ${_WM_COLOR_DIM}Add 'claudecode' to plugins in .zshrc${_WM_COLOR_RESET}\n"
        printf "\n"
        shown_any=true
    fi

    # If nothing installed, show install hint with doc link
    if ! $shown_any; then
        printf "  ${_WM_COLOR_YELLOW}⚠ Autocomplete tools not installed${_WM_COLOR_RESET}\n"
        printf "  ${_WM_COLOR_DIM}Run: "
        if [[ -f "$terminal_doc" ]]; then
            printf '\e]8;;cursor://file%s\e\\' "$terminal_doc"
        fi
        printf "${_WM_COLOR_CYAN}./shell-config/install.sh --terminal-only${_WM_COLOR_RESET}"
        if [[ -f "$terminal_doc" ]]; then
            printf '\e]8;;\e\\'
        fi
        printf "${_WM_COLOR_RESET}\n"
    fi
}
