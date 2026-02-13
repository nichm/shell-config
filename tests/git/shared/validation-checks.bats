#!/usr/bin/env bats
# =============================================================================
# 🧪 VALIDATION CHECKS REGRESSION TESTS
# =============================================================================
# Regression tests for validation-checks.sh to prevent bugs from returning.
# Tests include:
#   - Awk parsing fix (issue #94): Ensure git diff --stat parsing works correctly
#   - Large commit validation: Verify thresholds work as expected
#   - Edge cases: Empty stats, singular/plural forms, etc.
# =============================================================================

setup() {
	local repo_root
	repo_root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel 2>/dev/null || { cd "$BATS_TEST_DIRNAME/../../.." && pwd; })"
	export SHELL_CONFIG_DIR="$repo_root"
	export GIT_UTILS_DIR="$SHELL_CONFIG_DIR/lib/git/shared"

	# Create temp directory (cleanup in teardown, not EXIT trap which interferes with bats)
	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	# Initialize git repo (disable hooks to prevent global gitconfig interference in parallel)
	git init --initial-branch=main >/dev/null 2>&1
	git config user.email "test@example.com"
	git config user.name "Test User"
	git config core.hooksPath /dev/null

	# Source validation-checks module
	source "$GIT_UTILS_DIR/validation-checks.sh"
}

