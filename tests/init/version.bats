#!/usr/bin/env bats
# Tests for VERSION file and version management

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export VERSION_FILE="$SHELL_CONFIG_DIR/VERSION"
}

@test "VERSION file exists" {
	[ -f "$VERSION_FILE" ]
}

@test "VERSION file is not empty" {
	[ -s "$VERSION_FILE" ]
}

@test "VERSION file contains valid semver format" {
	run cat "$VERSION_FILE"
	[ "$status" -eq 0 ]
	# Match semver pattern: MAJOR.MINOR.PATCH
	[[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "VERSION file has no trailing whitespace except newline" {
	run bash -c "cat '$VERSION_FILE' | tr -d '\n' | grep -E '\\s$' || echo 'clean'"
	[ "$output" = "clean" ]
}
