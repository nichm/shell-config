#!/usr/bin/env bats
# =============================================================================
# ALIAS TESTS: Git shortcuts
# =============================================================================
# Tests for lib/aliases/git.sh
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export ALIAS_FILE="$SHELL_CONFIG_DIR/lib/aliases/git.sh"
}

@test "git aliases: file exists and is readable" {
	[ -f "$ALIAS_FILE" ]
	[ -r "$ALIAS_FILE" ]
}

@test "git aliases: valid bash syntax" {
	run bash -n "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "git aliases: sources without error" {
	run bash -c "source '$ALIAS_FILE'"
	[ "$status" -eq 0 ]
}

@test "git aliases: has idempotent load guard" {
	run grep -q '_SHELL_CONFIG_ALIASES_GIT_LOADED' "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "git aliases: defines gs as git status" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias gs
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"git status"* ]]
}

@test "git aliases: defines ga as git add" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias ga
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"git add"* ]]
}

@test "git aliases: defines gc as git commit" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias gc
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"git commit"* ]]
}

@test "git aliases: defines gp as git push" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias gp
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"git push"* ]]
}

@test "git aliases: defines gl as git log" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias gl
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"git log"* ]]
}

@test "git aliases: defines gd as git diff" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias gd
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"git diff"* ]]
}

@test "git aliases: double-source is idempotent" {
	run bash -c "
		source '$ALIAS_FILE'
		source '$ALIAS_FILE'
	"
	[ "$status" -eq 0 ]
}
