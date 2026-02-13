#!/usr/bin/env bats
# =============================================================================
# WELCOME SHELL STARTUP TIME TESTS
# =============================================================================
# Tests for lib/welcome/shell-startup-time.sh
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export STARTUP_FILE="$SHELL_CONFIG_DIR/lib/welcome/shell-startup-time.sh"
}

@test "startup-time: file exists and is readable" {
	[ -f "$STARTUP_FILE" ]
	[ -r "$STARTUP_FILE" ]
}

@test "startup-time: valid bash syntax" {
	run bash -n "$STARTUP_FILE"
	[ "$status" -eq 0 ]
}

@test "startup-time: defines _welcome_show_shell_startup_time function" {
	run grep -q '_welcome_show_shell_startup_time()' "$STARTUP_FILE"
	[ "$status" -eq 0 ]
}

@test "startup-time: uses WELCOME_SHELL_STARTUP_TIME toggle" {
	run grep -q 'WELCOME_SHELL_STARTUP_TIME' "$STARTUP_FILE"
	[ "$status" -eq 0 ]
}

@test "startup-time: uses SHELL_CONFIG_START_TIME for timing" {
	run grep -q 'SHELL_CONFIG_START_TIME' "$STARTUP_FILE"
	[ "$status" -eq 0 ]
}

@test "startup-time: has three performance tiers" {
	# <200ms = Excellent, <400ms = Good, ≥400ms = Slow
	run grep -q 'Excellent' "$STARTUP_FILE"
	[ "$status" -eq 0 ]
	run grep -q 'Good' "$STARTUP_FILE"
	[ "$status" -eq 0 ]
	run grep -q 'Slow' "$STARTUP_FILE"
	[ "$status" -eq 0 ]
}

@test "startup-time: uses perl for millisecond precision" {
	run grep -q 'perl.*Time::HiRes' "$STARTUP_FILE"
	[ "$status" -eq 0 ]
}

@test "startup-time: validates numeric values before calculation" {
	run grep -q 'end_time.*=~.*\^' "$STARTUP_FILE"
	[ "$status" -eq 0 ]
}

@test "startup-time: sanity checks elapsed_ms bounds" {
	# Prevents display of negative or >60s values
	run grep -q '60000' "$STARTUP_FILE"
	[ "$status" -eq 0 ]
}

@test "startup-time: shows optimization hint when slow" {
	run grep -q 'hyperfine' "$STARTUP_FILE"
	[ "$status" -eq 0 ]
}

@test "startup-time: has command_exists fallback" {
	run grep -q 'declare -f command_exists' "$STARTUP_FILE"
	[ "$status" -eq 0 ]
}
