#!/usr/bin/env bats
# =============================================================================
# Tests for lib/git/stages/merge/post-merge.sh
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export POST_MERGE_LIB="$SHELL_CONFIG_DIR/lib/git/stages/merge/post-merge.sh"
	export TEST_TMP="$BATS_TEST_TMPDIR/post-merge-test"
	mkdir -p "$TEST_TMP"
}

teardown() {
	/bin/rm -rf "$TEST_TMP" 2>/dev/null || true
}

# =============================================================================
# LIBRARY LOADING
# =============================================================================

@test "post-merge library exists" {
	[ -f "$POST_MERGE_LIB" ]
}

@test "post-merge is valid bash syntax" {
	run bash -n "$POST_MERGE_LIB"
	[ "$status" -eq 0 ]
}

# =============================================================================
# FUNCTION DEFINITIONS
# =============================================================================

@test "run_post_merge_tasks function is defined" {
	run bash -c "
		log_info() { :; }
		export -f log_info
		source '$POST_MERGE_LIB'
		type run_post_merge_tasks
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# POST-MERGE TASKS
# =============================================================================

@test "run_post_merge_tasks succeeds without MERGE_HEAD" {
	run bash -c "
		log_info() { :; }
		export -f log_info
		source '$POST_MERGE_LIB'
		cd '$TEST_TMP'
		# No .git/MERGE_HEAD file
		run_post_merge_tasks 0
	"
	[ "$status" -eq 0 ]
}

@test "run_post_merge_tasks succeeds with squash merge flag" {
	run bash -c "
		log_info() { :; }
		export -f log_info
		source '$POST_MERGE_LIB'
		cd '$TEST_TMP'
		run_post_merge_tasks 1
	"
	[ "$status" -eq 0 ]
}

@test "run_post_merge_tasks handles MERGE_HEAD presence" {
	# Create a fake .git/MERGE_HEAD to simulate merge state
	mkdir -p "$TEST_TMP/.git"
	echo "abc123" >"$TEST_TMP/.git/MERGE_HEAD"

	run bash -c "
		log_info() { echo \"INFO: \$*\"; }
		export -f log_info
		source '$POST_MERGE_LIB'
		cd '$TEST_TMP'
		run_post_merge_tasks 0
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Merge completed"* ]]
}

@test "run_post_merge_tasks skips bun install for squash merge" {
	mkdir -p "$TEST_TMP/.git"
	echo "abc123" >"$TEST_TMP/.git/MERGE_HEAD"
	echo '{"dependencies":{}}' >"$TEST_TMP/package.json"

	run bash -c "
		log_info() { echo \"INFO: \$*\"; }
		export -f log_info
		# Mock bun to track if it gets called
		bun() { echo 'bun-called'; }
		export -f bun
		source '$POST_MERGE_LIB'
		cd '$TEST_TMP'
		run_post_merge_tasks 1
	"
	[ "$status" -eq 0 ]
	# Should NOT call bun for squash merges
	[[ "$output" != *"bun-called"* ]]
}
