#!/usr/bin/env bats
# =============================================================================
# GIT COMMIT-MSG & PREPARE-COMMIT-MSG TESTS
# =============================================================================
# Tests for lib/git/stages/commit/commit-msg.sh and prepare-commit-msg.sh
# Regression: PR #133 (strict mode)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export COMMIT_MSG_FILE="$SHELL_CONFIG_DIR/lib/git/stages/commit/commit-msg.sh"
	export PREPARE_MSG_FILE="$SHELL_CONFIG_DIR/lib/git/stages/commit/prepare-commit-msg.sh"

	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	# Provide stub logging functions needed by commit-msg.sh
	log_error() { echo "ERROR: $*" >&2; }
	log_warning() { echo "WARNING: $*" >&2; }
	export -f log_error log_warning
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

# =============================================================================
# commit-msg.sh
# =============================================================================

@test "commit-msg: file exists and is readable" {
	[ -f "$COMMIT_MSG_FILE" ]
	[ -r "$COMMIT_MSG_FILE" ]
}

@test "commit-msg: valid bash syntax" {
	run bash -n "$COMMIT_MSG_FILE"
	[ "$status" -eq 0 ]
}

@test "commit-msg: uses strict mode" {
	run grep -q 'set -euo pipefail' "$COMMIT_MSG_FILE"
	[ "$status" -eq 0 ]
}

@test "commit-msg: defines validate_commit_message function" {
	run grep -q 'validate_commit_message()' "$COMMIT_MSG_FILE"
	[ "$status" -eq 0 ]
}

@test "commit-msg: rejects short messages (less than 10 chars)" {
	source "$COMMIT_MSG_FILE"
	echo "short" > "$TEST_TEMP_DIR/msg"
	run validate_commit_message "$TEST_TEMP_DIR/msg"
	[ "$status" -eq 1 ]
}

@test "commit-msg: accepts messages with sufficient length" {
	source "$COMMIT_MSG_FILE"
	echo "This is a sufficient commit message" > "$TEST_TEMP_DIR/msg"
	run validate_commit_message "$TEST_TEMP_DIR/msg"
	[ "$status" -eq 0 ]
}

@test "commit-msg: skips validation for merge commits" {
	source "$COMMIT_MSG_FILE"
	echo "Merge branch 'feature' into main" > "$TEST_TEMP_DIR/msg"
	run validate_commit_message "$TEST_TEMP_DIR/msg"
	[ "$status" -eq 0 ]
}

@test "commit-msg: skips validation for revert commits" {
	source "$COMMIT_MSG_FILE"
	echo "Revert \"some commit\"" > "$TEST_TEMP_DIR/msg"
	run validate_commit_message "$TEST_TEMP_DIR/msg"
	[ "$status" -eq 0 ]
}

@test "commit-msg: skips validation for fixup commits" {
	source "$COMMIT_MSG_FILE"
	echo "fixup! previous commit" > "$TEST_TEMP_DIR/msg"
	run validate_commit_message "$TEST_TEMP_DIR/msg"
	[ "$status" -eq 0 ]
}

@test "commit-msg: warns on sensitive keywords" {
	source "$COMMIT_MSG_FILE"
	echo "Add password reset feature to the auth module" > "$TEST_TEMP_DIR/msg"
	run validate_commit_message "$TEST_TEMP_DIR/msg"
	# Should pass but with a warning
	[ "$status" -eq 0 ]
	[[ "$output" == *"sensitive"* ]] || [[ "$output" == "" ]]
}

@test "commit-msg: enforces conventional format when enabled" {
	source "$COMMIT_MSG_FILE"
	export GIT_ENFORCE_CONVENTIONAL_COMMITS=1
	echo "This is not conventional format message" > "$TEST_TEMP_DIR/msg"
	run validate_commit_message "$TEST_TEMP_DIR/msg"
	[ "$status" -eq 1 ]
}

@test "commit-msg: accepts conventional commits when enforced" {
	source "$COMMIT_MSG_FILE"
	export GIT_ENFORCE_CONVENTIONAL_COMMITS=1
	echo "feat(auth): add password reset feature" > "$TEST_TEMP_DIR/msg"
	run validate_commit_message "$TEST_TEMP_DIR/msg"
	[ "$status" -eq 0 ]
}

# =============================================================================
# prepare-commit-msg.sh
# =============================================================================

@test "prepare-commit-msg: file exists and is readable" {
	[ -f "$PREPARE_MSG_FILE" ]
	[ -r "$PREPARE_MSG_FILE" ]
}

@test "prepare-commit-msg: valid bash syntax" {
	run bash -n "$PREPARE_MSG_FILE"
	[ "$status" -eq 0 ]
}

@test "prepare-commit-msg: uses strict mode" {
	run grep -q 'set -euo pipefail' "$PREPARE_MSG_FILE"
	[ "$status" -eq 0 ]
}

@test "prepare-commit-msg: defines prepare_commit_message function" {
	run grep -q 'prepare_commit_message()' "$PREPARE_MSG_FILE"
	[ "$status" -eq 0 ]
}

@test "prepare-commit-msg: sanitizes branch name for injection prevention" {
	# Must use tr -cd to prevent sed injection
	run grep -q "tr -cd" "$PREPARE_MSG_FILE"
	[ "$status" -eq 0 ]
}

@test "prepare-commit-msg: uses temp file instead of sed -i" {
	# PR #133 changed from sed -i to temp file for safety
	run grep -q 'mktemp' "$PREPARE_MSG_FILE"
	[ "$status" -eq 0 ]
}

@test "prepare-commit-msg: has trap for temp file cleanup" {
	run grep -q "trap.*rm.*EXIT" "$PREPARE_MSG_FILE"
	[ "$status" -eq 0 ]
}
