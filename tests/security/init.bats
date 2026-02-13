#!/usr/bin/env bats
# =============================================================================
# 🔒 Security & Loaders Tests - Critical Protection Validation
# =============================================================================
# Tests for security/init.sh and core/loaders SSH/fnm functions
# These tests validate security-critical paths that protect against:
#   - AI agent bypass of rm wrapper via /bin/rm
#   - SSH key security through 1Password agent
#   - Lazy loading performance optimizations
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export SECURITY_LIB="$SHELL_CONFIG_DIR/lib/security/init.sh"
	export SECURITY_DIR="$SHELL_CONFIG_DIR/lib/security"
	export LOADER_SSH="$SHELL_CONFIG_DIR/lib/core/loaders/ssh.sh"
	export LOADER_COMPLETIONS="$SHELL_CONFIG_DIR/lib/core/loaders/completions.sh"
	export LOADER_FNM="$SHELL_CONFIG_DIR/lib/core/loaders/fnm.sh"
	export LOADER_BROOT="$SHELL_CONFIG_DIR/lib/core/loaders/broot.sh"
	export ENSURE_AUDIT_SCRIPT="$SHELL_CONFIG_DIR/lib/core/ensure-audit-symlink.sh"

	# Create temp directory (cleanup in teardown, not EXIT trap which interferes with bats)
	export TEST_TMPDIR="$BATS_TEST_TMPDIR/security_test_$$"
	mkdir -p "$TEST_TMPDIR"

	# Mock HOME for testing
	export ORIGINAL_HOME="$HOME"
	export HOME="$TEST_TMPDIR"

	# Create mock protected directories
	mkdir -p "$HOME/.ssh"
	mkdir -p "$HOME/.gnupg"
	mkdir -p "$HOME/.config"
	mkdir -p "$HOME/.shell-config"
	touch "$HOME/.zshrc"
	touch "$HOME/.bashrc"
	touch "$HOME/.gitconfig"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	export HOME="$ORIGINAL_HOME"
	[[ -n "${TEST_TMPDIR:-}" ]] && /bin/rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

# =============================================================================
# 🔒 SECURITY.SH TESTS
# =============================================================================

@test "security library exists" {
	[ -f "$SECURITY_LIB" ]
}

@test "security library sources without error (in bash)" {
	# Need to set SHELL_CONFIG_DIR for security.sh to find lib/bin/rm
	run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        export HOME='$TEST_TMPDIR'
        source '$SECURITY_LIB' 2>&1
    "
	[ "$status" -eq 0 ]
}

@test "security.sh defines RM_AUDIT_LOG variable" {
	run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        source '$SECURITY_LIB' 2>&1
        echo \"\$RM_AUDIT_LOG\"
    "
	[ "$status" -eq 0 ]
	[[ "$output" == *".rm_audit.log"* ]]
}

@test "security.sh defines RM_PROTECT_ENABLED variable" {
	run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        source '$SECURITY_LIB' 2>&1
        echo \"\$RM_PROTECT_ENABLED\"
    "
	[ "$status" -eq 0 ]
	[ "$output" = "1" ]
}

@test "security.sh creates .tmp directory with correct permissions" {
	run bash -c "
        export HOME='$TEST_TMPDIR'
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        source '$SECURITY_LIB' 2>&1
        if [[ -d '$TEST_TMPDIR/.tmp' ]]; then
            # Try GNU stat first (Linux), then BSD stat (macOS)
            stat -c '%a' '$TEST_TMPDIR/.tmp' 2>/dev/null || stat -f '%A' '$TEST_TMPDIR/.tmp' 2>/dev/null
        fi
    "
	[ "$status" -eq 0 ]
	[ "$output" = "700" ]
}

@test "security.sh sets TMPDIR to user tmp directory" {
	run bash -c "
        export HOME='$TEST_TMPDIR'
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        source '$SECURITY_LIB' 2>&1
        echo \"\$TMPDIR\"
    "
	[ "$status" -eq 0 ]
	[ "$output" = "$TEST_TMPDIR/.tmp" ]
}

# =============================================================================
# 📦 LOADERS.SH TESTS
# =============================================================================

