#!/usr/bin/env bash
# =============================================================================
# SECURITY RULES ENGINE
# =============================================================================
# Provides security rule definitions and warning display functions.
# All security warnings for dangerous git operations are defined here.
# Rules include:
# - reset_hard: Destructive local changes deletion
# - push_force: Remote history overwriting
# - rebase: History rewriting and conflicts
# - clone_dup: Duplicate repository detection
# - deps_change: Dependency security warnings
# - large_file: Large file detection warnings
# NOTE: No set -euo pipefail — sourced by wrapper.sh into interactive shells
# =============================================================================

# Get security rule value by key and field
_get_rule_value() {
    local key="$1"
    local field="$2"
    case "$key:$field" in
        reset_hard:emoji) echo "🔴 DANGER" ;;
        reset_hard:desc) echo "PERMANENTLY deletes all uncommitted changes" ;;
        reset_hard:msg1) echo "Before proceeding, consider:" ;;
        reset_hard:msg2) echo "  • git stash - 'git stash' to save changes temporarily" ;;
        reset_hard:msg3) echo "  • git checkout - 'git checkout .' to undo unstaged file changes" ;;
        reset_hard:msg4) echo "  • git restore - 'git restore <file>' to restore specific files" ;;
        reset_hard:msg5) echo "  • git diff - 'git diff' to see what would be lost" ;;
        reset_hard:bypass) echo "--force-danger" ;;
        push_force:emoji) echo "🔴 DANGER" ;;
        push_force:desc) echo "Can OVERWRITE other collaborators' work" ;;
        push_force:msg1) echo "• Use '--force-with-lease' instead - it's safer and checks if remote changed" ;;
        push_force:msg2) echo "• This command rewrites history and makes commits inaccessible for others" ;;
        push_force:alt1) echo "git push --force-with-lease  (recommended - checks remote first)" ;;
        push_force:alt2) echo "gh pr merge --squash         (use gh for pull request merges)" ;;
        push_force:bypass) echo "--force-allow" ;;
        rebase:emoji) echo "🟡 WARNING" ;;
        rebase:desc) echo "Can cause conflicts and rewrite history" ;;
        rebase:msg1) echo "Before rebasing:" ;;
        rebase:msg2) echo "  • Ensure your branch is up-to-date: git pull" ;;
        rebase:msg3) echo "  • Consider alternatives like merge commits" ;;
        rebase:msg4) echo "  • Check if you're on a shared branch (rebasing shared history is dangerous)" ;;
        rebase:bypass) echo "--force-danger" ;;
        clone_dup:emoji) echo "🔴 ERROR" ;;
        clone_dup:desc) echo "Repository already exists in ~/github" ;;
        clone_dup:msg1) echo "Please check this existing repository before cloning:" ;;
        clone_dup:msg2) echo "  cd '<repo_path>'" ;;
        clone_dup:msg3) echo "  git fetch origin" ;;
        clone_dup:msg4) echo "  git status" ;;
        clone_dup:bypass) echo "--force-allow" ;;
        deps_change:emoji) echo "⚠️ DEPENDENCIES" ;;
        deps_change:desc) echo "Committing dependency changes - potential security risk" ;;
        deps_change:msg1) echo "• 440,000+ AI-hallucinated packages exist (slopsquatting attacks)" ;;
        deps_change:msg2) echo "• Run: bun audit or cargo audit before committing" ;;
        deps_change:bypass) echo "--skip-deps-check" ;;
        large_file:emoji) echo "📦 LARGE FILE" ;;
        large_file:desc) echo "Committing file(s) of 5MB or larger" ;;
        large_file:msg1) echo "• Large files bloat repository size and slow down clones" ;;
        large_file:msg2) echo "• Consider using Git LFS for binaries, assets, and large data files" ;;
        large_file:msg3) echo "• Learn more: https://git-lfs.github.com/" ;;
        large_file:bypass) echo "--allow-large-files" ;;
        *) echo "" ;;
    esac
}

# Display security warning for a given rule base
_show_warning() {
    local base="$1"
    local emoji desc bypass
    emoji="$(_get_rule_value "$base" emoji)"
    desc="$(_get_rule_value "$base" desc)"
    bypass="$(_get_rule_value "$base" bypass)"

    echo "" >&2
    echo "$emoji: $desc" >&2
    echo "" >&2

    # Declare loop variables BEFORE loops to prevent zsh re-declaration output
    local i=1 msg="" j alt
    while true; do
        msg="$(_get_rule_value "$base" msg$i)"
        [[ -z "$msg" ]] && break
        echo "$msg" >&2
        : $((i++))
    done

    j=1
    while true; do
        alt="$(_get_rule_value "$base" alt$j)"
        [[ -z "$alt" ]] && break
        [[ $j -eq 1 ]] && echo "" >&2 && echo "💡 Alternative commands:" >&2
        echo "  $alt" >&2
        : $((j++))
    done

    if [[ -n "$bypass" ]]; then
        echo "" >&2
        echo "🔓 Use '$bypass' to bypass this safety check" >&2
    fi
}
