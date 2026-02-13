#!/usr/bin/env bats
# =============================================================================
# COMMAND SAFETY ENGINE - UTILS MODULE TESTS
# =============================================================================
# Tests for lib/command-safety/engine/utils.sh
# Regression: PR #87 (dead code removal), PR #98 (regex to string ops)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export COMMAND_SAFETY_ENGINE_DIR="$SHELL_CONFIG_DIR/lib/command-safety/engine"

	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	# Source utils module
	source "$COMMAND_SAFETY_ENGINE_DIR/utils.sh"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

# =============================================================================
# _has_bypass_flag tests
# =============================================================================

@test "utils: _has_bypass_flag finds matching flag" {
	run _has_bypass_flag "--force-delete" "rm" "-rf" "--force-delete" "/tmp/foo"
	[ "$status" -eq 0 ]
}

@test "utils: _has_bypass_flag returns 1 when flag not present" {
	run _has_bypass_flag "--force-delete" "rm" "-rf" "/tmp/foo"
	[ "$status" -eq 1 ]
}

@test "utils: _has_bypass_flag handles empty args" {
	run _has_bypass_flag "--force-delete"
	[ "$status" -eq 1 ]
}

@test "utils: _has_bypass_flag finds flag at end of args" {
	run _has_bypass_flag "--skip" "a" "b" "c" "--skip"
	[ "$status" -eq 0 ]
}

@test "utils: _has_bypass_flag finds flag at start of args" {
	run _has_bypass_flag "--skip" "--skip" "a" "b"
	[ "$status" -eq 0 ]
}

@test "utils: _has_bypass_flag does not match partial flags" {
	run _has_bypass_flag "--force" "--force-all" "--force-delete"
	[ "$status" -eq 1 ]
}

# =============================================================================
# _has_danger_flags tests
# =============================================================================

@test "utils: _has_danger_flags detects -rf combined" {
	run _has_danger_flags "-rf" "/tmp"
	[ "$status" -eq 0 ]
}

@test "utils: _has_danger_flags detects -fr combined" {
	run _has_danger_flags "-fr" "/tmp"
	[ "$status" -eq 0 ]
}

@test "utils: _has_danger_flags detects separate -r and -f" {
	run _has_danger_flags "-r" "-f" "/tmp"
	[ "$status" -eq 0 ]
}

@test "utils: _has_danger_flags detects --recursive and --force" {
	run _has_danger_flags "--recursive" "--force" "/tmp"
	[ "$status" -eq 0 ]
}

@test "utils: _has_danger_flags returns 1 with only -r" {
	run _has_danger_flags "-r" "/tmp"
	[ "$status" -eq 1 ]
}

@test "utils: _has_danger_flags returns 1 with only -f" {
	run _has_danger_flags "-f" "/tmp"
	[ "$status" -eq 1 ]
}

@test "utils: _has_danger_flags returns 1 with no flags" {
	run _has_danger_flags "/tmp" "somefile"
	[ "$status" -eq 1 ]
}

@test "utils: _has_danger_flags handles empty args" {
	run _has_danger_flags
	[ "$status" -eq 1 ]
}

# =============================================================================
# _in_git_repo tests
# =============================================================================

@test "utils: _in_git_repo returns 0 in git repo" {
	cd "$BATS_TEST_DIRNAME/../../.." || return 1
	run _in_git_repo
	[ "$status" -eq 0 ]
}

@test "utils: _in_git_repo returns 1 outside git repo" {
	cd "$TEST_TEMP_DIR" || return 1
	run _in_git_repo
	[ "$status" -eq 1 ]
}

@test "utils: _in_git_repo caches result for same directory" {
	cd "$BATS_TEST_DIRNAME/../../.." || return 1
	_in_git_repo
	# Second call should use cache (same dir)
	local cached_dir="$_GIT_REPO_CACHED_DIR"
	_in_git_repo
	[ "$_GIT_REPO_CACHED_DIR" = "$cached_dir" ]
	[ "$_GIT_REPO_CACHE" = "1" ]
}

@test "utils: _in_git_repo invalidates cache on dir change" {
	cd "$BATS_TEST_DIRNAME/../../.." || return 1
	_in_git_repo
	[ "$_GIT_REPO_CACHE" = "1" ]

	cd "$TEST_TEMP_DIR" || return 1
	_in_git_repo || true
	[ "$_GIT_REPO_CACHE" = "" ]
}

# =============================================================================
# command_exists fallback
# =============================================================================

@test "utils: command_exists fallback is defined" {
	# utils.sh defines a fallback command_exists if not already declared
	run type -t command_exists
	[ "$status" -eq 0 ]
	[[ "$output" == "function" ]]
}

@test "utils: command_exists finds bash" {
	run command_exists "bash"
	[ "$status" -eq 0 ]
}

@test "utils: command_exists rejects nonexistent command" {
	run command_exists "nonexistent_command_xyz_12345"
	[ "$status" -eq 1 ]
}
