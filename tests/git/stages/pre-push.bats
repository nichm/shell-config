#!/usr/bin/env bats
# =============================================================================
# Tests for lib/git/stages/push/pre-push.sh
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export PRE_PUSH_LIB="$SHELL_CONFIG_DIR/lib/git/stages/push/pre-push.sh"
	export TEST_TMP="$BATS_TEST_TMPDIR/pre-push-test"
	mkdir -p "$TEST_TMP"

	# Stub log functions
	log_info() { echo "INFO: $*"; }
	log_error() { echo "ERROR: $*" >&2; }
	log_success() { echo "SUCCESS: $*"; }
	export -f log_info log_error log_success

	# Stub colors
	export GREEN=''
	export NC=''
}

teardown() {
	/bin/rm -rf "$TEST_TMP" 2>/dev/null || true
}

# =============================================================================
# LIBRARY LOADING
# =============================================================================

@test "pre-push library exists" {
	[ -f "$PRE_PUSH_LIB" ]
}

@test "pre-push is valid bash syntax" {
	run bash -n "$PRE_PUSH_LIB"
	[ "$status" -eq 0 ]
}

# =============================================================================
# FUNCTION DEFINITIONS
# =============================================================================

@test "run_pre_push_checks function is defined" {
	run bash -c "
		log_info() { :; }; log_error() { :; }; log_success() { :; }
		export -f log_info log_error log_success
		export GREEN='' NC=''
		source '$PRE_PUSH_LIB'
		type run_pre_push_checks
	"
	[ "$status" -eq 0 ]
}

@test "run_push_unit_tests function is defined" {
	run bash -c "
		log_info() { :; }; log_error() { :; }; log_success() { :; }
		export -f log_info log_error log_success
		export GREEN='' NC=''
		source '$PRE_PUSH_LIB'
		type run_push_unit_tests
	"
	[ "$status" -eq 0 ]
}

@test "run_push_secrets_check function is defined" {
	run bash -c "
		log_info() { :; }; log_error() { :; }; log_success() { :; }
		export -f log_info log_error log_success
		export GREEN='' NC=''
		source '$PRE_PUSH_LIB'
		type run_push_secrets_check
	"
	[ "$status" -eq 0 ]
}

@test "display_push_blocked_message function is defined" {
	run bash -c "
		log_info() { :; }; log_error() { :; }; log_success() { :; }
		export -f log_info log_error log_success
		export GREEN='' NC=''
		source '$PRE_PUSH_LIB'
		type display_push_blocked_message
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# UNIT TEST CHECK
# =============================================================================

@test "run_push_unit_tests succeeds without package.json" {
	run bash -c "
		log_info() { :; }; log_error() { :; }; log_success() { :; }
		export -f log_info log_error log_success
		export GREEN='' NC=''
		source '$PRE_PUSH_LIB'
		cd '$TEST_TMP'
		run_push_unit_tests '$TEST_TMP'
	"
	[ "$status" -eq 0 ]
}

@test "run_push_unit_tests succeeds with package.json without test script" {
	echo '{}' >"$TEST_TMP/package.json"
	run bash -c "
		log_info() { :; }; log_error() { :; }; log_success() { :; }
		export -f log_info log_error log_success
		export GREEN='' NC=''
		source '$PRE_PUSH_LIB'
		cd '$TEST_TMP'
		run_push_unit_tests '$TEST_TMP'
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# SECRETS CHECK
# =============================================================================

@test "run_push_secrets_check succeeds when gitleaks not installed" {
	run bash -c "
		export PATH='$TEST_TMP/empty-bin'
		mkdir -p '$TEST_TMP/empty-bin'
		log_info() { :; }; log_error() { :; }; log_success() { :; }
		export -f log_info log_error log_success
		export GREEN='' NC=''
		source '$PRE_PUSH_LIB'
		run_push_secrets_check '$TEST_TMP'
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# BLOCKED MESSAGE
# =============================================================================

@test "display_push_blocked_message shows failed checks" {
	run bash -c "
		log_info() { :; }; log_error() { echo \"ERROR: \$*\" >&2; }; log_success() { :; }
		export -f log_info log_error log_success
		export GREEN='' NC=''
		source '$PRE_PUSH_LIB'
		display_push_blocked_message 'unit-tests' 'secrets-scan'
	" 3>&1

	# Check stderr output
	[[ "$output" == *"unit-tests"* ]] || [[ "$stderr" == *"unit-tests"* ]]
}

@test "display_push_blocked_message mentions --no-verify bypass" {
	run bash -c "
		log_info() { :; }; log_error() { echo \"ERROR: \$*\" >&2; }; log_success() { :; }
		export -f log_info log_error log_success
		export GREEN='' NC=''
		source '$PRE_PUSH_LIB'
		display_push_blocked_message 'test-check' 2>&1
	"
	[[ "$output" == *"--no-verify"* ]]
}
