#!/usr/bin/env bash
# =============================================================================
# COMMAND SAFETY ENGINE - RULE REGISTRY
# =============================================================================
# Central registry for rule metadata. Arrays populated by rule-helpers.sh
# _rule() and consumed by matcher.sh (matching) and display.sh (warnings).
# Core arrays (populated by command_safety_register_rule):
#   COMMAND_SAFETY_RULE_ID        - Rule identifier (e.g., "git_reset")
#   COMMAND_SAFETY_RULE_ACTION    - "block" or "info"
#   COMMAND_SAFETY_RULE_COMMAND   - Command name (e.g., "git")
#   COMMAND_SAFETY_RULE_PATTERN   - Match pattern (e.g., "reset --hard")
#   COMMAND_SAFETY_RULE_EMOJI     - Display emoji
#   COMMAND_SAFETY_RULE_DESC      - Warning message
#   COMMAND_SAFETY_RULE_DOCS      - Documentation URL
#   COMMAND_SAFETY_RULE_BYPASS    - Bypass flag (e.g., "--force-danger")
#   COMMAND_SAFETY_RULE_ALTERNATIVES - Name of alternatives array variable
# Extended arrays (populated directly by _rule helper):
#   COMMAND_SAFETY_RULE_EXEMPT    - Exempt flag (skip match if present)
#   COMMAND_SAFETY_RULE_CONTEXT   - Context check ("git_repo")
#   COMMAND_SAFETY_RULE_MATCH_FN  - Custom match function name
#   _CS_CMD_RULES                 - Reverse index: command -> suffixes
# =============================================================================

# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# where set -e would cause the shell to exit on any command failure.

# --- Core metadata arrays ---
# shellcheck disable=SC2034 # Arrays are used by display.sh and matcher.sh
declare -gA COMMAND_SAFETY_RULE_ID=()
# shellcheck disable=SC2034
declare -gA COMMAND_SAFETY_RULE_ACTION=()
# shellcheck disable=SC2034
declare -gA COMMAND_SAFETY_RULE_COMMAND=()
# shellcheck disable=SC2034
declare -gA COMMAND_SAFETY_RULE_PATTERN=()
# shellcheck disable=SC2034
declare -gA COMMAND_SAFETY_RULE_EMOJI=()
# shellcheck disable=SC2034
declare -gA COMMAND_SAFETY_RULE_DESC=()
# shellcheck disable=SC2034
declare -gA COMMAND_SAFETY_RULE_DOCS=()
# shellcheck disable=SC2034
declare -gA COMMAND_SAFETY_RULE_BYPASS=()
# shellcheck disable=SC2034
declare -gA COMMAND_SAFETY_RULE_ALTERNATIVES=()
declare -ga COMMAND_SAFETY_RULE_SUFFIXES=()

# --- Extended matching arrays (populated by _rule helper) ---
# shellcheck disable=SC2034
declare -gA COMMAND_SAFETY_RULE_EXEMPT=()
# shellcheck disable=SC2034
declare -gA COMMAND_SAFETY_RULE_CONTEXT=()
# shellcheck disable=SC2034
declare -gA COMMAND_SAFETY_RULE_MATCH_FN=()

# Reverse index: command name -> space-separated rule suffixes
# Used by generic matcher for O(1) command lookup
# shellcheck disable=SC2034
declare -gA _CS_CMD_RULES=()

command_safety_register_rule() {
    local suffix="$1"
    local rule_id="$2"
    local rule_action="$3"
    local rule_command="$4"
    local rule_pattern="$5"
    local rule_emoji="$6"
    local rule_desc="$7"
    local rule_docs="$8"
    local rule_bypass="$9"
    local rule_alternatives_var="${10:-}"

    COMMAND_SAFETY_RULE_SUFFIXES+=("$suffix")
    # NOTE: No quotes around $suffix/$rule_command inside [] — in zsh, quotes
    # become literal key characters (e.g., key="foo" stores "\"foo\"" not "foo").
    # shellcheck disable=SC2034 # Used by display.sh
    COMMAND_SAFETY_RULE_ID[$suffix]="$rule_id"
    # shellcheck disable=SC2034
    COMMAND_SAFETY_RULE_ACTION[$suffix]="$rule_action"
    # shellcheck disable=SC2034
    COMMAND_SAFETY_RULE_COMMAND[$suffix]="$rule_command"
    # shellcheck disable=SC2034
    COMMAND_SAFETY_RULE_PATTERN[$suffix]="$rule_pattern"
    # shellcheck disable=SC2034
    COMMAND_SAFETY_RULE_EMOJI[$suffix]="$rule_emoji"
    # shellcheck disable=SC2034
    COMMAND_SAFETY_RULE_DESC[$suffix]="$rule_desc"
    # shellcheck disable=SC2034
    COMMAND_SAFETY_RULE_DOCS[$suffix]="$rule_docs"
    # shellcheck disable=SC2034
    COMMAND_SAFETY_RULE_BYPASS[$suffix]="$rule_bypass"

    if [[ -n "$rule_alternatives_var" ]]; then
        # shellcheck disable=SC2034
        COMMAND_SAFETY_RULE_ALTERNATIVES[$suffix]="$rule_alternatives_var"
    fi

    # Build reverse index for O(1) command lookup in generic matcher
    _CS_CMD_RULES[$rule_command]+="$suffix "
}
