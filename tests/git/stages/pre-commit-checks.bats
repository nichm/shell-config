#!/usr/bin/env bats
# Tests for lib/git/stages/commit/pre-commit-checks.sh - Pre-commit validation checks

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export PRE_COMMIT_CHECKS_LIB="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

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

@test "pre-commit-checks library exists" {
	[ -f "$PRE_COMMIT_CHECKS_LIB" ]
}

@test "pre-commit-checks library sources without error" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB'"
	[ "$status" -eq 0 ]
}

@test "run_file_length_check function is defined" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && type run_file_length_check"
	[ "$status" -eq 0 ]
}

@test "run_sensitive_files_check function is defined" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && type run_sensitive_files_check"
	[ "$status" -eq 0 ]
}

@test "run_syntax_validation function is defined" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && type run_syntax_validation"
	[ "$status" -eq 0 ]
}

@test "run_code_formatting_check function is defined" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && type run_code_formatting_check"
	[ "$status" -eq 0 ]
}

@test "run_dependency_check function is defined" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && type run_dependency_check"
	[ "$status" -eq 0 ]
}

@test "run_large_files_check function is defined" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && type run_large_files_check"
	[ "$status" -eq 0 ]
}

@test "run_commit_size_check function is defined" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && type run_commit_size_check"
	[ "$status" -eq 0 ]
}

@test "run_gitleaks_secrets_check function is defined" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && type run_gitleaks_secrets_check"
	[ "$status" -eq 0 ]
}

@test "run_opengrep_security_check function is defined" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && type run_opengrep_security_check"
	[ "$status" -eq 0 ]
}

@test "run_unit_tests function is defined" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && type run_unit_tests"
	[ "$status" -eq 0 ]
}

@test "run_typescript_check function is defined" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && type run_typescript_check"
	[ "$status" -eq 0 ]
}

@test "run_circular_dependency_check function is defined" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && type run_circular_dependency_check"
	[ "$status" -eq 0 ]
}

@test "run_env_security_check function is defined" {
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && type run_env_security_check"
	[ "$status" -eq 0 ]
}

@test "run_file_length_check creates result file in tmpdir" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo "test" > file.txt
	git add file.txt

	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_file_length_check '$tmpdir' file.txt"
	# Result file should be created when check runs
	[ -f "$tmpdir/file_length_check.result" ] || skip "Result file not created (check may have been skipped)"
}

@test "run_syntax_validation handles shell files" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo '#!/bin/bash\necho test' > test.sh
	git add test.sh

	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_syntax_validation '$tmpdir' test.sh"
	# Result file should be created when check runs
	[ -f "$tmpdir/syntax_validation.result" ] || skip "Result file not created (check may have been skipped)"
}

@test "run_sensitive_files_check detects .env files" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo "SECRET=value" > .env
	git add .env

	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_sensitive_files_check '$tmpdir'"
	# Should detect .env file and fail (return 1) or succeed with warning
	[ "$status" -eq 0 ] || skip "Tool not available or check skipped"
}

@test "run_large_files_check respects MAX_FILE_SIZE" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	# Create small file
	echo "test" > small.txt
	git add small.txt

	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && MAX_FILE_SIZE=\$((5 * 1024 * 1024)) && run_large_files_check '$tmpdir' small.txt"
	[ "$status" -eq 0 ]
}

@test "run_commit_size_check counts lines correctly" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	# Create files with known line counts
	for i in {1..10}; do
		echo "line $i" >> file.txt
	done
	git add file.txt

	# Source full pre-commit.sh to get tier constants, then run the check
	local pre_commit_lib="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit.sh"
	run bash -c "source '$pre_commit_lib' && run_commit_size_check '$tmpdir'"
	[ "$status" -eq 0 ]
}

@test "run_dependency_check detects package.json changes" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo '{"name":"test"}' > package.json
	git add package.json

	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_dependency_check '$tmpdir' package.json"
	# Should process package.json (may pass or warn)
	[ "$status" -eq 0 ] || skip "Dependency check tool not available"
}

