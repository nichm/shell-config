#!/usr/bin/env bash
# =============================================================================
# integrations/ghls/status.sh - Git repository status display
# =============================================================================
# Core function for getting enhanced folder status with PR info, branch
# tracking, and staged/unstaged file counts.
# Usage:
#   source "$GHLS_DIR/status.sh"
#   get_folder_status_enhanced "/path/to/repo"
# Dependencies:
#   - colors.sh must be sourced first
#   - temp_pr_file, temp_branch_file, temp_stash_file must be set
#   - SC_GH_AVAILABLE must be set
# =============================================================================

# External variables set by calling script
# shellcheck disable=SC2154

# Function to get folder statusline info (with pre-fetched data)
# Returns JSON-like format for easier processing
get_folder_status_enhanced() {
    local folder="$1"
    local original_pwd="$PWD"
    local folder_name="${folder#./}"

    cd "$folder" 2>/dev/null || return 1

    # Skip if not a git repo
    git rev-parse --git-dir >/dev/null 2>&1 || {
        cd "$original_pwd" || return 1
        echo "type=non-git|folder=$folder_name|display=📁 $folder_name"
        return 0
    }

    # Get directory colors (uses shared function from common.sh)
    local EMOJI BG_COLOR FG_COLOR
    _ghls_get_dir_colors "$folder_name"

    # Get branch info
    local BRANCH
    BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

    # Use pre-fetched data
    local total_prs=0 active_branches=0 stashed_changes=0
    local pr_display="$BRANCH" has_pr=false has_current_branch_pr=false
    local branch_color="$BRANCH_COLOR_NO_PR"

    if [[ $SC_GH_AVAILABLE == true && -f "$temp_pr_file" ]]; then
        # Get total PRs from our cached data - Bash 5 native string manipulation
        local pr_line branch_line stash_line tmp
        pr_line=$(grep "^$folder_name:" "$temp_pr_file" 2>/dev/null)
        tmp="${pr_line##*:}"
        total_prs="${tmp//[!0-9]/}"
        total_prs=${total_prs:-0}

        # Get active branches from our cached data - Bash 5 native string manipulation
        branch_line=$(grep "^$folder_name:" "$temp_branch_file" 2>/dev/null)
        tmp="${branch_line##*:}"
        active_branches="${tmp//[!0-9]/}"
        active_branches=${active_branches:-0}

        # Get stashed changes from our cached data - Bash 5 native string manipulation
        stash_line=$(grep "^$folder_name:" "$temp_stash_file" 2>/dev/null)
        tmp="${stash_line##*:}"
        stashed_changes="${tmp//[!0-9]/}"
        stashed_changes=${stashed_changes:-0}

        # Ensure all values are numbers
        [[ ! "$total_prs" =~ ^[0-9]+$ ]] && total_prs=0
        [[ ! "$active_branches" =~ ^[0-9]+$ ]] && active_branches=0
        [[ ! "$stashed_changes" =~ ^[0-9]+$ ]] && stashed_changes=0

        # Get current branch PR status
        if [[ "$total_prs" -gt 0 ]]; then
            # Get the remote URL and extract owner dynamically
            local remote_url owner actual_repo_name pr_number
            remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
            owner=""
            actual_repo_name="$folder_name"

            if [[ -n "$remote_url" && "$remote_url" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
                owner="${BASH_REMATCH[1]}"
                actual_repo_name=$(basename "${BASH_REMATCH[2]}" .git)
            else
                # Fallback: use GITHUB_ORG from personal config, or infer from gh CLI
                owner="${GITHUB_ORG:-}"
                if [[ -z "$owner" ]]; then
                    owner=$(gh api user -q .login 2>/dev/null || echo "")
                fi
                if [[ -z "$owner" ]]; then
                    cd "$original_pwd" || true
                    return 1
                fi
            fi

            pr_number=$(gh pr list --repo "$owner/$actual_repo_name" --head "$BRANCH" --json number --limit 1 --jq '.[0].number // ""' 2>/dev/null)

            # Fallback: try to get GitHub username from gh API
            if [[ -z "$pr_number" ]]; then
                local gh_username
                gh_username=$(gh api user -q .login 2>/dev/null || echo "")
                if [[ -n "$gh_username" && "$gh_username" != "$owner" ]]; then
                    pr_number=$(gh pr list --repo "$gh_username/$actual_repo_name" --head "$BRANCH" --json number --limit 1 --jq '.[0].number // ""' 2>/dev/null)
                fi
            fi

            # Validate pr_number is numeric before using it
            if [[ -n "$pr_number" ]] && [[ "$pr_number" =~ ^[0-9]+$ ]]; then
                pr_display="PR#${pr_number}:${BRANCH}"
                branch_color="$BRANCH_COLOR_HAS_PR"
                has_pr=true
                has_current_branch_pr=true
            fi
        fi
    fi

    # Set branch emoji
    local branch_emoji
    if [[ $has_current_branch_pr == true ]]; then
        branch_emoji="📬"
    elif [[ $BRANCH == "main" || $BRANCH == "master" ]]; then
        branch_emoji="🏠"
    else branch_emoji="🌿"; fi

    # Build full output (EXACT same as single-ghls.sh)
    local output="${BOLD}${BG_COLOR} ${EMOJI} ${FG_COLOR}${folder_name}${RESET}"

    # Enhanced status display with proper spacing (EXACT same as single-ghls.sh)
    local status_parts=()
    if [[ $total_prs -gt 0 ]]; then
        if [[ $total_prs -eq 1 ]]; then
            status_parts+=("◯1PR")
        else
            status_parts+=("◯${total_prs}PRs")
        fi
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
        output+=" ${SEP_COLOR}[${status_text}]${RESET}"
    fi

    # Add branch info (EXACT same as single-ghls.sh)
    output+=" ${SEP_COLOR}${branch_emoji}${RESET} ${branch_color}[${pr_display}]${RESET}"

    # Enhanced git status parsing (from single-ghls.sh)
    local GIT_STATUS is_clean=false
    GIT_STATUS=$(git status --porcelain=v1 -b 2>/dev/null || echo "")
    if [[ -z $GIT_STATUS ]]; then
        output+="  ${DIM}${SEP_COLOR}✓ clean${RESET}"
        is_clean=true
    else
        # Parse git status (enhanced parsing, skip branch line)
        local staged_files=0 working_files=0 untracked_files=0
        while IFS= read -r line; do
            # Skip branch line that starts with ##
            [[ "$line" =~ ^## ]] && continue

            case "${line:0:2}" in
                A? | M? | D? | R? | C?) ((staged_files++)) ;;
                \?\?) ((untracked_files++)) ;;
                *)
                    [[ "${line:0:1}" != " " ]] && ((working_files++))
                    ;;
            esac
        done <<<"$GIT_STATUS"

        # Early exit if no changes
        if [[ $staged_files -eq 0 && $working_files -eq 0 && $untracked_files -eq 0 ]]; then
            output+="  ${DIM}${SEP_COLOR}✓ clean${RESET}"
            is_clean=true
        else
            # 3-Phase Display (from single-ghls.sh)
            local changes_shown=false

            # Phase 1: Committed (if has PR)
            if [[ $has_current_branch_pr == true ]]; then
                local pr_base pr_stats pr_added pr_removed pr_files
                pr_base=$(gh pr view "$BRANCH" --json baseRefName -q '.baseRefName' 2>/dev/null || echo "main")
                pr_stats=$(git diff "${pr_base}...HEAD" --numstat 2>/dev/null)
                if [[ -n $pr_stats ]]; then
                    read -r pr_added pr_removed pr_files < <(echo "$pr_stats" | awk '
                    { add+=$1; del+=$2; files++ }
                    END { print add, del, files }
                    ')

                    output+=" ${PHASE_SEP}C${RESET}"
                    [[ $pr_added -gt 0 ]] && output+="${GREEN_ADD}+${pr_added}${RESET}"
                    [[ $pr_removed -gt 0 ]] && output+="${RED_DEL}-${pr_removed}${RESET}"
                    output+=" ${COMMITTED_COLOR}[${pr_files}f]${RESET}"
                    changes_shown=true
                fi
            fi

            # Phase 2: Staged
            if [[ $staged_files -gt 0 ]]; then
                local staged_added staged_removed
                read -r staged_added staged_removed < <(git diff --cached --numstat 2>/dev/null | awk '
                { add+=$1; del+=$2 }
                END { print add, del }
                ')
                [[ $changes_shown == true ]] && output+=" ${PHASE_SEP}│${RESET}"
                output+="S${RESET}"
                [[ $staged_added -gt 0 ]] && output+="${GREEN_ADD}+${staged_added}${RESET}"
                [[ $staged_removed -gt 0 ]] && output+="${RED_DEL}-${staged_removed}${RESET}"
                output+=" ${STAGED_COLOR}[${staged_files}f]${RESET}"
                changes_shown=true
            fi

            # Phase 3: Untracked
            if [[ $untracked_files -gt 0 ]]; then
                [[ $changes_shown == true ]] && output+=" ${PHASE_SEP}│${RESET}"
                output+="U${RESET}${UNTRACKED_COLOR}[${untracked_files}f]${RESET}"
                changes_shown=true
            fi

            # Phase 4: Working files
            if [[ $working_files -gt 0 ]]; then
                [[ $changes_shown == true ]] && output+="${PHASE_SEP}│${RESET}"
                output+="M${RESET}${SEP_COLOR}[${working_files}f]${RESET}"
            fi
        fi
    fi

    cd "$original_pwd" || return 1

    # Return structured data
    echo "type=git|folder=$folder_name|has_pr=$has_pr|total_prs=$total_prs|has_current_branch_pr=$has_current_branch_pr|is_clean=$is_clean|display=$output"
}
