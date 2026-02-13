#!/usr/bin/env bats
# =============================================================================
# RIPGREP INTEGRATION TESTS
# =============================================================================
# Tests for ripgrep integration and configuration
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

@test "ripgrep: integrations/ripgrep.sh exists and is readable" {
	[ -f "$INTEGRATIONS_DIR/ripgrep.sh" ]
	[ -r "$INTEGRATIONS_DIR/ripgrep.sh" ]
}

@test "ripgrep: integrations/ripgrep.sh sources without errors" {
	run bash -c "source '$INTEGRATIONS_DIR/ripgrep.sh'"
	[ "$status" -eq 0 ]
}

@test "ripgrep: integrations/ripgrep.sh references ripgrep command" {
	# Must reference rg command - this is a required feature
	run grep -q "rg" "$INTEGRATIONS_DIR/ripgrep.sh"
	[ "$status" -eq 0 ]
}

@test "ripgrep: integrations/ripgrep.sh has error handling for missing ripgrep" {
	# Must check if rg is installed before using - required error handling
	run grep -qE "(command_exists.*rg|command -v rg|which rg|type rg)" "$INTEGRATIONS_DIR/ripgrep.sh"
	[ "$status" -eq 0 ]
}
