#!/usr/bin/env bats
# =============================================================================
# ALIAS TESTS: 1Password & SSH shortcuts
# =============================================================================
# Tests for lib/aliases/1password.sh
# Regression coverage: PR #92 (alias moves)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export ALIAS_FILE="$SHELL_CONFIG_DIR/lib/aliases/1password.sh"
}

@test "1password aliases: file exists and is readable" {
	[ -f "$ALIAS_FILE" ]
	[ -r "$ALIAS_FILE" ]
}

@test "1password aliases: valid bash syntax" {
	run bash -n "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "1password aliases: sources without error" {
	run bash -c "source '$ALIAS_FILE'"
	[ "$status" -eq 0 ]
}

@test "1password aliases: has idempotent load guard" {
	run grep -q '_SHELL_CONFIG_ALIASES_1PASSWORD_LOADED' "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "1password aliases: defines 1password-ssh-sync alias" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias 1password-ssh-sync
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ssh-sync"* ]]
}

@test "1password aliases: defines op-diagnose alias" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias op-diagnose
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"diagnose"* ]]
}

@test "1password aliases: defines op-login alias" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias op-login
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"login"* ]]
}

@test "1password aliases: defines ssh-status alias" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias ssh-status
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"SSH_AUTH_SOCK"* ]]
}

@test "1password aliases: defines ssh-test alias" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias ssh-test
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"git@github.com"* ]]
}

@test "1password aliases: defines ssh-reload alias" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias ssh-reload
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ssh"* ]]
}

@test "1password aliases: double-source is idempotent" {
	run bash -c "
		source '$ALIAS_FILE'
		source '$ALIAS_FILE'
	"
	[ "$status" -eq 0 ]
}
