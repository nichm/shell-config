#!/usr/bin/env bats
# =============================================================================
# ALIAS TESTS: AI CLI shortcuts
# =============================================================================
# Tests for lib/aliases/ai-cli.sh
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export ALIAS_FILE="$SHELL_CONFIG_DIR/lib/aliases/ai-cli.sh"
}

@test "ai-cli aliases: file exists and is readable" {
	[ -f "$ALIAS_FILE" ]
	[ -r "$ALIAS_FILE" ]
}

@test "ai-cli aliases: valid bash syntax" {
	run bash -n "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "ai-cli aliases: sources without error" {
	run bash -c "source '$ALIAS_FILE'"
	[ "$status" -eq 0 ]
}

@test "ai-cli aliases: has idempotent load guard" {
	run grep -q '_SHELL_CONFIG_ALIASES_AI_CLI_LOADED' "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "ai-cli aliases: defines claude aliases" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias cl && alias clc && alias clr
	"
	[ "$status" -eq 0 ]
}

@test "ai-cli aliases: clauded includes --dangerously-skip-permissions" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias clauded
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"dangerously-skip-permissions"* ]]
}

@test "ai-cli aliases: defines codex aliases" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias cx && alias cxr
	"
	[ "$status" -eq 0 ]
}

@test "ai-cli aliases: double-source is idempotent" {
	run bash -c "
		source '$ALIAS_FILE'
		source '$ALIAS_FILE'
	"
	[ "$status" -eq 0 ]
}
