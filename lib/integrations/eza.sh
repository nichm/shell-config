#!/usr/bin/env bash
# =============================================================================
# eza.sh - Modern ls replacement with git integration and AI helpers
# =============================================================================
# Provides eza as a modern replacement for ls with git status, icons,
# and tree views. Includes AI/agent-friendly file tree helpers for
# code analysis and context gathering.
# Dependencies:
#   - eza - Install: brew install eza
#   - tree (optional) - For JSON tree output
# Aliases:
#   ls    - Basic eza (replaces system ls)
#   l     - Long format, directories first
#   ll    - Long format, git status, icons
#   la    - All files (including hidden), git status
#   lt    - Tree view (2 levels deep)
#   lsize - Sort by file size (largest first)
#   ldate - Sort by modified date (newest first)
# AI/Agent Helpers:
#   ai-tree [depth] - JSON tree output (3 levels default)
#   ai-context [depth] - Optimized tree for AI context
#   tree-json - Fixed JSON tree (3 levels, ignores common dirs)
# Usage:
#   Source this file from shell init - aliases available immediately
#   Use ls, ll, lt for listing; ai-tree for AI context
# =============================================================================

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

if command_exists "eza"; then
    alias ls="eza" l="eza -l --group-directories-first"
    alias ll="eza -la --git --group-directories-first --icons" la="eza -la --git --group-directories-first"
    alias lt="eza --tree --level=2 --icons --git-ignore"
    alias lsize="eza -la --sort=size --reverse" ldate="eza -la --sort=modified --reverse"
else
    [[ -z "${EZA_WARNING_SHOWN:-}" ]] && {
        echo "⚠️  eza not found. Install: brew install eza" >&2
        export EZA_WARNING_SHOWN=1
    }
fi

# AI/Agent file tree helpers: ai-tree [depth], ai-context [depth], tree-json
if command_exists "tree"; then
    alias tree-json="tree -J -L 3 -I 'node_modules|.git|dist|build|.next|target'"
    ai-tree() {
        local depth="${1:-3}"
        [[ "$depth" =~ ^[0-9]+$ ]] && [[ "$depth" -ge 1 ]] || {
            echo "Error: depth must be positive integer" >&2
            return 1
        }
        tree -J -L "$depth" -I 'node_modules|.git|dist|build|.next|target' 2>/dev/null \
            || eza --tree --level="$depth" --git-ignore 2>/dev/null \
            || find . -maxdepth "$depth" -type f -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -100
    }
    ai-context() {
        local depth="${1:-3}"
        [[ "$depth" =~ ^[0-9]+$ ]] && [[ "$depth" -ge 1 ]] || {
            echo "Error: depth must be positive integer" >&2
            return 1
        }
        echo "📁 Repository: $(basename "$(pwd)")"
        echo "🌿 Branch: $(git branch --show-current 2>/dev/null || echo "main")"
        echo "📝 Recent Changes" && git log --oneline -10 2>/dev/null || echo "No recent changes"
        echo -e "\n📂 File Structure" && ai-tree "$depth"
    }
elif command_exists "eza"; then
    ai-tree() {
        local depth="${1:-3}"
        [[ "$depth" =~ ^[0-9]+$ ]] && [[ "$depth" -ge 1 ]] || {
            echo "Error: depth must be positive integer" >&2
            return 1
        }
        eza --tree --level="$depth" --git-ignore
    }
    ai-context() {
        echo "⚠️  tree not found. Using eza fallback..."
        ai-tree "$@"
    }
else
    ai-tree() { find . -maxdepth "${1:-3}" -type f -not -path '*/node_modules/*' 2>/dev/null | head -100; }
    ai-context() {
        echo "⚠️  Neither tree nor eza available"
        ai-tree "$@"
    }
fi
