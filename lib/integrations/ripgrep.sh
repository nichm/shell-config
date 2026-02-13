#!/usr/bin/env bash
# =============================================================================
# ripgrep.sh - Ripgrep aliases and AI-optimized code search helpers
# =============================================================================
# Provides aliases and functions for enhanced code searching with ripgrep.
# Includes type-specific search, AI agent helpers, and benchmarking tools.
# Requires ripgrep to be installed via Homebrew.
# Dependencies:
#   - ripgrep (rg) - Install: brew install ripgrep
#   - Optional: config/ripgreprc - Link: ln -s ~/.shell-config/config/ripgreprc ~/.ripgreprc
# Core Aliases:
#   rg   - Pretty output (default)
#   rgi  - Case-insensitive search
#   rgl  - Files with matches only
#   rgf  - List files
#   rgc  - Show 3 lines context
#   rgs  - Search statistics
# Type-Specific Search:
#   rgcode  - Search web files (js, ts, jsx, tsx, vue, svelte)
#   rgtest   - Search test files
#   rgconfig - Search config files (json, yaml, toml, ini)
#   rgdocs   - Search documentation (md, mdx, txt, rst)
#   rgsh     - Search shell scripts (sh, bash, zsh, fish)
# AI Agent Helpers:
#   rgfunc   - Find function definitions
#   rgimport - Find import statements
#   rgtodo   - Find TODO/FIXME/HACK comments
#   rgapi    - Find API endpoints and calls
# Usage:
#   Source this file from shell init - automatically available if rg is installed
#   Functions available as commands: rgcode "pattern", rgfunc "name", etc.
# =============================================================================

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

if command_exists "rg"; then
    # Core aliases
    # shellcheck disable=SC2262  # Aliases are defined for interactive use in new shells
    alias rg='rg --pretty' rgi='rg --ignore-case' rgl='rg --files-with-matches'
    alias rgf='rg --files' rgc='rg --context 3' rgs='rg --stats'

    # Type-specific search
    rgcode() { rg --type-add 'web:*.{js,ts,jsx,tsx,vue,svelte}' --type web "$@"; }
    rgtest() { rg --type-add 'test:*test*.*' --type test "$@"; }
    rgconfig() { rg --type-add 'config:*.{json,yaml,yml,toml,ini,cfg,conf}' --type config "$@"; }
    rgdocs() { rg --type-add 'docs:*.{md,mdx,txt,rst}' --type docs "$@"; }
    rgsh() { rg --type-add 'shell:*.{sh,bash,zsh,fish}' --type shell "$@"; }

    # AI agent helpers
    rgfunc() { rg "function[[:space:]]+\w+|const[[:space:]]+\w+[[:space:]]*=[[:space:]]*\(.*\)[[:space:]]*=>" "$@" --type-add 'code:*.{js,ts,jsx,tsx,py,rb,go,rs}' --type code; }
    rgimport() { rg "import[[:space:]]+.*from|from[[:space:]]+.*import|require\(|use[[:space:]]+" "$@" --type-add 'code:*.{js,ts,jsx,tsx,py}' --type code; }
    rgtodo() { rg "(TODO|FIXME|HACK|XXX|NOTE):" "$@" --type-add 'code:*.{js,ts,jsx,tsx,py,rb,go,rs,sh,bash}' --type code; }
    rgapi() { rg "(get|post|put|delete|patch)\(|\.get\(|\.post\(|query[[:space:]]+|mutation[[:space:]]+" "$@" --type-add 'code:*.{js,ts,jsx,tsx,py}' --type code; }

    # Benchmark: grep vs rg
    rgbench() {
        local s="${1:-test}"
        echo "🔍 Benchmarking: '$s'"
        echo -e "\n📊 grep:"
        time grep -r "$s" . >/dev/null 2>&1 || true
        echo -e "\n⚡ ripgrep:"
        time rg "$s" >/dev/null 2>&1 || true
    }
    rgconfigshow() {
        echo "📋 Ripgrep Configuration:"
        [[ -f "$HOME/.ripgreprc" ]] && cat "$HOME/.ripgreprc" || [[ -f "$HOME/.shell-config/config/ripgreprc" ]] && cat "$HOME/.shell-config/config/ripgreprc" || echo "⚠️  No .ripgreprc found"
    }
else
    [[ -z "${RIPGREP_WARNING_SHOWN:-}" ]] && {
        echo "⚠️  ripgrep not found. Install: brew install ripgrep" >&2
        export RIPGREP_WARNING_SHOWN=1
    }
fi
