#!/usr/bin/env bats
# =============================================================================
# GIT PRE-COMMIT EXTENDED CHECKS TESTS
# =============================================================================
# Tests for lib/git/stages/commit/pre-commit-checks-extended.sh
# Regression: PR #82 (TS validators), PR #133 (strict mode)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export EXTENDED_FILE="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks-extended.sh"

	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	# Provide color stubs
	GREEN="" NC="" BLUE="" YELLOW=""
	export GREEN NC BLUE YELLOW
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "pre-commit-extended: file exists and is readable" {
	[ -f "$EXTENDED_FILE" ]
	[ -r "$EXTENDED_FILE" ]
}

@test "pre-commit-extended: valid bash syntax" {
	run bash -n "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: uses strict mode" {
	run grep -q 'set -euo pipefail' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: defines run_unit_tests function" {
	run grep -q 'run_unit_tests()' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: defines run_typescript_check function" {
	run grep -q 'run_typescript_check()' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: defines run_circular_dependency_check function" {
	run grep -q 'run_circular_dependency_check()' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: defines run_python_type_check function" {
	run grep -q 'run_python_type_check()' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: typescript check respects GIT_SKIP_TSC_CHECK" {
	run grep -q 'GIT_SKIP_TSC_CHECK' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: circular deps check respects GIT_SKIP_CIRCULAR_DEPS" {
	run grep -q 'GIT_SKIP_CIRCULAR_DEPS' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: python check respects GIT_SKIP_MYPY_CHECK" {
	run grep -q 'GIT_SKIP_MYPY_CHECK' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: uses configurable timeout via SC_HOOK_TIMEOUT" {
	run grep -q 'SC_HOOK_TIMEOUT' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: uses command_exists for tool checks" {
	run grep -q 'command_exists' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: handles TS file extensions correctly" {
	# Should match ts, tsx, mts, cts
	run grep -q 'ts | tsx | mts | cts' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: unit tests use bun test" {
	run grep -q 'bun test' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: uses portable timeout (timeout or gtimeout)" {
	run grep -q 'gtimeout' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}

@test "pre-commit-extended: handles no tsconfig.json gracefully" {
	run grep -q 'tsconfig.json' "$EXTENDED_FILE"
	[ "$status" -eq 0 ]
}
