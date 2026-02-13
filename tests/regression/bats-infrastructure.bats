#!/usr/bin/env bats
# =============================================================================
# bats-infrastructure.bats - Regression tests for bats test infrastructure
# =============================================================================
# Tests for issues discovered during PR #139 review:
# 1. EXIT traps in setup() interfere with bats parallel execution
# 2. rm wrapper in PATH blocks test cleanup
# 3. Global gitconfig hooks interfere with test git commits
# 4. set -u leaking from sourced scripts causes unbound variable errors
# 5. Protected paths should check both original and resolved symlink paths
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
}

# =============================================================================
# EXIT trap interference (caused tests to silently skip in parallel runs)
# =============================================================================

@test "regression: no bats test files use EXIT traps in setup" {
	# EXIT traps in setup() cause bats to silently skip tests in parallel mode.
	# All cleanup should be done in teardown() instead.
	# Exclude this file from the check (it mentions EXIT in test assertions only)
	local count
	count=$(grep -rl "trap.*'.*EXIT" "$SHELL_CONFIG_DIR/tests/" --include="*.bats" 2>/dev/null | \
		grep -v "bats-infrastructure.bats" | wc -l)
	[ "$count" -eq 0 ]
}

# =============================================================================
# rm wrapper interference (caused test cleanup to fail)
# =============================================================================

@test "regression: test teardown uses /bin/rm for cleanup, not bare rm" {
	# The rm wrapper (lib/bin/rm) can block cleanup of test paths.
	# All test teardown that uses rm should use /bin/rm explicitly.
	local bad_files=()
	while IFS= read -r file; do
		# Check if teardown does rm -rf without /bin/ prefix
		local teardown_block
		teardown_block=$(sed -n '/^teardown()/,/^}/p' "$file" 2>/dev/null) || continue
		if echo "$teardown_block" | grep -q 'rm -rf' && \
		   ! echo "$teardown_block" | grep -q '/bin/rm'; then
			bad_files+=("$(basename "$file")")
		fi
	done < <(find "$SHELL_CONFIG_DIR/tests" -name "*.bats" -type f)
	[ ${#bad_files[@]} -eq 0 ]
}

# =============================================================================
# Git hooks isolation (caused git commit failures in parallel tests)
# =============================================================================

@test "regression: git test files that commit also disable hooks" {
	# Global gitconfig hooks (hooksPath) cause test git commits to fail
	# in parallel when hooks source libraries that conflict.
	# Test files that do git commit should set core.hooksPath /dev/null.
	local bad_files=()
	while IFS= read -r file; do
		# Only check files that actually do git commit (where hooks would interfere)
		if grep -q "git commit" "$file" && grep -q "git init" "$file" && \
		   ! grep -q "core.hooksPath" "$file"; then
			bad_files+=("$(basename "$file")")
		fi
	done < <(find "$SHELL_CONFIG_DIR/tests" -name "*.bats" -type f)
	[ ${#bad_files[@]} -eq 0 ]
}

# =============================================================================
# Protected paths symlink handling
# =============================================================================

@test "regression: protected-paths checks original path before symlink resolution" {
	# Bug: readlink -f resolves symlinks before matching, so ~/.shell-config
	# (a symlink to the repo) resolved to the repo path and was NOT protected.
	# Fix: check both original and resolved paths.
	source "$SHELL_CONFIG_DIR/lib/core/protected-paths.sh"

	# The original path pattern should be protected regardless of symlink target
	local result
	result=$(get_protected_path_type "$HOME/.shell-config" 2>/dev/null)
	[ $? -eq 0 ]
	[ "$result" = "protected-path" ]
}

@test "regression: protected-paths still catches symlink bypass attempts" {
	# Symlinks pointing TO protected paths should still be blocked.
	# e.g., /tmp/evil -> ~/.ssh must still be protected.
	source "$SHELL_CONFIG_DIR/lib/core/protected-paths.sh"

	local test_link
	test_link=$(mktemp -d)/evil-link
	ln -sf "$HOME/.ssh" "$test_link"

	local result
	result=$(get_protected_path_type "$test_link" 2>/dev/null)
	[ $? -eq 0 ]
	[ "$result" = "protected-path" ]

	/bin/rm -rf "$(dirname "$test_link")"
}

# =============================================================================
# ZSH_VERSION unbound variable
# =============================================================================

@test "regression: hardening.sh handles unset ZSH_VERSION with set -u" {
	# Bug: lib/security/hardening.sh used $ZSH_VERSION without default,
	# causing 'unbound variable' errors when set -u was active in bash.
	# Fix: use ${ZSH_VERSION:-}
	local hardening="$SHELL_CONFIG_DIR/lib/security/hardening.sh"
	[ -f "$hardening" ]

	# Verify the fix is in place
	grep -q 'ZSH_VERSION:-' "$hardening"
}

# =============================================================================
# Portable gitconfig paths
# =============================================================================

@test "regression: gitconfig uses portable paths not hardcoded" {
	# Bug: gitconfig had hardcoded /Users/<username>/.githooks path.
	# Fix: use ~/.githooks for portability.
	local gitconfig="$SHELL_CONFIG_DIR/config/gitconfig"
	[ -f "$gitconfig" ]

	# Should NOT contain hardcoded /Users/ paths
	! grep -q '/Users/[a-zA-Z]' "$gitconfig"
}
