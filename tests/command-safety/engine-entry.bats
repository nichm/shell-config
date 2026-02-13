#!/usr/bin/env bats
# =============================================================================
# COMMAND SAFETY ENGINE ENTRY POINT TESTS
# =============================================================================
# Tests for lib/command-safety/engine.sh (the main entry point)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export ENGINE_FILE="$SHELL_CONFIG_DIR/lib/command-safety/engine.sh"
}

@test "engine entry: file exists and is readable" {
	[ -f "$ENGINE_FILE" ]
	[ -r "$ENGINE_FILE" ]
}

@test "engine entry: valid bash syntax" {
	run bash -n "$ENGINE_FILE"
	[ "$status" -eq 0 ]
}

@test "engine entry: loads modules in dependency order" {
	# Must load: loader → utils → logging → display → matcher → wrapper
	run grep -n 'source.*engine/' "$ENGINE_FILE"
	[ "$status" -eq 0 ]
	# loader must come before utils
	local loader_line utils_line
	loader_line=$(grep -n 'engine/loader.sh' "$ENGINE_FILE" | head -1 | cut -d: -f1)
	utils_line=$(grep -n 'engine/utils.sh' "$ENGINE_FILE" | head -1 | cut -d: -f1)
	[ "$loader_line" -lt "$utils_line" ]
}

@test "engine entry: defines command_safety_init function" {
	run grep -q 'command_safety_init()' "$ENGINE_FILE"
	[ "$status" -eq 0 ]
}

@test "engine entry: respects COMMAND_SAFETY_ENABLED flag" {
	run grep -q 'COMMAND_SAFETY_ENABLED' "$ENGINE_FILE"
	[ "$status" -eq 0 ]
}

@test "engine entry: uses _COMMAND_SAFETY_DIR for module paths" {
	run grep -q '_COMMAND_SAFETY_DIR' "$ENGINE_FILE"
	[ "$status" -eq 0 ]
}

@test "engine entry: supports SHELL_CONFIG_DIR for directory detection" {
	run grep -q 'SHELL_CONFIG_DIR' "$ENGINE_FILE"
	[ "$status" -eq 0 ]
}

@test "engine entry: handles all 6 engine modules" {
	# loader, utils, logging, display, matcher, wrapper
	local count
	count=$(grep -c '^source.*engine/' "$ENGINE_FILE")
	[ "$count" -eq 6 ]
}

@test "engine entry: warns on wrapper generation failure" {
	run grep -q 'Failed wrapper' "$ENGINE_FILE"
	[ "$status" -eq 0 ]
}
