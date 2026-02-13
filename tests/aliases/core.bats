#!/usr/bin/env bats
# =============================================================================
# ALIAS TESTS: Core navigation and safety aliases
# =============================================================================
# Tests for lib/aliases/core.sh
# Regression coverage: PR #93 (emoji standardization)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export ALIAS_FILE="$SHELL_CONFIG_DIR/lib/aliases/core.sh"
}

@test "core aliases: file exists and is readable" {
	[ -f "$ALIAS_FILE" ]
	[ -r "$ALIAS_FILE" ]
}

@test "core aliases: valid bash syntax" {
	run bash -n "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "core aliases: sources without error" {
	run bash -c "source '$ALIAS_FILE'"
	[ "$status" -eq 0 ]
}

@test "core aliases: has idempotent load guard" {
	run grep -q '_SHELL_CONFIG_ALIASES_CORE_LOADED' "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "core aliases: defines navigation aliases" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias .. && alias ... && alias ....
	"
	[ "$status" -eq 0 ]
}

@test "core aliases: .. navigates up one directory" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias ..
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"cd .."* ]]
}

@test "core aliases: safety alias mv includes -i flag" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias mv
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"-i"* ]]
}

@test "core aliases: safety alias cp includes -i flag" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias cp
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"-i"* ]]
}

@test "core aliases: ln includes -i for safety" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias ln
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"-i"* ]]
}

@test "core aliases: chmod includes -v for verbose" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias chmod
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"-v"* ]]
}

@test "core aliases: double-source is idempotent" {
	run bash -c "
		source '$ALIAS_FILE'
		source '$ALIAS_FILE'
	"
	[ "$status" -eq 0 ]
}
