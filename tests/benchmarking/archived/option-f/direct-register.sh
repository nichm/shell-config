#!/usr/bin/env bash
# =============================================================================
# direct-register.sh - Direct registration helpers (zero intermediary variables)
# =============================================================================
# Option F: The RULE_*_ID, RULE_*_ACTION, etc. variables are NEVER read after
# registration -- the registry copies everything into associative arrays.
# So we skip creating them entirely. Only ALTERNATIVES and VERIFY arrays
# are needed (for namerefs in display.sh).
#
# Result: Each rule = 1 register call + 2 array declarations = 3 statements
# =============================================================================

# Register rule directly without creating intermediary variables
# Args: suffix id action command pattern level emoji desc docs bypass ai_warning
_reg() {
    local suffix="$1" id="$2" action="$3" cmd="$4" pattern="$5" level="$6"
    local emoji="$7" desc="$8" docs="${9:-}" bypass="${10:-}" ai_warning="${11:-}"

    # Declare ONLY the arrays (needed for nameref access in display.sh)
    declare -ga "RULE_${suffix}_ALTERNATIVES=()"
    declare -ga "RULE_${suffix}_VERIFY=()"

    command_safety_register_rule "$suffix" \
        "$id" "$action" "$cmd" "$pattern" "$level" \
        "$emoji" "$desc" "$docs" "$bypass" "$ai_warning" "" \
        "RULE_${suffix}_ALTERNATIVES" "RULE_${suffix}_VERIFY"
}

# Set alternatives (same as D but works with _reg)
_alts() { local S="${1^^}"; shift; eval "RULE_${S}_ALTERNATIVES=(\"\$@\")"; }

# Set verify steps
_verify() { local S="${1^^}"; shift; eval "RULE_${S}_VERIFY=(\"\$@\")"; }