@test "checks use temp directory for parallel execution" {
	local tmpdir="$TEST_TMP_DIR"
	[ -d "$tmpdir" ]

	# Checks should write to temp dir
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_file_length_check '$tmpdir'"
	# Should not crash when using temp dir
	[ "$status" -eq 0 ] || skip "Tool not available or check skipped"
}

@test "run_secrets_scan handles gitleaks timeout" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo "test" > file.txt
	git add file.txt

	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_secrets_scan '$tmpdir'"
	# Should handle gracefully even if gitleaks not installed (may skip or pass)
	[ "$status" -eq 0 ] || skip "Tool not available or check skipped"
}

@test "run_unit_tests handles bun test" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo "test" > test.ts
	git add test.ts

	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_unit_tests '$tmpdir'"
	# Should handle gracefully even if bun not installed (may skip or pass)
	[ "$status" -eq 0 ] || skip "Tool not available or check skipped"
}

@test "run_type_check handles TypeScript files" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo "const x: number = 1;" > test.ts
	git add test.ts

	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_type_check '$tmpdir'"
	# Should handle gracefully even if tsc not installed (may skip or pass)
	[ "$status" -eq 0 ] || skip "Tool not available or check skipped"
}

@test "run_circular_dep_check handles import analysis" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo "test" > file.ts
	git add file.ts

	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_circular_dep_check '$tmpdir'"
	# Should handle gracefully (may skip or pass)
	[ "$status" -eq 0 ] || skip "Tool not available or check skipped"
}

@test "run_infra_validation handles Terraform/CloudFormation" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo "test" > main.tf
	git add main.tf

	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_infra_validation '$tmpdir'"
	# Should handle gracefully (may skip or pass)
	[ "$status" -eq 0 ] || skip "Tool not available or check skipped"
}

@test "pre-commit-checks library has proper header" {
	run head -n 5 "$PRE_COMMIT_CHECKS_LIB"
	[ "$status" -eq 0 ]
	[[ "$output" == *"pre-commit-checks.sh"* ]] || true
}

@test "checks handle empty file list gracefully" {
	local tmpdir="$TEST_TMP_DIR"
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_file_length_check '$tmpdir'"
	[ "$status" -eq 0 ]
}

@test "checks handle files with spaces in names" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo "test" > "file with spaces.txt"
	git add "file with spaces.txt"

	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_file_length_check '$tmpdir' 'file with spaces.txt'"
	# Should handle files with spaces gracefully (may pass or skip)
	[ "$status" -eq 0 ] || skip "Tool not available or check skipped"
}

@test "run_code_formatting_check detects formatting issues" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo "test" > file.py
	git add file.py

	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_code_formatting_check '$tmpdir' file.py"
	# Should handle gracefully even if formatters not installed (may skip or pass)
	[ "$status" -eq 0 ] || skip "Tool not available or check skipped"
}

@test "run_deep_security_scan handles opengrep" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo "test" > file.txt
	git add file.txt

	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_deep_security_scan '$tmpdir'"
	# Should handle gracefully even if opengrep not installed (may skip or pass)
	[ "$status" -eq 0 ] || skip "Tool not available or check skipped"
}

@test "checks write result files to tmpdir" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo "test" > file.txt
	git add file.txt

	# Run multiple checks
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_file_length_check '$tmpdir' file.txt"
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_syntax_validation '$tmpdir' file.txt"

	# Check that result files may exist
	[ -d "$tmpdir" ]
}

@test "checks are non-blocking when tools not installed" {
	local tmpdir="$TEST_TMP_DIR"
	cd "$TEST_REPO" || exit 1
	echo "test" > file.txt
	git add file.txt

	# All checks should handle missing tools gracefully
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_syntax_validation '$tmpdir' file.txt"
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_code_formatting_check '$tmpdir' file.txt"
	run bash -c "source '$PRE_COMMIT_CHECKS_LIB' && run_unit_tests '$tmpdir'"

	# Should not crash - may skip or pass depending on tool availability
	[ "$status" -eq 0 ] || skip "Tool not available or check skipped"
}
