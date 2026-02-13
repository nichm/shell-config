#!/usr/bin/env bats
# =============================================================================
# 🧪 GIT HOOKS MODULE TESTS - Git Hook Validation Testing
# =============================================================================
# Tests for git hooks and validation modules including:
#   - lib/validation/validators/core/file-validator.sh: File length validation
#   - lib/validation/validators/security/sensitive-files-validator.sh: Sensitive file detection
#   - lib/git/shared/validation-loop.sh: Validation iteration logic
# =============================================================================

setup() {
	local repo_root
	repo_root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel 2>/dev/null || { cd "$BATS_TEST_DIRNAME/../.." && pwd; })"
	export SHELL_CONFIG_DIR="$repo_root"
	export HOOKS_LIB_DIR="$SHELL_CONFIG_DIR/lib/git/hooks"
	export VALIDATION_LIB_DIR="$SHELL_CONFIG_DIR/lib/validation"

	# Create temp directory (cleanup in teardown, not EXIT trap which interferes with bats)
	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	# Initialize git repo (disable hooks to prevent global gitconfig interference in parallel)
	git init --initial-branch=main >/dev/null 2>&1
	git config user.email "test@example.com"
	git config user.name "Test User"
	git config core.hooksPath /dev/null

	# Source core dependencies first
	source "$SHELL_CONFIG_DIR/lib/core/colors.sh"
	
	# Source validation modules
	source "$VALIDATION_LIB_DIR/validators/core/file-validator.sh"
	source "$VALIDATION_LIB_DIR/validators/security/security-validator.sh"
	source "$VALIDATION_LIB_DIR/validators/security/sensitive-files-validator.sh" 2>/dev/null || true
	source "$SHELL_CONFIG_DIR/lib/git/shared/validation-loop.sh"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

# =============================================================================
# 📐 FILE LENGTH VALIDATOR TESTS
# =============================================================================

@test "file-validator: validate_file_length validates a file" {
	seq 1 100 >"small.py"
	
	file_validator_reset
	run validate_file_length "small.py"
	[ "$status" -eq 0 ]
}

@test "file-validator: validate_file_length detects large files" {
	seq 1 1000 >"large.py"
	
	file_validator_reset
	validate_file_length "large.py"
	run file_validator_has_violations
	[ "$status" -eq 0 ]  # has_violations returns 0 (true) when violations exist
}

@test "file-validator: file_validator_reset clears state" {
	seq 1 1000 >"large.py"
	validate_file_length "large.py"
	
	file_validator_reset
	
	# After reset, should have no violations
	[ "$(file_validator_extreme_count)" -eq 0 ]
	[ "$(file_validator_warning_count)" -eq 0 ]
}

@test "file-validator: validate_file_length detects extreme violations" {
	seq 1 1000 >"large.py"
	
	file_validator_reset
	validate_file_length "large.py"
	# Should detect extreme violations (1000 lines is above 800-line extreme threshold)
	[ "$(file_validator_extreme_count)" -gt 0 ]
}

# =============================================================================
# 🔒 SENSITIVE FILES VALIDATOR TESTS
# =============================================================================

@test "security-validator: detects sensitive filenames" {
	touch ".env"
	
	security_validator_reset
	# validate_sensitive_filename returns 1 for sensitive files, which is expected
	validate_sensitive_filename ".env" || true
	run security_validator_has_violations
	[ "$status" -eq 0 ]  # has_violations returns 0 (true) when violations exist
}

@test "security-validator: allows safe files" {
	touch "safe.txt"
	touch "config.json"
	
	security_validator_reset
	validate_sensitive_filename "safe.txt"
	validate_sensitive_filename "config.json"
	run security_validator_has_violations
	[ "$status" -eq 1 ]  # has_violations returns 1 (false) when no violations
}

# =============================================================================
# 🔄 VALIDATION LOOP TESTS
# =============================================================================

@test "validation-loop: run_validation_on_staged validates staged files" {
	# Create test files
	seq 1 100 >"test1.py"
	seq 1 200 >"test2.sh"
	git add test1.py test2.sh

	# Create a simple validation function
	test_validator() {
		local file="$1"
		[[ -f "$file" ]]
	}

	run run_validation_on_staged "test_validator" "\.py$"
	[ "$status" -eq 0 ]
}

