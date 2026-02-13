#!/usr/bin/env bats
# =============================================================================
# Tests for lib/integrations/1password/diagnose.sh
# =============================================================================
# Note: diagnose.sh is a standalone diagnostic script, not a sourceable library.
# It requires `op` CLI and `jq`. Tests focus on syntax, structure, and
# graceful failure when tools are missing.

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export DIAGNOSE_SCRIPT="$SHELL_CONFIG_DIR/lib/integrations/1password/diagnose.sh"
	export TEST_TMP="$BATS_TEST_TMPDIR/1p-diagnose-test"
	mkdir -p "$TEST_TMP"
}

teardown() {
	/bin/rm -rf "$TEST_TMP" 2>/dev/null || true
}

# =============================================================================
# SCRIPT EXISTS AND VALID
# =============================================================================

@test "diagnose script exists" {
	[ -f "$DIAGNOSE_SCRIPT" ]
}

@test "diagnose script is valid bash syntax" {
	run bash -n "$DIAGNOSE_SCRIPT"
	[ "$status" -eq 0 ]
}

@test "diagnose script has proper shebang" {
	run head -1 "$DIAGNOSE_SCRIPT"
	[[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "diagnose script uses strict mode" {
	run bash -c "grep -q 'set -euo pipefail' '$DIAGNOSE_SCRIPT'"
	[ "$status" -eq 0 ]
}

# =============================================================================
# SCRIPT STRUCTURE
# =============================================================================

@test "diagnose script sources colors library" {
	run bash -c "grep -q 'colors.sh' '$DIAGNOSE_SCRIPT'"
	[ "$status" -eq 0 ]
}

@test "diagnose script checks for op CLI" {
	run bash -c "grep -q 'op' '$DIAGNOSE_SCRIPT'"
	[ "$status" -eq 0 ]
}

@test "diagnose script provides install instructions on missing op" {
	run bash -c "grep -q 'brew install 1password-cli' '$DIAGNOSE_SCRIPT'"
	[ "$status" -eq 0 ]
}

# =============================================================================
# BEHAVIOR WITH MISSING OP CLI
# =============================================================================

@test "diagnose exits with error when op CLI missing" {
	# diagnose.sh sources colors.sh which defines log_* functions, then checks for op
	# When PATH is restricted, the script fails (may be 1 or 127 depending on what's missing)
	run bash -c "
		export PATH='/usr/bin:/bin'
		# Ensure op is not available
		if command -v op >/dev/null 2>&1; then
			echo 'op-found'
			exit 0
		fi
		bash '$DIAGNOSE_SCRIPT' 2>&1
	"
	if [[ "$output" == *"op-found"* ]]; then
		skip "op CLI is installed on this system"
	fi
	[ "$status" -ne 0 ]
}

# =============================================================================
# SCRIPT CONTENT CHECKS
# =============================================================================

@test "diagnose script checks desktop app status" {
	run bash -c "grep -q 'pgrep.*1Password' '$DIAGNOSE_SCRIPT'"
	[ "$status" -eq 0 ]
}

@test "diagnose script checks account configuration" {
	run bash -c "grep -q 'op account list' '$DIAGNOSE_SCRIPT'"
	[ "$status" -eq 0 ]
}

@test "diagnose script checks authentication status" {
	run bash -c "grep -q 'op whoami' '$DIAGNOSE_SCRIPT'"
	[ "$status" -eq 0 ]
}

@test "diagnose script checks session tokens" {
	run bash -c "grep -q 'OP_SESSION' '$DIAGNOSE_SCRIPT'"
	[ "$status" -eq 0 ]
}

@test "diagnose script provides recommendations" {
	run bash -c "grep -q 'Recommendations' '$DIAGNOSE_SCRIPT'"
	[ "$status" -eq 0 ]
}

@test "diagnose script mentions op signin" {
	run bash -c "grep -q 'op signin' '$DIAGNOSE_SCRIPT'"
	[ "$status" -eq 0 ]
}
