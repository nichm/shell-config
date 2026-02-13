#!/usr/bin/env bats
# =============================================================================
# COMMAND SAFETY RULES - CORE AGGREGATOR TESTS
# =============================================================================
# Tests for lib/command-safety/rules.sh (rule loading and per-service disable)
# Regression: PR #139 (matchers merged into rules)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export COMMAND_SAFETY_DIR="$SHELL_CONFIG_DIR/lib/command-safety"

	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	# Source engine prereqs in order
	source "$COMMAND_SAFETY_DIR/engine/registry.sh"
	source "$COMMAND_SAFETY_DIR/engine/display.sh"
	source "$COMMAND_SAFETY_DIR/engine/wrapper.sh"
	source "$COMMAND_SAFETY_DIR/engine/loader.sh"
	source "$COMMAND_SAFETY_DIR/engine/matcher.sh"
	source "$COMMAND_SAFETY_DIR/engine/utils.sh"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "rules-core: rules.sh file exists" {
	[ -f "$COMMAND_SAFETY_DIR/rules.sh" ]
}

@test "rules-core: rules.sh is valid bash syntax" {
	run bash -n "$COMMAND_SAFETY_DIR/rules.sh"
	[ "$status" -eq 0 ]
}

@test "rules-core: rules directory exists with rule files" {
	[ -d "$COMMAND_SAFETY_DIR/rules" ]
	local count
	count=$(ls "$COMMAND_SAFETY_DIR/rules/"*.sh 2>/dev/null | wc -l)
	[ "$count" -gt 0 ]
}

@test "rules-core: settings.sh exists in rules directory" {
	[ -f "$COMMAND_SAFETY_DIR/rules/settings.sh" ]
}

@test "rules-core: settings.sh sources without error" {
	run bash -c "source '$COMMAND_SAFETY_DIR/rules/settings.sh'"
	[ "$status" -eq 0 ]
}

@test "rules-core: settings defines COMMAND_SAFETY_PROTECTED_COMMANDS array" {
	source "$COMMAND_SAFETY_DIR/rules/settings.sh"
	[ "${#COMMAND_SAFETY_PROTECTED_COMMANDS[@]}" -gt 0 ]
}

@test "rules-core: settings validates COMMAND_SAFETY_ENABLED" {
	source "$COMMAND_SAFETY_DIR/rules/settings.sh"
	[[ "$COMMAND_SAFETY_ENABLED" == "true" || "$COMMAND_SAFETY_ENABLED" == "false" ]]
}

@test "rules-core: settings validator rejects invalid COMMAND_SAFETY_ENABLED" {
	COMMAND_SAFETY_ENABLED="invalid"
	COMMAND_SAFETY_LOG_FILE="/tmp/test.log"
	COMMAND_SAFETY_INTERACTIVE=false
	COMMAND_SAFETY_PROTECTED_COMMANDS=(rm)
	run _command_safety_settings_validate
	[ "$status" -eq 1 ]
	[[ "$output" == *"ERROR"* ]]
}

@test "rules-core: settings validator rejects empty log file" {
	COMMAND_SAFETY_LOG_FILE=""
	COMMAND_SAFETY_ENABLED=true
	COMMAND_SAFETY_INTERACTIVE=false
	COMMAND_SAFETY_PROTECTED_COMMANDS=(rm)
	run _command_safety_settings_validate
	[ "$status" -eq 1 ]
	[[ "$output" == *"ERROR"* ]]
}

@test "rules-core: settings validator rejects empty protected commands" {
	COMMAND_SAFETY_LOG_FILE="/tmp/test.log"
	COMMAND_SAFETY_ENABLED=true
	COMMAND_SAFETY_INTERACTIVE=false
	COMMAND_SAFETY_PROTECTED_COMMANDS=()
	run _command_safety_settings_validate
	[ "$status" -eq 1 ]
	[[ "$output" == *"ERROR"* ]]
}

@test "rules-core: rules.sh loads all rule files" {
	source "$COMMAND_SAFETY_DIR/rules.sh"

	# After loading, there should be registered rules
	[ "${#COMMAND_SAFETY_RULE_SUFFIXES[@]}" -gt 0 ]
}

@test "rules-core: rules.sh skips disabled services via COMMAND_SAFETY_DISABLE_*" {
	# Must reset and re-source with disable flag BEFORE rules load
	# (loader.sh sources rules.sh automatically, so we do a fresh load)
	COMMAND_SAFETY_RULE_SUFFIXES=()
	COMMAND_SAFETY_RULE_ID=()
	COMMAND_SAFETY_RULE_ACTION=()
	COMMAND_SAFETY_RULE_COMMAND=()
	COMMAND_SAFETY_RULE_PATTERN=()
	COMMAND_SAFETY_RULE_EMOJI=()
	COMMAND_SAFETY_RULE_DESC=()
	COMMAND_SAFETY_RULE_DOCS=()
	COMMAND_SAFETY_RULE_BYPASS=()
	COMMAND_SAFETY_RULE_ALTERNATIVES=()
	_CS_CMD_RULES=()

	# Disable docker rules
	export COMMAND_SAFETY_DISABLE_DOCKER=true

	unset _COMMAND_SAFETY_DIR
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	source "$COMMAND_SAFETY_DIR/rules.sh"

	# Docker rules should NOT be loaded - check by command field
	local has_docker=false
	for suffix in "${COMMAND_SAFETY_RULE_SUFFIXES[@]}"; do
		if [[ "$suffix" == *"DOCKER"* ]]; then
			has_docker=true
			break
		fi
	done
	[ "$has_docker" = "false" ]
}

@test "rules-core: most rule files document per-service disable" {
	# Most rule files should document how to disable them
	# Exceptions: settings.sh, dangerous-commands.sh, package-managers.sh (generic categories)
	local with_disable=0
	local total=0
	for rule_file in "$COMMAND_SAFETY_DIR/rules/"*.sh; do
		[[ "$(basename "$rule_file")" == "settings.sh" ]] && continue
		((++total))
		if grep -q 'COMMAND_SAFETY_DISABLE_' "$rule_file" 2>/dev/null; then
			((++with_disable))
		fi
	done
	# At least 80% of rule files should have disable documentation
	[ "$with_disable" -gt 0 ]
	[ "$((with_disable * 100 / total))" -ge 80 ]
}

@test "rules-core: all rule files are valid bash syntax" {
	for rule_file in "$COMMAND_SAFETY_DIR/rules/"*.sh; do
		run bash -n "$rule_file"
		[ "$status" -eq 0 ]
	done
}
