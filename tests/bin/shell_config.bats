#!/usr/bin/env bats
# Tests for lib/bin/shell-config CLI tool

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export SHELL_CONFIG_CLI="$SHELL_CONFIG_DIR/lib/bin/shell-config"
}

@test "shell-config CLI exists and is executable" {
	[ -f "$SHELL_CONFIG_CLI" ]
	[ -x "$SHELL_CONFIG_CLI" ]
}

@test "shell-config with no args shows usage" {
	run "$SHELL_CONFIG_CLI"
	[ "$status" -eq 0 ]
	[[ "$output" == *"USAGE"* ]] || [[ "$output" == *"shell-config"* ]]
}

@test "shell-config help shows usage" {
	run "$SHELL_CONFIG_CLI" help
	[ "$status" -eq 0 ]
	[[ "$output" == *"COMMANDS"* ]]
}

@test "shell-config --help shows usage" {
	run "$SHELL_CONFIG_CLI" --help
	[ "$status" -eq 0 ]
	[[ "$output" == *"COMMANDS"* ]]
}

@test "shell-config --version shows version" {
	run "$SHELL_CONFIG_CLI" --version
	[ "$status" -eq 0 ]
	[[ "$output" == *"shell-config v"* ]]
}

@test "shell-config -v shows version" {
	run "$SHELL_CONFIG_CLI" -v
	[ "$status" -eq 0 ]
	[[ "$output" == *"shell-config v"* ]]
}

@test "shell-config version shows version" {
	run "$SHELL_CONFIG_CLI" version
	[ "$status" -eq 0 ]
	[[ "$output" == *"shell-config v"* ]]
}

@test "shell-config unknown command shows error" {
	run "$SHELL_CONFIG_CLI" unknowncommand
	[ "$status" -eq 1 ]
	[[ "$output" == *"Unknown command"* ]] || [[ "$output" == *"unknown"* ]]
}
