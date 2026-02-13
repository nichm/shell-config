#!/usr/bin/env bats
# =============================================================================
# GIT AUDIT LOGGING TESTS
# =============================================================================
# Tests for lib/git/shared/audit-logging.sh
# Regression: PR #87 (dead code removal)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export AUDIT_FILE="$SHELL_CONFIG_DIR/lib/git/shared/audit-logging.sh"

	TEST_TEMP_DIR="$(mktemp -d)"
	export HOME="$TEST_TEMP_DIR/fakehome"
	mkdir -p "$HOME"
	cd "$TEST_TEMP_DIR" || return 1

	source "$AUDIT_FILE"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "audit-logging: file exists and is readable" {
	[ -f "$AUDIT_FILE" ]
	[ -r "$AUDIT_FILE" ]
}

@test "audit-logging: valid bash syntax" {
	run bash -n "$AUDIT_FILE"
	[ "$status" -eq 0 ]
}

@test "audit-logging: defines _log_bypass function" {
	run type -t _log_bypass
	[ "$status" -eq 0 ]
	[ "$output" = "function" ]
}

@test "audit-logging: _log_bypass creates audit log file" {
	_log_bypass "--no-verify" "push origin main"
	[ -f "$HOME/.shell-config-audit.log" ]
}

@test "audit-logging: _log_bypass writes bypass flag" {
	_log_bypass "--no-verify" "push origin main"
	run grep -q "BYPASS: --no-verify" "$HOME/.shell-config-audit.log"
	[ "$status" -eq 0 ]
}

@test "audit-logging: _log_bypass writes command" {
	_log_bypass "--skip-secrets" "commit -m test"
	run grep -q "Command: git commit -m test" "$HOME/.shell-config-audit.log"
	[ "$status" -eq 0 ]
}

@test "audit-logging: _log_bypass writes CWD" {
	_log_bypass "--no-verify" "push"
	run grep -q "CWD:" "$HOME/.shell-config-audit.log"
	[ "$status" -eq 0 ]
}

@test "audit-logging: _log_bypass includes timestamp" {
	_log_bypass "--no-verify" "push"
	run grep -E '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' "$HOME/.shell-config-audit.log"
	[ "$status" -eq 0 ]
}

@test "audit-logging: _log_bypass appends multiple entries" {
	_log_bypass "--no-verify" "push"
	_log_bypass "--skip-secrets" "commit"
	_log_bypass "--allow-large-files" "add"

	local line_count
	line_count=$(wc -l < "$HOME/.shell-config-audit.log")
	[ "$line_count" -eq 3 ]
}

@test "audit-logging: no set -euo pipefail (sourced into interactive shells)" {
	# Check for actual command (not in a comment) - line must start with set
	run grep -E '^set -euo pipefail' "$AUDIT_FILE"
	[ "$status" -ne 0 ]
}
