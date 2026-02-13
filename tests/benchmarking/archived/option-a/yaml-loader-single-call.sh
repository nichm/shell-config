#!/usr/bin/env bash
# =============================================================================
# yaml-loader-single-call.sh - Maximum optimization: ONE yq call total
# =============================================================================
# Merges all YAML files, extracts everything in a single yq invocation,
# outputs a simple line protocol that bash parses with read loops.
# =============================================================================
set -euo pipefail

load_all_yaml_rules_single_call() {
    local yaml_dir="$1"

    # ONE yq call across ALL files: output tab-separated fields per rule
    # Format: id\tcommand\tpattern\taction\tlevel\temoji\tdesc\tdocs\tbypass\talt_count\tverify_count
    local all_data
    all_data=$(yq eval-all '
        . as $doc | to_entries[] |
        .value.id + "\t" +
        .value.command + "\t" +
        (.value.pattern // "") + "\t" +
        .value.action + "\t" +
        .value.level + "\t" +
        .value.emoji + "\t" +
        .value.desc + "\t" +
        (.value.docs // "") + "\t" +
        (.value.bypass // "") + "\t" +
        ((.value.alternatives // []) | length | tostring) + "\t" +
        ((.value.verify // []) | length | tostring)
    ' "$yaml_dir"/*.yaml)

    # Also get arrays and ai_warnings in a separate single call
    local arrays_data
    arrays_data=$(yq eval-all '
        . as $doc | to_entries[] |
        "RULE_START:" + .value.id + "\n" +
        "AI_WARNING:" + ((.value.ai_warning // "") | sub("\n$"; "") | gsub("\n"; "\\n")) + "\n" +
        ((.value.alternatives // []) | .[] | "ALT:" + .) + "\n" +
        ((.value.verify // []) | .[] | "VERIFY:" + .)
    ' "$yaml_dir"/*.yaml 2>/dev/null) || arrays_data=""

    # Parse the scalar fields
    while IFS=$'\t' read -r id command pattern action level emoji desc docs bypass alt_count verify_count; do
        [[ -z "$id" ]] && continue
        local suffix="${id^^}"

        # Create empty arrays
        declare -ga "RULE_${suffix}_ALTERNATIVES=()"
        declare -ga "RULE_${suffix}_VERIFY=()"

        # Register with empty ai_warning for now (filled below)
        command_safety_register_rule "$suffix" \
            "$id" "$action" "$command" "$pattern" "$level" \
            "$emoji" "$desc" "$docs" "$bypass" "" \
            "RULE_${suffix}_ALTERNATIVES" "RULE_${suffix}_VERIFY"
    done <<< "$all_data"

    # Parse arrays and ai_warnings
    local current_suffix=""
    while IFS= read -r line; do
        if [[ "$line" == RULE_START:* ]]; then
            local rid="${line#RULE_START:}"
            current_suffix="${rid^^}"
        elif [[ "$line" == AI_WARNING:* ]]; then
            local warning="${line#AI_WARNING:}"
            # Restore newlines
            warning="${warning//\\n/$'\n'}"
            COMMAND_SAFETY_RULE_AI_WARNING["$current_suffix"]="$warning"
        elif [[ "$line" == ALT:* ]]; then
            local alt="${line#ALT:}"
            eval "RULE_${current_suffix}_ALTERNATIVES+=(\"$alt\")"
        elif [[ "$line" == VERIFY:* ]]; then
            local ver="${line#VERIFY:}"
            eval "RULE_${current_suffix}_VERIFY+=(\"$ver\")"
        fi
    done <<< "$arrays_data"
}
