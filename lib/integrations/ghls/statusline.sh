#!/usr/bin/env bash
# =============================================================================
# 🐙 GIT STATUSLINE - Rich Status Display on Directory Change
# =============================================================================
# Shows full status bar (EXACT same format as ghls) for current git repo
# Automatically runs when you `cd` into a git repository
# =============================================================================

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Colors and formatting (EXACT copy from ghls)
# Use : ${var:=...} to avoid "read-only variable" error on re-source
: "${_SL_BOLD:=$'\033[1m'}"
: "${_SL_DIM:=$'\033[2m'}"
: "${_SL_RESET:=$'\033[0m'}"
: "${_SL_CYAN:=$'\033[38;5;39m'}"
: "${_SL_GREEN:=$'\033[38;5;34m'}"
: "${_SL_YELLOW:=$'\033[38;5;208m'}"
: "${_SL_BLUE:=$'\033[38;5;33m'}"

# Git colors (from ghls)
: "${_SL_BRANCH_COLOR_HAS_PR:=$'\033[38;5;34m'}"
: "${_SL_BRANCH_COLOR_NO_PR:=$'\033[38;5;208m'}"
: "${_SL_STAGED_COLOR:=$'\033[38;5;193m'}"
: "${_SL_UNTRACKED_COLOR:=$'\033[38;5;208m'}"
: "${_SL_COMMITTED_COLOR:=$'\033[38;5;147m'}"
: "${_SL_SEP_COLOR:=$'\033[38;5;245m'}"
: "${_SL_PHASE_SEP:=$'\033[38;5;240m'}"
: "${_SL_GREEN_ADD:=$'\033[38;5;34m'}"
: "${_SL_RED_DEL:=$'\033[38;5;196m'}"

# Check for GitHub CLI availability (lazy check - only verify command exists)
# Actual auth is checked lazily in git_statusline to avoid startup delay
SC_GH_AVAILABLE=false
if command_exists "gh"; then
    SC_GH_AVAILABLE=true
fi
export SC_GH_AVAILABLE

