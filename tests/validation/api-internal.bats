#!/usr/bin/env bats
# =============================================================================
# VALIDATION API INTERNAL TESTS
# =============================================================================
# Tests for lib/validation/api-internal.sh
# Regression: PR #82 (TS validators), PR #98 (string ops)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export API_INTERNAL_FILE="$SHELL_CONFIG_DIR/lib/validation/api-internal.sh"

	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	# Stub color variables
	GREEN="" RED="" YELLOW="" BLUE="" NC=""
	export GREEN RED YELLOW BLUE NC

	# Reset load guard
	unset _VALIDATOR_API_INTERNAL_LOADED

	# Provide required env vars for the module
	export VALIDATOR_OUTPUT="console"
	export VALIDATOR_PARALLEL=0
	export VALIDATOR_OUTPUT_FILE=""

	source "$API_INTERNAL_FILE"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	_validator_api_cleanup 2>/dev/null || true
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "api-internal: file exists and is readable" {
	[ -f "$API_INTERNAL_FILE" ]
	[ -r "$API_INTERNAL_FILE" ]
}

@test "api-internal: valid bash syntax" {
	run bash -n "$API_INTERNAL_FILE"
	[ "$status" -eq 0 ]
}

@test "api-internal: has idempotent load guard" {
	run grep -q '_VALIDATOR_API_INTERNAL_LOADED' "$API_INTERNAL_FILE"
	[ "$status" -eq 0 ]
}

@test "api-internal: _validator_api_validate_env accepts console output" {
	VALIDATOR_OUTPUT="console"
	VALIDATOR_PARALLEL=0
	VALIDATOR_OUTPUT_FILE=""
	run _validator_api_validate_env
	[ "$status" -eq 0 ]
}

@test "api-internal: _validator_api_validate_env accepts json output" {
	VALIDATOR_OUTPUT="json"
	VALIDATOR_PARALLEL=0
	VALIDATOR_OUTPUT_FILE=""
	run _validator_api_validate_env
	[ "$status" -eq 0 ]
}

@test "api-internal: _validator_api_validate_env rejects invalid output type" {
	VALIDATOR_OUTPUT="xml"
	VALIDATOR_PARALLEL=0
	VALIDATOR_OUTPUT_FILE=""
	run _validator_api_validate_env
	[ "$status" -eq 2 ]
}

@test "api-internal: _validator_api_validate_env rejects non-integer parallel" {
	VALIDATOR_OUTPUT="console"
	VALIDATOR_PARALLEL="abc"
	VALIDATOR_OUTPUT_FILE=""
	run _validator_api_validate_env
	[ "$status" -eq 2 ]
}

@test "api-internal: _validator_encode_filename produces consistent output" {
	local encoded1 encoded2
	encoded1=$(_validator_encode_filename "test/file.sh")
	encoded2=$(_validator_encode_filename "test/file.sh")
	[ "$encoded1" = "$encoded2" ]
}

@test "api-internal: _validator_encode_filename handles special chars" {
	local encoded
	encoded=$(_validator_encode_filename "path/to/file with spaces.sh")
	[[ "$encoded" != *" "* ]]
	[ -n "$encoded" ]
}

@test "api-internal: _validator_api_init creates temp directories" {
	_validator_api_init
	[ -d "$_VALIDATOR_API_TMP_DIR/results" ]
	[ -d "$_VALIDATOR_API_TMP_DIR/errors" ]
	[ -d "$_VALIDATOR_API_TMP_DIR/parallel" ]
}

@test "api-internal: _validator_set_result and _validator_get_result round-trip" {
	_validator_api_init
	_validator_set_result "test.sh" "pass"
	local result
	result=$(_validator_get_result "test.sh")
	[ "$result" = "pass" ]
}

@test "api-internal: _validator_set_error and _validator_get_errors round-trip" {
	_validator_api_init
	_validator_set_error "test.sh" "Syntax error on line 5"
	local errors
	errors=$(_validator_get_errors "test.sh")
	[[ "$errors" == *"Syntax error"* ]]
}

@test "api-internal: _validator_has_errors returns true when errors exist" {
	_validator_api_init
	_validator_set_error "test.sh" "Error!"
	_validator_has_errors "test.sh"
}

@test "api-internal: _validator_has_errors returns false when no errors" {
	_validator_api_init
	run _validator_has_errors "no-errors.sh"
	[ "$status" -ne 0 ]
}

@test "api-internal: _validator_api_cleanup removes temp directory" {
	_validator_api_init
	local tmp_dir="$_VALIDATOR_API_TMP_DIR"
	[ -d "$tmp_dir" ]
	_validator_api_cleanup
	[ ! -d "$tmp_dir" ]
}
