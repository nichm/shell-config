#!/usr/bin/env bash
# =============================================================================
# rule-compact.sh - Compact rule definition using associative arrays
# =============================================================================
# Option E: Each rule is a single _R() call with named parameters.
# Uses Bash 5 features for maximum compactness.
# Zero external dependencies. Same performance as original.
#
# Usage:
#   _R id=rm_rf cmd=rm pat="-rf|-r -f" act=warn lvl=critical \
#      em="🔴" desc="Recursive force delete" byp="--force-danger"
#   _A rm_rf "alt1" "alt2"
#   _V rm_rf "step1" "step2"
#   _W rm_rf "AI warning text"
# =============================================================================

# Compact rule definition
_R() {
    local id="" cmd="" pat="" act="" lvl="" em="" desc="" docs="" byp=""

    # Parse key=value arguments
    for arg in "$@"; do
        case "$arg" in
            id=*)   id="${arg#id=}" ;;
            cmd=*)  cmd="${arg#cmd=}" ;;
            pat=*)  pat="${arg#pat=}" ;;
            act=*)  act="${arg#act=}" ;;
            lvl=*)  lvl="${arg#lvl=}" ;;
            em=*)   em="${arg#em=}" ;;
            desc=*) desc="${arg#desc=}" ;;
            docs=*) docs="${arg#docs=}" ;;
            byp=*)  byp="${arg#byp=}" ;;
        esac
    done

    local S="${id^^}"

    # shellcheck disable=SC2034
    declare -g "RULE_${S}_ID=$id"
    declare -g "RULE_${S}_ACTION=$act"
    declare -g "RULE_${S}_COMMAND=$cmd"
    declare -g "RULE_${S}_PATTERN=$pat"
    declare -g "RULE_${S}_LEVEL=$lvl"
    declare -g "RULE_${S}_EMOJI=$em"
    declare -g "RULE_${S}_DESC=$desc"
    declare -g "RULE_${S}_DOCS=$docs"
    declare -g "RULE_${S}_BYPASS=$byp"
    declare -g "RULE_${S}_AI_WARNING="
    declare -ga "RULE_${S}_ALTERNATIVES=()"
    declare -ga "RULE_${S}_VERIFY=()"

    command_safety_register_rule "$S" \
        "$id" "$act" "$cmd" "$pat" "$lvl" \
        "$em" "$desc" "$docs" "$byp" "" "" \
        "RULE_${S}_ALTERNATIVES" "RULE_${S}_VERIFY"
}

# Compact alternatives
_A() { local S="${1^^}"; shift; eval "RULE_${S}_ALTERNATIVES=(\"\$@\")"; }

# Compact verify
_V() { local S="${1^^}"; shift; eval "RULE_${S}_VERIFY=(\"\$@\")"; }

# Compact AI warning
_W() {
    local S="${1^^}"
    declare -g "RULE_${S}_AI_WARNING=$2"
    COMMAND_SAFETY_RULE_AI_WARNING["$S"]="$2"
}
