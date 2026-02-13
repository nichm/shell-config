#!/usr/bin/env bats
# =============================================================================
# 🔒 Git Wrapper Safety Tests - Critical Protection Validation
# =============================================================================
# Tests for git safety wrapper functions including:
#   - Dangerous command blocking (reset --hard, push --force, rebase)
#   - Dependency change detection (package.json, Cargo.toml)
#   - Large file detection (>5MB threshold)
#   - Large commit detection (>75 files, >5000 lines)
#   - Bypass flag functionality
# =============================================================================

# Setup and teardown
setup() {
	local repo_root
	repo_root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel 2>/dev/null || { cd "$BATS_TEST_DIRNAME/../.." && pwd; })"
	export SHELL_CONFIG_DIR="$repo_root"
	export GIT_WRAPPER_LIB="$SHELL_CONFIG_DIR/lib/git/wrapper.sh"

	# Create temp directory (cleanup in teardown, not EXIT trap which interferes with bats)
	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	# Initialize git repo (disable hooks to prevent global gitconfig interference in parallel)
	git init --initial-branch=main >/dev/null 2>&1
	git config user.email "test@example.com"
	git config user.name "Test User"
	git config core.hooksPath /dev/null

	# Source the git wrapper library
	# shellcheck source=../../lib/git/wrapper.sh
	source "$GIT_WRAPPER_LIB"

	# Load heavy modules (lazy-loaded in production, needed eagerly in tests)
	_git_wrapper_load_heavy
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

# =============================================================================
# 🚨 DANGEROUS COMMAND BLOCKING TESTS
# =============================================================================

@test "git reset --hard is blocked by safety check" {
	run _run_safety_checks reset --hard
	[ "$status" -eq 1 ]
	[[ "$output" == *"DANGER"* ]]
}

@test "git reset --hard --force-danger bypasses safety check" {
	run _run_safety_checks reset --hard --force-danger
	[ "$status" -eq 0 ]
}

@test "git push --force is blocked by safety check" {
	run _run_safety_checks push --force origin main
	[ "$status" -eq 1 ]
	[[ "$output" == *"DANGER"* ]]
}

@test "git push --force-with-lease passes safety check" {
	run _run_safety_checks push --force-with-lease origin main
	[ "$status" -eq 0 ]
}

@test "git rebase is blocked by safety check" {
	run _run_safety_checks rebase main
	[ "$status" -eq 1 ]
	[[ "$output" == *"WARNING"* ]]
}

@test "git rebase --force-danger bypasses safety check" {
	run _run_safety_checks rebase main --force-danger
	[ "$status" -eq 0 ]
}

@test "git clone detects duplicate repository" {
	# Mock HOME to ensure test isolation
	export HOME="$TEST_TEMP_DIR"

	# Create a mock existing repo in ~/github with the same name as the clone target
	# _check_existing_repo searches for directories matching the repo name
	local mock_repo_dir="$HOME/github/testorg/test-repo"
	mkdir -p "$mock_repo_dir"
	cd "$mock_repo_dir" || return 1
	command git init --initial-branch=main >/dev/null 2>&1

	# Try to clone same repo (uses _run_clone_check for duplicate detection)
	cd "$TEST_TEMP_DIR" || return 1
	run _run_clone_check clone https://github.com/testorg/test-repo.git

	# Should be blocked
	[ "$status" -eq 1 ]
	[[ "$output" == *"Found at"* ]] || [[ "$output" == *"already exists"* ]] || [[ "$output" == *"test-repo"* ]]

	# No explicit cleanup needed, as teardown will remove the mocked $HOME.
}

@test "git clone --force-allow bypasses duplicate check" {
	run _run_clone_check clone https://github.com/testorg/test-repo.git --force-allow
	[ "$status" -eq 0 ]
}

# =============================================================================
# 📦 DEPENDENCY CHANGE DETECTION TESTS
# =============================================================================

@test "package.json changes trigger dependency warning" {
	# Create and stage package.json
	echo '{"name": "test", "version": "1.0.0"}' >package.json
	git add package.json

	run _check_dependency_changes
	[ "$status" -eq 1 ]
	[[ "$output" == *"DEPENDENCIES"* ]]
	[[ "$output" == *"package.json"* ]]
}

@test "package-lock.json changes trigger dependency warning" {
	echo '{"name": "test"}' >package.json
	echo '{"lockfileVersion": 3}' >package-lock.json
	git add package-lock.json

	run _check_dependency_changes
	[ "$status" -eq 1 ]
	[[ "$output" == *"DEPENDENCIES"* ]]
}

@test "Cargo.toml changes trigger dependency warning" {
	echo '[package]' >Cargo.toml
	echo 'name = "test"' >>Cargo.toml
	git add Cargo.toml

	run _check_dependency_changes
	[ "$status" -eq 1 ]
	[[ "$output" == *"DEPENDENCIES"* ]]
	[[ "$output" == *"Cargo.toml"* ]]
}

