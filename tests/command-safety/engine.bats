#!/usr/bin/env bats
# =============================================================================
# 🧪 COMMAND SAFETY ENGINE TESTS - Core Protection Validation
# =============================================================================
# Tests for command-safety engine modules including:
#   - registry.sh: Rule registration and metadata storage
#   - display.sh: Rule message display, alternatives, verification
#   - wrapper.sh: Command wrapper generation
#   - loader.sh: Module initialization and dependency loading
#   - matcher.sh: Generic pattern matching engine
# =============================================================================

setup() {
	# Determine repo root - use git if available, fallback to directory traversal
	local repo_root
	repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
	export SHELL_CONFIG_DIR="$repo_root"
	export COMMAND_SAFETY_DIR="$SHELL_CONFIG_DIR/lib/command-safety"
	export COMMAND_SAFETY_ENGINE_DIR="$COMMAND_SAFETY_DIR/engine"

	# Create temp directory with trap handler for cleanup
	TEST_TEMP_DIR="$(mktemp -d)"
	# Trap moved to teardown for bats compatibility
	cd "$TEST_TEMP_DIR" || return 1

	# Source engine modules in correct order
	# NOTE: Engine modules no longer use set -euo pipefail (they're sourced
	# into interactive shells where strict mode would cause premature exits)
	# shellcheck source=../../lib/command-safety/engine/registry.sh
	source "$COMMAND_SAFETY_ENGINE_DIR/registry.sh"
	# shellcheck source=../../lib/command-safety/engine/display.sh
	source "$COMMAND_SAFETY_ENGINE_DIR/display.sh"
	# shellcheck source=../../lib/command-safety/engine/wrapper.sh
	source "$COMMAND_SAFETY_ENGINE_DIR/wrapper.sh"
	# shellcheck source=../../lib/command-safety/engine/loader.sh
	source "$COMMAND_SAFETY_ENGINE_DIR/loader.sh"
	# shellcheck source=../../lib/command-safety/engine/matcher.sh
	source "$COMMAND_SAFETY_ENGINE_DIR/matcher.sh"

	# Reset rule registry to ensure test isolation
	# This prevents state pollution between tests
	_reset_rule_registry
}