git_statusline() {
    # Only show if in a git repo
    git rev-parse --git-dir >/dev/null 2>&1 || return 0

    # Skip in non-interactive contexts (but allow if forced or PS1 is set)
    [[ -z "$PS1" ]] && [[ -z "$STATUSLINE_FORCE" ]] && return 0

    local folder_name
    folder_name=$(basename "$(git rev-parse --show-toplevel)")

    # Get directory colors (project-specific)
    local folder_lower
    # Cross-shell lowercase: bash uses ${var,,}, zsh uses ${(L)var}
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # shellcheck disable=SC2296  # zsh-specific lowercase expansion
        folder_lower="${(L)folder_name}"
    else
        folder_lower="${folder_name,,}"
    fi
    local EMOJI BG_COLOR FG_COLOR
    case "$folder_lower" in
        "shell-config")
            EMOJI='🔧'
            BG_COLOR='\033[48;5;94m'
            FG_COLOR='\033[38;5;255m'
            ;;
        *)
            EMOJI='📂'
            if [[ -f "package.json" ]]; then
                EMOJI='📦'
                BG_COLOR='\033[48;5;28m'
            elif [[ -f "Cargo.toml" ]]; then
                EMOJI='🦀'
                BG_COLOR='\033[48;5;208m'
            elif [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]]; then
                EMOJI='🐍'
                BG_COLOR='\033[48;5;26m'
            elif [[ -f "go.mod" ]]; then
                EMOJI='🐹'
                BG_COLOR='\033[48;5;39m'
            elif [[ -f "Dockerfile" ]]; then
                EMOJI='🐳'
                BG_COLOR='\033[48;5;24m'
            else BG_COLOR='\033[48;5;94m'; fi
            FG_COLOR='\033[38;5;255m'
            ;;
    esac

    # Get branch info
    local BRANCH
    BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

    # Initialize variables
    local total_prs=0 active_branches=0 stashed_changes=0
    local pr_display="$BRANCH"
    local has_current_branch_pr=false
    local branch_color="$_SL_BRANCH_COLOR_NO_PR"

    # Check if current branch has an open PR (only if gh is available and authenticated)
    # Skip the gh call to avoid slow API requests on every cd
    # Users can run 'gh pr view' manually if they need PR info

    # Get stashed changes - Bash 5 native space removal with read
    local stash_count
    read -r stash_count < <(git stash list 2>/dev/null | wc -l)
    stash_count=${stash_count:-0}
    stashed_changes="$stash_count"

    # Get active branches (excluding main/master)
    local branch_count
    branch_count=$(git branch --no-color 2>/dev/null | grep -cv -E '^\* main$|^\* master$' || echo "0")
    branch_count="${branch_count// /}" # Trim spaces
    active_branches="$branch_count"

    # Set branch emoji
    local branch_emoji
    if [[ $has_current_branch_pr == true ]]; then
        branch_emoji="📬"
    elif [[ $BRANCH == "main" || $BRANCH == "master" ]]; then
        branch_emoji="🏠"
    else
        branch_emoji="🌿"
    fi

    # Build full output
    local output="${_SL_BOLD}${BG_COLOR} ${EMOJI} ${FG_COLOR}${folder_name}${_SL_RESET}"

    # Status display
    local status_parts=()
    if [[ $total_prs -gt 0 ]]; then
        status_parts+=("◯${total_prs}PR")
    fi
    if [[ $active_branches -gt 0 ]]; then
        status_parts+=("${active_branches}⎇")
    fi
    if [[ $stashed_changes -gt 0 ]]; then
        status_parts+=("${stashed_changes}≡")
    fi

    if [[ ${#status_parts[@]} -gt 0 ]]; then
        local status_text=""
        local _sp
        for _sp in "${status_parts[@]}"; do
            [[ -n "$status_text" ]] && status_text+=" "
            status_text+="$_sp"
        done
        output+=" ${_SL_SEP_COLOR}[${status_text}]${_SL_RESET}"
    fi

    # Add branch info
    output+=" ${_SL_SEP_COLOR}${branch_emoji}${_SL_RESET} ${branch_color}[${pr_display}]${_SL_RESET}"

    # Git status parsing
    local GIT_STATUS
    GIT_STATUS=$(git status --porcelain=v1 -b 2>/dev/null || echo "")

    if [[ -z $GIT_STATUS ]]; then
        output+="  ${_SL_DIM}${_SL_SEP_COLOR}✓ clean${_SL_RESET}"
    else
        local staged_files=0 working_files=0 untracked_files=0
        while IFS= read -r line; do
            [[ "$line" =~ ^## ]] && continue
            case "${line:0:2}" in
                A? | M? | D? | R? | C?) ((staged_files++)) ;;
                \?\?) ((untracked_files++)) ;;
                *) [[ "${line:0:1}" != " " ]] && ((working_files++)) ;;
            esac
        done <<<"$GIT_STATUS"

        if [[ $staged_files -eq 0 && $working_files -eq 0 && $untracked_files -eq 0 ]]; then
            output+="  ${_SL_DIM}${_SL_SEP_COLOR}✓ clean${_SL_RESET}"
        else
            local changes_shown=false

            # Staged files
            if [[ $staged_files -gt 0 ]]; then
                output+=" S${_SL_RESET} ${_SL_STAGED_COLOR}[${staged_files}f]${_SL_RESET}"
                changes_shown=true
            fi

            # Untracked files
            if [[ $untracked_files -gt 0 ]]; then
                [[ $changes_shown == true ]] && output+=" ${_SL_PHASE_SEP}│${_SL_RESET}"
                output+=" U${_SL_RESET}${_SL_UNTRACKED_COLOR}[${untracked_files}f]${_SL_RESET}"
                changes_shown=true
            fi

            # Working files
            if [[ $working_files -gt 0 ]]; then
                [[ $changes_shown == true ]] && output+="${_SL_PHASE_SEP}│${_SL_RESET}"
                output+=" M${_SL_RESET}${_SL_SEP_COLOR}[${working_files}f]${_SL_RESET}"
            fi
        fi
    fi

    # Print output
    echo -e "${output}"
}

# Auto-run on directory change
_show_statusline_if_git() {
    [[ -t 1 ]] || return 0
    git rev-parse --git-dir >/dev/null 2>&1 || return 0
    git_statusline
}

# Register as zsh chpwd function
if [[ -n "${ZSH_VERSION:-}" ]]; then
    # Use ${chpwd_functions[@]:-} to avoid "parameter not set" errors with set -u
    # shellcheck disable=SC2206  # Zsh-specific array assignment syntax
    chpwd_functions=(${chpwd_functions[@]:-} _show_statusline_if_git)
    # Skip initial run on shell startup for faster load
    # _show_statusline_if_git
fi
