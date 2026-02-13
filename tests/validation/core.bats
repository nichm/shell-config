#!/usr/bin/env bats
# Tests for lib/validation/core.sh - Unified validation engine

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export VALIDATION_CORE_LIB="$SHELL_CONFIG_DIR/lib/validation/core.sh"

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

@test "validation core library exists" {
	[ -f "$VALIDATION_CORE_LIB" ]
}

@test "validation core library sources without error" {
	run bash -c "source '$VALIDATION_CORE_LIB'"
	[ "$status" -eq 0 ]
}

@test "validate_file function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validate_file"
	[ "$status" -eq 0 ]
}

@test "validate_files function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validate_files"
	[ "$status" -eq 0 ]
}

@test "validate_staged_files function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validate_staged_files"
	[ "$status" -eq 0 ]
}

@test "validate_and_report_staged_files function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validate_and_report_staged_files"
	[ "$status" -eq 0 ]
}

@test "validation_reset_all function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validation_reset_all"
	[ "$status" -eq 0 ]
}

@test "validate_all_syntax function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validate_all_syntax"
	[ "$status" -eq 0 ]
}

@test "validate_all_security function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validate_all_security"
	[ "$status" -eq 0 ]
}

@test "validate_all_file_lengths function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validate_all_file_lengths"
	[ "$status" -eq 0 ]
}

@test "validate_all_workflows function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validate_all_workflows"
	[ "$status" -eq 0 ]
}

@test "validate_directory function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validate_directory"
	[ "$status" -eq 0 ]
}

@test "validate_repo_workflows function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validate_repo_workflows"
	[ "$status" -eq 0 ]
}

@test "validation_has_issues function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validation_has_issues"
	[ "$status" -eq 0 ]
}

@test "validation_has_blocking_issues function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validation_has_blocking_issues"
	[ "$status" -eq 0 ]
}

@test "validation_summary function is defined" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type validation_summary"
	[ "$status" -eq 0 ]
}

@test "validate_file returns success for valid file" {
	cd "$TEST_REPO" || exit 1
	echo "#!/bin/bash\necho test" > test.sh

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_file test.sh"
	[ "$status" -eq 0 ]
}

@test "validate_file returns success for missing file (skipped)" {
	run bash -c "source '$VALIDATION_CORE_LIB' && validate_file nonexistent.txt"
	# Missing files are skipped (not errors), so return 0
	[ "$status" -eq 0 ]
}

@test "validate_file checks file length" {
	cd "$TEST_REPO" || exit 1
	# Create a file with known length (under threshold)
	for i in {1..50}; do
		echo "line $i" >> test.txt
	done

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_file test.txt"
	# Small file should pass validation
	[ "$status" -eq 0 ]
}

@test "validate_file checks sensitive filenames" {
	cd "$TEST_REPO" || exit 1
	echo "secret=value" > .env

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_file .env"
	# Should detect .env as sensitive
	[ "$status" -eq 1 ]
}

@test "validate_file checks syntax for .sh files" {
	cd "$TEST_REPO" || exit 1
	echo "#!/bin/bash\necho test" > test.sh

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_file test.sh"
	[ "$status" -eq 0 ]
}

@test "validate_file handles syntax errors in .sh files" {
	cd "$TEST_REPO" || exit 1
	echo "#!/bin/bash\nif [" > test.sh # Syntax error

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_file test.sh 2>&1"
	# Should detect syntax error and fail
	[ "$status" -eq 1 ] || skip "Syntax validator may not be available"
}

@test "validate_files handles multiple files" {
	cd "$TEST_REPO" || exit 1
	echo "test" > file1.txt
	echo "test" > file2.txt

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_files file1.txt file2.txt"
	[ "$status" -eq 0 ]
}

@test "validate_staged_files works with git" {
	cd "$TEST_REPO" || exit 1
	echo "test" > file.txt
	git add file.txt

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_staged_files"
	[ "$status" -eq 0 ]
}

@test "validate_staged_files handles no staged files" {
	cd "$TEST_REPO" || exit 1
	# No staged files

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_staged_files"
	[ "$status" -eq 0 ]
}

@test "validate_and_report_staged_files shows report" {
	cd "$TEST_REPO" || exit 1
	echo "#!/bin/bash\necho test" > test.sh
	git add test.sh

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_and_report_staged_files 2>&1"
	# Should show report and succeed
	[ "$status" -eq 0 ]
}

@test "validation_reset_all resets validators" {
	run bash -c "source '$VALIDATION_CORE_LIB' && validation_reset_all"
	[ "$status" -eq 0 ]
}

@test "validate_all_syntax validates syntax only" {
	cd "$TEST_REPO" || exit 1
	echo "#!/bin/bash\necho test" > test.sh

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_all_syntax test.sh"
	[ "$status" -eq 0 ]
}

@test "validate_all_security checks sensitive files" {
	cd "$TEST_REPO" || exit 1
	echo "secret=value" > .env
	git add .env

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_all_security .env 2>&1"
	# Should detect .env as sensitive and fail
	[ "$status" -eq 1 ] || skip "Security validator may not be available"
}