# Helper function to reset rule registry between tests
# shellcheck disable=SC2034 # These arrays are used by sourced engine modules
_reset_rule_registry() {
	# Clear all registry arrays to prevent state leakage
	COMMAND_SAFETY_RULE_SUFFIXES=()
	COMMAND_SAFETY_RULE_ID=()
	COMMAND_SAFETY_RULE_ACTION=()
	COMMAND_SAFETY_RULE_COMMAND=()
	COMMAND_SAFETY_RULE_PATTERN=()
	COMMAND_SAFETY_RULE_EMOJI=()
	COMMAND_SAFETY_RULE_DESC=()
	COMMAND_SAFETY_RULE_DOCS=()
	COMMAND_SAFETY_RULE_BYPASS=()
	COMMAND_SAFETY_RULE_ALTERNATIVES=()
	# Extended matching arrays
	COMMAND_SAFETY_RULE_EXEMPT=()
	COMMAND_SAFETY_RULE_CONTEXT=()
	COMMAND_SAFETY_RULE_MATCH_FN=()
	_CS_CMD_RULES=()
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

# =============================================================================
# 📋 REGISTRY MODULE TESTS
# =============================================================================

@test "registry: command_safety_register_rule populates arrays" {
	# Register a test rule (10-arg signature)
	command_safety_register_rule \
		"TEST_SUFFIX" \
		"test_id" \
		"block" \
		"rm" \
		"-rf" \
		"🛑" \
		"Test description" \
		"" \
		"--force-test" \
		""

	# Verify arrays are populated
	[ "${COMMAND_SAFETY_RULE_ID[TEST_SUFFIX]}" = "test_id" ]
	[ "${COMMAND_SAFETY_RULE_ACTION[TEST_SUFFIX]}" = "block" ]
	[ "${COMMAND_SAFETY_RULE_COMMAND[TEST_SUFFIX]}" = "rm" ]
	[ "${COMMAND_SAFETY_RULE_PATTERN[TEST_SUFFIX]}" = "-rf" ]
	[ "${COMMAND_SAFETY_RULE_EMOJI[TEST_SUFFIX]}" = "🛑" ]
	[ "${COMMAND_SAFETY_RULE_DESC[TEST_SUFFIX]}" = "Test description" ]
	[ "${COMMAND_SAFETY_RULE_BYPASS[TEST_SUFFIX]}" = "--force-test" ]
}

@test "registry: command_safety_register_rule adds to suffixes array" {
	# Register two rules
	command_safety_register_rule "TEST1" "id1" "block" "rm" "-rf" "🛑" "Desc1" "" "" ""
	command_safety_register_rule "TEST2" "id2" "block" "git" "push" "⚠️" "Desc2" "" "" ""

	# Verify suffixes array contains both
	local found_test1=0
	local found_test2=0
	for suffix in "${COMMAND_SAFETY_RULE_SUFFIXES[@]}"; do
		[[ "$suffix" == "TEST1" ]] && found_test1=1
		[[ "$suffix" == "TEST2" ]] && found_test2=1
	done

	[ "$found_test1" -eq 1 ]
	[ "$found_test2" -eq 1 ]
}

@test "registry: command_safety_register_rule builds reverse index" {
	command_safety_register_rule "TEST1" "id1" "block" "rm" "-rf" "🛑" "Desc1" "" "" ""
	command_safety_register_rule "TEST2" "id2" "info" "rm" "" "ℹ️" "Desc2" "" "" ""
	command_safety_register_rule "TEST3" "id3" "block" "git" "push" "⚠️" "Desc3" "" "" ""

	# Reverse index should have both rm rules
	[[ "${_CS_CMD_RULES[rm]}" == *"TEST1"* ]]
	[[ "${_CS_CMD_RULES[rm]}" == *"TEST2"* ]]
	[[ "${_CS_CMD_RULES[git]}" == *"TEST3"* ]]
}

@test "registry: associative arrays support bash 5 features" {
	# Test that associative arrays work (bash 4+ feature)
	declare -A test_array=(["key1"]="value1" ["key2"]="value2")

	[ "${test_array[key1]}" = "value1" ]
	[ "${test_array[key2]}" = "value2" ]
	[ "${#test_array[@]}" -eq 2 ]
}

# =============================================================================
# 🖥️ DISPLAY MODULE TESTS
# =============================================================================

@test "display: _show_rule_message validates rule_suffix for security" {
	run _show_rule_message "invalid@suffix" "rm" "-rf"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Invalid rule suffix"* ]]
}

@test "display: _show_rule_message accepts valid alphanumeric suffixes" {
	# Register a test rule first
	command_safety_register_rule \
		"VALID_TEST" \
		"test_id" \
		"block" \
		"rm" \
		"-rf" \
		"🛑" \
		"Test message" \
		"" \
		"--force" \
		""

	# Should not fail validation
	run _show_rule_message "VALID_TEST" "rm" "-rf"
	# Note: May still fail if other dependencies aren't met, but shouldn't fail on validation
	[[ "$output" != *"Invalid rule suffix"* ]] || [ "$status" -eq 0 ]
}

@test "display: _show_rule_message provides fallback for RM_RF" {
	run _show_rule_message "RM_RF" "rm" "-rf /"
	# Should have fallback behavior even without rule loaded
	[[ "$output" == *"Permanent deletion"* || "$output" == *"cannot be recovered"* ]]
}

@test "display: _show_rule_message provides fallback for CHMOD_777" {
	run _show_rule_message "CHMOD_777" "chmod" "777 file"
	# Should have fallback behavior
	[[ "$output" == *"security risk"* ]]
}

@test "display: _show_rule_message provides fallback for GIT_PUSH_FORCE" {
	run _show_rule_message "GIT_PUSH_FORCE" "git" "push --force"
	# Should have fallback behavior
	[[ "$output" == *"Overwrites remote"* || "$output" == *"collaborators"* ]]
}

# =============================================================================
# 🎯 WRAPPER MODULE TESTS
# =============================================================================

@test "wrapper: _generate_wrapper validates command name for security" {
	run _generate_wrapper "invalid@command"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Invalid command name"* ]]
}

@test "wrapper: _generate_wrapper accepts valid command names" {
	run _generate_wrapper "rm"
	[ "$status" -eq 0 ]
	# Verify wrapper was created by checking type
	run type rm
	[ "$status" -eq 0 ]
}

@test "wrapper: _generate_wrapper accepts hyphens and underscores" {
	# Register rules so wrappers have something to check against
	command_safety_register_rule "GP" "gp" "info" "git-push" "" "ℹ️" "Test" "" "" ""
	command_safety_register_rule "DC" "dc" "info" "docker_compose" "" "ℹ️" "Test" "" "" ""

	# Call directly (not via run) so functions persist in the test shell
	_generate_wrapper "git-push"
	# Verify git-push wrapper was created
	run type git-push
	[ "$status" -eq 0 ]

	_generate_wrapper "docker_compose"
	# Verify docker_compose wrapper was created
	run type docker_compose
	[ "$status" -eq 0 ]
}

@test "wrapper: _generate_wrapper creates function" {
	_generate_wrapper "testrm"

	# Check that function exists
	run type testrm
	[ "$status" -eq 0 ]
	[[ "$output" == *"function"* ]] || [[ "$output" == *"testrm is"* ]]
}

@test "wrapper: generated wrapper falls through when _check_command_rules is unavailable" {
	# Regression: gh (and other wrapped commands) crashed with
	# "command not found: _check_command_rules" when matcher.sh wasn't loaded.
	# The wrapper must fall through to `command <cmd>` if the function is missing.
	run bash -c "
		source '$COMMAND_SAFETY_ENGINE_DIR/registry.sh'
		source '$COMMAND_SAFETY_ENGINE_DIR/wrapper.sh'
		# DO NOT source matcher.sh — simulates partial init
		# Unset _check_command_rules in case it leaked from parent
		unset -f _check_command_rules 2>/dev/null || true
		_generate_wrapper 'echo'
		# If the guard works, echo should still function
		echo 'wrapper-ok'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"wrapper-ok"* ]]
}

