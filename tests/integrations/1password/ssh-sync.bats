#!/usr/bin/env bats
# =============================================================================
# 1PASSWORD SSH SYNC TESTS
# =============================================================================
# Tests for lib/integrations/1password/ssh-sync.sh
# Regression: PR #78 (WHAT/WHY/FIX format), PR #95 (SSH status)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export SSH_SYNC_FILE="$SHELL_CONFIG_DIR/lib/integrations/1password/ssh-sync.sh"
}

@test "ssh-sync: file exists and is readable" {
	[ -f "$SSH_SYNC_FILE" ]
	[ -r "$SSH_SYNC_FILE" ]
}

@test "ssh-sync: valid bash syntax" {
	run bash -n "$SSH_SYNC_FILE"
	[ "$status" -eq 0 ]
}

@test "ssh-sync: uses strict mode" {
	run grep -q 'set -euo pipefail' "$SSH_SYNC_FILE"
	[ "$status" -eq 0 ]
}

@test "ssh-sync: sources protected-paths.sh for SSH_DIR constant" {
	run grep -q 'protected-paths.sh' "$SSH_SYNC_FILE"
	[ "$status" -eq 0 ]
}

@test "ssh-sync: uses PROTECTED_SSH_DIR constant" {
	run grep -q 'PROTECTED_SSH_DIR' "$SSH_SYNC_FILE"
	[ "$status" -eq 0 ]
}

@test "ssh-sync: supports --list flag" {
	run grep -q '\-\-list' "$SSH_SYNC_FILE"
	[ "$status" -eq 0 ]
}

@test "ssh-sync: supports --import flag" {
	run grep -q '\-\-import' "$SSH_SYNC_FILE"
	[ "$status" -eq 0 ]
}

@test "ssh-sync: checks for op command existence" {
	run grep -q 'command_exists.*op\|command -v.*op' "$SSH_SYNC_FILE"
	[ "$status" -eq 0 ]
}

@test "ssh-sync: uses OP_VAULT env var with default" {
	run grep -q 'OP_VAULT' "$SSH_SYNC_FILE"
	[ "$status" -eq 0 ]
}

@test "ssh-sync: sources shared colors library" {
	run grep -q 'colors.sh' "$SSH_SYNC_FILE"
	[ "$status" -eq 0 ]
}

@test "ssh-sync: defines log helper functions" {
	run grep -q '_log()' "$SSH_SYNC_FILE"
	[ "$status" -eq 0 ]
	run grep -q '_success()' "$SSH_SYNC_FILE"
	[ "$status" -eq 0 ]
	run grep -q '_error()' "$SSH_SYNC_FILE"
	[ "$status" -eq 0 ]
}

@test "ssh-sync: has command_exists fallback" {
	run grep -q 'declare -f command_exists' "$SSH_SYNC_FILE"
	[ "$status" -eq 0 ]
}
