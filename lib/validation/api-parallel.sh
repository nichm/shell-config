#!/usr/bin/env bash
# =============================================================================
# ⚡ VALIDATOR API PARALLEL EXECUTION
# =============================================================================
# Parallel validation logic split from api.sh for better organization.
# Handles concurrent file validation to improve performance.
# =============================================================================
set -euo pipefail

# Prevent double-sourcing
[[ -n "${_VALIDATOR_API_PARALLEL_LOADED:-}" ]] && return 0
readonly _VALIDATOR_API_PARALLEL_LOADED=1

# Validate files in parallel
# Usage: _validator_validate_parallel file1 file2 file3 ...
_validator_validate_parallel() {
    local files=("$@")
    local jobs="$VALIDATOR_PARALLEL"
    local pids=()
    local file tmp_file encoded
    local running=0

    for file in "${files[@]}"; do
        # Track this file
        _VALIDATOR_FILES+=("$file")

        # Wait if we've reached max parallel jobs
        while [[ $running -ge $jobs ]]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    unset "pids[$i]"
                    ((running--)) || true
                fi
            done
            [[ $running -ge $jobs ]] && sleep 0.01
        done

        # Create unique temp file path using encoded filename
        encoded=$(_validator_encode_filename "$file")
        tmp_file="$_VALIDATOR_API_TMP_DIR/parallel/$encoded"

        # Launch validation in background
        (
            # Disable set -e in subshell to handle validation failures gracefully
            set +e
            source "$_VALIDATOR_API_DIR/core.sh" >/dev/null 2>&1
            validation_reset_all

            local result="pass"
            local errors=()

            if ! validate_file "$file" 2>/dev/null; then
                result="fail"
                if file_validator_has_violations; then
                    errors+=("File length exceeds limits")
                fi
                if security_validator_has_violations; then
                    errors+=("Sensitive filename detected")
                fi
                if syntax_validator_has_errors; then
                    errors+=("Syntax errors detected")
                fi
                if workflow_validator_has_errors; then
                    errors+=("Workflow validation failed")
                fi
                if infra_validator_has_errors; then
                    errors+=("Infrastructure validation failed")
                fi
            fi

            # Write results to temp file
            echo "result=$result"
            [[ ${#errors[@]} -gt 0 ]] && printf 'error=%s\n' "${errors[@]}"
        ) >"$tmp_file" 2>/dev/null &

        pids+=($!)
        ((running++)) || true
    done

    # Wait for all background jobs
    wait "${pids[@]}" 2>/dev/null || true

    # Read results from temp files and store in our structure
    for file in "${files[@]}"; do
        encoded=$(_validator_encode_filename "$file")
        tmp_file="$_VALIDATOR_API_TMP_DIR/parallel/$encoded"
        if [[ -f "$tmp_file" ]]; then
            local result=""
            while IFS= read -r line; do
                case "$line" in
                    result=*)
                        result="${line#result=}"
                        _validator_set_result "$file" "$result"
                        ;;
                    error=*)
                        _validator_set_error "$file" "${line#error=}"
                        ;;
                esac
            done <"$tmp_file"
        fi
    done
}
