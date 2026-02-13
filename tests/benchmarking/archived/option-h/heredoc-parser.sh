#!/usr/bin/env bash
# =============================================================================
# heredoc-parser.sh - Heredoc data table format + pure bash parser
# =============================================================================
# Option H: Rules defined as structured text blocks. A pure-bash parser reads
# them without any external tools. Custom format optimized for this exact use case.
#
# Format:
#   RULE <id> <command> <action> <level> <emoji>
#   PAT <pattern>
#   DESC <description>
#   BYP <bypass flag>
#   DOCS <documentation url>
#   ALT <alternative command>
#   CHK <verification step>
#   AI <ai warning line>
#   END
#
# Zero external dependencies. Pure string processing with bash builtins.
# =============================================================================

# Parse a rule data file and register all rules
_parse_rules() {
    local datafile="$1"

    local id="" cmd="" action="" level="" emoji="" pattern="" desc="" docs="" bypass=""
    local ai_warning=""
    local -a alts=()
    local -a checks=()
    local in_rule=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue

        local keyword="${line%% *}"
        local rest="${line#* }"

        case "$keyword" in
            RULE)
                in_rule=true
                # Parse: RULE <id> <command> <action> <level> <emoji>
                read -r id cmd action level emoji <<< "$rest"
                pattern="" desc="" docs="" bypass="" ai_warning=""
                alts=()
                checks=()
                ;;
            PAT)  pattern="$rest" ;;
            DESC) desc="$rest" ;;
            BYP)  bypass="$rest" ;;
            DOCS) docs="$rest" ;;
            ALT)  alts+=("$rest") ;;
            CHK)  checks+=("$rest") ;;
            AI)
                if [[ -n "$ai_warning" ]]; then
                    ai_warning+=$'\n'"$rest"
                else
                    ai_warning="$rest"
                fi
                ;;
            END)
                if [[ "$in_rule" == true ]]; then
                    local suffix="${id^^}"

                    # Create arrays
                    declare -ga "RULE_${suffix}_ALTERNATIVES=()"
                    declare -ga "RULE_${suffix}_VERIFY=()"

                    if [[ ${#alts[@]} -gt 0 ]]; then
                        eval "RULE_${suffix}_ALTERNATIVES=(\"\${alts[@]}\")"
                    fi
                    if [[ ${#checks[@]} -gt 0 ]]; then
                        eval "RULE_${suffix}_VERIFY=(\"\${checks[@]}\")"
                    fi

                    # Register directly
                    command_safety_register_rule "$suffix" \
                        "$id" "$action" "$cmd" "$pattern" "$level" \
                        "$emoji" "$desc" "$docs" "$bypass" "$ai_warning" "" \
                        "RULE_${suffix}_ALTERNATIVES" "RULE_${suffix}_VERIFY"

                    in_rule=false
                fi
                ;;
        esac
    done < "$datafile"
}

# Load all data files from a directory
load_heredoc_rules() {
    local data_dir="$1"
    for datafile in "$data_dir"/*.rules; do
        [[ -f "$datafile" ]] || continue
        _parse_rules "$datafile"
    done
}