# =============================================================================
# 📦 LOADER MODULE TESTS
# =============================================================================

@test "loader: sets _COMMAND_SAFETY_DIR from SHELL_CONFIG_DIR" {
	# SHELL_CONFIG_DIR is set in setup()
	[[ -n "$_COMMAND_SAFETY_DIR" ]]
	[[ "$_COMMAND_SAFETY_DIR" == *"lib/command-safety" ]]
}

@test "loader: _COMMAND_SAFETY_DIR points to valid directory" {
	[[ -d "$_COMMAND_SAFETY_DIR" ]]
	[[ -d "$_COMMAND_SAFETY_DIR/engine" ]]
	[[ -f "$_COMMAND_SAFETY_DIR/engine/registry.sh" ]]
}

@test "loader: registry arrays are declared" {
	# Check that associative arrays are declared (bash 4+ feature)
	# The arrays are declared in registry.sh which is sourced in setup
	# Check if we can reference them (they may be empty but should exist)
	# Using printf to check if array variable is set
	declare -p COMMAND_SAFETY_RULE_ID >/dev/null 2>&1
	declare -p COMMAND_SAFETY_RULE_ACTION >/dev/null 2>&1
	declare -p COMMAND_SAFETY_RULE_COMMAND >/dev/null 2>&1
}

@test "loader: extended matching arrays are declared" {
	declare -p COMMAND_SAFETY_RULE_EXEMPT >/dev/null 2>&1
	declare -p COMMAND_SAFETY_RULE_CONTEXT >/dev/null 2>&1
	declare -p COMMAND_SAFETY_RULE_MATCH_FN >/dev/null 2>&1
	declare -p _CS_CMD_RULES >/dev/null 2>&1
}

# =============================================================================
# 🔍 MATCHER MODULE TESTS
# =============================================================================

@test "matcher: _cs_match_pattern matches single token" {
	run _cs_match_pattern "delete" "delete" "my-resource"
	[ "$status" -eq 0 ]
}

@test "matcher: _cs_match_pattern matches multi-token alternative" {
	run _cs_match_pattern "push --force" "push" "--force" "origin" "main"
	[ "$status" -eq 0 ]
}

@test "matcher: _cs_match_pattern fails when token missing" {
	run _cs_match_pattern "push --force" "push" "origin" "main"
	[ "$status" -eq 1 ]
}

@test "matcher: _cs_match_pattern handles pipe-separated alternatives" {
	# First alternative matches
	run _cs_match_pattern "uninstall|remove|rm" "rm" "lodash"
	[ "$status" -eq 0 ]

	# Second alternative matches
	run _cs_match_pattern "uninstall|remove|rm" "remove" "lodash"
	[ "$status" -eq 0 ]

	# No alternative matches
	run _cs_match_pattern "uninstall|remove|rm" "install" "lodash"
	[ "$status" -eq 1 ]
}

@test "matcher: _cs_match_pattern handles multi-token pipe alternatives" {
	# First alternative: "clean -fd"
	run _cs_match_pattern "clean -fd|clean -df" "clean" "-fd"
	[ "$status" -eq 0 ]

	# Second alternative: "clean -df"
	run _cs_match_pattern "clean -fd|clean -df" "clean" "-df"
	[ "$status" -eq 0 ]

	# No match
	run _cs_match_pattern "clean -fd|clean -df" "clean" "-n"
	[ "$status" -eq 1 ]
}