@test "validation-loop: run_validation_on_staged filters by regex pattern" {
	seq 1 100 >"test.py"
	seq 1 100 >"test.sh"
	git add test.py test.sh

	# Test that only .py files are processed by checking output
	validate_python() {
		echo "validated: $1"
		return 0
	}
	export -f validate_python

	run run_validation_on_staged "validate_python" "\.py$"
	[ "$status" -eq 0 ]
	[[ "$output" == *"test.py"* ]]
	[[ "$output" != *"test.sh"* ]]
}

@test "validation-loop: run_validation_on_staged handles no matching files" {
	run run_validation_on_staged "echo" "\.nonexistent$"
	[ "$status" -eq 0 ]
}

@test "validation-loop: run_validation_on_staged returns failure on validation errors" {
	echo "test" >"test.txt"
	git add "test.txt"

	failing_validator() {
		return 1
	}

	run run_validation_on_staged "failing_validator"
	[ "$status" -eq 1 ]
}

@test "validation-loop: run_validation_on_all validates all tracked files" {
	echo "test1" >"file1.txt"
	echo "test2" >"file2.txt"
	git add file1.txt file2.txt
	git commit --no-verify -m "Initial commit" >/dev/null 2>&1

	count_validator() {
		echo "validated: $1"
		return 0
	}
	export -f count_validator

	run run_validation_on_all "count_validator" "\.txt$"
	[ "$status" -eq 0 ]
	[[ "$output" == *"file1.txt"* ]]
	[[ "$output" == *"file2.txt"* ]]
}

@test "validation-loop: run_validation_on_range validates files in range" {
	echo "v1" >"file.txt"
	git add file.txt
	git commit --no-verify -m "Commit 1" >/dev/null 2>&1

	echo "v2" >"file.txt"
	git add file.txt
	git commit --no-verify -m "Commit 2" >/dev/null 2>&1

	count_validator() {
		echo "validated: $1"
		return 0
	}
	export -f count_validator

	run run_validation_on_range "count_validator" "HEAD~1..HEAD" "\.txt$"
	[ "$status" -eq 0 ]
	[[ "$output" == *"file.txt"* ]]
}

# =============================================================================
# 🔧 ADVANCED VALIDATION LOOP TESTS
# =============================================================================

@test "validation-loop: run_validation_collect_errors collects all errors" {
	echo "error1" >"file1.txt"
	echo "error2" >"file2.txt"
	git add file1.txt file2.txt

	error_collecting_validator() {
		echo "Error in $1"
	}

	run run_validation_collect_errors "error_collecting_validator"
	[ "$status" -eq 2 ]  # 2 files should fail
	[[ "$output" == *"Error in file1.txt"* ]]
	[[ "$output" == *"Error in file2.txt"* ]]
}

@test "validation-loop: run_validation_if executes validation when condition is met" {
	echo "test" >"test.txt"
	git add "test.txt"

	test_validator() {
		return 0
	}

	run run_validation_if "command -v echo" "test_validator"
	[ "$status" -eq 0 ]
}

@test "validation-loop: run_validation_if skips when condition fails" {
	echo "test" >"test.txt"
	git add "test.txt"

	test_validator() {
		echo "Should not run"
		return 1
	}

	run run_validation_if "command -v nonexistentcommand_xyz123" "test_validator"
	[ "$status" -eq 0 ]
	[[ "$output" != *"Should not run"* ]]
}

@test "validation-loop: run_validation_with_skip respects skip flag" {
	echo "test" >"test.txt"
	git add "test.txt"

	test_validator() {
		echo "Should not run"
		return 1
	}

	export TEST_SKIP_FLAG=1
	run run_validation_with_skip "TEST_SKIP_FLAG" "test_validator"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Skipped"* ]]
}

@test "validation-loop: run_validation_with_skip executes when flag not set" {
	echo "test" >"test.txt"
	git add "test.txt"

	test_validator() {
		return 0
	}

	unset TEST_SKIP_FLAG
	run run_validation_with_skip "TEST_SKIP_FLAG" "test_validator"
	[ "$status" -eq 0 ]
	[[ "$output" != *"Skipped"* ]]
}

