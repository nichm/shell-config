#!/usr/bin/env bats
# =============================================================================
# VALIDATION API OUTPUT TESTS
# =============================================================================
# Tests for lib/validation/api-output.sh
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export API_OUTPUT_FILE="$SHELL_CONFIG_DIR/lib/validation/api-output.sh"
	export API_INTERNAL_FILE="$SHELL_CONFIG_DIR/lib/validation/api-internal.sh"

	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	GREEN="" RED="" YELLOW="" BLUE="" NC=""
	export GREEN RED YELLOW BLUE NC
	export VALIDATOR_OUTPUT="console"
	export VALIDATOR_PARALLEL=0
	export VALIDATOR_OUTPUT_FILE=""

	unset _VALIDATOR_API_INTERNAL_LOADED
	unset _VALIDATOR_API_OUTPUT_LOADED

	source "$API_INTERNAL_FILE"
	source "$API_OUTPUT_FILE"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	_validator_api_cleanup 2>/dev/null || true
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "api-output: file exists and is readable" {
	[ -f "$API_OUTPUT_FILE" ]
	[ -r "$API_OUTPUT_FILE" ]
}

@test "api-output: valid bash syntax" {
	run bash -n "$API_OUTPUT_FILE"
	[ "$status" -eq 0 ]
}

@test "api-output: has idempotent load guard" {
	run grep -q '_VALIDATOR_API_OUTPUT_LOADED' "$API_OUTPUT_FILE"
	[ "$status" -eq 0 ]
}

@test "api-output: _json_escape handles quotes" {
	local result
	result=$(_json_escape 'hello "world"')
	[[ "$result" == *'\"'* ]]
}

@test "api-output: _json_escape handles backslashes" {
	local result
	result=$(_json_escape 'path\to\file')
	[[ "$result" == *'\\'* ]]
}

@test "api-output: _json_escape handles newlines" {
	local result
	result=$(_json_escape $'line1\nline2')
	# Result should contain escaped newline (literal \n, not actual newline)
	[[ "$result" != *$'\n'* ]]
	[[ "$result" == *'n'* ]]
}

@test "api-output: _json_escape handles tabs" {
	local result
	result=$(_json_escape $'before\tafter')
	# Result should not contain literal tab
	[[ "$result" != *$'\t'* ]]
}

@test "api-output: _validator_api_build_json produces valid structure" {
	_validator_api_init
	_VALIDATOR_FILES=("test.sh")
	_validator_set_result "test.sh" "pass"

	_validator_api_build_json
	[[ "$_VALIDATOR_API_JSON_OUTPUT" == *'"version"'* ]]
	[[ "$_VALIDATOR_API_JSON_OUTPUT" == *'"results"'* ]]
	[[ "$_VALIDATOR_API_JSON_OUTPUT" == *'"summary"'* ]]
}

@test "api-output: JSON output includes timestamp" {
	_validator_api_init
	_VALIDATOR_FILES=()
	_validator_api_build_json
	[[ "$_VALIDATOR_API_JSON_OUTPUT" == *'"timestamp"'* ]]
}

@test "api-output: JSON output includes correct counts" {
	_validator_api_init
	_VALIDATOR_FILES=("a.sh" "b.sh")
	_validator_set_result "a.sh" "pass"
	_validator_set_result "b.sh" "fail"

	_validator_api_build_json
	[[ "$_VALIDATOR_API_JSON_OUTPUT" == *'"total":2'* ]]
	[[ "$_VALIDATOR_API_JSON_OUTPUT" == *'"passed":1'* ]]
	[[ "$_VALIDATOR_API_JSON_OUTPUT" == *'"failed":1'* ]]
}

@test "api-output: JSON writes to file when VALIDATOR_OUTPUT_FILE set" {
	_validator_api_init
	_VALIDATOR_FILES=("test.sh")
	_validator_set_result "test.sh" "pass"

	VALIDATOR_OUTPUT_FILE="$TEST_TEMP_DIR/output.json"
	_validator_api_print_json 2>/dev/null
	[ -f "$TEST_TEMP_DIR/output.json" ]
}

@test "api-output: console output includes results header" {
	_validator_api_init
	_VALIDATOR_FILES=()

	run _validator_api_print_console
	[[ "$output" == *"Validation Results"* ]]
}
