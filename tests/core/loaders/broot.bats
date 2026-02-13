#!/usr/bin/env bats
# =============================================================================
# BROOT LOADER TESTS
# =============================================================================
# Tests for broot loader and configuration
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export LOADERS_DIR="$SHELL_CONFIG_DIR/lib/core/loaders"

	# Create temp directory for test artifacts
	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1
}

teardown() {
	# Return to safe directory before cleanup (prevents getcwd errors)
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "broot: loaders/broot.sh exists and is readable" {
	[ -f "$LOADERS_DIR/broot.sh" ]
	[ -r "$LOADERS_DIR/broot.sh" ]
}

@test "broot: loaders/broot.sh sources without errors" {
	run bash -c "source '$LOADERS_DIR/broot.sh'"
	[ "$status" -eq 0 ]
}

@test "broot: loaders/broot.sh references broot command" {
	# Must reference broot command - this is a required feature
	run grep -q "broot" "$LOADERS_DIR/broot.sh"
	[ "$status" -eq 0 ]
}

@test "broot: loaders/broot.sh has error handling for missing broot" {
	# Must check if broot is installed before using - required error handling
	run grep -qE "(command_exists.*broot|command -v broot|which broot|type broot)" "$LOADERS_DIR/broot.sh"
	[ "$status" -eq 0 ]
}

@test "broot: loaders/broot.sh defines br function" {
	run grep -q "^br()" "$LOADERS_DIR/broot.sh"
	[ "$status" -eq 0 ]
}
