#!/usr/bin/env bash
# =============================================================================
# ⚠️ PRETTIER RULES
# =============================================================================
# Safety rules for Prettier code formatter.
# Disable: export COMMAND_SAFETY_DISABLE_PRETTIER=true
# Custom match functions:
#   _cs_match_prettier_write_recursive - --write + glob with **
#   _cs_match_prettier_write_all       - --write + . (current directory)
# =============================================================================

# shellcheck disable=SC2034

# =============================================================================
# Custom match functions
# =============================================================================

# Match prettier --write with recursive glob (**/* or similar)
_cs_match_prettier_write_recursive() {
    local args=("$@")
    local has_write=false has_recursive=false

    local arg
    for arg in "${args[@]}"; do
        [[ "$arg" == "--write" ]] && has_write=true
        [[ "$arg" == *"**"* ]] && has_recursive=true
    done

    [[ "$has_write" == true && "$has_recursive" == true ]]
}

# Match prettier --write . (all files in current directory)
_cs_match_prettier_write_all() {
    local args=("$@")
    local has_write=false has_dot=false

    local arg
    for arg in "${args[@]}"; do
        [[ "$arg" == "--write" ]] && has_write=true
        [[ "$arg" == "." ]] && has_dot=true
    done

    [[ "$has_write" == true && "$has_dot" == true ]]
}

# =============================================================================
# Rule definitions
# =============================================================================

# --- prettier --write **/* ---
_rule PRETTIER_WRITE_RECURSIVE cmd="prettier" match_fn="_cs_match_prettier_write_recursive" \
    block="Recursively overwrites ALL matched files without preview" \
    bypass="--force-prettier-write"

_fix PRETTIER_WRITE_RECURSIVE \
    "prettier --check <path>  # Preview changes first (dry-run)"

# --- prettier --write . ---
_rule PRETTIER_WRITE_ALL cmd="prettier" match_fn="_cs_match_prettier_write_all" \
    block="Overwrites ALL files in current directory without preview" \
    bypass="--force-prettier-write"

_fix PRETTIER_WRITE_ALL \
    "prettier --check .  # Preview changes first (dry-run)"