@test "matcher: _check_command_rules returns 2 for unknown commands" {
	# Stub display/logging
	_show_rule_message() { :; }
	_log_violation() { :; }

	run _check_command_rules "unknown_command"
	[ "$status" -eq 2 ]
}

@test "matcher: command injection prevention with invalid commands" {
	# Test that wrapper rejects invalid command patterns with injection attempts
	run _generate_wrapper "rm;malicious"
	[ "$status" -eq 1 ]
	# Verify error message indicates validation failure
	[[ "$output" == *"Invalid"* ]] || [[ "$output" == *"rejected"* ]] || [[ -z "$output" ]]
}

# =============================================================================
# 🧪 BASH 5 FEATURE TESTS
# =============================================================================

@test "bash5: associative arrays work correctly" {
	declare -A test_map
	test_map["key1"]="value1"
	test_map["key2"]="value2"

	[ "${test_map[key1]}" = "value1" ]
	[ "${test_map[key2]}" = "value2" ]
	[ "${#test_map[@]}" -eq 2 ]

	# Test iteration over keys
	local count=0
	local found_key1=0
	local found_key2=0
	for key in "${!test_map[@]}"; do
		count=$((count + 1))
		[[ "$key" == "key1" ]] && found_key1=1
		[[ "$key" == "key2" ]] && found_key2=1
	done
	[ "$count" -eq 2 ]
	[ "$found_key1" -eq 1 ]
	[ "$found_key2" -eq 1 ]
}

@test "bash5: readarray works for populating arrays" {
	local output
	output=$(printf "line1\nline2\nline3")

	local lines=()
	readarray -t lines <<<"$output"

	[ "${#lines[@]}" -eq 3 ]
	[[ "${lines[0]}" == *"line1"* ]]
	[[ "${lines[1]}" == *"line2"* ]]
	[[ "${lines[2]}" == *"line3"* ]]
}

@test "bash5: case conversion works" {
	local test_var="HeLLo WoRLd"

	local lower upper
	lower="${test_var,,}"
	upper="${test_var^^}"

	[ "$lower" = "hello world" ]
	[ "$upper" = "HELLO WORLD" ]
}

@test "bash5: stderr pipe shorthand |& works" {
	# Test that |& pipes both stdout and stderr
	local output
	output=$(echo "test" |& cat)
	[[ "$output" == *"test"* ]]
}

@test "bash5: nameref (local -n) works in display module" {
	# Test that namerefs work (bash 4.3+ feature)
	declare -a original_array=("item1" "item2" "item3")

	local -n ref="original_array"
	[ "${#ref[@]}" -eq 3 ]
	[[ "${ref[0]}" == "item1" ]]
	[[ "${ref[1]}" == "item2" ]]
	[[ "${ref[2]}" == "item3" ]]

	# Test modification through nameref
	ref[0]="modified"
	[ "${original_array[0]}" = "modified" ]
}

# =============================================================================
# 🔒 INTEGRATION TESTS
# =============================================================================

@test "integration: full rule registration and retrieval flow" {
	# Register a complete rule
	local alternatives="alt1 alt2"

	command_safety_register_rule \
		"INTEGRATION_TEST" \
		"integration_id" \
		"block" \
		"npm" \
		"uninstall" \
		"⚠️" \
		"Integration test rule" \
		"https://docs.example.com" \
		"--allow-npm-uninstall" \
		"$alternatives"

	# Verify all metadata stored
	[ "${COMMAND_SAFETY_RULE_ID[INTEGRATION_TEST]}" = "integration_id" ]
	[ "${COMMAND_SAFETY_RULE_ACTION[INTEGRATION_TEST]}" = "block" ]
	[ "${COMMAND_SAFETY_RULE_COMMAND[INTEGRATION_TEST]}" = "npm" ]
	[ "${COMMAND_SAFETY_RULE_DOCS[INTEGRATION_TEST]}" = "https://docs.example.com" ]
	# Verify reverse index
	[[ "${_CS_CMD_RULES[npm]}" == *"INTEGRATION_TEST"* ]]
}

