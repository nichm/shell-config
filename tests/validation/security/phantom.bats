#!/usr/bin/env bats
# =============================================================================
# 🧪 PHANTOM VALIDATOR MODULE TESTS - Supply Chain Security
# =============================================================================
# Tests for phantom-validator.sh - supply chain security validation
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export PHANTOM_VALIDATOR="$SHELL_CONFIG_DIR/lib/validation/validators/security/phantom-validator.sh"
	export VALIDATION_LIB_DIR="$SHELL_CONFIG_DIR/lib/validation"

	# Create temp directory (cleanup in teardown, not EXIT trap which interferes with bats)
	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	# Mock HOME
	export HOME="$TEST_TEMP_DIR/home"
	mkdir -p "$HOME"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

# =============================================================================
# 📁 FILE EXISTENCE TESTS
# =============================================================================

@test "phantom-validator: phantom-validator.sh exists and is readable" {
	[ -f "$PHANTOM_VALIDATOR" ]
	[ -r "$PHANTOM_VALIDATOR" ]
}

@test "phantom-validator: sources without errors" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		export VALIDATION_LIB_DIR='$VALIDATION_LIB_DIR'
		source '$PHANTOM_VALIDATOR'
	"
	[ "$status" -eq 0 ]
}

@test "phantom-validator: has valid bash syntax" {
	run bash -n "$PHANTOM_VALIDATOR"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🔧 FUNCTION DEFINITION TESTS
# =============================================================================

@test "phantom-validator: defines phantom_validator_reset function" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		type phantom_validator_reset
	"
	[ "$status" -eq 0 ]
}

@test "phantom-validator: defines validate_package_security function" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		type validate_package_security
	"
	[ "$status" -eq 0 ]
}

@test "phantom-validator: defines validate_package_json function" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		type validate_package_json
	"
	[ "$status" -eq 0 ]
}

@test "phantom-validator: defines validate_requirements_txt function" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		type validate_requirements_txt
	"
	[ "$status" -eq 0 ]
}

@test "phantom-validator: defines phantom_validator_has_violations function" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		type phantom_validator_has_violations
	"
	[ "$status" -eq 0 ]
}

@test "phantom-validator: defines phantom_validator_show_violations function" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		type phantom_validator_show_violations
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🛡️ FUNCTIONALITY TESTS
# =============================================================================

@test "phantom-validator: phantom_guard_available checks for phantom-guard" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		phantom_guard_available && echo 'installed' || echo 'not installed'
	"
	[ "$status" -eq 0 ]
	# Output should be either 'installed' or 'not installed'
	[[ "$output" == "installed" ]] || [[ "$output" == "not installed" ]]
}

@test "phantom-validator: reset clears violations" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		phantom_validator_reset
		phantom_validator_has_violations && echo 'has violations' || echo 'no violations'
	"
	[ "$status" -eq 0 ]
	[ "$output" = "no violations" ]
}

@test "phantom-validator: handles missing package.json gracefully" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		validate_package_json '/nonexistent/package.json'
	"
	[ "$status" -eq 0 ]
}

@test "phantom-validator: handles missing requirements.txt gracefully" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		validate_requirements_txt '/nonexistent/requirements.txt'
	"
	[ "$status" -eq 0 ]
}

@test "phantom-validator: handles missing directory gracefully" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		validate_package_files_in_dir '/nonexistent/directory'
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 📋 STRUCTURE TESTS
# =============================================================================

@test "phantom-validator: has double-sourcing guard" {
	grep -q "_PHANTOM_VALIDATOR_LOADED" "$PHANTOM_VALIDATOR"
}

@test "phantom-validator: sources shared reporters" {
	grep -q "reporters.sh" "$PHANTOM_VALIDATOR"
}

@test "phantom-validator: config file location is configurable" {
	grep -q "PHANTOM_CONFIG_FILE" "$PHANTOM_VALIDATOR"
}

# =============================================================================
# 🔧 INTEGRATION TESTS
# =============================================================================

@test "integration: can be sourced multiple times" {
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		source '$PHANTOM_VALIDATOR'
		echo 'success'
	"
	[ "$status" -eq 0 ]
	[ "$output" = "success" ]
}

@test "integration: works with empty project directory" {
	mkdir -p "$TEST_TEMP_DIR/empty-project"
	# validate_package_files_in_dir returns non-zero for empty dirs (no package files)
	# Use || true to prevent set -e from exiting the subshell
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		validate_package_files_in_dir '$TEST_TEMP_DIR/empty-project' 2>/dev/null || true
		echo 'completed'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"completed"* ]]
}

@test "integration: processes package.json when present" {
	mkdir -p "$TEST_TEMP_DIR/test-project"
	echo '{"name": "test", "dependencies": {}}' > "$TEST_TEMP_DIR/test-project/package.json"
	
	run bash -c "
		export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
		source '$PHANTOM_VALIDATOR'
		validate_package_json '$TEST_TEMP_DIR/test-project/package.json'
	"
	# Should succeed (phantom-guard may not be installed)
	[ "$status" -eq 0 ]
}
