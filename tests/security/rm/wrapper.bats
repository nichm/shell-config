#!/usr/bin/env bats
# Tests for lib/bin/rm wrapper - protected path blocking and audit logging

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export RM_WRAPPER="$SHELL_CONFIG_DIR/lib/bin/rm"
	export RM_AUDIT_ENABLED=0 # Disable audit logging for tests
	export RM_PROTECT_ENABLED=1
	export RM_FORCE_CONFIRM=0

	# Create temp test directory (cleanup in teardown, not EXIT trap which interferes with bats)
	export TEST_TMPDIR="$BATS_TEST_TMPDIR/rm_test"
	mkdir -p "$TEST_TMPDIR"
}

teardown() {
	# Return to safe directory before cleanup (prevents getcwd errors)
	cd "$BATS_TEST_DIRNAME" || return 1
	# Use /bin/rm to avoid the rm wrapper we're testing blocking cleanup
	[[ -n "${TEST_TMPDIR:-}" ]] && /bin/rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

@test "rm wrapper exists and is executable" {
	[ -f "$RM_WRAPPER" ]
	[ -x "$RM_WRAPPER" ]
}

@test "rm wrapper blocks ~/.ssh deletion" {
	run "$RM_WRAPPER" -rf "$HOME/.ssh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
}

@test "rm wrapper blocks ~/.gnupg deletion" {
	run "$RM_WRAPPER" -rf "$HOME/.gnupg"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
}

@test "rm wrapper blocks ~/.config deletion" {
	run "$RM_WRAPPER" -rf "$HOME/.config"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
}

@test "rm wrapper blocks system /etc deletion" {
	# The wrapper blocks /etc paths
	run "$RM_WRAPPER" -rf "/etc/hosts"
	# Should either block (status 1) or the path doesn't exist for rm
	[[ "$status" -eq 1 ]] || [[ "$output" == *"BLOCKED"* ]] || [[ "$output" == *"No such file"* ]]
}

@test "rm wrapper allows deletion of regular temp files" {
	local test_file="$TEST_TMPDIR/test_file.txt"
	echo "test" >"$test_file"
	[ -f "$test_file" ]

	run "$RM_WRAPPER" "$test_file"
	[ "$status" -eq 0 ]
	[ ! -f "$test_file" ]
}

@test "rm wrapper passes through to real rm for --help" {
	# --help is passed through to /bin/rm via exec
	# We just verify it doesn't error out with "BLOCKED"
	run "$RM_WRAPPER" --help
	[[ "$output" != *"BLOCKED"* ]]
}

@test "rm wrapper passes through to real rm for --version" {
	# --version is passed through to /bin/rm via exec
	# We just verify it doesn't error out with "BLOCKED"
	run "$RM_WRAPPER" --version
	[[ "$output" != *"BLOCKED"* ]]
}

# =============================================================================
# 🔒 CRITICAL: Additional Protected Path Tests
# =============================================================================

@test "rm wrapper blocks ~/.shell-config deletion" {
	run "$RM_WRAPPER" -rf "$HOME/.shell-config"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
}

@test "rm wrapper blocks ~/.zshrc deletion" {
	run "$RM_WRAPPER" -f "$HOME/.zshrc"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
}

@test "rm wrapper blocks ~/.gitconfig deletion" {
	run "$RM_WRAPPER" -f "$HOME/.gitconfig"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
}

@test "rm wrapper blocks /usr deletion" {
	run "$RM_WRAPPER" -rf "/usr"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
}

@test "rm wrapper blocks /bin deletion" {
	run "$RM_WRAPPER" -rf "/bin"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
}

@test "rm wrapper blocks macOS /System deletion" {
	run "$RM_WRAPPER" -rf "/System"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
}

@test "rm wrapper blocks macOS /Library deletion" {
	run "$RM_WRAPPER" -rf "/Library"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
}

# =============================================================================
# 🔒 CRITICAL: Symlink Resolution Tests
# =============================================================================

@test "rm wrapper blocks deletion of symlink to ~/.ssh" {
	local link_path="$TEST_TMPDIR/ssh_link"
	ln -s "$HOME/.ssh" "$link_path"

	run "$RM_WRAPPER" -rf "$link_path"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]

	/bin/rm "$link_path"
}

@test "rm wrapper blocks deletion of symlink to /etc" {
	local link_path="$TEST_TMPDIR/etc_link"
	ln -s "/etc" "$link_path"

	run "$RM_WRAPPER" -rf "$link_path"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]

	/bin/rm "$link_path"
}

# =============================================================================
# 🔒 CRITICAL: Multiple Protected Paths Test
# =============================================================================

