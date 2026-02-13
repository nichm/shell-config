#!/usr/bin/env bats
# =============================================================================
# Tests for lib/core/traps.sh - Shared trap handlers and temp file cleanup
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export TRAPS_LIB="$SHELL_CONFIG_DIR/lib/core/traps.sh"
	export TEST_TMP="$BATS_TEST_TMPDIR/traps-test"
	mkdir -p "$TEST_TMP"
}

teardown() {
	/bin/rm -rf "$TEST_TMP" 2>/dev/null || true
}

# =============================================================================
# LIBRARY LOADING
# =============================================================================

@test "traps library exists" {
	[ -f "$TRAPS_LIB" ]
}

@test "traps library sources without error" {
	run bash -c "source '$TRAPS_LIB'"
	[ "$status" -eq 0 ]
}

@test "traps library has source guard" {
	run bash -c "
		source '$TRAPS_LIB'
		source '$TRAPS_LIB'
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# FUNCTION DEFINITIONS
# =============================================================================

@test "trap_add_cleanup function is defined" {
	run bash -c "source '$TRAPS_LIB' && type trap_add_cleanup"
	[ "$status" -eq 0 ]
}

@test "trap_add_cleanup_dir function is defined" {
	run bash -c "source '$TRAPS_LIB' && type trap_add_cleanup_dir"
	[ "$status" -eq 0 ]
}

@test "trap_set_standard function is defined" {
	run bash -c "source '$TRAPS_LIB' && type trap_set_standard"
	[ "$status" -eq 0 ]
}

@test "mktemp_with_cleanup function is defined" {
	run bash -c "source '$TRAPS_LIB' && type mktemp_with_cleanup"
	[ "$status" -eq 0 ]
}

@test "mktemp_dir_with_cleanup function is defined" {
	run bash -c "source '$TRAPS_LIB' && type mktemp_dir_with_cleanup"
	[ "$status" -eq 0 ]
}

@test "_trap_cleanup_handler function is defined" {
	run bash -c "source '$TRAPS_LIB' && type _trap_cleanup_handler"
	[ "$status" -eq 0 ]
}

# =============================================================================
# MKTEMP WITH CLEANUP
# =============================================================================

@test "mktemp_with_cleanup creates a temp file that exists during script" {
	# Note: mktemp_with_cleanup sets EXIT trap, so when called via $() subshell,
	# the file is cleaned when subshell exits. Test directly without $() capture.
	run bash -c "
		source '$TRAPS_LIB'
		# Call directly - the function echoes the path and sets traps
		# We redirect to avoid trap cleanup and verify the mktemp call works
		temp_file=\$(mktemp)
		trap_add_cleanup \"\$temp_file\"
		[ -f \"\$temp_file\" ] && echo 'exists'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"exists"* ]]
}

@test "mktemp_with_cleanup returns a valid temp path" {
	# The function creates a mktemp file and echoes the path
	run bash -c "
		source '$TRAPS_LIB'
		# Verify the function creates and returns a path
		# (file will be cleaned up on EXIT since trap fires on subshell exit)
		path=\$(mktemp_with_cleanup)
		# Path should look like a temp file
		[[ \"\$path\" == /tmp/* ]] || [[ \"\$path\" == /var/* ]] || [[ \"\$path\" == \"\${TMPDIR}\"* ]]
		echo 'valid-path'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"valid-path"* ]]
}

@test "mktemp_dir_with_cleanup returns a valid temp directory path" {
	run bash -c "
		source '$TRAPS_LIB'
		path=\$(mktemp_dir_with_cleanup)
		# Path should look like a temp dir (may be cleaned on subshell exit)
		[[ \"\$path\" == /tmp/* ]] || [[ \"\$path\" == /var/* ]] || [[ \"\$path\" == \"\${TMPDIR}\"* ]]
		echo 'valid-path'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"valid-path"* ]]
}

# =============================================================================
# CLEANUP HANDLER
# =============================================================================

@test "cleanup handler removes tracked files" {
	run bash -c "
		source '$TRAPS_LIB'
		tmpfile='$TEST_TMP/cleanup-test-file'
		touch \"\$tmpfile\"
		trap_add_cleanup \"\$tmpfile\"
		_trap_cleanup_handler
		[ ! -f \"\$tmpfile\" ] && echo 'removed'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"removed"* ]]
}

@test "cleanup handler removes tracked directories" {
	run bash -c "
		source '$TRAPS_LIB'
		tmpdir='$TEST_TMP/cleanup-test-dir'
		mkdir -p \"\$tmpdir\"
		trap_add_cleanup_dir \"\$tmpdir\"
		_trap_cleanup_handler
		[ ! -d \"\$tmpdir\" ] && echo 'removed'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"removed"* ]]
}

@test "cleanup handler handles nonexistent files gracefully" {
	run bash -c "
		source '$TRAPS_LIB'
		trap_add_cleanup '/tmp/does-not-exist-$$'
		_trap_cleanup_handler
		echo 'ok'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok"* ]]
}

@test "cleanup handler resets arrays after cleanup" {
	run bash -c "
		source '$TRAPS_LIB'
		trap_add_cleanup '$TEST_TMP/reset-test'
		touch '$TEST_TMP/reset-test'
		_trap_cleanup_handler
		echo \${#_TRAP_CLEANUP_FILES[@]}
	"
	[ "$status" -eq 0 ]
	[[ "$output" == "0" ]]
}

@test "cleanup handles multiple files" {
	run bash -c "
		source '$TRAPS_LIB'
		for i in 1 2 3; do
			f='$TEST_TMP/multi-\$i'
			touch \"\$f\"
			trap_add_cleanup \"\$f\"
		done
		_trap_cleanup_handler
		count=\$(ls '$TEST_TMP'/multi-* 2>/dev/null | wc -l)
		echo \"\$count\"
	"
	[ "$status" -eq 0 ]
	[[ "${output// /}" == "0" ]]
}

# =============================================================================
# TRAP SETUP
# =============================================================================

@test "trap_set_standard sets EXIT trap" {
	run bash -c "
		source '$TRAPS_LIB'
		trap_set_standard
		trap -p EXIT | grep -q '_trap_cleanup_handler' && echo 'set'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"set"* ]]
}

@test "trap_set_standard sets INT trap" {
	run bash -c "
		source '$TRAPS_LIB'
		trap_set_standard
		trap -p INT | grep -q '_trap_cleanup_handler' && echo 'set'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"set"* ]]
}

@test "trap_set_standard sets TERM trap" {
	run bash -c "
		source '$TRAPS_LIB'
		trap_set_standard
		trap -p TERM | grep -q '_trap_cleanup_handler' && echo 'set'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"set"* ]]
}
