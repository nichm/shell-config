#!/usr/bin/env bash
# =============================================================================
# 📊 VALIDATOR API OUTPUT FORMATTING
# =============================================================================
# Output formatting functions for console and JSON results.
# Split from api.sh to keep the main API focused on validation logic.
# =============================================================================
set -euo pipefail

# Prevent double-sourcing
[[ -n "${_VALIDATOR_API_OUTPUT_LOADED:-}" ]] && return 0
readonly _VALIDATOR_API_OUTPUT_LOADED=1

# Ensure command_exists is available (sourced via init.sh/hook-bootstrap chain)
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# =============================================================================
# CONSOLE OUTPUT
# =============================================================================

# Print console results
_validator_api_print_console() {
    local file result
    local has_failures=0

    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "           Validation Results"
    echo "════════════════════════════════════════════════════════════════"
    echo ""

    for file in "${_VALIDATOR_FILES[@]}"; do
        result=$(_validator_get_result "$file")
        local status="✓"
        local color="${GREEN}"

        case "$result" in
            pass)
                status="✓"
                color="${GREEN}"
                ;;
            fail)
                status="✗"
                color="${RED}"
                has_failures=1
                ;;
            skipped)
                status="⊘"
                color="${YELLOW}"
                ;;
        esac

        printf '%b%s%b %s\n' "${color}" "$status" "${NC}" "$file"

        if _validator_has_errors "$file"; then
            while IFS= read -r error; do
                [[ -n "$error" ]] && printf '  %b├─%b %s\n' "${RED}" "${NC}" "$error"
            done < <(_validator_get_errors "$file")
        fi
    done

    printf '\n'
    echo "════════════════════════════════════════════════════════════════"
    echo "  Time: $(_validator_api_elapsed)s"
    echo "  Files: ${#_VALIDATOR_FILES[@]}"
    local status_text
    if [[ $has_failures -eq 0 ]]; then
        status_text="PASSED"
    else
        status_text="FAILED"
    fi
    echo "  Status: $status_text"
    echo "════════════════════════════════════════════════════════════════"
    printf '\n'

    return $has_failures
}

# =============================================================================
# JSON OUTPUT
# =============================================================================

# Escape a string for JSON output (handles all control characters)
# This is critical for valid JSON - malformed filenames/errors can break parsers
_json_escape() {
    local input="$1"
    local output=""

    # Use jq if available (most reliable)
    if command_exists "jq"; then
        # jq -Rs outputs a JSON string (with quotes), so we strip them
        output=$(printf '%s' "$input" | jq -Rs '.' | sed 's/^"//; s/"$//')
        printf '%s' "$output"
        return 0
    fi

    # Fallback: manual escaping (handles common cases)
    # Order matters: backslash first, then other characters
    output="$input"
    output="${output//\\/\\\\}"   # Backslash
    output="${output//\"/\\\"}"   # Double quote
    output="${output//$'\t'/\\t}" # Tab
    output="${output//$'\r'/\\r}" # Carriage return
    output="${output//$'\n'/\\n}" # Newline (proper JSON escape, not space)
    output="${output//$'\b'/\\b}" # Backspace
    output="${output//$'\f'/\\f}" # Form feed

    printf '%s' "$output"
}

# Build JSON result object
_validator_api_build_json() {
    local file result
    local json=""
    local timestamp
    local elapsed
    local total passed failed skipped

    # Gather data
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    elapsed=$(_validator_api_elapsed)
    total=${#_VALIDATOR_FILES[@]}
    passed=0
    failed=0
    skipped=0

    for file in "${_VALIDATOR_FILES[@]}"; do
        result=$(_validator_get_result "$file")
        case "$result" in
            pass) ((passed++)) || true ;;
            fail) ((failed++)) || true ;;
            skipped) ((skipped++)) || true ;;
        esac
    done

    # Start JSON object
    json='{'
    json+='"version":"1.0",'
    json+='"timestamp":"'"$timestamp"'",'
    json+='"elapsed":"'"$elapsed"'s",'
    json+='"summary":{'
    json+='"total":'"$total"','
    json+='"passed":'"$passed"','
    json+='"failed":'"$failed"','
    json+='"skipped":'"$skipped"
    json+='},'
    json+='"results":['

    local first=1
    for file in "${_VALIDATOR_FILES[@]}"; do
        [[ $first -eq 0 ]] && json+=','
        first=0

        # Use proper JSON escaping for all control characters
        local escaped_file
        escaped_file=$(_json_escape "$file")
        result=$(_validator_get_result "$file")

        json+='{'
        json+='"file":"'"$escaped_file"'",'
        json+='"status":"'"$result"'"'

        if _validator_has_errors "$file"; then
            json+=',"errors":['
            local error_first=1
            while IFS= read -r error; do
                [[ -z "$error" ]] && continue
                [[ $error_first -eq 0 ]] && json+=','
                error_first=0
                # Use proper JSON escaping for all control characters
                local escaped_error
                escaped_error=$(_json_escape "$error")
                json+='"'"$escaped_error"'"'
            done < <(_validator_get_errors "$file")
            json+=']'
        fi

        json+='}'
    done

    json+=']'
    json+='}'

    _VALIDATOR_API_JSON_OUTPUT="$json"
}

# Print JSON results
_validator_api_print_json() {
    _validator_api_build_json

    if [[ -n "$VALIDATOR_OUTPUT_FILE" ]]; then
        printf '%s\n' "$_VALIDATOR_API_JSON_OUTPUT" >"$VALIDATOR_OUTPUT_FILE"
        echo "Results written to: $VALIDATOR_OUTPUT_FILE" >&2
    else
        printf '%s\n' "$_VALIDATOR_API_JSON_OUTPUT"
    fi
}