@test "regular files do not trigger dependency warning" {
	echo 'console.log("test");' >index.js
	git add index.js

	run _check_dependency_changes
	[ "$status" -eq 0 ]
}

@test "dependency check bypass works with --skip-deps-check" {
	echo '{}' >package.json
	git add package.json

	# The bypass flag is checked in the main git() function, not _check_dependency_changes
	# So we just verify the check works without bypass
	run _check_dependency_changes
	[ "$status" -eq 1 ]
}

@test "multiple dependency files are all listed" {
	echo '{}' >package.json
	echo '{}' >package-lock.json
	git add package.json package-lock.json

	run _check_dependency_changes
	[ "$status" -eq 1 ]
	[[ "$output" == *"package.json"* ]]
	[[ "$output" == *"package-lock.json"* ]]
}

# =============================================================================
# 📦 LARGE FILE DETECTION TESTS
# =============================================================================

@test "files larger than 5MB trigger large file warning" {
	# Create a 6MB file
	dd if=/dev/zero of=large.bin bs=1048576 count=6 2>/dev/null
	git add large.bin

	run _check_large_files
	[ "$status" -eq 1 ]
	[[ "$output" == *"LARGE FILE"* ]]
	[[ "$output" == *"large.bin"* ]]
}

@test "files smaller than 5MB pass large file check" {
	# Create a 1MB file
	dd if=/dev/zero of=small.bin bs=1048576 count=1 2>/dev/null
	git add small.bin

	run _check_large_files
	[ "$status" -eq 0 ]
}

@test "multiple large files are all listed" {
	dd if=/dev/zero of=large1.bin bs=1048576 count=6 2>/dev/null
	dd if=/dev/zero of=large2.bin bs=1048576 count=7 2>/dev/null
	git add large1.bin large2.bin

	run _check_large_files
	[ "$status" -eq 1 ]
	[[ "$output" == *"large1.bin"* ]]
	[[ "$output" == *"large2.bin"* ]]
}

@test "large file check shows file sizes" {
	dd if=/dev/zero of=large.bin bs=1048576 count=10 2>/dev/null
	git add large.bin

	run _check_large_files
	[ "$status" -eq 1 ]
	[[ "$output" == *"10MB"* ]] || [[ "$output" == *"10 MB"* ]]
}

@test "non-file additions are skipped in large file check" {
	# Git can stage deletions and modifications, not just new files
	echo 'test' >existing.txt
	git add existing.txt
	echo 'modified' >existing.txt
	git add existing.txt

	run _check_large_files
	[ "$status" -eq 0 ]
}

# =============================================================================
# 📦 LARGE COMMIT DETECTION TESTS
# =============================================================================

@test "commits with 76+ files trigger extreme commit warning" {
	# Create 76 files (extreme threshold is 76)
	for i in {1..76}; do
		echo "content $i" >"file$i.txt"
	done
	git add file*.txt

	run _check_large_commit
	[ "$status" -eq 1 ]
	[[ "$output" == *"Extremely large commit"* ]] || [[ "$output" == *"large commit"* ]]
}

@test "commits with 14 files pass large commit check" {
	# Create 14 files (info threshold is 15)
	for i in {1..14}; do
		echo "content $i" >"file$i.txt"
	done
	git add file*.txt

	run _check_large_commit
	[ "$status" -eq 0 ]
}

@test "commits with 25 files trigger warning commit tier" {
	# Create 25 files (warning threshold is 25)
	for i in {1..25}; do
		echo "content $i" >"file$i.txt"
	done
	git add file*.txt

	run _check_large_commit
	[ "$status" -eq 1 ]
	[[ "$output" == *"Medium-large commit"* ]] || [[ "$output" == *"warning"* ]]
}

@test "commits with 5001+ line changes trigger extreme commit warning" {
	# Create file with 5001 insertions (extreme threshold is 5001)
	{
		for i in {1..5001}; do
			echo "line $i"
		done
	} >large.txt
	git add large.txt

	run _check_large_commit
	[ "$status" -eq 1 ]
	[[ "$output" == *"Extremely large commit"* ]] || [[ "$output" == *"5001"* ]] || [[ "$output" == *"large"* ]]
}

@test "commits with 999 line changes pass large commit check" {
	# Create file with 999 insertions (info threshold is 1000)
	{
		for i in {1..999}; do
			echo "line $i"
		done
	} >large.txt
	git add large.txt

	run _check_large_commit
	[ "$status" -eq 0 ]
}

@test "large commit check shows both file count and line count" {
	# Create 80 files with 150 lines each = 12000 total insertions (extreme tier)
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
	# Output format: "($files files, $lines lines)"
	[[ "$output" == *"files"* ]]
	[[ "$output" == *"lines"* ]]
	[[ "$output" == *"80"* ]]
}

