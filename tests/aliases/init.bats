#!/usr/bin/env bats
# Tests for lib/aliases/init.sh - shell aliases

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export ALIASES_LIB="$SHELL_CONFIG_DIR/lib/aliases/init.sh"
}

@test "aliases library exists" {
	[ -f "$ALIASES_LIB" ]
}

@test "aliases library sources without error" {
	run bash -c "source '$ALIASES_LIB' 2>/dev/null"
	[ "$status" -eq 0 ]
}

@test "aliases library is valid bash syntax" {
	run bash -n "$ALIASES_LIB"
	[ "$status" -eq 0 ]
}

@test "aliases defines clauded alias" {
	run bash -c "
        shopt -s expand_aliases
        source '$ALIASES_LIB' 2>/dev/null
        alias clauded
    "
	[ "$status" -eq 0 ]
	[[ "$output" == *"claude"* ]]
}
