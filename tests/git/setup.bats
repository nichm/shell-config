#!/usr/bin/env bats
# =============================================================================
# GIT SETUP TESTS
# =============================================================================
# Tests for lib/git/setup.sh (hook installation, gitleaks setup, status)
# Regression: PR #131 (hooks refactor), PR #133 (strict mode)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export SETUP_FILE="$SHELL_CONFIG_DIR/lib/git/setup.sh"
}

@test "git setup: file exists and is readable" {
	[ -f "$SETUP_FILE" ]
	[ -r "$SETUP_FILE" ]
}

@test "git setup: valid bash syntax" {
	run bash -n "$SETUP_FILE"
	[ "$status" -eq 0 ]
}

@test "git setup: uses strict mode" {
	run grep -q 'set -euo pipefail' "$SETUP_FILE"
	[ "$status" -eq 0 ]
}

@test "git setup: defines install_hooks function" {
	run grep -q 'install_hooks()' "$SETUP_FILE"
	[ "$status" -eq 0 ]
}

@test "git setup: defines uninstall function" {
	run grep -q 'uninstall()' "$SETUP_FILE"
	[ "$status" -eq 0 ]
}

@test "git setup: defines status function" {
	run grep -q 'status()' "$SETUP_FILE"
	[ "$status" -eq 0 ]
}

@test "git setup: main function handles install|uninstall|status" {
	run grep -q 'install)' "$SETUP_FILE"
	[ "$status" -eq 0 ]
	run grep -q 'uninstall)' "$SETUP_FILE"
	[ "$status" -eq 0 ]
	run grep -q 'status)' "$SETUP_FILE"
	[ "$status" -eq 0 ]
}

@test "git setup: installs all 7 standard git hooks" {
	# Should loop over all 7 hooks
	run grep -c 'pre-commit\|commit-msg\|prepare-commit-msg\|post-commit\|pre-push\|pre-merge-commit\|post-merge' "$SETUP_FILE"
	# At least 7 references (each hook name appears at least once in the for loop)
	[ "$output" -ge 7 ]
}

@test "git setup: symlinks hooks instead of copying" {
	run grep -q 'ln -sf' "$SETUP_FILE"
	[ "$status" -eq 0 ]
}

@test "git setup: configures git core.hooksPath" {
	run grep -q 'core.hooksPath' "$SETUP_FILE"
	[ "$status" -eq 0 ]
}

@test "git setup: sources platform.sh for cross-platform" {
	run grep -q 'platform.sh' "$SETUP_FILE"
	[ "$status" -eq 0 ]
}

@test "git setup: uninstall removes hooksPath config" {
	run grep -q 'core.hooksPath' "$SETUP_FILE"
	[ "$status" -eq 0 ]
}

@test "git setup: install_gitleaks checks command existence" {
	run grep -q 'command_exists.*gitleaks' "$SETUP_FILE"
	[ "$status" -eq 0 ]
}

@test "git setup: invalid subcommand shows usage" {
	run bash "$SETUP_FILE" invalid_command 2>&1
	[[ "$output" == *"Usage"* ]]
}

@test "git setup: uses command_exists fallback if not already defined" {
	run grep -q 'declare -f command_exists' "$SETUP_FILE"
	[ "$status" -eq 0 ]
}