@test "validation-loop: run_multiple_validations runs all validations" {
	run run_multiple_validations "true" "true" "true"
	[ "$status" -eq 0 ]
}

@test "validation-loop: run_multiple_validations detects failures" {
	run run_multiple_validations "true" "false" "true"
	[ "$status" -eq 1 ]
}

@test "validation-loop: run_multiple_validations_strict exits on first failure" {
	first_validator() {
		echo "first"
		return 0
	}
	failing_validator() {
		echo "failing"
		return 1
	}
	third_validator() {
		echo "third"
		return 0
	}
	export -f first_validator failing_validator third_validator

	run run_multiple_validations_strict "first_validator" "failing_validator" "third_validator"
	[ "$status" -eq 1 ]
	[[ "$output" == *"first"* ]]
	[[ "$output" == *"failing"* ]]
	[[ "$output" != *"third"* ]]
}

@test "validation-loop: run_validation_on_extensions filters by extension" {
	echo "test" >"file.py"
	echo "test" >"file.js"
	echo "test" >"file.txt"
	git add file.py file.js file.txt

	count_validator() {
		echo "validated: $1"
		return 0
	}
	export -f count_validator

	run run_validation_on_extensions "count_validator" "py,js"
	[ "$status" -eq 0 ]
	[[ "$output" == *"file.py"* ]]
	[[ "$output" == *"file.js"* ]]
	[[ "$output" != *"file.txt"* ]]
}

@test "validation-loop: run_validation_exclude_paths excludes specified paths" {
	mkdir -p vendor
	echo "test" >"file.txt"
	echo "test" >"vendor/file.txt"
	git add file.txt vendor/file.txt

	count_validator() {
		echo "validated: $1"
		return 0
	}
	export -f count_validator

	run run_validation_exclude_paths "count_validator" "vendor" "\.txt$"
	[ "$status" -eq 0 ]
	[[ "$output" == *"file.txt"* ]]
	[[ "$output" != *"vendor/file.txt"* ]]
}

# =============================================================================
# 🔧 INTEGRATION TESTS
# =============================================================================

@test "integration: file-validator and security-validator work together" {
	# Create files that violate both checks
	seq 1 1000 >"large.py"
	touch ".env"

	file_validator_reset
	security_validator_reset
	
	validate_file_length "large.py"
	# validate_sensitive_filename returns 1 for sensitive files, which is expected
	validate_sensitive_filename ".env" || true
	
	# Both should have violations
	run file_validator_has_violations
	[ "$status" -eq 0 ]
	
	run security_validator_has_violations
	[ "$status" -eq 0 ]
}

@test "integration: validation loop can orchestrate multiple validators" {
	seq 1 600 >"warning.py"
	touch ".env"
	git add warning.py .env

	# Create simple validators that return failure
	check_length() {
		return 1
	}

	check_sensitive() {
		return 1
	}

	run run_multiple_validations_strict "check_length" "check_sensitive"
	[ "$status" -eq 1 ]
}

# =============================================================================
# 🔗 PRE-COMMIT DISPLAY REGRESSION TESTS (PR #95)
# =============================================================================

@test "pre-commit.sh sources pre-commit-display.sh from correct path" {
	local pre_commit_script="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit.sh"
	local pre_commit_display="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-display.sh"

	# Verify both files exist
	[ -f "$pre_commit_script" ]
	[ -f "$pre_commit_display" ]

	# Verify the source path is correct (should not have ../commit/ prefix)
	local source_line
	source_line=$(grep -n "source.*pre-commit-display.sh" "$pre_commit_script" || echo "")

	[ -n "$source_line" ]

	# Should source from same directory, not ../commit/
	[[ "$source_line" == *'source "$PRE_COMMIT_DIR/pre-commit-display.sh"'* ]] || \
	[[ "$source_line" == *'source "$PRE_COMMIT_DIR/../../hooks/pre-commit-display.sh"'* ]]
}

@test "pre-commit-display.sh contains required functions" {
	local pre_commit_display="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-display.sh"

	[ -f "$pre_commit_display" ]

	# Source the file
	# shellcheck source=lib/git/stages/commit/pre-commit-display.sh
	source "$pre_commit_display"

	# Verify key display functions exist
	type display_validation_results &>/dev/null
	type display_blocked_message &>/dev/null
}
