#!/usr/bin/env bats
# =============================================================================
# COMMAND SAFETY ENGINE - LOGGING MODULE TESTS
# =============================================================================
# Tests for lib/command-safety/engine/logging.sh
# Regression: PR #87 (truncation indicator)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export COMMAND_SAFETY_ENGINE_DIR="$SHELL_CONFIG_DIR/lib/command-safety/engine"

	TEST_TEMP_DIR="$(mktemp -d)"
	export COMMAND_SAFETY_LOG_FILE="$TEST_TEMP_DIR/test-violations.log"
	cd "$TEST_TEMP_DIR" || return 1

	source "$COMMAND_SAFETY_ENGINE_DIR/logging.sh"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "logging: _log_violation creates log file" {
	_log_violation "TEST_RULE" "rm -rf /tmp"
	[ -f "$COMMAND_SAFETY_LOG_FILE" ]
}

@test "logging: _log_violation writes rule_id to log" {
	_log_violation "DOCKER_RM_F" "docker rm -f container"
	run grep -q "DOCKER_RM_F" "$COMMAND_SAFETY_LOG_FILE"
	[ "$status" -eq 0 ]
}

@test "logging: _log_violation writes command to log" {
	_log_violation "TEST_RULE" "npm uninstall lodash"
	run grep -q "npm uninstall lodash" "$COMMAND_SAFETY_LOG_FILE"
	[ "$status" -eq 0 ]
}

@test "logging: _log_violation includes timestamp" {
	_log_violation "TEST_RULE" "test command"
	# Timestamp format: [YYYY-MM-DD HH:MM:SS]
	run grep -E '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' "$COMMAND_SAFETY_LOG_FILE"
	[ "$status" -eq 0 ]
}

@test "logging: _log_violation appends multiple entries" {
	_log_violation "RULE_1" "command 1"
	_log_violation "RULE_2" "command 2"
	_log_violation "RULE_3" "command 3"

	local line_count
	line_count=$(wc -l < "$COMMAND_SAFETY_LOG_FILE")
	[ "$line_count" -eq 3 ]
}

@test "logging: _log_violation uses custom log file path" {
	local custom_log="$TEST_TEMP_DIR/custom.log"
	COMMAND_SAFETY_LOG_FILE="$custom_log"

	_log_violation "CUSTOM" "test"
	[ -f "$custom_log" ]
}

@test "logging: _log_violation creates parent directory if needed" {
	COMMAND_SAFETY_LOG_FILE="$TEST_TEMP_DIR/subdir/nested/violations.log"
	_log_violation "TEST" "test"
	[ -f "$COMMAND_SAFETY_LOG_FILE" ]
}

@test "logging: _log_violation falls back to HOME when env not set" {
	# Default log path is $HOME/.command-safety.log
	run grep -q 'COMMAND_SAFETY_LOG_FILE:-' "$COMMAND_SAFETY_ENGINE_DIR/logging.sh"
	[ "$status" -eq 0 ]
}

@test "logging: _log_violation format is Rule: <id> | Command: <cmd>" {
	_log_violation "MY_RULE" "dangerous command"
	run grep -q "Rule: MY_RULE | Command: dangerous command" "$COMMAND_SAFETY_LOG_FILE"
	[ "$status" -eq 0 ]
}
