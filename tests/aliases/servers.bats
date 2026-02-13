#!/usr/bin/env bats
# =============================================================================
# ALIAS TESTS: Server/login shortcuts
# =============================================================================
# Tests for lib/aliases/servers.sh
# Regression coverage: PR #92 (server alias refactor)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export ALIAS_FILE="$SHELL_CONFIG_DIR/lib/aliases/servers.sh"
}

@test "servers aliases: file exists and is readable" {
	[ -f "$ALIAS_FILE" ]
	[ -r "$ALIAS_FILE" ]
}

@test "servers aliases: valid bash syntax" {
	run bash -n "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "servers aliases: sources without error" {
	run bash -c "source '$ALIAS_FILE'"
	[ "$status" -eq 0 ]
}

@test "servers aliases: has idempotent load guard" {
	run grep -q '_SHELL_CONFIG_ALIASES_SERVERS_LOADED' "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "servers aliases: loads from personal.env config" {
	# servers.sh dynamically creates aliases from personal.env SERVER_N vars
	run grep -q 'personal.env' "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "servers aliases: does not contain hardcoded IPs" {
	# PR #104 removed personal server info for open source
	run grep -E '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$ALIAS_FILE"
	[ "$status" -ne 0 ]
}

@test "servers aliases: double-source is idempotent" {
	run bash -c "
		source '$ALIAS_FILE'
		source '$ALIAS_FILE'
	"
	[ "$status" -eq 0 ]
}
