#!/usr/bin/env bash
# =============================================================================
# 📊 VALIDATION CONFIG - Language Limits & Thresholds
# =============================================================================
# Centralized configuration for file validation thresholds.
# Used by: file-validator.sh, check-file-length.sh
# Philosophy: "Don't let perfect be the enemy of good"
# These limits are 50-400% more generous than ideal standards.
# NOTE: Uses case statements for clarity (associative arrays also available with Bash 5.x)
# =============================================================================
set -euo pipefail

# Prevent double-sourcing
[[ -n "${_VALIDATION_CONFIG_LOADED:-}" ]] && return 0
readonly _VALIDATION_CONFIG_LOADED=1

# THRESHOLD PERCENTAGES (two-tier violation system)
readonly INFO_THRESHOLD_PERCENT=60    # 60% - Warning only, doesn't block
readonly WARNING_THRESHOLD_PERCENT=75 # 75% - Hard block with bypass

# Minimum INFO threshold (shell = 600 * 0.60 = 360)
# shellcheck disable=SC2034  # Used by file-validator.sh after sourcing
readonly MIN_INFO_THRESHOLD=360

# Default limit for unknown file types
readonly DEFAULT_LINE_LIMIT=800

# LANGUAGE LIMITS
_get_limit_by_ext() {
    local ext="$1"
    case "$ext" in
        # Systems programming (1500 lines)
        rs | rust | go | c | cpp | cc | cxx | h | hpp | hxx) echo 1500 ;;

        # Web development (800 lines)
        ts | tsx | mts | cts | js | jsx | mjs | cjs | vue | svelte) echo 800 ;;

        # Application languages (800 lines except Java at 700)
        py | pyi | rb | swift | php | phtml | dart) echo 800 ;;
        ex | exs | erl | hrl) echo 800 ;;      # Elixir/Erlang
        fs | fsi | fsx | ml | mli) echo 800 ;; # F#/OCaml
        r | R | jl | nim | v | zig | ada) echo 800 ;;

        # Java family (700 lines)
        java | scala | kt | kts | cs | vb) echo 700 ;;

        # Shell & scripting (600 lines)
        sh | bash | zsh | fish | lua | tcl) echo 600 ;;

        # Data & config (5000 lines)
        json | jsonl | xml | xsd | xsl | xslt) echo 5000 ;;
        yaml | yml | toml | ini | cfg | conf) echo 5000 ;;
        md | markdown | rst | txt | text | csv | tsv) echo 5000 ;;

        # SQL (1500 lines)
        sql) echo 1500 ;;

        # Unknown
        *) echo "" ;;
    esac
}

_get_limit_by_filename() {
    local filename="$1"
    case "$filename" in
        Dockerfile | Makefile | CMakeLists.txt) echo 2000 ;;
        .gitattributes | package.json | requirements.txt | Gemfile | composer.json) echo 2000 ;;
        .gitignore | package-lock.json | yarn.lock | pnpm-lock.yaml | bun.lockb) echo 5000 ;;
        Cargo.lock | go.sum | Gemfile.lock | composer.lock) echo 5000 ;;
        *) echo "" ;;
    esac
}

# HELPER FUNCTIONS

get_language_limit() {
    local file="$1"
    local filename
    filename=$(basename "$file")

    # Check special files first
    local special_limit
    special_limit=$(_get_limit_by_filename "$filename")
    if [[ -n "$special_limit" ]]; then
        echo "$special_limit"
        return
    fi

    # Get extension
    local ext="${file##*.}"
    [[ "$ext" == "$file" ]] && ext="" # No extension

    # Check for double extensions (e.g., .d.ts, .test.tsx)
    local double_ext=""
    if [[ "$file" =~ \.[a-z]+\.[a-z]+$ ]]; then
        local last_ext="${file##*.}"
        local without_last="${file%.*}"
        local prev_ext="${without_last##*.}"
        double_ext="${prev_ext}.${last_ext}"
    fi

    # Return limit for extension (prefer double extension match)
    local limit=""
    if [[ -n "$double_ext" ]]; then
        limit=$(_get_limit_by_ext "$double_ext")
    fi
    if [[ -z "$limit" ]] && [[ -n "$ext" ]]; then
        limit=$(_get_limit_by_ext "$ext")
    fi

    echo "${limit:-$DEFAULT_LINE_LIMIT}"
}

get_thresholds() {
    local limit="$1"
    local info=$((limit * INFO_THRESHOLD_PERCENT / 100))
    local warning=$((limit * WARNING_THRESHOLD_PERCENT / 100))
    local extreme=$limit
    echo "$info $warning $extreme"
}

# Export functions if possible
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f get_language_limit 2>/dev/null || true
    export -f get_thresholds 2>/dev/null || true
    export -f _get_limit_by_ext 2>/dev/null || true
    export -f _get_limit_by_filename 2>/dev/null || true
fi
