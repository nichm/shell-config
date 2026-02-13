#!/usr/bin/env bats
# =============================================================================
# VALIDATION SHARED CONFIG TESTS
# =============================================================================
# Tests for lib/validation/shared/config.sh
# Regression: PR #130 (env vars externalization)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export CONFIG_FILE="$SHELL_CONFIG_DIR/lib/validation/shared/config.sh"

	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	unset _VALIDATION_CONFIG_LOADED
	source "$CONFIG_FILE"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "validation config: file exists and is readable" {
	[ -f "$CONFIG_FILE" ]
	[ -r "$CONFIG_FILE" ]
}

@test "validation config: valid bash syntax" {
	run bash -n "$CONFIG_FILE"
	[ "$status" -eq 0 ]
}

@test "validation config: has idempotent load guard" {
	run grep -q '_VALIDATION_CONFIG_LOADED' "$CONFIG_FILE"
	[ "$status" -eq 0 ]
}

@test "validation config: INFO_THRESHOLD_PERCENT is 60" {
	[ "$INFO_THRESHOLD_PERCENT" -eq 60 ]
}

@test "validation config: WARNING_THRESHOLD_PERCENT is 75" {
	[ "$WARNING_THRESHOLD_PERCENT" -eq 75 ]
}

@test "validation config: DEFAULT_LINE_LIMIT is 800" {
	[ "$DEFAULT_LINE_LIMIT" -eq 800 ]
}

# =============================================================================
# _get_limit_by_ext tests
# =============================================================================

@test "validation config: shell scripts get 600 line limit" {
	local limit
	limit=$(_get_limit_by_ext "sh")
	[ "$limit" -eq 600 ]
}

@test "validation config: bash scripts get 600 line limit" {
	local limit
	limit=$(_get_limit_by_ext "bash")
	[ "$limit" -eq 600 ]
}

@test "validation config: TypeScript gets 800 line limit" {
	local limit
	limit=$(_get_limit_by_ext "ts")
	[ "$limit" -eq 800 ]
}

@test "validation config: Rust gets 1500 line limit" {
	local limit
	limit=$(_get_limit_by_ext "rs")
	[ "$limit" -eq 1500 ]
}

@test "validation config: Go gets 1500 line limit" {
	local limit
	limit=$(_get_limit_by_ext "go")
	[ "$limit" -eq 1500 ]
}

@test "validation config: Java gets 700 line limit" {
	local limit
	limit=$(_get_limit_by_ext "java")
	[ "$limit" -eq 700 ]
}

@test "validation config: YAML gets 5000 line limit" {
	local limit
	limit=$(_get_limit_by_ext "yaml")
	[ "$limit" -eq 5000 ]
}

@test "validation config: SQL gets 1500 line limit" {
	local limit
	limit=$(_get_limit_by_ext "sql")
	[ "$limit" -eq 1500 ]
}

@test "validation config: unknown extension returns empty" {
	local limit
	limit=$(_get_limit_by_ext "xyz_unknown")
	[ -z "$limit" ]
}

# =============================================================================
# _get_limit_by_filename tests
# =============================================================================

@test "validation config: Dockerfile gets 2000 line limit" {
	local limit
	limit=$(_get_limit_by_filename "Dockerfile")
	[ "$limit" -eq 2000 ]
}

@test "validation config: package.json gets 2000 line limit" {
	local limit
	limit=$(_get_limit_by_filename "package.json")
	[ "$limit" -eq 2000 ]
}

@test "validation config: package-lock.json gets 5000 line limit" {
	local limit
	limit=$(_get_limit_by_filename "package-lock.json")
	[ "$limit" -eq 5000 ]
}

@test "validation config: unknown filename returns empty" {
	local limit
	limit=$(_get_limit_by_filename "random_file.txt")
	[ -z "$limit" ]
}

# =============================================================================
# get_language_limit tests
# =============================================================================

@test "validation config: get_language_limit for .sh file returns 600" {
	local limit
	limit=$(get_language_limit "test.sh")
	[ "$limit" -eq 600 ]
}

@test "validation config: get_language_limit for Dockerfile returns 2000" {
	local limit
	limit=$(get_language_limit "Dockerfile")
	[ "$limit" -eq 2000 ]
}

@test "validation config: get_language_limit for unknown returns default 800" {
	local limit
	limit=$(get_language_limit "file.unknownext")
	[ "$limit" -eq 800 ]
}

# =============================================================================
# get_thresholds tests
# =============================================================================

@test "validation config: get_thresholds for 600 returns correct values" {
	local thresholds
	thresholds=$(get_thresholds 600)
	local info warning extreme
	read -r info warning extreme <<< "$thresholds"
	[ "$info" -eq 360 ]
	[ "$warning" -eq 450 ]
	[ "$extreme" -eq 600 ]
}

@test "validation config: get_thresholds for 800 returns correct values" {
	local thresholds
	thresholds=$(get_thresholds 800)
	local info warning extreme
	read -r info warning extreme <<< "$thresholds"
	[ "$info" -eq 480 ]
	[ "$warning" -eq 600 ]
	[ "$extreme" -eq 800 ]
}
