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
