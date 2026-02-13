#!/usr/bin/env bats
# =============================================================================
# CAT INTEGRATION TESTS
# =============================================================================
# Tests for cat integration and configuration
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

@test "cat: integrations/cat.sh exists and is readable" {
	[ -f "$INTEGRATIONS_DIR/cat.sh" ]
	[ -r "$INTEGRATIONS_DIR/cat.sh" ]
}

@test "cat: integrations/cat.sh sources without errors" {
	run bash -c "source '$INTEGRATIONS_DIR/cat.sh'"
	[ "$status" -eq 0 ]
}

@test "cat: integrations/cat.sh defines cat function" {
	run grep -q "^cat()" "$INTEGRATIONS_DIR/cat.sh"
	[ "$status" -eq 0 ]
}

@test "cat: integrations/cat.sh checks for bat command" {
	run grep -qE "(command_exists.*bat|command -v bat|which bat|type bat)" "$INTEGRATIONS_DIR/cat.sh"
	[ "$status" -eq 0 ]
}

@test "cat: integrations/cat.sh checks for ccat command" {
	run grep -qE "(command_exists.*ccat|command -v ccat|which ccat|type ccat)" "$INTEGRATIONS_DIR/cat.sh"
	[ "$status" -eq 0 ]
}

@test "cat: integrations/cat.sh checks for pygmentize command" {
	run grep -qE "(command_exists.*pygmentize|command -v pygmentize|which pygmentize|type pygmentize)" "$INTEGRATIONS_DIR/cat.sh"
	[ "$status" -eq 0 ]
}

@test "cat: integrations/cat.sh has fallback to standard cat" {
	# Must fall back to standard cat when no highlighting tools available
	run grep -q "command cat" "$INTEGRATIONS_DIR/cat.sh"
	[ "$status" -eq 0 ]
}
