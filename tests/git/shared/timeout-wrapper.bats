#!/usr/bin/env bats
# =============================================================================
# Tests for lib/git/shared/timeout-wrapper.sh
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export TIMEOUT_LIB="$SHELL_CONFIG_DIR/lib/git/shared/timeout-wrapper.sh"
	export TEST_TMP="$BATS_TEST_TMPDIR/timeout-test"
	mkdir -p "$TEST_TMP"

	# Source colors first (timeout-wrapper uses log functions)
	source "$SHELL_CONFIG_DIR/lib/core/colors.sh"
}

teardown() {
	/bin/rm -rf "$TEST_TMP" 2>/dev/null || true
}

# =============================================================================
# LIBRARY LOADING
# =============================================================================

@test "timeout-wrapper library exists" {
	[ -f "$TIMEOUT_LIB" ]
}

@test "timeout-wrapper library sources without error" {
	run bash -c "source '$SHELL_CONFIG_DIR/lib/core/colors.sh' && source '$TIMEOUT_LIB'"
	[ "$status" -eq 0 ]
}

# =============================================================================
# FUNCTION DEFINITIONS
# =============================================================================

@test "_portable_timeout function is defined" {
	run bash -c "source '$SHELL_CONFIG_DIR/lib/core/colors.sh' && source '$TIMEOUT_LIB' && type _portable_timeout"
	[ "$status" -eq 0 ]
}

@test "_has_timeout_capability function is defined" {
	run bash -c "source '$SHELL_CONFIG_DIR/lib/core/colors.sh' && source '$TIMEOUT_LIB' && type _has_timeout_capability"
	[ "$status" -eq 0 ]
}

# =============================================================================
# TIMEOUT CAPABILITY DETECTION
# =============================================================================

@test "_has_timeout_capability returns 0 when timeout exists" {
	# On macOS, gtimeout is from coreutils; on Linux, timeout is built-in
	run bash -c "source '$SHELL_CONFIG_DIR/lib/core/colors.sh' && source '$TIMEOUT_LIB' && _has_timeout_capability"
	if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
		[ "$status" -eq 0 ]
	else
		skip "Neither timeout nor gtimeout available"
	fi
}

@test "_has_timeout_capability returns 1 when no timeout tools" {
	run bash -c "
		export PATH='$TEST_TMP/empty-bin'
		mkdir -p '$TEST_TMP/empty-bin'
		source '$SHELL_CONFIG_DIR/lib/core/colors.sh'
		source '$TIMEOUT_LIB'
		_has_timeout_capability
	"
	[ "$status" -eq 1 ]
}

# =============================================================================
# COMMAND EXECUTION
# =============================================================================

@test "_portable_timeout runs command successfully" {
	run bash -c "
		source '$SHELL_CONFIG_DIR/lib/core/colors.sh'
		source '$TIMEOUT_LIB'
		_portable_timeout 5 echo 'hello'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"hello"* ]]
}

@test "_portable_timeout propagates command exit code" {
	run bash -c "
		source '$SHELL_CONFIG_DIR/lib/core/colors.sh'
		source '$TIMEOUT_LIB'
		_portable_timeout 5 bash -c 'exit 1'
	"
	[ "$status" -ne 0 ]
}

@test "_portable_timeout propagates success exit code" {
	run bash -c "
		source '$SHELL_CONFIG_DIR/lib/core/colors.sh'
		source '$TIMEOUT_LIB'
		_portable_timeout 5 bash -c 'exit 0'
	"
	[ "$status" -eq 0 ]
}

@test "_portable_timeout runs without timeout tools" {
	run bash -c "
		export PATH='$TEST_TMP/mock-bin:/usr/bin:/bin'
		mkdir -p '$TEST_TMP/mock-bin'
		source '$SHELL_CONFIG_DIR/lib/core/colors.sh'
		source '$TIMEOUT_LIB'
		_portable_timeout 5 echo 'fallback'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"fallback"* ]]
}