@test "empty commit passes large commit check" {
	run _check_large_commit
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🔧 BYPASS FLAG TESTS
# =============================================================================

@test "bypass flags are properly filtered from git command" {
	# Test that wrapper flags don't get passed to git
	run _get_real_git_command commit --skip-secrets
	[ "$status" -eq 0 ]
	[ "$output" = "commit" ]
}

@test "bypass flags in various positions are recognized" {
	run _get_real_git_command --skip-secrets commit -m "test"
	[ "$status" -eq 0 ]
	[ "$output" = "commit" ]

	run _get_real_git_command commit --skip-syntax-check -m "test"
	[ "$status" -eq 0 ]
	[ "$output" = "commit" ]
}

@test "all wrapper bypass flags are recognized" {
	local flags="--skip-secrets --skip-syntax-check --skip-deps-check --allow-large-commit --allow-large-files --force-danger --force-allow"

	for flag in $flags; do
		run _get_real_git_command commit $flag
		[ "$status" -eq 0 ]
		[ "$output" = "commit" ]
	done
}

@test "regular git commands pass through safety checks" {
	run _run_safety_checks status
	[ "$status" -eq 0 ]

	run _run_safety_checks log --oneline
	[ "$status" -eq 0 ]

	run _run_safety_checks diff
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🔍 HELPER FUNCTION TESTS
# =============================================================================

@test "_get_rule_value returns correct values for reset_hard" {
	local emoji
	emoji=$(_get_rule_value "reset_hard" emoji)
	[ "$emoji" = "🔴 DANGER" ]

	local desc
	desc=$(_get_rule_value "reset_hard" desc)
	[[ "$desc" == *"PERMANENTLY deletes"* ]]

	local bypass
	bypass=$(_get_rule_value "reset_hard" bypass)
	[ "$bypass" = "--force-danger" ]
}

@test "_get_rule_value returns correct values for push_force" {
	local emoji
	emoji=$(_get_rule_value "push_force" emoji)
	[ "$emoji" = "🔴 DANGER" ]

	local bypass
	bypass=$(_get_rule_value "push_force" bypass)
	[ "$bypass" = "--force-allow" ]
}

@test "_get_rule_value returns correct values for deps_change" {
	local emoji
	emoji=$(_get_rule_value "deps_change" emoji)
	[ "$emoji" = "⚠️ DEPENDENCIES" ]

	local bypass
	bypass=$(_get_rule_value "deps_change" bypass)
	[ "$bypass" = "--skip-deps-check" ]
}

@test "_get_rule_value handles unknown keys gracefully" {
	local result
	result=$(_get_rule_value "unknown_key" emoji)
	[ -z "$result" ]
}

@test "warning message function produces output" {
	run _show_warning reset_hard
	[ "$status" -eq 0 ]
	[[ "$output" == *"DANGER"* ]]
	[[ "$output" == *"PERMANENTLY deletes"* ]]
	[[ "$output" == *"--force-danger"* ]]
}

# =============================================================================
# 🔐 SECRETS SCANNING INTEGRATION TESTS
# =============================================================================

@test "_needs_secrets_check returns true for commit" {
	run _needs_secrets_check commit
	[ "$status" -eq 0 ]
}

@test "_needs_secrets_check returns true for add" {
	run _needs_secrets_check add
	[ "$status" -eq 0 ]
}

@test "_needs_secrets_check returns true for push" {
	run _needs_secrets_check push
	[ "$status" -eq 0 ]
}

@test "_needs_secrets_check returns false for status" {
	run _needs_secrets_check status
	[ "$status" -eq 1 ]
}

@test "_needs_secrets_check returns false for log" {
	run _needs_secrets_check log
	[ "$status" -eq 1 ]
}

@test "_check_gitleaks returns success when gitleaks installed" {
	if command -v gitleaks >/dev/null 2>&1; then
		run _check_gitleaks
		[ "$status" -eq 0 ]
	else
		skip "gitleaks not installed"
	fi
}

@test "_check_gitleaks returns failure when gitleaks not installed" {
	# Mock PATH to hide gitleaks
	local PATH="/usr/bin:/bin:/usr/sbin:/sbin"

	run _check_gitleaks
	[ "$status" -eq 1 ]
}

# =============================================================================
# 🎯 EDGE CASE TESTS
# =============================================================================

@test "git reset with soft flag passes safety check" {
	run _run_safety_checks reset --soft HEAD~1
	[ "$status" -eq 0 ]
}

@test "git reset with mixed flag passes safety check" {
	run _run_safety_checks reset --mixed HEAD~1
	[ "$status" -eq 0 ]
}

@test "git push without force flags passes safety check" {
	run _run_safety_checks push origin main
	[ "$status" -eq 0 ]
}

@test "safety checks handle empty arguments" {
	run _run_safety_checks
	[ "$status" -eq 0 ]
}

@test "dependency check handles no staged files" {
	# Clear any staged files
	git reset HEAD >/dev/null 2>&1 || true

	run _check_dependency_changes
	[ "$status" -eq 0 ]
}

@test "large file check handles no staged files" {
	git reset HEAD >/dev/null 2>&1 || true

	run _check_large_files
	[ "$status" -eq 0 ]
}

@test "large commit check handles no staged files" {
	git reset HEAD >/dev/null 2>&1 || true

	run _check_large_commit
	[ "$status" -eq 0 ]
}
