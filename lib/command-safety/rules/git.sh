#!/usr/bin/env bash
# =============================================================================
# ⚠️ GIT & GITHUB CLI RULES
# =============================================================================
# Safety rules for git operations and the GitHub CLI (gh).
# Disable: export COMMAND_SAFETY_DISABLE_GIT=true
# Special matching:
#   GIT_PUSH_FORCE - exempt="--force-with-lease" (safe force push)
#   MV_GIT         - context="git_repo" (only fires inside git repos)
#   RM_GIT         - context="git_repo" (only fires inside git repos)
# =============================================================================

# shellcheck disable=SC2034

# =============================================================================
# Git Core Operations
# =============================================================================

# --- git reset --hard ---
_rule GIT_RESET cmd="git" match="reset --hard" \
    block="Permanently destroys all uncommitted changes — cannot be undone" \
    bypass="--force-danger"

_fix GIT_RESET \
    "git stash           # Save changes temporarily" \
    "git checkout .      # Undo unstaged changes only" \
    "git restore <file>  # Restore specific file"

# --- git push --force ---
_rule GIT_PUSH_FORCE cmd="git" match="push --force|push -f" \
    block="Overwrites remote history — can destroy collaborators' work" \
    bypass="--force-allow" \
    exempt="--force-with-lease"

_fix GIT_PUSH_FORCE \
    "git push --force-with-lease  # Safer: checks remote first" \
    "gh pr merge --squash         # For PR merges"

# --- git rebase ---
_rule GIT_REBASE cmd="git" match="rebase" \
    block="Rewrites commit history — can cause conflicts on shared branches" \
    bypass="--force-danger"

_fix GIT_REBASE \
    "git merge <branch>  # Preserves history" \
    "git pull            # Auto-merge from remote"

# --- git clean -fd ---
_rule GIT_CLEAN cmd="git" match="clean -fd|clean -df" \
    block="Permanently removes ALL untracked files and directories" \
    bypass="--force-clean"

_fix GIT_CLEAN \
    "git clean -n     # Dry run — preview what will be deleted" \
    "git stash -u     # Stash untracked files instead of deleting"

# --- git clone ---
_rule GIT_CLONE cmd="git" match="clone" \
    block="Check if repository already exists locally before cloning" \
    bypass="--force-clone"

_fix GIT_CLONE \
    "cd <existing-dir> && git pull  # If already cloned" \
    "gh repo clone <repo>            # GitHub CLI alternative"

# --- git init ---
_rule GIT_INIT cmd="git" match="init" \
    block="Check for existing git repo — nested repos cause problems" \
    bypass="--force-init"

# --- git stash ---
_rule GIT_STASH cmd="git" match="stash" \
    block="Stashed changes are easily forgotten — consider committing instead" \
    bypass="--force-stash"

_fix GIT_STASH \
    "git commit -m 'WIP'       # Commit work-in-progress instead" \
    "git checkout -b <feature>  # Create feature branch for work"

# --- git branch -D ---
_rule GIT_BRANCH_D cmd="git" match="branch -D|branch --delete --force" \
    block="Force deletes branch without checking if commits are merged" \
    bypass="--force-branch-delete"

_fix GIT_BRANCH_D \
    "git branch -d <branch>  # Safe delete — checks merge status first" \
    "git merge <branch>      # Merge before deleting"

# --- git checkout -f ---
_rule GIT_CHECKOUT_F cmd="git" match="checkout -f|checkout --force" \
    block="Discards all local changes and switches branches" \
    bypass="--force-checkout"

_fix GIT_CHECKOUT_F \
    "git stash              # Save changes first" \
    "git checkout <branch>  # Normal checkout (preserves changes)"

# --- git cherry-pick --abort ---
_rule GIT_CHERRY_PICK_ABORT cmd="git" match="cherry-pick --abort" \
    block="Aborts cherry-pick operation — in-progress work may be lost" \
    bypass="--force-cherry-pick-abort"

_fix GIT_CHERRY_PICK_ABORT \
    "git cherry-pick --continue  # Resolve conflicts and continue" \
    "git cherry-pick --skip      # Skip this commit only"

