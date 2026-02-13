#!/usr/bin/env bats
# =============================================================================
# FZF INTEGRATION TESTS
# =============================================================================
# Tests for fzf integration and configuration
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export INTEGRATIONS_DIR="$SHELL_CONFIG_DIR/lib/integrations"

	# Create temp directory for test artifacts
	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1
}

teardown() {
	# Return to safe directory before cleanup (prevents getcwd errors)
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "fzf: integrations/fzf.sh exists and is readable" {
	[ -f "$INTEGRATIONS_DIR/fzf.sh" ]
	[ -r "$INTEGRATIONS_DIR/fzf.sh" ]
}

@test "fzf: integrations/fzf.sh sources without errors" {
	run bash -c "source '$INTEGRATIONS_DIR/fzf.sh'"
	[ "$status" -eq 0 ]
}

@test "fzf: integrations/fzf.sh references fzf command" {
	# Must reference fzf command - this is a required feature
	run grep -q "fzf" "$INTEGRATIONS_DIR/fzf.sh"
	[ "$status" -eq 0 ]
}

@test "fzf: integrations/fzf.sh has error handling for missing fzf" {
	# Must check if fzf is installed before using - required error handling
	run grep -qE "(command_exists.*fzf|command -v fzf|which fzf|type fzf)" "$INTEGRATIONS_DIR/fzf.sh"
	[ "$status" -eq 0 ]
}

@test "fzf: integrations/fzf.sh defines fe function" {
	run grep -q "^fe()" "$INTEGRATIONS_DIR/fzf.sh"
	[ "$status" -eq 0 ]
}

@test "fzf: integrations/fzf.sh defines fcd function" {
	run grep -q "^fcd()" "$INTEGRATIONS_DIR/fzf.sh"
	[ "$status" -eq 0 ]
}

@test "fzf: integrations/fzf.sh defines fh function" {
	run grep -q "^fh()" "$INTEGRATIONS_DIR/fzf.sh"
	[ "$status" -eq 0 ]
}

@test "fzf: integrations/fzf.sh defines fkill function" {
	run grep -q "^fkill()" "$INTEGRATIONS_DIR/fzf.sh"
	[ "$status" -eq 0 ]
}

@test "fzf: integrations/fzf.sh defines fbr function" {
	run grep -q "^fbr()" "$INTEGRATIONS_DIR/fzf.sh"
	[ "$status" -eq 0 ]
}

@test "fzf: integrations/fzf.sh defines fstash function" {
	run grep -q "^fstash()" "$INTEGRATIONS_DIR/fzf.sh"
	[ "$status" -eq 0 ]
}
