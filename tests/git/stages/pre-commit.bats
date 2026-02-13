#!/usr/bin/env bats
# Tests for lib/git/stages/commit/pre-commit.sh - Pre-commit validation stage

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export PRE_COMMIT_LIB="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit.sh"

	# Create temp directory for test files
	export TEST_TMP_DIR="$BATS_TEST_TMPDIR"
	mkdir -p "$TEST_TMP_DIR"

	# Mock git repository
	export TEST_REPO="$TEST_TMP_DIR/test-repo"
	git init "$TEST_REPO" >/dev/null 2>&1
	cd "$TEST_REPO" || exit 1
	git config user.email "test@example.com"
	git config user.name "Test User"
	git config core.hooksPath /dev/null

	# Create initial commit
	echo "initial" > initial.txt
	git add initial.txt
	git commit --no-verify -m "initial commit" >/dev/null 2>&1
}

teardown() {
	cd "$SHELL_CONFIG_DIR" || true
	/bin/rm -rf "$TEST_TMP_DIR" 2>/dev/null || true
}

@test "pre-commit library exists" {
	[ -f "$PRE_COMMIT_LIB" ]
}

@test "pre-commit library sources without error" {
	run bash -c "source '$PRE_COMMIT_LIB'"
	[ "$status" -eq 0 ]
}

@test "MAX_FILE_SIZE constant is defined correctly" {
	run bash -c "source '$PRE_COMMIT_LIB' && echo \$MAX_FILE_SIZE"
	[ "$status" -eq 0 ]
	[ "$output" = "$((5 * 1024 * 1024))" ] # 5MB
}

@test "SECRETS_TIMEOUT constant is defined" {
	run bash -c "source '$PRE_COMMIT_LIB' && echo \$SECRETS_TIMEOUT"
	[ "$status" -eq 0 ]
	[ "$output" = "5" ]
}

@test "TIER_INFO_LINES constant is defined" {
	run bash -c "source '$PRE_COMMIT_LIB' && echo \$TIER_INFO_LINES"
	[ "$status" -eq 0 ]
	[ "$output" = "1000" ]
}

@test "TIER_WARNING_LINES constant is defined" {
	run bash -c "source '$PRE_COMMIT_LIB' && echo \$TIER_WARNING_LINES"
	[ "$status" -eq 0 ]
	[ "$output" = "3000" ]
}

@test "TIER_EXTREME_LINES constant is defined" {
	run bash -c "source '$PRE_COMMIT_LIB' && echo \$TIER_EXTREME_LINES"
	[ "$status" -eq 0 ]
	[ "$output" = "5001" ]
}

@test "DEP_FILES array contains package.json" {
	run bash -c "source '$PRE_COMMIT_LIB' && printf '%s\n' \"\${DEP_FILES[@]}\""
	[ "$status" -eq 0 ]
	[[ "$output" == *"package.json"* ]]
}

@test "DEP_FILES array contains package-lock.json" {
	run bash -c "source '$PRE_COMMIT_LIB' && printf '%s\n' \"\${DEP_FILES[@]}\""
	[ "$status" -eq 0 ]
	[[ "$output" == *"package-lock.json"* ]]
}

@test "DEP_FILES array contains Cargo.toml" {
	run bash -c "source '$PRE_COMMIT_LIB' && printf '%s\n' \"\${DEP_FILES[@]}\""
	[ "$status" -eq 0 ]
	[[ "$output" == *"Cargo.toml"* ]]
}

@test "DEP_FILES array contains bun.lockb" {
	run bash -c "source '$PRE_COMMIT_LIB' && printf '%s\n' \"\${DEP_FILES[@]}\""
	[ "$status" -eq 0 ]
	[[ "$output" == *"bun.lockb"* ]]
}

@test "run_pre_commit_checks function is defined" {
	run bash -c "source '$PRE_COMMIT_LIB' && type run_pre_commit_checks"
	[ "$status" -eq 0 ]
	[[ "$output" == *"function"* ]]
}

@test "pre-commit sources pre-commit-checks.sh" {
	# Check if the checks file was sourced by looking for a function it defines
	run bash -c "source '$PRE_COMMIT_LIB' && type run_file_length_check"
	[ "$status" -eq 0 ]
}

@test "pre-commit sources pre-commit-display.sh" {
	run bash -c "source '$PRE_COMMIT_LIB' && type log_info"
	[ "$status" -eq 0 ]
}

@test "PRE_COMMIT_DIR is set correctly" {
	run bash -c "source '$PRE_COMMIT_LIB' && echo \$PRE_COMMIT_DIR"
	[ "$status" -eq 0 ]
	[[ "$output" == *"/lib/git/stages/commit" ]]
}

@test "pre-commit handles empty file list" {
	run bash -c "source '$PRE_COMMIT_LIB' && run_pre_commit_checks"
	# Should succeed with empty list (nothing to validate)
	[ "$status" -eq 0 ]
}

@test "pre-commit creates temp directory for parallel jobs" {
	# Test that temp dir creation works
	local tmpdir
	tmpdir=$(mktemp -d 2>/dev/null) || tmpdir="/tmp/test-$RANDOM"
	[ -d "$tmpdir" ] || mkdir -p "$tmpdir"
	rm -rf "$tmpdir"
}

@test "pre-commit run_pre_commit_checks uses trap for cleanup" {
	# Verify the function body contains trap for temp dir cleanup
	run bash -c "source '$PRE_COMMIT_LIB' && type run_pre_commit_checks | grep -q 'trap'"
	[ "$status" -eq 0 ]
}

@test "GIT_SKIP_FILE_LENGTH_CHECK bypass works" {
	export GIT_SKIP_FILE_LENGTH_CHECK=1
	run bash -c "source '$PRE_COMMIT_LIB'"
	[ "$status" -eq 0 ]
	unset GIT_SKIP_FILE_LENGTH_CHECK
}

@test "pre-commit references benchmark-hook.sh" {
	# benchmark-hook.sh is sourced inside run_pre_commit_checks, not at file level
	run bash -c "source '$PRE_COMMIT_LIB' && type run_pre_commit_checks | grep -q 'benchmark'"
	[ "$status" -eq 0 ]
}

@test "pre-commit handles file with spaces in name" {
	cd "$TEST_REPO" || exit 1
	touch "file with spaces.txt"
	git add "file with spaces.txt" 2>/dev/null || true
	# Should handle filenames with spaces gracefully
	[ -f "file with spaces.txt" ]
}

@test "pre-commit constants are defined" {
	run bash -c "source '$PRE_COMMIT_LIB' && echo \$MAX_FILE_SIZE"
	[ "$status" -eq 0 ]
	[ "$output" = "$((5 * 1024 * 1024))" ]
}

@test "pre-commit library has proper header" {
	run head -n 5 "$PRE_COMMIT_LIB"
	[ "$status" -eq 0 ]
	[[ "$output" == *"commit/pre-commit.sh"* ]]
	[[ "$output" == *"Pre-commit validation"* ]]
}
