#!/usr/bin/env bats
# Tests for lib/core/logging.sh - atomic writes and log rotation

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export LOGGING_LIB="$SHELL_CONFIG_DIR/lib/core/logging.sh"

	# Create temp directory for test logs
	export TEST_TMPDIR="$BATS_TEST_TMPDIR/logging_test"
	mkdir -p "$TEST_TMPDIR"
}

teardown() {
	# Return to safe directory before cleanup (prevents getcwd errors)
	cd "$BATS_TEST_DIRNAME" || true
	/bin/rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

@test "logging library exists" {
	[ -f "$LOGGING_LIB" ]
}

@test "logging library sources without error" {
	run bash -c "source '$LOGGING_LIB'"
	[ "$status" -eq 0 ]
}

@test "atomic_write creates file with content" {
	run bash -c "
        source '$LOGGING_LIB'
        atomic_write 'test content' '$TEST_TMPDIR/test.log'
        cat '$TEST_TMPDIR/test.log'
    "
	[ "$status" -eq 0 ]
	[ "$output" = "test content" ]
}

@test "atomic_write overwrites existing file" {
	echo "old content" >"$TEST_TMPDIR/overwrite.log"
	run bash -c "
        source '$LOGGING_LIB'
        atomic_write 'new content' '$TEST_TMPDIR/overwrite.log'
        cat '$TEST_TMPDIR/overwrite.log'
    "
	[ "$status" -eq 0 ]
	[ "$output" = "new content" ]
}

@test "atomic_append appends to existing file" {
	echo "line1" >"$TEST_TMPDIR/append.log"
	run bash -c "
        source '$LOGGING_LIB'
        atomic_append 'line2' '$TEST_TMPDIR/append.log'
        cat '$TEST_TMPDIR/append.log'
    "
	[ "$status" -eq 0 ]
	[[ "$output" == *"line1"* ]]
	[[ "$output" == *"line2"* ]]
}

@test "atomic_append creates file if not exists" {
	run bash -c "
        source '$LOGGING_LIB'
        atomic_append 'first line' '$TEST_TMPDIR/new_append.log'
        cat '$TEST_TMPDIR/new_append.log'
    "
	[ "$status" -eq 0 ]
	[ "$output" = "first line" ]
}

@test "_log_rotation_status function exists" {
	run bash -c "
        source '$LOGGING_LIB'
        type _log_rotation_status
    "
	[ "$status" -eq 0 ]
}

@test "_shell_config_rotate_logs function exists" {
	run bash -c "
        source '$LOGGING_LIB'
        type _shell_config_rotate_logs
    "
	[ "$status" -eq 0 ]
}