# =============================================================================
# Agent Safety Rules — Protect Main Branch & Remote State
# =============================================================================
# These rules prevent AI agents (or hasty humans) from bypassing PR workflow.
# Protected branches: COMMAND_SAFETY_PROTECTED_BRANCHES (default: "main master")
# Bypass all: add the per-rule --force-* flag to the command.
# Bypass all agent-safety rules: export COMMAND_SAFETY_DISABLE_AGENT_SAFETY=true
#   (same as setting COMMAND_SAFETY_DISABLE_GIT=true but scoped)
# =============================================================================

# --- Helper: check if a branch name is in the protected list ---
# Usage: _cs_is_protected_branch "main"
# Reads: COMMAND_SAFETY_PROTECTED_BRANCHES (space-separated, default "main master")
_cs_is_protected_branch() {
    local name="$1"
    local b
    for b in ${COMMAND_SAFETY_PROTECTED_BRANCHES:-main master}; do
        [[ "$name" == "$b" ]] && return 0
    done
    return 1
}

# --- match_fn: detect push to a protected branch in all refspec forms ---
# Handles: git push origin main / git push origin HEAD:main /
#          git push origin feature:main / git push origin +main /
#          git push (bare on main) / git push origin (on main)
_cs_match_push_to_main() {
    # Only relevant for the push subcommand
    local _found_push=false
    local _a
    for _a in "$@"; do [[ "$_a" == "push" ]] && { _found_push=true; break; }; done
    [[ "$_found_push" == false ]] && return 1

    # If this is a deletion command, defer to GIT_PUSH_DELETE_REMOTE
    local _da
    for _da in "$@"; do
        [[ "$_da" == "--delete" || "$_da" == "-d" ]] && return 1
        [[ "$_da" == :?* ]] && return 1  # colon-prefix refspec = delete
    done

    local found_refspec=false
    local a dest current_branch
    for a in "$@"; do
        [[ "$a" == "push" ]] && continue
        [[ "$a" == --* ]] && continue
        [[ "$a" =~ ^-[a-zA-Z]$ ]] && continue   # single-char flag like -u, -v

        local spec="${a#+}"  # strip force-push prefix (+)

        if [[ "$spec" == *:* ]]; then
            # Refspec with explicit destination (src:dst or :dst)
            dest="${spec##*:}"
            dest="${dest#refs/heads/}"
            found_refspec=true
            # HEAD as destination resolves to current branch
            if [[ "$dest" == "HEAD" ]]; then
                current_branch=$(git symbolic-ref --short HEAD 2>/dev/null) || continue
                dest="$current_branch"
            fi
            [[ -n "$dest" ]] && _cs_is_protected_branch "$dest" && return 0
        else
            dest="${spec#refs/heads/}"
            # HEAD arg resolves to current branch
            if [[ "$dest" == "HEAD" ]]; then
                current_branch=$(git symbolic-ref --short HEAD 2>/dev/null) || continue
                dest="$current_branch"
                found_refspec=true
                _cs_is_protected_branch "$dest" && return 0
                continue
            fi
            # Simple name: could be remote OR branch — only flag if it's protected
            if _cs_is_protected_branch "$dest"; then
                found_refspec=true
                return 0
            fi
        fi
    done

    # No explicit refspec — bare push uses tracking branch; check current branch
    if [[ "$found_refspec" == false ]]; then
        current_branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return 1
        _cs_is_protected_branch "$current_branch" && return 0
    fi

    return 1
}

# --- match_fn: detect remote branch deletion ---
# Handles: git push --delete origin branch / git push origin :branch
_cs_match_push_delete_remote() {
    local a
    for a in "$@"; do
        [[ "$a" == "--delete" || "$a" == "-d" ]] && return 0
        # Colon-prefix refspec = delete (e.g. :feature-branch)
        [[ "$a" == :?* ]] && return 0
    done
    return 1
}