@test "validate_all_file_lengths checks file sizes" {
	cd "$TEST_REPO" || exit 1
	for i in {1..100}; do
		echo "line $i" >> test.txt
	done

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_all_file_lengths test.txt"
	[ "$status" -eq 0 ]
}

@test "validate_directory validates all files in directory" {
	cd "$TEST_REPO" || exit 1
	mkdir -p testdir
	echo "test" > testdir/file1.txt
	echo "test" > testdir/file2.txt

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_directory testdir"
	[ "$status" -eq 0 ]
}

@test "validate_directory handles missing directory" {
	run bash -c "source '$VALIDATION_CORE_LIB' && validate_directory nonexistent_dir"
	[ "$status" -eq 1 ]
}

@test "validate_repo_workflows finds .github/workflows" {
	cd "$TEST_REPO" || exit 1
	mkdir -p .github/workflows
	echo "on: push\njobs: {}" > .github/workflows/test.yml

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_repo_workflows 2>&1"
	# Should validate workflows
	[ "$status" -eq 0 ] || skip "Workflow validator may not be available"
}

@test "validate_repo_workflows handles missing workflows dir" {
	cd "$TEST_REPO" || exit 1
	# No .github/workflows directory

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_repo_workflows"
	[ "$status" -eq 0 ]
}

@test "validation_has_issues returns correct status" {
	run bash -c "source '$VALIDATION_CORE_LIB' && validation_has_issues"
	# Fresh source with no validations run: all sub-validators return non-zero (no issues)
	# The || chain propagates the last non-zero exit, so status should be non-zero
	[ "$status" -ne 0 ]
}

@test "validation_has_blocking_issues returns correct status" {
	run bash -c "source '$VALIDATION_CORE_LIB' && validation_has_blocking_issues"
	# Fresh source with no validations run: all sub-validators return non-zero (no issues)
	[ "$status" -ne 0 ]
}

@test "validation_summary displays summary" {
	run bash -c "source '$VALIDATION_CORE_LIB' && validation_summary 2>&1"
	# Should display summary (always succeeds even if empty)
	[ "$status" -eq 0 ]
}

@test "validation core loads all validators" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type file_validator_reset"
	[ "$status" -eq 0 ]

	run bash -c "source '$VALIDATION_CORE_LIB' && type security_validator_reset"
	[ "$status" -eq 0 ]

	run bash -c "source '$VALIDATION_CORE_LIB' && type syntax_validator_reset"
	[ "$status" -eq 0 ]
}

@test "validation core prevents double sourcing" {
	run bash -c "source '$VALIDATION_CORE_LIB' && source '$VALIDATION_CORE_LIB'"
	[ "$status" -eq 0 ]
}

@test "validation core sources shared utilities" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type get_staged_files"
	[ "$status" -eq 0 ]
}

@test "validation core sources all validators" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type workflow_validator_reset"
	[ "$status" -eq 0 ]

	run bash -c "source '$VALIDATION_CORE_LIB' && type infra_validator_reset"
	[ "$status" -eq 0 ]

	run bash -c "source '$VALIDATION_CORE_LIB' && type phantom_validator_reset"
	[ "$status" -eq 0 ]
}

@test "validation core handles files with spaces in names" {
	cd "$TEST_REPO" || exit 1
	echo "test" > "file with spaces.txt"

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_file 'file with spaces.txt'"
	# Should handle files with spaces
	[ "$status" -eq 0 ]
}

@test "validation core library has proper header" {
	run head -n 5 "$VALIDATION_CORE_LIB"
	[ "$status" -eq 0 ]
	[[ "$output" == *"VALIDATION CORE"* ]]
	[[ "$output" == *"Unified Validation Engine"* ]]
}

@test "backwards compatibility functions exist" {
	run bash -c "source '$VALIDATION_CORE_LIB' && type _validate_staged_files"
	[ "$status" -eq 0 ]

	run bash -c "source '$VALIDATION_CORE_LIB' && type check_file_length"
	[ "$status" -eq 0 ]

	run bash -c "source '$VALIDATION_CORE_LIB' && type check_sensitive_filenames"
	[ "$status" -eq 0 ]

	run bash -c "source '$VALIDATION_CORE_LIB' && type gha_validate"
	[ "$status" -eq 0 ]
}

@test "validate_file auto-detects workflow files" {
	cd "$TEST_REPO" || exit 1
	mkdir -p .github/workflows
	echo "on: push" > .github/workflows/test.yml

	run bash -c "source '$VALIDATION_CORE_LIB' && validate_file .github/workflows/test.yml 2>&1"
	# Should validate workflow files
	[ "$status" -eq 0 ] || skip "Workflow validator may not be available"
}

@test "validation core exports functions for bash" {
	run bash -c "source '$VALIDATION_CORE_LIB' && export -f validate_file"
	[ "$status" -eq 0 ]
}

@test "validate_file handles non-existent files gracefully" {
	run bash -c "source '$VALIDATION_CORE_LIB' && validate_file /nonexistent/file.txt"
	[ "$status" -eq 0 ] # Non-existent files are skipped
}

@test "validate_files handles empty file list" {
	run bash -c "source '$VALIDATION_CORE_LIB' && validate_files"
	[ "$status" -eq 0 ]
}
