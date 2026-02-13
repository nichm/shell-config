#!/usr/bin/env bats
# =============================================================================
# FZF INTEGRATION TESTS
# =============================================================================
# Tests for lib/integrations/fzf.sh
# Regression: PR #138 (fzf integration changes)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export FZF_FILE="$SHELL_CONFIG_DIR/lib/integrations/fzf.sh"

	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "fzf: file exists and is readable" {
	[ -f "$FZF_FILE" ]
	[ -r "$FZF_FILE" ]
}

@test "fzf: valid bash syntax" {
	run bash -n "$FZF_FILE"
	[ "$status" -eq 0 ]
}

@test "fzf: checks for fzf command existence" {
	run grep -q 'command_exists.*fzf' "$FZF_FILE"
	[ "$status" -eq 0 ]
}

@test "fzf: warns when fzf not installed" {
	run grep -q 'fzf not found' "$FZF_FILE"
	[ "$status" -eq 0 ]
}

@test "fzf: defines fe (fuzzy file editor) function" {
	run grep -q 'fe()' "$FZF_FILE"
	[ "$status" -eq 0 ]
}

@test "fzf: defines fcd (fuzzy directory changer) function" {
	run grep -q 'fcd()' "$FZF_FILE"
	[ "$status" -eq 0 ]
}

@test "fzf: defines fh (fuzzy history) function" {
	run grep -q 'fh()' "$FZF_FILE"
	[ "$status" -eq 0 ]
}

@test "fzf: defines fkill (fuzzy process killer) function" {
	run grep -q 'fkill()' "$FZF_FILE"
	[ "$status" -eq 0 ]
}

@test "fzf: defines fbr (fuzzy git branch) function" {
	run grep -q 'fbr()' "$FZF_FILE"
	[ "$status" -eq 0 ]
}

@test "fzf: defines fstash (fuzzy git stash) function" {
	run grep -q 'fstash()' "$FZF_FILE"
	[ "$status" -eq 0 ]
}

@test "fzf: fe uses fd when available for better performance" {
	run grep -q 'command_exists.*fd' "$FZF_FILE"
	[ "$status" -eq 0 ]
}

@test "fzf: fe falls back to find when fd not available" {
	run grep -q 'find.*-type f' "$FZF_FILE"
	[ "$status" -eq 0 ]
}

@test "fzf: sources command-cache for optimized tool checks" {
	run grep -q 'command-cache.sh' "$FZF_FILE"
	[ "$status" -eq 0 ]
}

@test "fzf: uses EDITOR variable with vi fallback" {
	run grep -q 'EDITOR:-vi' "$FZF_FILE"
	[ "$status" -eq 0 ]
}
