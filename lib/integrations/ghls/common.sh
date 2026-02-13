#!/usr/bin/env bash
# =============================================================================
# GHLS Common Functions
# =============================================================================
# Shared logic for git status display across status.sh and statusline.sh
# =============================================================================

# Load custom project colors from config/personal.env (GHLS_PROJECT_N entries)
# Populates _GHLS_CUSTOM_PROJECTS associative array: name -> "emoji|bg|fg"
# shellcheck disable=SC2034  # associative array used by _ghls_get_dir_colors
_ghls_load_custom_projects() {
    # Only load once
    [[ -n "${_GHLS_PROJECTS_LOADED:-}" ]] && return 0
    _GHLS_PROJECTS_LOADED=1

    declare -gA _GHLS_CUSTOM_PROJECTS

    local config_file="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/config/personal.env"
    [[ -f "$config_file" ]] || return 0

    local line key value name emoji bg fg
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        # Match GHLS_PROJECT_N="name|emoji|bg|fg"
        if [[ "$line" =~ ^GHLS_PROJECT_[0-9]+=[\"\']?([^\"\']+)[\"\']?$ ]]; then
            value="${BASH_REMATCH[1]}"
            IFS='|' read -r name emoji bg fg <<< "$value"
            if [[ -n "$name" && -n "$emoji" ]]; then
                local name_lower="${name,,}"
                _GHLS_CUSTOM_PROJECTS["$name_lower"]="${emoji}|${bg:-94}|${fg:-255}"
            fi
        fi
    done < "$config_file"
}

# Get directory emoji and colors based on folder name
# Usage: _ghls_get_dir_colors "folder_name" -> sets EMOJI, BG_COLOR, FG_COLOR
# Output variables: EMOJI, BG_COLOR, FG_COLOR (set as global for caller)
# shellcheck disable=SC2034  # EMOJI/BG_COLOR/FG_COLOR are intentionally global for callers
_ghls_get_dir_colors() {
    local folder_name="$1"
    local folder_lower=${folder_name,,}

    # Load custom projects on first call
    _ghls_load_custom_projects

    # Check custom project config first
    if [[ -n "${_GHLS_CUSTOM_PROJECTS[$folder_lower]+x}" ]]; then
        local config="${_GHLS_CUSTOM_PROJECTS[$folder_lower]}"
        IFS='|' read -r EMOJI _bg _fg <<< "$config"
        BG_COLOR="\033[48;5;${_bg}m"
        FG_COLOR="\033[38;5;${_fg}m"
        return 0
    fi

    # Built-in: shell-config itself
    case "$folder_lower" in
        "shell-config")
            EMOJI='🔧'
            BG_COLOR='\033[48;5;94m'
            FG_COLOR='\033[38;5;255m'
            ;;
        *)
            # Universal auto-detection based on project files
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
            else
                BG_COLOR='\033[48;5;94m'
            fi
            FG_COLOR='\033[38;5;255m'
            ;;
    esac
}

# Get branch emoji based on branch and PR status
# Usage: _ghls_get_branch_emoji "branch_name" has_pr -> sets branch_emoji
# Output variable: branch_emoji (set as global for caller)
# shellcheck disable=SC2034  # branch_emoji is intentionally global for callers
_ghls_get_branch_emoji() {
    local branch="$1"
    local has_pr="$2"

    if [[ "$has_pr" == "true" ]]; then
        branch_emoji="📬"
    elif [[ "$branch" == "main" || "$branch" == "master" ]]; then
        branch_emoji="🏠"
    else
        branch_emoji="🌿"
    fi
}

# Parse git status and return file counts
# Usage: _ghls_parse_git_status "git_status_output" -> echoes "staged working untracked"
# Git status format: XY filename
#   X = staged status (space if clean)
#   Y = working tree status (space if clean)
_ghls_parse_git_status() {
    local git_status="$1"

    local staged_files=0 working_files=0 untracked_files=0
    while IFS= read -r line; do
        # Skip branch line that starts with ##
        [[ "$line" =~ ^## ]] && continue

        # Parse git status XY format
        local index_status="${line:0:1}"
        local work_tree_status="${line:1:1}"

        # Untracked files show as ??
        if [[ "$index_status" == "?" && "$work_tree_status" == "?" ]]; then
            ((untracked_files++))
            continue
        fi

        # Staged changes: X in [AMDRC]
        if [[ "$index_status" != " " && "$index_status" != "?" ]]; then
            ((staged_files++))
        fi

        # Working tree changes: Y in [AMDRC]
        if [[ "$work_tree_status" != " " && "$work_tree_status" != "?" ]]; then
            ((working_files++))
        fi
    done <<<"$git_status"

    echo "$staged_files $working_files $untracked_files"
}
