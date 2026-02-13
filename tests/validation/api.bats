#!/usr/bin/env bats
# Require BATS 1.5.0+ for `run !` syntax
bats_require_minimum_version 1.5.0

# =============================================================================
# 🧪 VALIDATION MODULE TESTS - Comprehensive Validation Testing
# =============================================================================
# Tests for validation module including:
#   - file-validator.sh: File size and line count validation
#   - infra-validator.sh: Infrastructure configuration validation
#   - security-validator.sh: Sensitive filename detection
#   - workflow-validator.sh: GitHub Actions workflow validation
#   - shared/config.sh: Validation configuration
#   - shared/file-operations.sh: File handling utilities
#   - shared/patterns.sh: Regex patterns for validation
#   - shared/reporters.sh: Output formatting
#   - shared/workflow-scanners.sh: Workflow scanning utilities
# =============================================================================

setup() {
	local repo_root
	repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
	export SHELL_CONFIG_DIR="$repo_root"
	export VALIDATION_LIB_DIR="$SHELL_CONFIG_DIR/lib/validation"

	# Create temp directory (cleanup in teardown, not EXIT trap which interferes with bats)
	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	# Initialize git repo (disable hooks to prevent global gitconfig interference in parallel)
	git init --initial-branch=main >/dev/null 2>&1
	git config user.email "test@example.com"
	git config user.name "Test User"
	git config core.hooksPath /dev/null

	# Source validation libraries (patterns.sh must be sourced before security-validator.sh)
	source "$VALIDATION_LIB_DIR/shared/config.sh"
	source "$VALIDATION_LIB_DIR/shared/patterns.sh"
	source "$VALIDATION_LIB_DIR/shared/file-operations.sh"
	source "$VALIDATION_LIB_DIR/shared/reporters.sh"
	source "$VALIDATION_LIB_DIR/validators/core/file-validator.sh"
	source "$VALIDATION_LIB_DIR/validators/security/security-validator.sh"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

# =============================================================================
# 📐 FILE VALIDATOR TESTS
# =============================================================================

@test "file-validator: validate_file_length handles missing file" {
	run validate_file_length "/nonexistent/file.txt"
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "file-validator: get_language_limit returns correct limit for Python files" {
	local limit
	limit=$(get_language_limit "test.py")
	[ "$limit" = "800" ]
}

@test "file-validator: get_language_limit returns correct limit for JavaScript files" {
	local limit
	limit=$(get_language_limit "test.js")
	[ "$limit" = "800" ]
}

@test "file-validator: get_language_limit returns correct limit for Shell scripts" {
	local limit
	limit=$(get_language_limit "test.sh")
	[ "$limit" = "600" ]
}

@test "file-validator: get_language_limit returns correct limit for Rust files" {
	local limit
	limit=$(get_language_limit "test.rs")
	[ "$limit" = "1500" ]
}

@test "file-validator: get_language_limit returns correct limit for YAML files" {
	local limit
	limit=$(get_language_limit "test.yml")
	[ "$limit" = "5000" ]
}

@test "file-validator: get_language_limit returns correct limit for JSON files" {
	local limit
	limit=$(get_language_limit "test.json")
	[ "$limit" = "5000" ]
}

@test "file-validator: get_language_limit returns correct limit for Dockerfile" {
	local limit
	limit=$(get_language_limit "Dockerfile")
	[ "$limit" = "2000" ]
}

@test "file-validator: get_language_limit returns correct limit for package.json" {
	local limit
	limit=$(get_language_limit "package.json")
	[ "$limit" = "2000" ]
}

@test "file-validator: get_language_limit returns correct limit for .gitignore" {
	local limit
	limit=$(get_language_limit ".gitignore")
	[ "$limit" = "5000" ]
}

@test "file-validator: get_language_limit returns default for unknown extension" {
	local limit
	limit=$(get_language_limit "test.unknown")
	[ "$limit" = "800" ]
}

@test "file-validator: get_language_limit handles files without extension" {
	local limit
	limit=$(get_language_limit "Makefile")
	[ "$limit" = "2000" ]
}

@test "file-validator: get_thresholds returns correct three-tier thresholds" {
	local thresholds
	thresholds=$(get_thresholds 800)
	# Expected: 480 600 800 (60%, 75%, 100%)
	[[ "$thresholds" == *"480"* ]]
	[[ "$thresholds" == *"600"* ]]
	[[ "$thresholds" == *"800"* ]]
}

@test "file-validator: validate_file_length detects extreme violation" {
	# Create a file exceeding limit (800 lines for .py)
	local test_file="large.py"
	seq 1 1000 >"$test_file"

	file_validator_reset
	validate_file_length "$test_file"
	file_validator_has_violations
	[ "$(file_validator_extreme_count)" -eq 1 ]
}

@test "file-validator: validate_file_length detects warning violation" {
	# Create a file at warning level (600 lines for .py = 75% of 800)
	local test_file="warning.py"
	seq 1 600 >"$test_file"

	file_validator_reset
	validate_file_length "$test_file"
	file_validator_has_violations
	[ "$(file_validator_warning_count)" -eq 1 ]
}

@test "file-validator: validate_file_length detects info violation" {
	# Create a file at info level (480 lines for .py = 60% of 800)
	local test_file="info.py"
	seq 1 480 >"$test_file"

	file_validator_reset
	validate_file_length "$test_file"
	file_validator_has_violations
	[ "$(file_validator_info_count)" -eq 1 ]
}

@test "file-validator: validate_file_length skips small files" {
	local test_file="small.py"
	seq 1 100 >"$test_file"

	# Reset before test
	file_validator_reset
	
	# Run validation directly (not in subshell) so arrays persist
	validate_file_length "$test_file"
	
	# Should have no violations for small file
	# shellcheck disable=SC2314 # Direct negation needed to preserve array state (not in subshell)
	! file_validator_has_violations
}

@test "file-validator: file_validator_reset clears all violations" {
	local test_file="large.py"
	seq 1 1000 >"$test_file"

	# First create some violations
	file_validator_reset
	validate_file_length "$test_file"
	file_validator_has_violations

	# Reset and verify cleared
	file_validator_reset
	# shellcheck disable=SC2314 # Direct negation needed to preserve array state (not in subshell)
	! file_validator_has_violations
	[ "$(file_validator_info_count)" -eq 0 ]
	[ "$(file_validator_warning_count)" -eq 0 ]
	[ "$(file_validator_extreme_count)" -eq 0 ]
}

@test "file-validator: validate_files_length handles multiple files" {
	seq 1 1000 >"extreme.py"
	seq 1 600 >"warning.py"
	seq 1 480 >"info.py"
	seq 1 100 >"small.py"

	# validate_files_length calls file_validator_reset internally
	validate_files_length extreme.py warning.py info.py small.py
	[ "$(file_validator_extreme_count)" -eq 1 ]
	[ "$(file_validator_warning_count)" -eq 1 ]
	[ "$(file_validator_info_count)" -eq 1 ]
}

# =============================================================================
# 📁 FILE OPERATIONS TESTS
# =============================================================================

@test "file-operations: count_file_lines returns correct count" {
	local test_file="test.txt"
	seq 1 100 >"$test_file"

	local lines
	lines=$(count_file_lines "$test_file")
	[ "$lines" = "100" ]
}

@test "file-operations: count_file_lines returns 0 for missing file" {
	local lines
	lines=$(count_file_lines "/nonexistent/file.txt")
	[ "$lines" = "0" ]
}

@test "file-operations: get_file_extension extracts extension correctly" {
	local ext
	ext=$(get_file_extension "test.py")
	[ "$ext" = "py" ]

	ext=$(get_file_extension "/path/to/file.json")
	[ "$ext" = "json" ]
}

@test "file-operations: get_file_extension handles files without extension" {
	local ext
	ext=$(get_file_extension "Makefile")
	[ "$ext" = "" ]

	ext=$(get_file_extension "/path/to/Dockerfile")
	[ "$ext" = "" ]
}

@test "file-operations: get_filename returns basename" {
	local filename
	filename=$(get_filename "/path/to/test.py")
	[ "$filename" = "test.py" ]
}

@test "file-operations: is_file_type detects correct type" {
	run is_file_type "test.py" "py"
	[ "$status" -eq 0 ]

	run is_file_type "test.js" "py"
	[ "$status" -eq 1 ]
}

@test "file-operations: is_shell_script detects by extension" {
	run is_shell_script "test.sh"
	[ "$status" -eq 0 ]

	run is_shell_script "test.bash"
	[ "$status" -eq 0 ]

	run is_shell_script "test.py"
	[ "$status" -eq 1 ]
}

@test "file-operations: is_shell_script detects by shebang" {
	local test_file="script"
	echo "#!/usr/bin/env bash" >"$test_file"
	echo "echo 'test'" >>"$test_file"

	is_shell_script "$test_file"
	[ "$?" -eq 0 ]
}

@test "file-operations: is_yaml_file detects YAML files" {
	run is_yaml_file "test.yml"
	[ "$status" -eq 0 ]

	run is_yaml_file "test.yaml"
	[ "$status" -eq 0 ]

	run is_yaml_file "test.json"
	[ "$status" -eq 1 ]
}

@test "file-operations: is_json_file detects JSON files" {
	run is_json_file "test.json"
	[ "$status" -eq 0 ]

	run is_json_file "test.yml"
	[ "$status" -eq 1 ]
}

@test "file-operations: is_github_workflow detects workflow files" {
	run is_github_workflow ".github/workflows/test.yml"
	[ "$status" -eq 0 ]

	run is_github_workflow "/path/to/.github/workflows/test.yaml"
	[ "$status" -eq 0 ]

	run is_github_workflow "test.yml"
	[ "$status" -eq 1 ]
}

@test "file-operations: get_file_hash returns SHA256 hash" {
	local test_file="test.txt"
	echo "test content" >"$test_file"

	local hash
	hash=$(get_file_hash "$test_file")
	[ "$?" -eq 0 ]
	[ "${#hash}" -eq 64 ] # SHA256 produces 64 character hash
}

@test "file-operations: is_binary_file detects binary files" {
	# Skip if file command not available
	command -v file >/dev/null 2>&1 || skip "file command not available"

	# Create a binary file
	printf '\x00\x01\x02\x03' >"binary.bin"

	is_binary_file "binary.bin"
	[ "$?" -eq 0 ]
}

@test "file-operations: is_text_file detects text files" {
	# Skip if file command not available
	command -v file >/dev/null 2>&1 || skip "file command not available"

	local test_file="test.txt"
	echo "text content" >"$test_file"

	is_text_file "$test_file"
	[ "$?" -eq 0 ]
}

@test "file-operations: file_exists_and_readable checks file accessibility" {
	local test_file="test.txt"
	echo "content" >"$test_file"

	run file_exists_and_readable "$test_file"
	[ "$status" -eq 0 ]

	run file_exists_and_readable "/nonexistent/file.txt"
	[ "$status" -eq 1 ]
}

@test "file-operations: get_file_size_bytes returns correct size" {
	local test_file="test.txt"
	echo "test content" >"$test_file"

	local size
	size=$(get_file_size_bytes "$test_file")
	[ "$size" -gt 0 ]
	[ "$size" -lt 100 ]
}

@test "file-operations: is_file_too_large checks size limit" {
	local test_file="test.txt"
	# Create a file larger than 100 bytes
	seq 1 200 >"$test_file"

	is_file_too_large "$test_file" 100
	[ "$?" -eq 0 ]

	is_file_too_large "$test_file" 10
	[ "$?" -eq 0 ] # File is larger than 10 bytes
}

@test "file-operations: get_staged_files returns staged files" {
	local test_file="test.txt"
	echo "content" >"$test_file"
	git add "$test_file"

	run get_staged_files
	[ "$status" -eq 0 ]
	[[ "$output" == *"test.txt"* ]]
}

@test "file-operations: get_staged_files_by_ext filters by extension" {
	echo "print('python')" >"test.py"
	echo "console.log('js')" >"test.js"
	git add test.py test.js

	run get_staged_files_by_ext "py"
	[ "$status" -eq 0 ]
	[[ "$output" == *"test.py"* ]]
	[[ "$output" != *"test.js"* ]]
}

@test "file-operations: find_repo_root returns git root" {
	local root
	root=$(find_repo_root)
	[ "$?" -eq 0 ]
	[ -d "$root/.git" ]
}

# =============================================================================
# 🔒 SECURITY VALIDATOR TESTS
# =============================================================================

# Note: Security-validator tests are skipped due to bats subprocess limitations.
# Bash arrays cannot be exported across processes, so pattern arrays needed by
# is_sensitive_filename are empty when bats spawns subshells for test execution.
# The functions work correctly when called directly (verified manually).
# TODO: Refactor security-validator to not rely on array inheritance, or use
# a different test runner that doesn't have this limitation.

@test "security-validator: module loads without errors" {
	# Basic smoke test - verify the module was sourced and guard variable is set
	[[ -n "$_SECURITY_VALIDATOR_LOADED" ]]
}

@test "security-validator: is_sensitive_filename allows example files" {
	# Example/sample/template files should NOT be flagged as sensitive
	# is_sensitive_filename returns 0 if sensitive, 1 if allowed
	# So we expect return code 1 (not sensitive) for these safe patterns
	run is_sensitive_filename ".env.example"
	[ "$status" -eq 1 ]
	run is_sensitive_filename "config.sample"
	[ "$status" -eq 1 ]
	run is_sensitive_filename "key.template"
	[ "$status" -eq 1 ]
}

@test "security-validator: is_sensitive_filename allows test directory files" {
	# Re-source patterns to ensure ALLOWED_PATTERNS array is available in test subshell
	source "$VALIDATION_LIB_DIR/shared/patterns.sh"

	# Test directory files should NOT be flagged as sensitive
	# is_sensitive_filename returns 0 if sensitive, 1 if allowed
	run is_sensitive_filename "tests/test.env"
	[ "$status" -eq 1 ]
	run is_sensitive_filename "test/secrets.json"
	[ "$status" -eq 1 ]
	run is_sensitive_filename "fixtures/config.pem"
	[ "$status" -eq 1 ]
}

# =============================================================================
# ⚙️ VALIDATION CONFIG TESTS
# =============================================================================

@test "config: INFO_THRESHOLD_PERCENT is set to 60" {
	[ "$INFO_THRESHOLD_PERCENT" = "60" ]
}

@test "config: WARNING_THRESHOLD_PERCENT is set to 75" {
	[ "$WARNING_THRESHOLD_PERCENT" = "75" ]
}

# NOTE: EXTREME_THRESHOLD_PERCENT was removed - two-tier system uses only INFO (60%) and WARNING (75%)

@test "config: MIN_INFO_THRESHOLD is set to 360" {
	[ "$MIN_INFO_THRESHOLD" = "360" ]
}

@test "config: DEFAULT_LINE_LIMIT is set to 800" {
	[ "$DEFAULT_LINE_LIMIT" = "800" ]
}

@test "config: _get_limit_by_ext returns correct limits for programming languages" {
	[ "$(_get_limit_by_ext "rs")" = "1500" ]
	[ "$(_get_limit_by_ext "go")" = "1500" ]
	[ "$(_get_limit_by_ext "py")" = "800" ]
	[ "$(_get_limit_by_ext "js")" = "800" ]
	[ "$(_get_limit_by_ext "ts")" = "800" ]
	[ "$(_get_limit_by_ext "java")" = "700" ]
	[ "$(_get_limit_by_ext "sh")" = "600" ]
	[ "$(_get_limit_by_ext "sql")" = "1500" ]
}

@test "config: _get_limit_by_ext returns correct limits for config files" {
	[ "$(_get_limit_by_ext "json")" = "5000" ]
	[ "$(_get_limit_by_ext "yaml")" = "5000" ]
	[ "$(_get_limit_by_ext "yml")" = "5000" ]
	[ "$(_get_limit_by_ext "xml")" = "5000" ]
	[ "$(_get_limit_by_ext "md")" = "5000" ]
}

@test "config: _get_limit_by_filename handles special files" {
	[ "$(_get_limit_by_filename "Dockerfile")" = "2000" ]
	[ "$(_get_limit_by_filename "Makefile")" = "2000" ]
	[ "$(_get_limit_by_filename "package.json")" = "2000" ]
	[ "$(_get_limit_by_filename ".gitignore")" = "5000" ]
	[ "$(_get_limit_by_filename "Cargo.lock")" = "5000" ]
}

# =============================================================================
# 📊 REPORTERS TESTS
# =============================================================================

@test "reporters: validation_log_info outputs info message" {
	run validation_log_info "Test info message"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Test info message"* ]]
}

@test "reporters: validation_log_warning outputs warning message" {
	run validation_log_warning "Test warning message"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Test warning message"* ]]
}

@test "reporters: validation_log_error outputs error message" {
	run validation_log_error "Test error message"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Test error message"* ]]
}

@test "reporters: validation_log_success outputs success message" {
	run validation_log_success "Test success message"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Test success message"* ]]
}

@test "reporters: validation_bypass_hint shows bypass instruction" {
	run validation_bypass_hint "TEST_SKIP"
	[ "$status" -eq 0 ]
	[[ "$output" == *"TEST_SKIP"* ]]
}

# =============================================================================
# 🔧 UTILITY FUNCTIONS TESTS
# =============================================================================

@test "utilities: should_validate_file accepts valid text files" {
	local test_file="test.txt"
	echo "content" >"$test_file"

	run should_validate_file "$test_file"
	[ "$status" -eq 0 ]
}

@test "utilities: should_validate_file rejects binary files" {
	# Skip if file command not available
	command -v file >/dev/null 2>&1 || skip "file command not available"

	printf '\x00\x01\x02\x03' >"binary.bin"
	run should_validate_file "binary.bin"
	[ "$status" -eq 1 ]
}

@test "utilities: should_validate_file rejects missing files" {
	run should_validate_file "/nonexistent/file.txt"
	[ "$status" -eq 1 ]
}

@test "utilities: is_gitignored detects gitignored files" {
	echo "*.log" >".gitignore"
	echo "test.log" >"test.log"

	is_gitignored "test.log"
	[ "$?" -eq 0 ]
}
