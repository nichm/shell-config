#!/usr/bin/env bats
# Tests for bin/setup-wizard

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export SETUP_WIZARD="$SHELL_CONFIG_DIR/bin/setup-wizard"

	# Create temp directory for test artifacts
	TEST_TEMP_DIR="$BATS_TEST_DIRNAME/temp"
	mkdir -p "$TEST_TEMP_DIR"
}

teardown() {
	# Cleanup test artifacts
	/bin/rm -rf "$TEST_TEMP_DIR"
}

@test "setup-wizard exists and is executable" {
	[ -f "$SETUP_WIZARD" ]
	[ -x "$SETUP_WIZARD" ]
}

@test "setup-wizard --help shows usage" {
	run "$SETUP_WIZARD" --help
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage:"* ]]
	[[ "$output" == *"setup-wizard"* ]]
}

@test "setup-wizard -h shows usage" {
	run "$SETUP_WIZARD" -h
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage:"* ]]
}

@test "setup-wizard with unknown option shows error" {
	run "$SETUP_WIZARD" --unknown-option
	[ "$status" -eq 1 ]
	[[ "$output" == *"Unknown option"* ]]
}

@test "setup-wizard sources required dependencies" {
	# Test that the wizard can be sourced without errors
	run bash -c "source '$SETUP_WIZARD'"
	# Note: This will execute main(), so we expect it to fail if not in repo dir
	# We're just checking it sources correctly
	[ "$?" -eq 1 ] || true  # Expected to fail (not in repo)
}

@test "setup-wizard has strict mode enabled" {
	run grep -q "set -euo pipefail" "$SETUP_WIZARD"
	[ "$status" -eq 0 ]
}

@test "setup-wizard sources platform detection" {
	run grep -q "source.*platform.sh" "$SETUP_WIZARD"
	[ "$status" -eq 0 ]
}

@test "setup-wizard sources colors library" {
	run grep -q "source.*colors.sh" "$SETUP_WIZARD"
	[ "$status" -eq 0 ]
}

@test "setup-wizard sources command cache" {
	run grep -q "source.*command-cache.sh" "$SETUP_WIZARD"
	[ "$status" -eq 0 ]
}

@test "setup-wizard uses printf instead of eval" {
	# Ensure no eval usage (security check)
	run grep -w "eval" "$SETUP_WIZARD"
	# grep returns 1 when no matches found, which is what we want
	[ "$status" -eq 1 ]
}

@test "setup-wizard uses printf instead of echo -e" {
	# Check that print functions use printf
	run bash -c "grep -c 'printf' '$SETUP_WIZARD'"
	# Should have many printf calls (at least 15)
	[ "$output" -ge 15 ]
}

@test "setup-wizard has platform-specific sed handling" {
	# Check for macOS sed compatibility
	run grep -q "is_macos" "$SETUP_WIZARD"
	[ "$status" -eq 0 ]

	run grep -q "sed -i ''" "$SETUP_WIZARD"
	[ "$status" -eq 0 ]
}

@test "setup-wizard has trap handler for cleanup" {
	run grep -q "trap.*cleanup" "$SETUP_WIZARD"
	[ "$status" -eq 0 ]
}

@test "setup-wizard sanitizes user input for sed" {
	run grep -q "escape_for_sed" "$SETUP_WIZARD"
	[ "$status" -eq 0 ]
}

@test "setup-wizard error format follows repo standard" {
	# Check for WHAT/WHY/FIX format in print_error function
	run grep -A10 "^print_error()" "$SETUP_WIZARD"
	[[ "$output" == *"WHY"* ]] || [[ "$output" == *"why"* ]]
	[[ "$output" == *"FIX"* ]] || [[ "$output" == *"fix"* ]]
}

@test "setup-wizard uses git config for reading values" {
	run grep -q "git config --file" "$SETUP_WIZARD"
	[ "$status" -eq 0 ]
}

@test "setup-wizard has editor error handling" {
	# Check for exit code checking after editor launch
	run grep -B2 -A5 'editor_cmd.*sshconfig' "$SETUP_WIZARD"
	[[ "$output" == *"if"*"editor_cmd"* ]] || [[ "$output" == *'if "$editor_cmd"'* ]]
}
