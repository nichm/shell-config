#!/usr/bin/env bats
# =============================================================================
# ALIAS TESTS: GitHub Actions security scanning
# =============================================================================
# Tests for lib/aliases/gha.sh
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export ALIAS_FILE="$SHELL_CONFIG_DIR/lib/aliases/gha.sh"
}

@test "gha aliases: file exists and is readable" {
	[ -f "$ALIAS_FILE" ]
	[ -r "$ALIAS_FILE" ]
}

@test "gha aliases: valid bash syntax" {
	run bash -n "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "gha aliases: sources without error" {
	run bash -c "source '$ALIAS_FILE'"
	[ "$status" -eq 0 ]
}

@test "gha aliases: has idempotent load guard" {
	run grep -q '_SHELL_CONFIG_ALIASES_GHA_LOADED' "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "gha aliases: defines gha-scan function" {
	run bash -c "
		source '$ALIAS_FILE'
		type -t gha-scan
	"
	[ "$status" -eq 0 ]
	[[ "$output" == "function" ]]
}

@test "gha aliases: gha-scan delegates to bin/gha-scan binary" {
	# Verify gha-scan function references the binary path
	run grep -q 'bin/gha-scan' "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "gha aliases: gha-scan error includes WHAT/WHY/FIX format" {
	# gha-scan errors go to stderr; verify the source file has proper error handling
	run grep -q 'ERROR' "$ALIAS_FILE"
	[ "$status" -eq 0 ]
	run grep -q 'WHY' "$ALIAS_FILE"
	[ "$status" -eq 0 ]
	run grep -q 'FIX' "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "gha aliases: defines ghas shortcut alias" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias ghas
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"gha-scan"* ]]
}

@test "gha aliases: defines ghasq quick mode alias" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias ghasq
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"-q"* ]]
}

@test "gha aliases: defines ghasm modified files alias" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias ghasm
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"-m"* ]]
}

@test "gha aliases: double-source is idempotent" {
	run bash -c "
		source '$ALIAS_FILE'
		source '$ALIAS_FILE'
	"
	[ "$status" -eq 0 ]
}