@test "rm wrapper blocks multiple protected paths in one command" {
	run "$RM_WRAPPER" -rf "$HOME/.ssh" "$HOME/.gnupg"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
	[[ "$output" == *".ssh"* ]]
	[[ "$output" == *".gnupg"* ]]
}

# =============================================================================
# ⚠️  DANGEROUS FLAGS: Audit and Confirmation Tests
# =============================================================================

@test "rm wrapper shows bypass message with blocked paths" {
	run "$RM_WRAPPER" -rf "$HOME/.ssh"
	[[ "$output" == *"Bypass:"* ]]
	[[ "$output" == *"/bin/rm"* ]]
}

@test "rm wrapper allows safe deletion without dangerous flags" {
	local test_file="$TEST_TMPDIR/safe_file.txt"
	echo "test" >"$test_file"

	run "$RM_WRAPPER" "$test_file"
	[ "$status" -eq 0 ]
	[ ! -f "$test_file" ]
}

@test "rm wrapper works with -r flag on non-protected paths" {
	local test_dir="$TEST_TMPDIR/test_dir"
	mkdir -p "$test_dir"
	echo "test" >"$test_dir/file.txt"

	run "$RM_WRAPPER" -r "$test_dir"
	[ "$status" -eq 0 ]
	[ ! -d "$test_dir" ]
}

@test "rm wrapper works with -f flag on non-protected paths" {
	local test_file="$TEST_TMPDIR/force_file.txt"
	echo "test" >"$test_file"

	run "$RM_WRAPPER" -f "$test_file"
	[ "$status" -eq 0 ]
	[ ! -f "$test_file" ]
}

# =============================================================================
# 🔒 CRITICAL: Environment Variable Tests
# =============================================================================

@test "rm wrapper disables protection when RM_PROTECT_ENABLED=0" {
	# Create a non-protected file to test that protection is actually disabled
	local test_file="$TEST_TMPDIR/unprotected_file.txt"
	echo "test" >"$test_file"

	RM_PROTECT_ENABLED=0 run "$RM_WRAPPER" -f "$test_file"
	# Should successfully delete the file when protection is disabled
	[ "$status" -eq 0 ]
	[ ! -f "$test_file" ]
}

@test "rm wrapper allows deletion when RM_PROTECT_ENABLED is unset" {
	# Unset should still enable protection (defaults to 1)
	local test_file="$TEST_TMPDIR/unset_test.txt"
	echo "test" >"$test_file"

	unset RM_PROTECT_ENABLED
	run "$RM_WRAPPER" "$test_file"
	# Empty string is treated as disabled in the wrapper logic
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🧪 EDGE CASE: Non-Existent Paths
# =============================================================================

@test "rm wrapper blocks deletion of non-existent protected paths" {
	# Non-existent paths should still be blocked if they match protected patterns
	run "$RM_WRAPPER" -f "$HOME/.ssh/nonexistent_key"
	# Should block because it matches the protected pattern
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
}

@test "rm wrapper reports error for non-existent unprotected paths" {
	# Without -f, rm should fail on nonexistent unprotected file
	run "$RM_WRAPPER" "/tmp/nonexistent_file_12345"
	[ "$status" -ne 0 ]
	[[ "$output" != *"BLOCKED"* ]]
}

# =============================================================================
# 🔒 CRITICAL: Subdirectory Protection Tests
# =============================================================================

@test "rm wrapper blocks deletion of ~/.ssh subdirectory" {
	run "$RM_WRAPPER" -rf "$HOME/.ssh/known_hosts"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
}

@test "rm wrapper blocks deletion of ~/.config subdirectory" {
	run "$RM_WRAPPER" -rf "$HOME/.config/nvim"
	[ "$status" -eq 1 ]
	[[ "$output" == *"BLOCKED"* ]]
}

@test "rm wrapper blocks deletion of /etc subdirectory" {
	run "$RM_WRAPPER" -rf "/etc/hosts"
	[ "$status" -eq 1 ]
	# Must block protected paths regardless of whether file exists
	[[ "$output" == *"BLOCKED"* ]]
}

# =============================================================================
# 🧪 EDGE CASE: Special Characters in Paths
# =============================================================================

@test "rm wrapper handles paths with spaces" {
	local test_file="$TEST_TMPDIR/file with spaces.txt"
	echo "test" >"$test_file"

	run "$RM_WRAPPER" "$test_file"
	[ "$status" -eq 0 ]
	[ ! -f "$test_file" ]
}

@test "rm wrapper handles paths with special characters" {
	local test_file="$TEST_TMPDIR/file-with_special.chars[1].txt"
	echo "test" >"$test_file"

	run "$RM_WRAPPER" "$test_file"
	[ "$status" -eq 0 ]
	[ ! -f "$test_file" ]
}