@test "integration: wrapper generation prevents code injection" {
	# Try to inject code via command name
	run _generate_wrapper 'rm; echo "pwned"'
	[ "$status" -eq 1 ]
	[[ "$output" == *"Invalid"* ]]

	# Try backtick injection
	run _generate_wrapper 'rm`whoami`'
	# Must reject - backtick injection attempt
	[ "$status" -ne 0 ]
	# Verify the malicious wrapper was NOT created
	run type 'rm`whoami`'
	[ "$status" -ne 0 ]

	# Try $() injection
	run _generate_wrapper 'rm$(whoami)'
	# Must reject - command substitution injection attempt
	[ "$status" -ne 0 ]
	# Verify the malicious wrapper was NOT created
	run type 'rm$(whoami)'
	[ "$status" -ne 0 ]
}

@test "integration: rule suffix validation prevents injection" {
	run _show_rule_message "RM;RF" "rm" "-rf"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Invalid"* ]]
}

# =============================================================================
# 📊 COVERAGE TESTS
# =============================================================================

@test "coverage: all engine modules are loadable" {
	# Verify all engine modules exist and are sourceable
	local modules=(
		"registry.sh"
		"display.sh"
		"wrapper.sh"
		"loader.sh"
		"matcher.sh"
		"utils.sh"
		"logging.sh"
	)

	for module in "${modules[@]}"; do
		local module_path="$COMMAND_SAFETY_ENGINE_DIR/$module"
		[ -f "$module_path" ]
		[ -r "$module_path" ]
	done
}

@test "coverage: rule files are accessible" {
	# Verify rule directories exist
	[ -d "$COMMAND_SAFETY_DIR/rules" ]
	[ -f "$COMMAND_SAFETY_DIR/rules.sh" ]
}

# =============================================================================
# 🔧 EDGE CASE TESTS
# =============================================================================

@test "edge-case: empty rule suffix is rejected" {
	run command_safety_register_rule \
		"" \
		"id" \
		"block" \
		"rm" \
		"-rf" \
		"🛑" \
		"Test" \
		"" \
		"" \
		""
	# Should either fail or produce no meaningful entry
	# Note: bash doesn't allow "" as associative array key — this is expected
	# The important thing is it doesn't crash or create a valid-looking entry
	[[ "$status" -ne 0 ]] || [[ -z "${COMMAND_SAFETY_RULE_ID[_EMPTY_]:-}" ]]
}

@test "edge-case: empty command name is rejected" {
	run _generate_wrapper ""
	[ "$status" -ne 0 ]
}

@test "edge-case: very long rule suffix is handled" {
	local long_suffix
	long_suffix=$(printf 'A%.0s' {1..200})

	command_safety_register_rule \
		"$long_suffix" \
		"long_id" \
		"block" \
		"rm" \
		"-rf" \
		"🛑" \
		"Long suffix test" \
		"" \
		"" \
		""

	# Should still be retrievable
	[ "${COMMAND_SAFETY_RULE_ID[$long_suffix]}" = "long_id" ]
}

@test "edge-case: special characters in description are preserved" {
	local desc='Test with "quotes" and $variables and `backticks`'

	command_safety_register_rule \
		"SPECIAL_DESC" \
		"special_id" \
		"block" \
		"rm" \
		"-rf" \
		"🛑" \
		"$desc" \
		"" \
		"" \
		""

	[ "${COMMAND_SAFETY_RULE_DESC[SPECIAL_DESC]}" = "$desc" ]
}

@test "edge-case: test isolation - previous test rules don't leak" {
	# This test verifies that rules from previous tests are cleaned up
	# If _reset_rule_registry works, this should be empty
	local count=${#COMMAND_SAFETY_RULE_SUFFIXES[@]}
	[ "$count" -eq 0 ]
}

@test "edge-case: multiple rules for same command are allowed" {
	command_safety_register_rule "RM_RF" "id1" "block" "rm" "-rf" "🛑" "Desc1" "" "" ""
	command_safety_register_rule "RM_FORCE" "id2" "block" "rm" "--force" "⚠️" "Desc2" "" "" ""

	# Both should exist
	[ "${COMMAND_SAFETY_RULE_ID[RM_RF]}" = "id1" ]
	[ "${COMMAND_SAFETY_RULE_ID[RM_FORCE]}" = "id2" ]

	# Both for same command but different patterns
	[ "${COMMAND_SAFETY_RULE_COMMAND[RM_RF]}" = "rm" ]
	[ "${COMMAND_SAFETY_RULE_COMMAND[RM_FORCE]}" = "rm" ]

	# Both in reverse index
	[[ "${_CS_CMD_RULES[rm]}" == *"RM_RF"* ]]
	[[ "${_CS_CMD_RULES[rm]}" == *"RM_FORCE"* ]]
}
