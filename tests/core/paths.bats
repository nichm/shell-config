#!/usr/bin/env bats
# =============================================================================
# Tests for lib/core/paths.sh - PATH and environment setup
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export PATHS_LIB="$SHELL_CONFIG_DIR/lib/core/paths.sh"
	export TEST_TMP="$BATS_TEST_TMPDIR/paths-test"
	mkdir -p "$TEST_TMP"
}

teardown() {
	/bin/rm -rf "$TEST_TMP" 2>/dev/null || true
}

# =============================================================================
# LIBRARY LOADING
# =============================================================================

@test "paths library exists" {
	[ -f "$PATHS_LIB" ]
}

@test "paths is valid bash syntax" {
	run bash -n "$PATHS_LIB"
	[ "$status" -eq 0 ]
}

@test "paths library sources without error" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PATHS_LIB'
	"
	[ "$status" -eq 0 ]
}

@test "paths has source guard" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PATHS_LIB'
		source '$PATHS_LIB'
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# SHELL_CONFIG_DIR DETECTION
# =============================================================================

@test "sets SHELL_CONFIG_DIR from BASH_SOURCE if not set" {
	run bash -c "
		unset SHELL_CONFIG_DIR
		source '$PATHS_LIB'
		echo \"\$SHELL_CONFIG_DIR\"
	"
	[ "$status" -eq 0 ]
	[[ -n "$output" ]]
}

@test "preserves existing SHELL_CONFIG_DIR" {
	run bash -c "
		export SHELL_CONFIG_DIR='/custom/path'
		source '$PATHS_LIB'
		echo \"\$SHELL_CONFIG_DIR\"
	"
	[ "$status" -eq 0 ]
	[[ "$output" == "/custom/path" ]]
}

# =============================================================================
# PATH ENTRIES
# =============================================================================

@test "adds shell-config lib/bin to PATH" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PATHS_LIB'
		echo \"\$PATH\"
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"lib/bin"* ]]
}

@test "adds ghls integration to PATH" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PATHS_LIB'
		echo \"\$PATH\"
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ghls"* ]]
}

@test "adds .local/bin to PATH" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PATHS_LIB'
		echo \"\$PATH\"
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *".local/bin"* ]]
}

@test "sets BUN_INSTALL variable" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PATHS_LIB'
		echo \"\$BUN_INSTALL\"
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *".bun"* ]]
}

# =============================================================================
# HOMEBREW (MACOS)
# =============================================================================

@test "sets HOMEBREW_PREFIX when SC_HOMEBREW_PREFIX and SC_OS=macos" {
	# paths.sh checks [[ -d "$SC_HOMEBREW_PREFIX" ]], so /opt/homebrew must exist
	[[ -d "/opt/homebrew" ]] || skip "Requires /opt/homebrew (macOS only)"
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		export SC_HOMEBREW_PREFIX='/opt/homebrew'
		export SC_OS='macos'
		source '$PATHS_LIB'
		echo \"\$HOMEBREW_PREFIX\"
	"
	[ "$status" -eq 0 ]
	[[ "$output" == "/opt/homebrew" ]]
}

@test "does not set HOMEBREW_PREFIX on linux" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		unset HOMEBREW_PREFIX
		export SC_HOMEBREW_PREFIX='/opt/homebrew'
		export SC_OS='linux'
		source '$PATHS_LIB'
		echo \"\${HOMEBREW_PREFIX:-unset}\"
	"
	[ "$status" -eq 0 ]
	[[ "$output" == "unset" ]]
}

@test "does not set HOMEBREW_PREFIX without SC_HOMEBREW_PREFIX" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		unset HOMEBREW_PREFIX
		unset SC_HOMEBREW_PREFIX
		export SC_OS='macos'
		source '$PATHS_LIB'
		echo \"\${HOMEBREW_PREFIX:-unset}\"
	"
	[ "$status" -eq 0 ]
	[[ "$output" == "unset" ]]
}

# =============================================================================
# CARGO
# =============================================================================

@test "sources cargo env if it exists" {
	# Create a fake cargo env
	mkdir -p "$TEST_TMP/cargo"
	echo 'export CARGO_SOURCED=1' >"$TEST_TMP/cargo/env"

	run bash -c "
		export HOME='$TEST_TMP'
		mkdir -p '$TEST_TMP/.cargo'
		echo 'export CARGO_SOURCED=1' > '$TEST_TMP/.cargo/env'
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PATHS_LIB'
		echo \"\${CARGO_SOURCED:-0}\"
	"
	[ "$status" -eq 0 ]
	[[ "$output" == "1" ]]
}

@test "does not fail without cargo env" {
	run bash -c "
		export HOME='$TEST_TMP'
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PATHS_LIB'
	"
	[ "$status" -eq 0 ]
}
