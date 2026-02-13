#!/usr/bin/env bash
# =============================================================================
# ✅ ASSERTION HELPERS
# =============================================================================
# Extended assertion functions beyond basic BATS assertions.
#
# Usage: source this file in your test setup
# =============================================================================

# Assert that output contains a substring
assert_output_contains() {
    local expected="$1"
    [[ "$output" == *"$expected"* ]]
}

# Assert that output does not contain a substring
assert_output_not_contains() {
    local expected="$1"
    [[ "$output" != *"$expected"* ]]
}

# Assert that command succeeded
assert_success() {
    [ "$status" -eq 0 ]
}

# Assert that command failed
assert_failure() {
    [ "$status" -ne 0 ]
}

# Assert that variable is set
assert_var_set() {
    local var_name="$1"
    [[ -n "${!var_name:-}" ]]
}

# Assert that variable is empty
assert_var_empty() {
    local var_name="$1"
    [[ -z "${!var_name:-}" ]]
}

# Assert that a file exists
assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "Expected file to exist: $file" >&2
        return 1
    fi
}

# Assert that a file does not exist
assert_file_not_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        echo "Expected file to not exist: $file" >&2
        return 1
    fi
}

# Assert that directory exists
assert_dir_exists() {
    local dirpath="$1"
    [ -d "$dirpath" ]
}

# Assert that a file contains specific content
assert_file_contains() {
    local file="$1"
    local content="$2"

    if [[ ! -f "$file" ]]; then
        echo "File does not exist: $file" >&2
        return 1
    fi

    if ! grep -q "$content" "$file"; then
        echo "File '$file' does not contain: $content" >&2
        return 1
    fi
}

# Assert that a file does not contain specific content
assert_file_not_contains() {
    local file="$1"
    local content="$2"

    if [[ ! -f "$file" ]]; then
        echo "File does not exist: $file" >&2
        return 1
    fi

    if grep -q "$content" "$file"; then
        echo "File '$file' should not contain: $content" >&2
        return 1
    fi
}

# Assert that a mock command was called
assert_mock_called() {
    local mock_name="$1"
    local expected_call="$2"
    local calls_file="${TEST_TEMP_DIR}/mock-${mock_name}-calls.txt"

    if [[ ! -f "$calls_file" ]]; then
        echo "Mock $mock_name was never called" >&2
        return 1
    fi

    if [[ -n "$expected_call" ]]; then
        if ! grep -q "$expected_call" "$calls_file"; then
            echo "Mock $mock_name was not called with: $expected_call" >&2
            echo "Actual calls:" >&2
            cat "$calls_file" >&2
            return 1
        fi
    fi
}

# Assert that a mock command was NOT called
assert_mock_not_called() {
    local mock_name="$1"
    local unexpected_call="$2"
    local calls_file="${TEST_TEMP_DIR}/mock-${mock_name}-calls.txt"

    if [[ -f "$calls_file" ]] && [[ -n "$unexpected_call" ]]; then
        if grep -q "$unexpected_call" "$calls_file"; then
            echo "Mock $mock_name should not have been called with: $unexpected_call" >&2
            return 1
        fi
    fi
}

# Get number of times a mock was called
get_mock_call_count() {
    local mock_name="$1"
    local calls_file="${TEST_TEMP_DIR}/mock-${mock_name}-calls.txt"

    if [[ ! -f "$calls_file" ]]; then
        echo "0"
        return
    fi

    wc -l < "$calls_file" | tr -d ' '
}