@test "core loaders exist" {
	[ -f "$LOADER_SSH" ]
	[ -f "$LOADER_COMPLETIONS" ]
	[ -f "$LOADER_FNM" ]
	# Note: broot loader is optional (may not be installed)
	# [ -f "$LOADER_BROOT" ]
}

@test "_load_ssh function is defined in ssh loader" {
	run bash -c "grep -q '_load_ssh' '$LOADER_SSH'"
	[ "$status" -eq 0 ]
}

@test "_load_uv_completions function is defined in completions loader" {
	run bash -c "grep -q '_load_uv_completions' '$LOADER_COMPLETIONS'"
	[ "$status" -eq 0 ]
}

@test "ssh loader checks for 1Password SSH socket" {
	run bash -c "grep -q '2BUA8C4S2C.com.1password' '$LOADER_SSH'"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🔗 ENSURE-AUDIT-SYMLINK.SH TESTS
# =============================================================================

@test "ensure-audit-symlink script exists" {
	[ -f "$ENSURE_AUDIT_SCRIPT" ]
}

@test "ensure-audit-symlink script has valid bash syntax" {
	run bash -n "$ENSURE_AUDIT_SCRIPT"
	[ "$status" -eq 0 ]
}

@test "ensure-audit-symlink creates symlink when it doesn't exist" {
	# Setup: Create repo structure and target audit log
	local repo_root="$TEST_TMPDIR/repo"
	mkdir -p "$repo_root"
	touch "$HOME/.shell-config-audit.log"

	# Mock the script directory detection
	run bash -c "
        export HOME='$TEST_TMPDIR'
        export SHELL_CONFIG_DIR='$repo_root'
        cd '$repo_root'
        # Create lib/core structure
        mkdir -p lib/core
        # Copy script to test location
        cp '$ENSURE_AUDIT_SCRIPT' lib/core/ensure-audit-symlink.sh
        # Source it
        source lib/core/ensure-audit-symlink.sh 2>&1
        # Check if symlink was created
        [[ -L logs/audit.log ]] && readlink logs/audit.log
    "
	[ "$status" -eq 0 ]
	[[ "$output" == *".shell-config-audit.log"* ]]
}

@test "ensure-audit-symlink creates logs directory if missing" {
	local repo_root="$TEST_TMPDIR/repo2"
	mkdir -p "$repo_root"
	touch "$HOME/.shell-config-audit.log"

	run bash -c "
        export HOME='$TEST_TMPDIR'
        export SHELL_CONFIG_DIR='$repo_root'
        cd '$repo_root'
        mkdir -p lib/core
        cp '$ENSURE_AUDIT_SCRIPT' lib/core/ensure-audit-symlink.sh
        source lib/core/ensure-audit-symlink.sh 2>&1
        [[ -d logs ]]
    "
	[ "$status" -eq 0 ]
}

@test "ensure-audit-symlink displays user message on first creation" {
	local repo_root="$TEST_TMPDIR/repo3"
	mkdir -p "$repo_root"
	touch "$HOME/.shell-config-audit.log"

	run bash -c "
        unset _AUDIT_SYMLINK_CREATED
        export HOME='$TEST_TMPDIR'
        export SHELL_CONFIG_DIR='$repo_root'
        cd '$repo_root'
        mkdir -p lib/core
        cp '$ENSURE_AUDIT_SCRIPT' lib/core/ensure-audit-symlink.sh
        source lib/core/ensure-audit-symlink.sh 2>&1
    "
	[ "$status" -eq 0 ]
	[[ "$output" == *"Created symlink"* ]]
	[[ "$output" == *"shell-config/logs/audit.log"* ]]
	[[ "$output" == *"tail -20 shell-config/logs/audit.log"* ]]
}

@test "ensure-audit-symlink does not show message on subsequent runs" {
	local repo_root="$TEST_TMPDIR/repo4"
	mkdir -p "$repo_root"
	touch "$HOME/.shell-config-audit.log"

	# First run - should show message
	run bash -c "
        unset _AUDIT_SYMLINK_CREATED
        export HOME='$TEST_TMPDIR'
        export SHELL_CONFIG_DIR='$repo_root'
        cd '$repo_root'
        mkdir -p lib/core
        cp '$ENSURE_AUDIT_SCRIPT' lib/core/ensure-audit-symlink.sh
        source lib/core/ensure-audit-symlink.sh 2>&1
    "
	[ "$status" -eq 0 ]
	[[ "$output" == *"Created symlink"* ]]

	# Second run in same session - should NOT show message (flag set)
	run bash -c "
        export HOME='$TEST_TMPDIR'
        export SHELL_CONFIG_DIR='$repo_root'
        export _AUDIT_SYMLINK_CREATED=1
        cd '$repo_root'
        source lib/core/ensure-audit-symlink.sh 2>&1
    "
	[ "$status" -eq 0 ]
	[[ "$output" != *"Created symlink"* ]]
}

@test "ensure-audit-symlink replaces symlink with wrong target" {
	local repo_root="$TEST_TMPDIR/repo5"
	mkdir -p "$repo_root/logs"
	touch "$HOME/.shell-config-audit.log"
	touch "$TEST_TMPDIR/wrong-target.log"

	# Create symlink with wrong target
	ln -s "$TEST_TMPDIR/wrong-target.log" "$repo_root/logs/audit.log"

	run bash -c "
        export HOME='$TEST_TMPDIR'
        export SHELL_CONFIG_DIR='$repo_root'
        cd '$repo_root'
        mkdir -p lib/core
        cp '$ENSURE_AUDIT_SCRIPT' lib/core/ensure-audit-symlink.sh
        source lib/core/ensure-audit-symlink.sh 2>&1
        readlink logs/audit.log
    "
	[ "$status" -eq 0 ]
	[[ "$output" == *".shell-config-audit.log"* ]]
	[[ "$output" != *"wrong-target.log"* ]]
}

@test "ensure-audit-symlink does not overwrite existing regular file" {
	local repo_root="$TEST_TMPDIR/repo6"
	mkdir -p "$repo_root/logs"
	touch "$HOME/.shell-config-audit.log"
	echo "existing content" >"$repo_root/logs/audit.log"

	run bash -c "
        export HOME='$TEST_TMPDIR'
        export SHELL_CONFIG_DIR='$repo_root'
        cd '$repo_root'
        mkdir -p lib/core
        cp '$ENSURE_AUDIT_SCRIPT' lib/core/ensure-audit-symlink.sh
        source lib/core/ensure-audit-symlink.sh 2>&1
        # File should still exist and not be a symlink
        [[ -f logs/audit.log ]] && ! [[ -L logs/audit.log ]] && cat logs/audit.log
    "
	[ "$status" -eq 0 ]
	[[ "$output" == *"existing content"* ]]
}

@test "ensure-audit-symlink leaves correct symlink unchanged" {
	local repo_root="$TEST_TMPDIR/repo7"
	mkdir -p "$repo_root/logs"
	touch "$HOME/.shell-config-audit.log"

	# Create correct symlink first
	ln -s "$HOME/.shell-config-audit.log" "$repo_root/logs/audit.log"

	run bash -c "
        export HOME='$TEST_TMPDIR'
        export SHELL_CONFIG_DIR='$repo_root'
        cd '$repo_root'
        mkdir -p lib/core
        cp '$ENSURE_AUDIT_SCRIPT' lib/core/ensure-audit-symlink.sh
        source lib/core/ensure-audit-symlink.sh 2>&1
        # Should be silent (no output) when symlink already correct
        echo 'done'
    "
	[ "$status" -eq 0 ]
	[[ "$output" == "done" ]]
}

@test "ensure-audit-symlink handles missing target gracefully" {
	local repo_root="$TEST_TMPDIR/repo8"
	mkdir -p "$repo_root"
	# Don't create the target audit log file

	run bash -c "
        export HOME='$TEST_TMPDIR'
        export SHELL_CONFIG_DIR='$repo_root'
        cd '$repo_root'
        mkdir -p lib/core
        cp '$ENSURE_AUDIT_SCRIPT' lib/core/ensure-audit-symlink.sh
        source lib/core/ensure-audit-symlink.sh 2>&1
        # Should still create symlink even if target doesn't exist yet
        [[ -L logs/audit.log ]] && readlink logs/audit.log
    "
	[ "$status" -eq 0 ]
	[[ "$output" == *".shell-config-audit.log"* ]]
}

# =============================================================================
# 🛡️ PROTECTED PATH DETECTION TESTS
# =============================================================================

@test "lib/bin/rm wrapper exists and is executable" {
	local rm_wrapper="$SHELL_CONFIG_DIR/lib/bin/rm"
	[ -f "$rm_wrapper" ]
	[ -x "$rm_wrapper" ]
}

@test "lib/bin/rm sources shared protected-paths module" {
	# After centralization, lib/bin/rm sources the shared module instead of defining inline
	run bash -c "grep -q 'protected-paths.sh' '$SHELL_CONFIG_DIR/lib/bin/rm'"
	[ "$status" -eq 0 ]
}

@test "protected-paths module blocks ~/.ssh path" {
	# Protected paths are now in lib/core/protected-paths.sh
	run bash -c "grep -q '\\.ssh' '$SHELL_CONFIG_DIR/lib/core/protected-paths.sh'"
	[ "$status" -eq 0 ]
}

@test "protected-paths module blocks ~/.gnupg path" {
	run bash -c "grep -q '\\.gnupg' '$SHELL_CONFIG_DIR/lib/core/protected-paths.sh'"
	[ "$status" -eq 0 ]
}

@test "protected-paths module blocks ~/.config path" {
	run bash -c "grep -q '\\.config' '$SHELL_CONFIG_DIR/lib/core/protected-paths.sh'"
	[ "$status" -eq 0 ]
}

@test "protected-paths module blocks system paths (/etc, /usr)" {
	run bash -c "grep -qE '/etc|/usr' '$SHELL_CONFIG_DIR/lib/core/protected-paths.sh'"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🔐 AUDIT LOGGING TESTS
# =============================================================================

@test "security module defines rm-audit function" {
	# Functions are now in lib/security/rm/audit.sh
	run bash -c "grep -q 'rm-audit()' '$SECURITY_DIR/rm/audit.sh'"
	[ "$status" -eq 0 ]
}

@test "security module defines rm-audit-clear function" {
	run bash -c "grep -q 'rm-audit-clear()' '$SECURITY_DIR/rm/audit.sh'"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🔧 FILESYSTEM PROTECTION TESTS
# =============================================================================

@test "security module defines protect-file function" {
	# Functions are now in lib/security/filesystem/protect.sh
	run bash -c "grep -q 'protect-file()' '$SECURITY_DIR/filesystem/protect.sh'"
	[ "$status" -eq 0 ]
}

@test "security module defines unprotect-file function" {
	run bash -c "grep -q 'unprotect-file()' '$SECURITY_DIR/filesystem/protect.sh'"
	[ "$status" -eq 0 ]
}

@test "security module defines protect-dir function" {
	run bash -c "grep -q 'protect-dir()' '$SECURITY_DIR/filesystem/protect.sh'"
	[ "$status" -eq 0 ]
}

@test "security module defines trash-rm function" {
	# Function is now in lib/security/trash/trash.sh
	run bash -c "grep -q 'trash-rm()' '$SECURITY_DIR/trash/trash.sh'"
	[ "$status" -eq 0 ]
}

# =============================================================================
# ⚡ FNM LAZY LOADING TESTS
# =============================================================================

@test "fnm loader implements fnm lazy loading" {
	run bash -c "grep -q 'fnm()' '$LOADER_FNM'"
	[ "$status" -eq 0 ]
}

@test "fnm loader implements node lazy loading" {
	run bash -c "grep -q 'node()' '$LOADER_FNM'"
	[ "$status" -eq 0 ]
}

@test "fnm loader implements npm lazy loading" {
	run bash -c "grep -q 'npm()' '$LOADER_FNM'"
	[ "$status" -eq 0 ]
}

@test "fnm loader implements npx lazy loading" {
	run bash -c "grep -q 'npx()' '$LOADER_FNM'"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🔒 UMASK SECURITY TESTS
# =============================================================================

@test "security module sets secure umask 077" {
	# Umask is now in lib/security/hardening.sh
	run bash -c "grep -q 'umask 077' '$SECURITY_DIR/hardening.sh'"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 📝 BREW VERIFICATION TESTS
# =============================================================================

@test "security module defines brew-verify function" {
	# Function is now in lib/security/hardening.sh
	run bash -c "grep -q 'brew-verify()' '$SECURITY_DIR/hardening.sh'"
	[ "$status" -eq 0 ]
}
