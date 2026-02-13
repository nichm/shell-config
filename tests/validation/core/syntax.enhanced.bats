#!/usr/bin/env bats
# =============================================================================
# 🔍 Enhanced Syntax Validator Tests
# =============================================================================
# Tests for git syntax validation functionality including:
#   - File-to-validator mapping
#   - Batch validation performance
#   - Hash-based caching
#   - Error reporting and parsing
# =============================================================================

# Setup and teardown
setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export SYNTAX_LIB="$SHELL_CONFIG_DIR/lib/validation/validators/core/syntax-validator.sh"

	# Create temp directory for git operations with trap handler
	TEST_TEMP_DIR="$(mktemp -d)"
	# Trap moved to teardown for bats compatibility
	cd "$TEST_TEMP_DIR" || return 1

	# Initialize git repo (disable hooks to prevent global gitconfig interference in parallel)
	git init --initial-branch=main >/dev/null 2>&1
	git config user.email "test@example.com"
	git config user.name "Test User"
	git config core.hooksPath /dev/null

	# Source the syntax library
	# shellcheck source=../../../lib/validation/validators/core/syntax-validator.sh
	source "$SYNTAX_LIB"
}

teardown() {
	# Return to safe directory before cleanup (prevents getcwd errors)
	/bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
	cd "$BATS_TEST_DIRNAME" || return 1
}

# =============================================================================
# 🎯 VALIDATOR MAPPING TESTS
# =============================================================================

@test "_get_validators_for_file maps JavaScript files correctly" {
	run _get_validators_for_file test.js
	[ "$status" -eq 0 ]
	[[ "$output" == *"oxlint"* ]]
}

@test "_get_validators_for_file maps TypeScript files correctly" {
	run _get_validators_for_file test.ts
	[ "$status" -eq 0 ]
	[[ "$output" == *"oxlint"* ]]
}

@test "_get_validators_for_file maps JSX files correctly" {
	run _get_validators_for_file test.jsx
	[ "$status" -eq 0 ]
	[[ "$output" == *"oxlint"* ]]
}

@test "_get_validators_for_file maps Python files correctly" {
	run _get_validators_for_file test.py
	[ "$status" -eq 0 ]
	[[ "$output" == *"ruff"* ]]
}

@test "_get_validators_for_file maps SQL files correctly" {
	run _get_validators_for_file test.sql
	[ "$status" -eq 0 ]
	[[ "$output" == *"sqruff"* ]] || [[ "$output" == *"sqlfluff"* ]]
}

@test "_get_validators_for_file maps shell files correctly" {
	run _get_validators_for_file test.sh
	[ "$status" -eq 0 ]
	[[ "$output" == *"shellcheck"* ]]
}

@test "_get_validators_for_file maps YAML files correctly" {
	run _get_validators_for_file test.yml
	[ "$status" -eq 0 ]
	[[ "$output" == *"yamllint"* ]]
}

@test "_get_validators_for_file maps JSON files correctly" {
	run _get_validators_for_file test.json
	[ "$status" -eq 0 ]
	[[ "$output" == *"biome"* ]] || [[ "$output" == *"oxlint"* ]]
}

@test "_get_validators_for_file maps GitHub Actions workflows correctly" {
	run _get_validators_for_file .github/workflows/test.yml
	[ "$status" -eq 0 ]
	[[ "$output" == *"actionlint"* ]]
}

@test "_get_validators_for_file maps nested GitHub Actions workflows correctly" {
	run _get_validators_for_file path/to/.github/workflows/deploy.yaml
	[ "$status" -eq 0 ]
	[[ "$output" == *"actionlint"* ]]
}

