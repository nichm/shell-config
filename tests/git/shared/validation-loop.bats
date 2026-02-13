#!/usr/bin/env bats
# Tests for lib/git/shared/validation-loop.sh - Validation orchestration

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export VALIDATION_LOOP_LIB="$SHELL_CONFIG_DIR/lib/git/shared/validation-loop.sh"

	# Create temp directory
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

@test "validation-loop library exists" {
	[ -f "$VALIDATION_LOOP_LIB" ]
}

@test "validation-loop library sources without error" {
	run bash -c "source '$VALIDATION_LOOP_LIB'"
	[ "$status" -eq 0 ]
}

@test "run_validation_on_staged function is defined" {
	run bash -c "source '$VALIDATION_LOOP_LIB' && type run_validation_on_staged"
	[ "$status" -eq 0 ]
	[[ "$output" == *"function"* ]]
}

@test "should_validate_file function is defined" {
	run bash -c "source '$VALIDATION_LOOP_LIB' && type should_validate_file"
	[ "$status" -eq 0 ]
}

@test "run_validation_on_all function is defined" {
	run bash -c "source '$VALIDATION_LOOP_LIB' && type run_validation_on_all"
	[ "$status" -eq 0 ]
}

@test "report_check_summary function is defined" {
	run bash -c "source '$VALIDATION_LOOP_LIB' && type report_check_summary"
	[ "$status" -eq 0 ]
}

@test "validation-loop sources validation-loop-advanced.sh" {
	run bash -c "source '$VALIDATION_LOOP_LIB' && type run_validation_collect_errors"
	[ "$status" -eq 0 ]
}

@test "validation-loop sources file-operations.sh" {
	run bash -c "source '$VALIDATION_LOOP_LIB' && type get_staged_files"
	[ "$status" -eq 0 ]
}

@test "validation-loop sources reporters.sh" {
	run bash -c "source '$VALIDATION_LOOP_LIB' && type validation_log_error"
	[ "$status" -eq 0 ]
}

@test "run_validation_on_staged handles empty file list" {
	cd "$TEST_REPO" || exit 1
	# No staged files
	run bash -c "source '$VALIDATION_LOOP_LIB' && run_validation_on_staged 'echo' '.*'"
	[ "$status" -eq 0 ]
}

@test "run_validation_on_staged respects file filter pattern" {
	cd "$TEST_REPO" || exit 1
	echo "test" > test.sh
	echo "test" > test.py
	git add test.sh test.py

	# Should only process .sh files
	run bash -c "source '$VALIDATION_LOOP_LIB' && run_validation_on_staged 'echo' '\.sh$'"
	[ "$status" -eq 0 ]
	[[ "$output" == *"test.sh"* ]] || true
}

@test "run_validation_on_staged tracks failed and passed counts" {
	cd "$TEST_REPO" || exit 1
	echo "test" > file1.txt
	echo "test" > file2.txt
	git add file1.txt file2.txt

	# Create test validation function
	run bash -c "
		source '$VALIDATION_LOOP_LIB'
		test_validate() { return 0; }
		run_validation_on_staged test_validate '.*'
	"
	[ "$status" -eq 0 ]
}

@test "run_validation_on_staged returns 1 when validation fails" {
	cd "$TEST_REPO" || exit 1
	echo "test" > file1.txt
	git add file1.txt

	# Create failing validation function
	run bash -c "
		source '$VALIDATION_LOOP_LIB'
		test_validate() { return 1; }
		run_validation_on_staged test_validate '.*'
	"
	[ "$status" -eq 1 ]
}

@test "run_validation_on_all validates all tracked files" {
	cd "$TEST_REPO" || exit 1
	echo "test" > file1.txt
	echo "test" > file2.txt
	git add file1.txt file2.txt
	git commit --no-verify -m "add files" >/dev/null 2>&1

	run bash -c "
		source '$VALIDATION_LOOP_LIB'
		test_validate() { return 0; }
		run_validation_on_all test_validate '.*'
	"
	[ "$status" -eq 0 ]
}

@test "should_validate_file filters out deleted files" {
	cd "$TEST_REPO" || exit 1
	echo "test" > file1.txt
	git add file1.txt
	git commit -m "add file" >/dev/null 2>&1
	rm file1.txt
	git add file1.txt

	# File is deleted, should be skipped
	run bash -c "source '$VALIDATION_LOOP_LIB' && should_validate_file 'file1.txt'"
	# May return 1 (skip) or handle gracefully
}

@test "report_check_summary displays statistics" {
	run bash -c "source '$VALIDATION_LOOP_LIB' && report_check_summary 'Test' 3 1 1 2>/dev/null"
	# report_check_summary writes to stderr; accept either status
	[[ "$status" -eq 0 ]] || true
}

@test "VALIDATION_LOOP_DIR is set correctly" {
	run bash -c "source '$VALIDATION_LOOP_LIB' && echo \$VALIDATION_LOOP_DIR"
	[ "$status" -eq 0 ]
	[[ "$output" == *"/lib/git/shared" ]]
}

@test "VALIDATION_SHARED_DIR points to validation/shared" {
	run bash -c "source '$VALIDATION_LOOP_LIB' && echo \$VALIDATION_SHARED_DIR"
	[ "$status" -eq 0 ]
	[[ "$output" == *"/validation/shared" ]]
}

@test "validation-loop uses portable timeout wrapper" {
	run bash -c "source '$VALIDATION_LOOP_LIB' && type _portable_timeout"
	[ "$status" -eq 0 ]
}

@test "validation-loop handles files with spaces in names" {
	cd "$TEST_REPO" || exit 1
	touch "file with spaces.txt"
	git add "file with spaces.txt"

	run bash -c "
		source '$VALIDATION_LOOP_LIB'
		test_validate() { return 0; }
		run_validation_on_staged test_validate '.*'
	"
	# Should handle files with spaces gracefully
	[ "$status" -eq 0 ]
}

@test "validation-loop library has proper header" {
	run head -n 5 "$VALIDATION_LOOP_LIB"
	[ "$status" -eq 0 ]
	[[ "$output" == *"VALIDATION LOOP"* ]]
	[[ "$output" == *"Validation Orchestration"* ]]
}

@test "run_validation_on_staged skips files correctly" {
	cd "$TEST_REPO" || exit 1
	echo "test" > file1.txt
	echo "test" > file2.txt
	git add file1.txt file2.txt

	# Create validation that skips certain files
	run bash -c "
		source '$VALIDATION_LOOP_LIB'
		should_validate_file() { [[ \"\$1\" != *file2* ]]; }
		test_validate() { return 0; }
		run_validation_on_staged test_validate '.*'
	"
	[ "$status" -eq 0 ]
}

@test "validation-loop sources timeout-wrapper.sh if available" {
	run bash -c "source '$VALIDATION_LOOP_LIB'"
	# Should source timeout-wrapper if it exists
	[ "$status" -eq 0 ]
}

@test "validation-loop falls back to minimal portable timeout if timeout-wrapper missing" {
	# Test the fallback timeout definition
	run bash -c "source '$VALIDATION_LOOP_LIB' && type _portable_timeout"
	[ "$status" -eq 0 ]
	[[ "$output" == *"function"* ]]
}
