#!/usr/bin/env bats
# =============================================================================
# GIT HOOK CHECK TESTS
# =============================================================================
# Tests for lib/git/shared/hook-check.sh
# Regression: PR #131 (hooks refactor), PR #95 (SSH status)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export HOOK_CHECK_FILE="$SHELL_CONFIG_DIR/lib/git/shared/hook-check.sh"

	TEST_TEMP_DIR="$(mktemp -d)"
	export HOME="$TEST_TEMP_DIR/fakehome"
	mkdir -p "$HOME/.githooks"
	cd "$TEST_TEMP_DIR" || return 1

	# Reset load guard so we can re-source
	unset _HOOK_CHECK_LOADED
	source "$HOOK_CHECK_FILE"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "hook-check: file exists and is readable" {
	[ -f "$HOOK_CHECK_FILE" ]
	[ -r "$HOOK_CHECK_FILE" ]
}

@test "hook-check: valid bash syntax" {
	run bash -n "$HOOK_CHECK_FILE"
	[ "$status" -eq 0 ]
}

@test "hook-check: has idempotent load guard" {
	run grep -q '_HOOK_CHECK_LOADED' "$HOOK_CHECK_FILE"
	[ "$status" -eq 0 ]
}

@test "hook-check: check_hook_symlink returns missing for nonexistent hook" {
	run check_hook_symlink "nonexistent-hook"
	[ "$status" -eq 0 ]
	[ "$output" = "missing" ]
}

@test "hook-check: check_hook_symlink returns file_not_symlink for regular file" {
	touch "$HOME/.githooks/test-hook"
	chmod +x "$HOME/.githooks/test-hook"
	run check_hook_symlink "test-hook"
	[ "$status" -eq 0 ]
	[ "$output" = "file_not_symlink" ]
}

@test "hook-check: check_hook_symlink returns valid for correct symlink" {
	# Create a fake shell-config hook target
	local target_dir="$TEST_TEMP_DIR/shell-config/lib/git/hooks"
	mkdir -p "$target_dir"
	touch "$target_dir/pre-commit"
	ln -sf "$target_dir/pre-commit" "$HOME/.githooks/pre-commit"

	run check_hook_symlink "pre-commit"
	[ "$status" -eq 0 ]
	[ "$output" = "valid" ]
}

@test "hook-check: check_hook_symlink returns wrong_target for bad symlink" {
	# Target must exist for -e to pass; create a real file that's not shell-config
	touch "$TEST_TEMP_DIR/other-hook"
	ln -sf "$TEST_TEMP_DIR/other-hook" "$HOME/.githooks/pre-commit"
	run check_hook_symlink "pre-commit"
	[ "$status" -eq 0 ]
	[ "$output" = "wrong_target" ]
}

@test "hook-check: get_standard_hooks returns 7 hooks" {
	local count
	count=$(get_standard_hooks | wc -l)
	[ "$count" -eq 7 ]
}

@test "hook-check: get_standard_hooks includes pre-commit" {
	run get_standard_hooks
	[[ "$output" == *"pre-commit"* ]]
}

@test "hook-check: get_standard_hooks includes all expected hooks" {
	local hooks
	hooks=$(get_standard_hooks)
	[[ "$hooks" == *"pre-commit"* ]]
	[[ "$hooks" == *"commit-msg"* ]]
	[[ "$hooks" == *"prepare-commit-msg"* ]]
	[[ "$hooks" == *"post-commit"* ]]
	[[ "$hooks" == *"pre-push"* ]]
	[[ "$hooks" == *"pre-merge-commit"* ]]
	[[ "$hooks" == *"post-merge"* ]]
}

@test "hook-check: check_hooks_batch returns count of valid hooks" {
	# No hooks installed = 0 valid
	run check_hooks_batch
	[ "$status" -eq 0 ]
	[ "$output" = "0" ]
}

@test "hook-check: check_hooks_batch counts valid symlinks" {
	# Install one valid hook
	local target_dir="$TEST_TEMP_DIR/shell-config/lib/git/hooks"
	mkdir -p "$target_dir"
	touch "$target_dir/pre-commit"
	ln -sf "$target_dir/pre-commit" "$HOME/.githooks/pre-commit"

	run check_hooks_batch "pre-commit"
	[ "$output" = "1" ]
}

@test "hook-check: no set -euo pipefail (sourced into interactive shells)" {
	# This file is sourced by welcome/git-hooks-status.sh into interactive shells
	# Check for actual command (not comment) - line must start with set
	run grep -E '^set -euo pipefail' "$HOOK_CHECK_FILE"
	[ "$status" -ne 0 ]
}
