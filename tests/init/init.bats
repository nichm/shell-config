#!/usr/bin/env bats
# Tests for init.sh - master shell configuration loader

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export INIT_SCRIPT="$SHELL_CONFIG_DIR/init.sh"
}

@test "init.sh exists" {
	[ -f "$INIT_SCRIPT" ]
}

# Note: init.sh uses ZSH-specific syntax, so we test with zsh when available

@test "init.sh has proper shebang" {
	run head -1 "$INIT_SCRIPT"
	[ "$status" -eq 0 ]
	[[ "$output" == "#!/"* ]]
}

@test "init.sh contains SHELL_CONFIG_DIR assignment" {
	run grep "SHELL_CONFIG_DIR=" "$INIT_SCRIPT"
	[ "$status" -eq 0 ]
}

@test "init.sh contains SHELL_CONFIG_START_TIME assignment" {
	run grep "SHELL_CONFIG_START_TIME" "$INIT_SCRIPT"
	[ "$status" -eq 0 ]
}

@test "init.sh sources config loader" {
	run grep "config.sh" "$INIT_SCRIPT"
	[ "$status" -eq 0 ]
}

@test "init.sh sources logging module" {
	run grep "logging.sh" "$INIT_SCRIPT"
	[ "$status" -eq 0 ]
}

@test "init.sh adds lib/bin to PATH" {
	# PATH setup is now in lib/core/paths.sh (sourced by init.sh)
	local paths_file="$SHELL_CONFIG_DIR/lib/core/paths.sh"
	run bash -c "grep 'lib/bin' '$INIT_SCRIPT' || grep 'lib/bin' '$paths_file'"
	[ "$status" -eq 0 ]
}

@test "init.sh adds lib/integrations/ghls to PATH" {
	# PATH setup is now in lib/core/paths.sh (sourced by init.sh)
	# ghls was moved from lib/ghls to lib/integrations/ghls in Phase 3
	local paths_file="$SHELL_CONFIG_DIR/lib/core/paths.sh"
	run bash -c "grep -E 'lib/(integrations/)?ghls' '$INIT_SCRIPT' || grep -E 'lib/(integrations/)?ghls' '$paths_file'"
	[ "$status" -eq 0 ]
}
