#!/usr/bin/env bash
# =============================================================================
# rule-helpers.sh - Declarative rule definition helpers
# =============================================================================
# Option D: Pure bash helper functions that eliminate boilerplate.
# Each rule goes from ~40 lines to ~10 lines. Zero external dependencies.
#
# Usage:
#   _rule <id> <command> <pattern> <action> <level> <emoji> <desc> [docs] [bypass]
#   _alts <id> "alt1" "alt2" ...
#   _verify <id> "step1" "step2" ...
#   _ai <id> "multiline warning text"
# =============================================================================

# Define a rule's scalar fields and register it
_rule() {
    local id="$1" cmd="$2" pattern="$3" action="$4" level="$5" emoji="$6" desc="$7"
    local docs="${8:-}" bypass="${9:-}"
    local suffix="${id^^}"

    # shellcheck disable=SC2034
    declare -g "RULE_${suffix}_ID=$id"
    declare -g "RULE_${suffix}_ACTION=$action"
    declare -g "RULE_${suffix}_COMMAND=$cmd"
    declare -g "RULE_${suffix}_PATTERN=$pattern"
    declare -g "RULE_${suffix}_LEVEL=$level"
    declare -g "RULE_${suffix}_EMOJI=$emoji"
    declare -g "RULE_${suffix}_DESC=$desc"
    declare -g "RULE_${suffix}_DOCS=$docs"
    declare -g "RULE_${suffix}_BYPASS=$bypass"
    declare -g "RULE_${suffix}_AI_WARNING="
    declare -ga "RULE_${suffix}_ALTERNATIVES=()"
    declare -ga "RULE_${suffix}_VERIFY=()"

    command_safety_register_rule "$suffix" \
        "$id" "$action" "$cmd" "$pattern" "$level" \
        "$emoji" "$desc" "$docs" "$bypass" "" "" \
        "RULE_${suffix}_ALTERNATIVES" "RULE_${suffix}_VERIFY"
}

# Set alternatives for a rule
_alts() {
    local suffix="${1^^}"; shift
    declare -ga "RULE_${suffix}_ALTERNATIVES=("
    local arr_name="RULE_${suffix}_ALTERNATIVES"
    # Reset and fill
    eval "$arr_name=()"
    for alt in "$@"; do
        eval "$arr_name+=(\"\$alt\")"
    done
}

# Set verification steps for a rule
_verify() {
    local suffix="${1^^}"; shift
    local arr_name="RULE_${suffix}_VERIFY"
    eval "$arr_name=()"
    for step in "$@"; do
        eval "$arr_name+=(\"\$step\")"
    done
}

# Set AI warning for a rule
_ai() {
    local suffix="${1^^}"
    local warning="$2"
    declare -g "RULE_${suffix}_AI_WARNING=$warning"
    COMMAND_SAFETY_RULE_AI_WARNING["$suffix"]="$warning"
}