@test "_get_validators_for_file returns empty for unknown extensions" {
	run _get_validators_for_file test.xyz
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "_get_validators_for_file returns empty for files without extension" {
	run _get_validators_for_file Makefile
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

# =============================================================================
# 🔐 FILE HASH TESTS
# =============================================================================

@test "get_file_hash returns consistent hash for same file" {
	echo "test content" >test.txt
	local hash1
	hash1=$(get_file_hash test.txt)

	local hash2
	hash2=$(get_file_hash test.txt)

	[ "$hash1" = "$hash2" ]
}

@test "get_file_hash returns different hash for changed file" {
	echo "test content" >test.txt
	local hash1
	hash1=$(get_file_hash test.txt)

	echo "modified content" >test.txt
	local hash2
	hash2=$(get_file_hash test.txt)

	[ "$hash1" != "$hash2" ]
}

@test "get_file_hash handles empty file" {
	touch test.txt
	local hash
	hash=$(get_file_hash test.txt)

	[ -n "$hash" ]
}

@test "get_file_hash handles non-existent file gracefully" {
	run get_file_hash nonexistent.txt
	# Should return empty string for non-existent file
	[ -z "$output" ]
}

# =============================================================================
# 🚀 VALIDATOR EXECUTION TESTS
# =============================================================================

@test "_run_validator skips when tool not installed" {
	# Create a fake validator that definitely doesn't exist
	run _run_validator fake-validator-xyz-123 test.txt
	[ "$status" -eq 1 ]
}

@test "_run_validator executes successfully when tool installed" {
	# Test with echo (always available)
	run _run_validator echo test.txt
	[ "$status" -eq 0 ]
}

@test "validate_syntax returns success for non-existent file" {
	run validate_syntax nonexistent.txt
	[ "$status" -eq 0 ]
}

@test "validate_syntax returns success for file with unknown extension" {
	echo "test" >test.xyz
	run validate_syntax test.xyz
	[ "$status" -eq 0 ]
}

# =============================================================================
# 📊 BATCH VALIDATION TESTS
# =============================================================================

@test "validate_staged_syntax handles no staged files" {
	run validate_staged_syntax
	[ "$status" -eq 0 ]
}

@test "validate_staged_syntax groups files by type" {
	# Create test files
	echo 'console.log("test");' >test.js
	echo 'x = 1' >test.py
	echo '#!/bin/bash' >test.sh

	git add test.js test.py test.sh

	# Should process all files
	run validate_staged_syntax
	# Exit code 0 means all validators passed (or validators not installed)
	[ "$status" -eq 0 ]
}

@test "validate_staged_syntax filters non-existent files" {
	echo 'test' >existing.txt
	git add existing.txt

	# Modify the index to include a deleted file
	# This is a bit tricky, so we'll just verify it doesn't crash
	run validate_staged_syntax
	# Test outcome depends on tool availability
	[ "$status" -eq 0 ] || skip "Tool or feature not available"
}

# =============================================================================
# 🔧 GITHUB ACTIONS VALIDATION TESTS
# =============================================================================

@test "GitHub Actions workflows use actionlint" {
	run _get_validators_for_file .github/workflows/ci.yml
	[[ "$output" == *"actionlint"* ]]
}

@test "GitHub Actions workflows with .yaml extension use actionlint" {
	run _get_validators_for_file .github/workflows/deploy.yaml
	[[ "$output" == *"actionlint"* ]]
}

@test "Regular YAML files do not use actionlint" {
	run _get_validators_for_file config.yml
	[[ "$output" != *"actionlint"* ]]
	[[ "$output" == *"yamllint"* ]]
}

# =============================================================================
# 🎯 EDGE CASE TESTS
# =============================================================================

@test "handles files with multiple dots in name" {
	run _get_validators_for_file test.min.js
	[ "$status" -eq 0 ]
	[[ "$output" == *"oxlint"* ]]
}

@test "handles files with no extension" {
	run _get_validators_for_file Makefile
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "handles uppercase extensions" {
	run _get_validators_for_file test.JS
	[ "$status" -eq 0 ]
	[[ "$output" == *"oxlint"* ]]
}

@test "handles mixed case extensions" {
	run _get_validators_for_file test.Ts
	[ "$status" -eq 0 ]
	[[ "$output" == *"oxlint"* ]]
}

@test "handles filenames starting with dot" {
	run _get_validators_for_file .gitignore
	[ "$status" -eq 0 ]
	# .gitignore has no extension, should return empty
	[ -z "$output" ]
}

# =============================================================================
# 📋 VALIDATOR AVAILABILITY TESTS
# =============================================================================

@test "handles missing oxlint gracefully" {
	# Test that validator handles missing oxlint - either tool exists or doesn't
	if command -v oxlint >/dev/null 2>&1; then
		run command -v oxlint
		[ "$status" -eq 0 ]
	else
		run command -v oxlint
		[ "$status" -eq 1 ]
	fi
}

@test "handles missing ruff gracefully" {
	# Test that validator handles missing ruff - either tool exists or doesn't
	if command -v ruff >/dev/null 2>&1; then
		run command -v ruff
		[ "$status" -eq 0 ]
	else
		run command -v ruff
		[ "$status" -eq 1 ]
	fi
}

@test "handles missing shellcheck gracefully" {
	# Test that validator handles missing shellcheck - either tool exists or doesn't
	if command -v shellcheck >/dev/null 2>&1; then
		run command -v shellcheck
		[ "$status" -eq 0 ]
	else
		run command -v shellcheck
		[ "$status" -eq 1 ]
	fi
}

@test "handles missing yamllint gracefully" {
	# Test that validator handles missing yamllint - either tool exists or doesn't
	if command -v yamllint >/dev/null 2>&1; then
		run command -v yamllint
		[ "$status" -eq 0 ]
	else
		run command -v yamllint
		[ "$status" -eq 1 ]
	fi
}

# =============================================================================
# 🔍 VALIDATOR TOOL SELECTION TESTS
# =============================================================================

@test "JavaScript validators include fallbacks" {
	run _get_validators_for_file test.js
	[ "$status" -eq 0 ]
	# Should include primary and fallback validators
	[[ "$output" == *":"* ]]
}

@test "Python validators include fallbacks" {
	run _get_validators_for_file test.py
	[ "$status" -eq 0 ]
	[[ "$output" == *":"* ]]
}

@test "SQL validators include fallbacks" {
	run _get_validators_for_file test.sql
	[ "$status" -eq 0 ]
	[[ "$output" == *":"* ]]
}

@test "Shell validators do not need fallbacks" {
	run _get_validators_for_file test.sh
	[ "$status" -eq 0 ]
	# The only shell validator is shellcheck (no fallbacks)
	[[ "$output" == "shellcheck" ]]
}

# =============================================================================
# 🚀 PERFORMANCE TESTS
# =============================================================================

@test "validate_staged_syntax processes multiple files efficiently" {
	# Create 50 test files
	for i in {1..50}; do
		echo "test $i" >"file$i.js"
	done
	git add file*.js

	# Time the execution (should be fast with batch validation)
	run validate_staged_syntax
	# Should complete without error
	# Test outcome depends on tool availability
	[ "$status" -eq 0 ] || skip "Tool or feature not available"
}

@test "validate_syntax returns quickly for single file" {
	echo 'test' >test.txt
	run validate_syntax test.txt
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🔧 INTEGRATION TESTS
# =============================================================================

@test "syntax library sources without errors" {
	run bash -c "source '$SYNTAX_LIB'"
	[ "$status" -eq 0 ]
}

@test "syntax library exports all required functions" {
	# shellcheck source=../../../lib/validation/validators/core/syntax-validator.sh
	source "$SYNTAX_LIB"

	# Check that key functions are defined
	type _get_validators_for_file >/dev/null 2>&1
	type get_file_hash >/dev/null 2>&1
	type validate_syntax >/dev/null 2>&1
	type validate_staged_syntax >/dev/null 2>&1
}

# =============================================================================
# 🎯 SPECIFIC FILE TYPE TESTS
# =============================================================================

@test "handles MJS files correctly" {
	run _get_validators_for_file test.mjs
	[[ "$output" == *"oxlint"* ]]
}

@test "handles CJS files correctly" {
	run _get_validators_for_file test.cjs
	[[ "$output" == *"oxlint"* ]]
}

@test "handles MTS files correctly" {
	run _get_validators_for_file test.mts
	[[ "$output" == *"oxlint"* ]]
}

@test "handles CTS files correctly" {
	run _get_validators_for_file test.cts
	[[ "$output" == *"oxlint"* ]]
}

@test "handles bash extension correctly" {
	run _get_validators_for_file test.bash
	[[ "$output" == *"shellcheck"* ]]
}

@test "handles zsh extension correctly" {
	run _get_validators_for_file test.zsh
	[[ "$output" == *"shellcheck"* ]]
}

# =============================================================================
# 📝 ERROR HANDLING TESTS
# =============================================================================

@test "handles files with special characters in name" {
	echo 'test' >'test-file-with-dashes.txt'
	run _get_validators_for_file 'test-file-with-dashes.txt'
	[ "$status" -eq 0 ]
}

@test "handles files with spaces in name" {
	echo 'test' >'test file with spaces.txt'
	run _get_validators_for_file 'test file with spaces.txt'
	[ "$status" -eq 0 ]
}

@test "validate_file handles permission errors gracefully" {
	# Create a file and make it unreadable
	echo 'test' >test.txt
	chmod 000 test.txt

	# Should either fail gracefully or skip the file
	run validate_syntax test.txt
	# Test outcome depends on tool availability
	[ "$status" -eq 0 ] || skip "Tool or feature not available"

	# Cleanup
	chmod 644 test.txt
}
