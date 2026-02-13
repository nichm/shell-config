#!/usr/bin/env bats
# =============================================================================
# EZA INTEGRATION TESTS
# =============================================================================
# Tests for eza integration and configuration
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export INTEGRATIONS_DIR="$SHELL_CONFIG_DIR/lib/integrations"

	# Create temp directory (cleanup in teardown, not EXIT trap which interferes with bats)
	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "eza: integrations/eza.sh exists and is readable" {
	[ -f "$INTEGRATIONS_DIR/eza.sh" ]
	[ -r "$INTEGRATIONS_DIR/eza.sh" ]
}

@test "eza: integrations/eza.sh sources without errors" {
	run bash -c "source '$INTEGRATIONS_DIR/eza.sh'"
	[ "$status" -eq 0 ]
}

@test "eza: integrations/eza.sh references eza command" {
	# Must reference eza command - this is a required feature
	run grep -q "eza" "$INTEGRATIONS_DIR/eza.sh"
	[ "$status" -eq 0 ]
}

@test "eza: integrations/eza.sh has error handling for missing eza" {
	# Must check if eza is installed before using - required error handling
	run grep -qE "(command_exists.*eza|command -v eza|which eza|type eza)" "$INTEGRATIONS_DIR/eza.sh"
	[ "$status" -eq 0 ]
}