# --- match_fn: detect merge while currently on a protected branch ---
# Excludes: --abort, --continue, --quit (those are resolution commands, not new merges)
_cs_match_merge_on_main() {
    # Only relevant for the merge subcommand
    local _found_merge=false
    local _a
    for _a in "$@"; do [[ "$_a" == "merge" ]] && { _found_merge=true; break; }; done
    [[ "$_found_merge" == false ]] && return 1

    # First check we're on a protected branch
    local current_branch
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return 1
    _cs_is_protected_branch "$current_branch" || return 1

    # Exclude resolution subcommands — they're undoing a merge, not starting one
    local a
    for a in "$@"; do
        [[ "$a" == "--abort" || "$a" == "--continue" || "$a" == "--quit" ]] && return 1
    done

    # Any other git merge while on protected branch = dangerous
    return 0
}

# --- GIT_PUSH_MAIN: block direct push to main/master ---
_rule GIT_PUSH_MAIN cmd="git" \
    match_fn="_cs_match_push_to_main" \
    block="Direct push to main/master bypasses PR review — use a branch and PR" \
    bypass="--force-push-main"

_fix GIT_PUSH_MAIN \
    "gh pr create                    # Open a pull request from current branch" \
    "git push origin HEAD            # Push current branch (not main)"

# --- GIT_PUSH_DELETE_REMOTE: block remote branch deletion ---
_rule GIT_PUSH_DELETE_REMOTE cmd="git" \
    match_fn="_cs_match_push_delete_remote" \
    block="Permanently deletes a remote branch — verify the branch is merged first" \
    bypass="--force-remote-delete"

_fix GIT_PUSH_DELETE_REMOTE \
    "git branch --merged main        # Check if branch is already merged" \
    "gh pr view <number>             # Confirm PR was merged before deleting"

# --- GIT_PUSH_ALL_BRANCHES: block push --all and push --mirror ---
_rule GIT_PUSH_ALL_BRANCHES cmd="git" match="push --all|push --mirror" \
    block="Pushes ALL branches (including main) to remote — use targeted pushes instead" \
    bypass="--force-push-all"

_fix GIT_PUSH_ALL_BRANCHES \
    "git push origin <branch>  # Push specific branch only"

# --- GIT_MERGE_ON_MAIN: block git merge while on a protected branch ---
_rule GIT_MERGE_ON_MAIN cmd="git" \
    match_fn="_cs_match_merge_on_main" \
    block="Merging directly into main/master bypasses PR review" \
    bypass="--force-merge-main"

_fix GIT_MERGE_ON_MAIN \
    "git checkout -b <feature>   # Work on a feature branch instead" \
    "gh pr create                # Open a PR from your feature branch"

# --- mv in git repo (info only) ---
_rule MV_GIT cmd="mv" context="git_repo" \
    info="Use git mv to preserve file history in the repository"

_fix MV_GIT \
    "git mv <src> <dst>  # Preserves git history"

# --- rm in git repo (info only) ---
_rule RM_GIT cmd="rm" context="git_repo" \
    info="Use git rm to preserve file tracking in the repository"

_fix RM_GIT \
    "git rm <file>  # Removes and stages deletion"

# =============================================================================
# GitHub CLI (gh)
# =============================================================================

# --- gh repo create ---
_rule GH_REPO_CREATE cmd="gh" match="repo create" \
    block="Verify repo doesn't already exist and flags are correct before creating" \
    bypass="--force-create" \
    emoji="⚠️"

# --- gh repo delete ---
_rule GH_REPO_DELETE cmd="gh" match="repo delete" \
    block="Permanently deletes the entire GitHub repository — irreversible" \
    bypass="--force-repo-delete"

_fix GH_REPO_DELETE \
    "gh repo archive <repo>  # Archive instead of deleting"

# --- gh release delete ---
_rule GH_RELEASE_DELETE cmd="gh" match="release delete" \
    block="Deleting releases breaks existing workflows and download links" \
    bypass="--force-release-delete"

_fix GH_RELEASE_DELETE \
    "gh release create <new-tag>  # Create new release instead" \
    "gh release edit <tag>        # Update existing release"
