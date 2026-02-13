#!/usr/bin/env bats
# Tests for install.sh - installation script validation

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export INSTALL_SCRIPT="$SHELL_CONFIG_DIR/install.sh"
}

@test "install.sh exists" {
	[ -f "$INSTALL_SCRIPT" ]
}

@test "install.sh is executable" {
	[ -x "$INSTALL_SCRIPT" ]
}

@test "install.sh is valid bash syntax" {
	run bash -n "$INSTALL_SCRIPT"
	[ "$status" -eq 0 ]
}

@test "install.sh has proper shebang" {
	run head -1 "$INSTALL_SCRIPT"
	[ "$status" -eq 0 ]
	[[ "$output" == "#!/"* ]]
	[[ "$output" == *"bash"* ]] || [[ "$output" == *"env bash"* ]]
}

@test "install.sh uses set -euo pipefail" {
	run grep -E "^set -[euop]+" "$INSTALL_SCRIPT"
	[ "$status" -eq 0 ]
}
