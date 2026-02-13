#!/usr/bin/env bash
# =============================================================================
# fzf.sh - Fuzzy finder integration for terminal productivity
# =============================================================================
# Provides fuzzy finding functions for files, directories, command history,
# git operations, and process management. Requires fzf to be installed.
# Dependencies:
#   - fzf - Install: brew install fzf
#   - fd (recommended) - Install: brew install fd
#   - git (for fbr, fstash functions)
# Functions:
#   fe    - Fuzzy file editor (opens selected file in $EDITOR)
#   fcd   - Fuzzy directory changer (cd to selected directory)
#   fh    - Fuzzy command history search (search and execute from history)
#   fkill - Fuzzy process killer (select and kill processes)
#   fbr   - Fuzzy git branch checkout
#   fstash - Fuzzy git stash management
# Usage:
#   Source this file from shell init - functions available immediately
#   Use fe to fuzzy edit files, fcd to fuzzy change directories, etc.
# =============================================================================

# Load command cache for optimized tool checking
if [[ -f "$SHELL_CONFIG_DIR/lib/core/command-cache.sh" ]]; then
    source "$SHELL_CONFIG_DIR/lib/core/command-cache.sh"
fi

# Check if fzf is installed
if ! command_exists "fzf"; then
    [[ -z "${FZF_WARNING_SHOWN:-}" ]] && {
        echo "⚠️  fzf not found. Install: brew install fzf" >&2
        export FZF_WARNING_SHOWN=1
    }
    return 0
fi

# =============================================================================
# FUZZY FILE EDITOR (fe)
# =============================================================================
# Opens selected file in $EDITOR (or vi if not set)
# Usage: fe [path]
fe() {
    local files
    local base_path="${1:-.}"

    # Check if fd is available for better file finding
    if command_exists "fd"; then
        files=$(fd --type f --hidden --follow --exclude .git --exclude node_modules . "$base_path" | fzf -m --preview 'bat --color=always {} 2>/dev/null || cat {}' | tr '\n' ' ')
    else
        files=$(find "$base_path" -type f 2>/dev/null | fzf -m | tr '\n' ' ')
    fi

    [[ -n "$files" ]] && ${EDITOR:-vi} $files
}

# =============================================================================
# FUZZY DIRECTORY CHANGER (fcd)
# =============================================================================
# Changes to selected directory using fuzzy search
# Usage: fcd [path]
fcd() {
    local dir
    local base_path="${1:-.}"

    # Check if fd is available for better directory finding
    if command_exists "fd"; then
        dir=$(fd --type d --hidden --follow --exclude .git . "$base_path" | fzf)
    else
        dir=$(find "$base_path" -type d 2>/dev/null | fzf)
    fi

    [[ -n "$dir" ]] && cd "$dir" || return 1
}

# =============================================================================
# FUZZY COMMAND HISTORY (fh)
# =============================================================================
# Searches command history and executes selected command
# Usage: fh
fh() {
    local cmd
    if [[ -n "$ZSH_NAME" ]]; then
        cmd=$(fc -l 1 | fzf +s --tac | sed 's/ *\([0-9]*\).*/\1/' | sed 's/^ *[0-9]* *//')
    else
        cmd=$(history | fzf +s --tac | sed 's/^ *[0-9]* *//')
    fi
    [[ -n "$cmd" ]] && print -z "$cmd"  # Put in command buffer for editing
}

# =============================================================================
# FUZZY PROCESS KILLER (fkill)
# =============================================================================
# Interactively select and kill processes
# Usage: fkill
fkill() {
    local pid
    pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')

    if [[ -n "$pid" ]]; then
        echo "$pid" | xargs kill -9
        echo "Killed: $pid"
    fi
}

# =============================================================================
# FUZZY GIT BRANCH CHECKOUT (fbr)
# =============================================================================
# Fuzzy search and checkout git branch
# Usage: fbr
fbr() {
    local branches branch
    branches=$(git branch -a) &&
    branch=$(echo "$branches" | fzf -d $'\t' +m --preview 'git log --oneline --graph --date=short $(echo {} | sed "s/.* //")' |
        sed "s/.* //" | sed "s#remotes/[^/]*/##") &&
    git checkout "$branch"
}

# =============================================================================
# FUZZY GIT STASH MANAGEMENT (fstash)
# =============================================================================
# View and apply git stashes
# Usage: fstash
fstash() {
    local out q k sha
    while out=$(
        git stash list | fzf --preview 'git stash show -p $(echo {} | cut -d: -f1)' \
            --query="$q" --exit-0 --expect=ctrl-d);
    do
        # Cross-shell: mapfile is bash-only, zsh uses ${(@f)var} for line splitting
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            # shellcheck disable=SC2296  # zsh-specific line splitting expansion
            out=("${(@f)out}")
            q="${out[1]}"
            k="${out[2]}"
            sha="${out[*]:3}"
        else
            # shellcheck disable=SC2128  # $out is scalar here, converted to array by mapfile
            mapfile -t out <<< "$out"
            q="${out[0]}"
            k="${out[1]}"
            sha="${out[*]:(2)}"
        fi
        sha="${sha%% *}"
        [[ -z "$sha" ]] && continue
        if [[ "$k" == 'ctrl-d' ]]; then
            git diff "$sha"
        else
            git stash show -p "$sha"
        fi
        q=
    done
}
