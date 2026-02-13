#!/usr/bin/env bats
# Tests for lib/core/config.sh - configuration loading and validation

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export CONFIG_LOADER="$SHELL_CONFIG_DIR/lib/core/config.sh"

	# Create temp config directory (cleanup in teardown, not EXIT trap which interferes with bats)
	export TEST_TMPDIR="$BATS_TEST_TMPDIR/config_test"
	mkdir -p "$TEST_TMPDIR"

	# Clear any existing config vars
	unset SHELL_CONFIG_WELCOME
	unset SHELL_CONFIG_COMMAND_SAFETY
	unset SHELL_CONFIG_SECRETS_CACHE_TTL
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TMPDIR:-}" ]] && /bin/rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

@test "config loader exists" {
	[ -f "$CONFIG_LOADER" ]
}

@test "config loader sources without error" {
	run bash -c "source '$CONFIG_LOADER'"
	[ "$status" -eq 0 ]
}

@test "config loader sets default values" {
	run bash -c "source '$CONFIG_LOADER' && echo \$SHELL_CONFIG_WELCOME"
	[ "$status" -eq 0 ]
	[ "$output" = "true" ]
}

@test "config loader respects environment variable override" {
	export SHELL_CONFIG_WELCOME=false
	run bash -c "source '$CONFIG_LOADER' && echo \$SHELL_CONFIG_WELCOME"
	[ "$status" -eq 0 ]
	[ "$output" = "false" ]
}

@test "shell_config_validate_config accepts valid boolean" {
	run bash -c "
        source '$CONFIG_LOADER'
        export SHELL_CONFIG_WELCOME=true
        shell_config_validate_config
    "
	[ "$status" -eq 0 ]
}

@test "shell_config_validate_config rejects invalid boolean" {
	run bash -c "
        source '$CONFIG_LOADER'
        export SHELL_CONFIG_WELCOME=maybe
        shell_config_validate_config 2>&1
    "
	[ "$status" -ne 0 ]
	[[ "$output" == *"must be true/false"* ]]
}

@test "shell_config_validate_config accepts valid integer for TTL" {
	run bash -c "
        source '$CONFIG_LOADER'
        export SHELL_CONFIG_SECRETS_CACHE_TTL=300
        shell_config_validate_config
    "
	[ "$status" -eq 0 ]
}

@test "shell_config_validate_config rejects invalid integer for TTL" {
	run bash -c "
        source '$CONFIG_LOADER'
        export SHELL_CONFIG_SECRETS_CACHE_TTL=not_a_number
        shell_config_validate_config 2>&1
    "
	[ "$status" -ne 0 ]
	[[ "$output" == *"must be positive integer"* ]]
}