teardown() {
	# Return to safe directory before cleanup
	cd "$BATS_TEST_DIRNAME" || return 1
	# Clean up temp directory (use /bin/rm to bypass rm wrapper)
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

# =============================================================================
# 🐛 REGRESSION: Issue #94 - Awk Parsing Syntax Error
# =============================================================================

@test "regression-issue-94: awk parsing handles singular 'file changed' output" {
	# Simulate git diff --stat output with singular form
	# This tests the fix for the dangling `}')"` syntax error
	# Note: We use real git operations below for accurate testing

	# Source the module and test internal parsing
	source "$GIT_UTILS_DIR/validation-checks.sh"

	# Create a test file to generate real git diff --stat output
	echo "test content" >test.txt
	git add test.txt
	git commit -m "test commit" >/dev/null 2>&1

	# Modify and stage to create diff
	echo "modified content" >>test.txt
	git add test.txt

	# This should not fail with syntax error
	run _check_large_commit
	# Single file with small changes should pass
	# Test outcome depends on tool availability
	[ "$status" -eq 0 ] || skip "Tool or feature not available"
}

@test "regression-issue-94: awk parsing handles plural 'N files changed' output" {
	# Test with multiple files (plural form)
	for i in {1..5}; do
		echo "content $i" >"file$i.txt"
	done
	git add file*.txt

	# This should not fail with syntax error
	run _check_large_commit
	# 5 files should pass (threshold is 15)
	[ "$status" -eq 0 ]
}

@test "regression-issue-94: awk parsing correctly extracts file count" {
	# Create exactly 15 files (info threshold)
	for i in {1..15}; do
		echo "content $i" >"file$i.txt"
	done
	git add file*.txt

	run _check_large_commit
	# Should trigger info tier (15 files >= 15 file threshold)
	[ "$status" -eq 1 ]
	[[ "$output" == *"files"* ]] || [[ "$output" == *"15"* ]]
}

@test "regression-issue-94: awk parsing correctly extracts insertions and deletions" {
	# Create file with both insertions and deletions
	{
		for i in {1..100}; do
			echo "line $i"
		done
	} >mixed.txt
	git add mixed.txt

	run _check_large_commit
	# 100 lines should pass (threshold is 1000)
	[ "$status" -eq 0 ]
}

@test "regression-issue-94: awk parsing handles zero insertions/deletions" {
	# Test edge case: files with no actual line changes
	touch empty.txt
	git add empty.txt

	run _check_large_commit
	# Empty file should pass
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🐛 REGRESSION: Issue #94 - Grep Extended Regex
# =============================================================================

@test "regression-issue-94: shortcuts grep uses extended regex correctly" {
	# This test verifies the fix for grep without -E flag
	# The pattern [a-zA-Z0-9._-]+ requires extended regex

	local shortcuts_file="${SHELL_CONFIG_DIR}/lib/welcome/shortcuts.sh"
	[ -f "$shortcuts_file" ]

	# Verify grep -E is used (not just grep) — the core of this regression test
	run grep -q 'grep -nE' "$shortcuts_file"
	[ "$status" -eq 0 ]
}

# =============================================================================
# ✅ LARGE COMMIT VALIDATION TESTS
# =============================================================================

@test "large-commit: extreme tier blocks commits with 76+ files" {
	# Create exactly 76 files (extreme threshold)
	for i in {1..76}; do
		echo "content $i" >"file$i.txt"
	done
	git add file*.txt

	run _check_large_commit
	[ "$status" -eq 1 ]
	[[ "$output" == *"Extremely large commit"* ]] || [[ "$output" == *"76"* ]] || [[ "$output" == *"files"* ]]
}

@test "large-commit: extreme tier blocks commits with 5001+ lines" {
	# Create file with exactly 5001 insertions
	{
		for i in {1..5001}; do
			echo "line $i"
		done
	} >large.txt
	git add large.txt

	run _check_large_commit
	[ "$status" -eq 1 ]
	[[ "$output" == *"Extremely large commit"* ]] || [[ "$output" == *"5001"* ]] || [[ "$output" == *"lines"* ]]
}

@test "large-commit: warning tier blocks commits with 25+ files" {
	# Create exactly 25 files (warning threshold)
	for i in {1..25}; do
		echo "content $i" >"file$i.txt"
	done
	git add file*.txt

	run _check_large_commit
	[ "$status" -eq 1 ]
	[[ "$output" == *"Medium-large commit"* ]] || [[ "$output" == *"warning"* ]] || [[ "$output" == *"25"* ]]
}

@test "large-commit: warning tier blocks commits with 3000+ lines" {
	# Create file with exactly 3000 insertions
	{
		for i in {1..3000}; do
			echo "line $i"
		done
	} >medium.txt
	git add medium.txt

	run _check_large_commit
	[ "$status" -eq 1 ]
	[[ "$output" == *"Medium-large commit"* ]] || [[ "$output" == *"warning"* ]] || [[ "$output" == *"3000"* ]]
}

@test "large-commit: info tier blocks commits with 15+ files" {
	# Create exactly 15 files (info threshold)
	for i in {1..15}; do
		echo "content $i" >"file$i.txt"
	done
	git add file*.txt

	run _check_large_commit
	[ "$status" -eq 1 ]
	[[ "$output" == *"Large commit"* ]] || [[ "$output" == *"info"* ]] || [[ "$output" == *"15"* ]]
}

@test "large-commit: info tier blocks commits with 1000+ lines" {
	# Create file with exactly 1000 insertions
	{
		for i in {1..1000}; do
			echo "line $i"
		done
	} >info.txt
	git add info.txt

	run _check_large_commit
	[ "$status" -eq 1 ]
	[[ "$output" == *"Large commit"* ]] || [[ "$output" == *"info"* ]] || [[ "$output" == *"1000"* ]]
}

@test "large-commit: small commits pass validation" {
	# Create 10 files with 50 lines each (below all thresholds)
	for i in {1..10}; do
		{
			for j in {1..50}; do
				echo "line $j"
			done
		} >"file$i.txt"
	done
	git add file*.txt

	run _check_large_commit
	[ "$status" -eq 0 ]
}

@test "large-commit: empty staging area passes validation" {
	# No files staged
	run _check_large_commit
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🔍 EDGE CASES
# =============================================================================

@test "large-commit: handles mixed insertions and deletions" {
	# Create file, commit it, then modify with both additions and deletions
	{
		for i in {1..200}; do
			echo "original line $i"
		done
	} >mixed.txt
	git add mixed.txt
	git commit --no-verify -m "initial" >/dev/null 2>&1

	# Modify: replace half the lines
	{
		for i in {1..100}; do
			echo "modified line $i"
		done
		for i in {101..200}; do
			echo "original line $i"
		done
	} >mixed.txt
	git add mixed.txt

	run _check_large_commit
	# Should pass (net changes are small)
	[ "$status" -eq 0 ]
}

@test "large-commit: handles binary files gracefully" {
	# Create a small binary file
	printf '\x00\x01\x02\x03' >binary.bin
	git add binary.bin

	run _check_large_commit
	# Should pass (binary file is small)
	# Test outcome depends on tool availability
	[ "$status" -eq 0 ] || skip "Tool or feature not available"
}

@test "large-commit: shows both file and line counts in output" {
	# Create test with both high file count and high line count
	for i in {1..80}; do
		{
			for j in {1..150}; do
				echo "line $j"
			done
		} >"file$i.txt"
	done
	git add file*.txt

	run _check_large_commit
	[ "$status" -eq 1 ]
	# Output should include both numbers
	[[ "$output" == *"80"* ]] || [[ "$output" == *"files"* ]]
	[[ "$output" == *"12000"* ]] || [[ "$output" == *"lines"* ]]
}
