#!/usr/bin/env bash
# =============================================================================
# aliases/formatting.sh - Formatting shortcuts
# =============================================================================
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/aliases/formatting.sh"
# =============================================================================

[[ -n "${_SHELL_CONFIG_ALIASES_FORMATTING_LOADED:-}" ]] && return 0
_SHELL_CONFIG_ALIASES_FORMATTING_LOADED=1

alias format-nginx='prettier --write --parser=nginx'
alias format-xml='prettier --write --parser=xml'
alias format-sql='prettier --write --parser=sql'
alias format-toml='prettier --write --parser=toml'

# Format file with prettier by extension
format-file() {
    local file="$1"
    local ext parser
    ext="${file##*.}"
    case "$ext" in
        conf | nginx) parser="nginx" ;;
        xml | svg | html | xhtml) parser="xml" ;;
        sql) parser="sql" ;;
        toml) parser="toml" ;;
        *)
            echo "❌ ERROR: Unsupported extension: $ext" >&2
            echo "ℹ️  WHY: No configured prettier parser for this file type" >&2
            echo "💡 FIX: Add a parser mapping in lib/aliases/formatting.sh" >&2
            return 1
            ;;
    esac
    echo "Formatting $file with $parser parser"
    prettier --write --parser="$parser" "$file"
}
