#!/usr/bin/env bats
# =============================================================================
# 1PASSWORD LOGIN TESTS
# =============================================================================
# Tests for lib/integrations/1password/login.sh
# Regression: PR #78 (WHAT/WHY/FIX format)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export LOGIN_FILE="$SHELL_CONFIG_DIR/lib/integrations/1password/login.sh"
}

@test "1password login: file exists and is readable" {
	[ -f "$LOGIN_FILE" ]
	[ -r "$LOGIN_FILE" ]
}

@test "1password login: valid bash syntax" {
	run bash -n "$LOGIN_FILE"
	[ "$status" -eq 0 ]
}

@test "1password login: uses strict mode" {
	run grep -q 'set -euo pipefail' "$LOGIN_FILE"
	[ "$status" -eq 0 ]
}

@test "1password login: checks for existing login with op whoami" {
	run grep -q 'op whoami' "$LOGIN_FILE"
	[ "$status" -eq 0 ]
}

@test "1password login: uses op account list for account detection" {
	run grep -q 'op account list' "$LOGIN_FILE"
	[ "$status" -eq 0 ]
}

@test "1password login: uses op signin for authentication" {
	run grep -q 'op signin' "$LOGIN_FILE"
	[ "$status" -eq 0 ]
}

@test "1password login: exports session token to OP_SESSION_ var" {
	run grep -q 'OP_SESSION_' "$LOGIN_FILE"
	[ "$status" -eq 0 ]
}

@test "1password login: provides error message on no account" {
	run grep -q 'No 1Password account found' "$LOGIN_FILE"
	[ "$status" -eq 0 ]
}

@test "1password login: provides error message on failed sign in" {
	run grep -q 'Failed to sign in' "$LOGIN_FILE"
	[ "$status" -eq 0 ]
}

@test "1password login: suggests biometric/Touch ID" {
	run grep -qi 'biometric\|Touch ID' "$LOGIN_FILE"
	[ "$status" -eq 0 ]
}
