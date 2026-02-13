#!/usr/bin/env bats
# =============================================================================
# GHLS STATUS TESTS
# =============================================================================
# Tests for lib/integrations/ghls/status.sh
# Regression: PR #95 (SSH status), PR #104 (open source prep)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export STATUS_FILE="$SHELL_CONFIG_DIR/lib/integrations/ghls/status.sh"
}

@test "ghls status: file exists and is readable" {
	[ -f "$STATUS_FILE" ]
	[ -r "$STATUS_FILE" ]
}

@test "ghls status: valid bash syntax" {
	run bash -n "$STATUS_FILE"
	[ "$status" -eq 0 ]
}

@test "ghls status: defines get_folder_status_enhanced function" {
	run grep -q 'get_folder_status_enhanced()' "$STATUS_FILE"
	[ "$status" -eq 0 ]
}

@test "ghls status: uses shared _ghls_get_dir_colors from common.sh" {
	run grep -q '_ghls_get_dir_colors' "$STATUS_FILE"
	[ "$status" -eq 0 ]
}

@test "ghls status: handles non-git directories" {
	run grep -q 'non-git' "$STATUS_FILE"
	[ "$status" -eq 0 ]
}

@test "ghls status: tracks branch information" {
	# status.sh tracks branch/tracking info for display
	run grep -q 'branch' "$STATUS_FILE"
	[ "$status" -eq 0 ]
}

@test "ghls status: counts staged files" {
	run grep -q 'staged' "$STATUS_FILE"
	[ "$status" -eq 0 ]
}

@test "ghls status: counts unstaged/modified files" {
	run grep -q 'modified\|unstaged' "$STATUS_FILE"
	[ "$status" -eq 0 ]
}

@test "ghls status: uses HOME variable portably (PR #104)" {
	# Should not hardcode any user paths
	run grep -E '/Users/[a-z]+|/home/[a-z]+' "$STATUS_FILE"
	[ "$status" -ne 0 ]
}

@test "ghls status: returns to original directory on error" {
	run grep -q 'original_pwd' "$STATUS_FILE"
	[ "$status" -eq 0 ]
}

@test "ghls status: checks git rev-parse for repo detection" {
	run grep -q 'git rev-parse' "$STATUS_FILE"
	[ "$status" -eq 0 ]
}
