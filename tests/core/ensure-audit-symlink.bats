#!/usr/bin/env bats
# =============================================================================
# Tests for lib/core/ensure-audit-symlink.sh - Audit log symlink management
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export AUDIT_LIB="$SHELL_CONFIG_DIR/lib/core/ensure-audit-symlink.sh"
	export TEST_TMP="$BATS_TEST_TMPDIR/audit-test"
	mkdir -p "$TEST_TMP"

	# Save original HOME
	ORIG_HOME="$HOME"

	# Create fake repo structure
	export FAKE_REPO="$TEST_TMP/fake-repo"
	mkdir -p "$FAKE_REPO/lib/core"
	# Copy the script into the fake repo
	cp "$AUDIT_LIB" "$FAKE_REPO/lib/core/ensure-audit-symlink.sh"
}

teardown() {
	export HOME="$ORIG_HOME"
	/bin/rm -rf "$TEST_TMP" 2>/dev/null || true
}

# =============================================================================
# LIBRARY LOADING
# =============================================================================

@test "ensure-audit-symlink script exists" {
	[ -f "$AUDIT_LIB" ]
}

@test "ensure-audit-symlink is valid bash syntax" {
	run bash -n "$AUDIT_LIB"
	[ "$status" -eq 0 ]
}

# =============================================================================
# SYMLINK CREATION
# =============================================================================

@test "creates logs directory if missing" {
	run bash -c "
		export HOME='$TEST_TMP/home'
		mkdir -p '$TEST_TMP/home'
		export SHELL_CONFIG_DIR='$FAKE_REPO'
		cd '$FAKE_REPO/lib/core'
		source '$FAKE_REPO/lib/core/ensure-audit-symlink.sh'
		[ -d '$FAKE_REPO/logs' ] && echo 'dir-created'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"dir-created"* ]]
}

@test "creates symlink pointing to audit log in HOME" {
	run bash -c "
		export HOME='$TEST_TMP/home'
		mkdir -p '$TEST_TMP/home'
		unset _AUDIT_SYMLINK_CREATED
		export SHELL_CONFIG_DIR='$FAKE_REPO'
		cd '$FAKE_REPO/lib/core'
		source '$FAKE_REPO/lib/core/ensure-audit-symlink.sh'
		[ -L '$FAKE_REPO/logs/audit.log' ] && echo 'symlink-exists'
		readlink '$FAKE_REPO/logs/audit.log'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"symlink-exists"* ]]
	[[ "$output" == *".shell-config-audit.log"* ]]
}

@test "shows creation message on first run" {
	run bash -c "
		export HOME='$TEST_TMP/home'
		mkdir -p '$TEST_TMP/home'
		unset _AUDIT_SYMLINK_CREATED
		export SHELL_CONFIG_DIR='$FAKE_REPO'
		cd '$FAKE_REPO/lib/core'
		source '$FAKE_REPO/lib/core/ensure-audit-symlink.sh'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Created symlink"* ]]
}

@test "skips if symlink already correct" {
	# Pre-create correct symlink
	export HOME="$TEST_TMP/home"
	mkdir -p "$TEST_TMP/home"
	mkdir -p "$FAKE_REPO/logs"
	ln -s "$HOME/.shell-config-audit.log" "$FAKE_REPO/logs/audit.log"

	run bash -c "
		export HOME='$TEST_TMP/home'
		export SHELL_CONFIG_DIR='$FAKE_REPO'
		cd '$FAKE_REPO/lib/core'
		source '$FAKE_REPO/lib/core/ensure-audit-symlink.sh'
	"
	[ "$status" -eq 0 ]
	# Should NOT show creation message (already correct)
	[[ "$output" != *"Created symlink"* ]]
}

@test "does not overwrite regular file" {
	# Pre-create a regular file at symlink path
	export HOME="$TEST_TMP/home"
	mkdir -p "$TEST_TMP/home"
	mkdir -p "$FAKE_REPO/logs"
	echo "real log data" >"$FAKE_REPO/logs/audit.log"

	run bash -c "
		export HOME='$TEST_TMP/home'
		export SHELL_CONFIG_DIR='$FAKE_REPO'
		cd '$FAKE_REPO/lib/core'
		source '$FAKE_REPO/lib/core/ensure-audit-symlink.sh'
		# Should still be a regular file, not symlink
		[ -f '$FAKE_REPO/logs/audit.log' ] && [ ! -L '$FAKE_REPO/logs/audit.log' ] && echo 'preserved'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"preserved"* ]]
}

@test "repairs symlink pointing to wrong target" {
	# Pre-create wrong symlink
	export HOME="$TEST_TMP/home"
	mkdir -p "$TEST_TMP/home"
	mkdir -p "$FAKE_REPO/logs"
	ln -s "/wrong/target" "$FAKE_REPO/logs/audit.log"

	run bash -c "
		export HOME='$TEST_TMP/home'
		unset _AUDIT_SYMLINK_CREATED
		export SHELL_CONFIG_DIR='$FAKE_REPO'
		cd '$FAKE_REPO/lib/core'
		source '$FAKE_REPO/lib/core/ensure-audit-symlink.sh'
		readlink '$FAKE_REPO/logs/audit.log'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *".shell-config-audit.log"* ]]
}
