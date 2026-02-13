#!/usr/bin/env bats
# =============================================================================
# GHA SECURITY SCANNER TESTS
# =============================================================================
# Tests for lib/bin/gha-scan and GHA validators.
# Covers:
#   - Tool checking utilities
#   - Workflow finding utilities
#   - Config finding utilities
#   - Console reporter functions
#   - Core scanner orchestration
# =============================================================================

load ../../test_helpers

setup() {
	setup_test_env

	local repo_root
	repo_root="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
	export SHELL_CONFIG_DIR="$repo_root"
	export GHA_SCAN_BIN="$SHELL_CONFIG_DIR/lib/bin/gha-scan"
	export GHA_VALIDATORS_DIR="$SHELL_CONFIG_DIR/lib/validation/validators/gha"
	export SHELL_CONFIG_LIB="$SHELL_CONFIG_DIR/lib"

	# Reset environment variables
	export GHA_SCAN_VERBOSE=0
	export GHA_SCAN_MODIFIED_ONLY=0
	export GHA_SCAN_MODE="default"
	export GHA_SCAN_OUTPUT="cli"

	# Create mock GitHub workflows directory
	mkdir -p "$TEST_REPO_DIR/.github/workflows"
}

_source_gha_scan() {
	# shellcheck source=../../../lib/bin/gha-scan
	source "$GHA_SCAN_BIN"
}

teardown() {
	cleanup_test_env
}

# =============================================================================
# FILE EXISTENCE TESTS
# =============================================================================

@test "gha-scan binary exists" {
	[ -f "$GHA_SCAN_BIN" ]
}

@test "actionlint-validator.sh exists" {
	[ -f "$GHA_VALIDATORS_DIR/actionlint-validator.sh" ]
}

@test "zizmor-validator.sh exists" {
	[ -f "$GHA_VALIDATORS_DIR/zizmor-validator.sh" ]
}

@test "poutine-validator.sh exists" {
	[ -f "$GHA_VALIDATORS_DIR/poutine-validator.sh" ]
}

@test "octoscan-validator.sh exists" {
	[ -f "$GHA_VALIDATORS_DIR/octoscan-validator.sh" ]
}

# =============================================================================
# TOOL CHECKER TESTS
# =============================================================================

@test "gha-scan sources without error" {
	run bash -c "SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR' source '$GHA_SCAN_BIN'"
	[ "$status" -eq 0 ]
}

@test "_gha_check_tool returns 0 for existing command" {
	_source_gha_scan
	run _gha_check_tool "bash"
	[ "$status" -eq 0 ]
}

@test "_gha_check_tool returns 1 for non-existent command" {
	_source_gha_scan
	run _gha_check_tool "nonexistent_command_xyz_123"
	[ "$status" -eq 1 ]
}

@test "_gha_get_tool_path returns path for existing command" {
	_source_gha_scan
	run _gha_get_tool_path "bash"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
	[[ "$output" == *"bash"* ]]
}

@test "_gha_get_tool_path returns empty for non-existent command" {
	_source_gha_scan
	run _gha_get_tool_path "nonexistent_command_xyz_123"
	[ -z "$output" ]
}

@test "_gha_extract_version extracts semver correctly" {
	_source_gha_scan
	run _gha_extract_version "actionlint version 1.6.27"
	[ "$status" -eq 0 ]
	[ "$output" == "1.6.27" ]
}

@test "_gha_extract_version returns first match for multiple versions" {
	_source_gha_scan
	run _gha_extract_version "tool 1.2.3 requires lib 4.5.6"
	[ "$output" == "1.2.3" ]
}

# =============================================================================
# WORKFLOW FINDER TESTS
# =============================================================================

@test "_gha_find_repo_root finds git root" {
	_source_gha_scan
	cd "$TEST_REPO_DIR" || return 1

	run _gha_find_repo_root "$(pwd)"
	[ "$status" -eq 0 ]
	[ "$output" == "$TEST_REPO_DIR" ]
}

@test "_gha_find_repo_root returns input for non-git directory" {
	_source_gha_scan
	local non_git_dir="$TEST_TEMP_DIR/non-git"
	mkdir -p "$non_git_dir"

	run _gha_find_repo_root "$non_git_dir"
	[ "$status" -eq 0 ]
	[ "$output" == "$non_git_dir" ]
}

@test "_gha_get_workflow_dir returns workflows path when exists" {
	_source_gha_scan

	run _gha_get_workflow_dir "$TEST_REPO_DIR"
	[ "$status" -eq 0 ]
	[ "$output" == "$TEST_REPO_DIR/.github/workflows" ]
}

@test "_gha_get_workflow_dir returns empty when no workflows" {
	_source_gha_scan
	local no_workflows_dir="$TEST_TEMP_DIR/no-workflows"
	mkdir -p "$no_workflows_dir"

	run _gha_get_workflow_dir "$no_workflows_dir"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

# =============================================================================
# CONFIG FINDER TESTS
# =============================================================================

@test "_gha_find_config returns repo-local config when exists" {
	_source_gha_scan
	echo "test config" >"$TEST_REPO_DIR/.actionlint.yaml"

	run _gha_find_config ".actionlint.yaml" "$TEST_REPO_DIR"
	[ "$status" -eq 0 ]
	[ "$output" == "$TEST_REPO_DIR/.actionlint.yaml" ]
}

@test "_gha_find_config returns empty when no config exists" {
	_source_gha_scan
	run _gha_find_config "nonexistent.yaml" "$TEST_REPO_DIR"
	[ -z "$output" ]
}

@test "_gha_find_config prefers global over local" {
	_source_gha_scan

	# Create global config (uses SHELL_CONFIG_DIR/lib path)
	mkdir -p "$SHELL_CONFIG_DIR/lib/validation/validators/gha/config"
	echo "global" >"$SHELL_CONFIG_DIR/lib/validation/validators/gha/config/test-gha-config.yaml"

	# Create local config
	echo "local" >"$TEST_REPO_DIR/test-gha-config.yaml"

	run _gha_find_config "test-gha-config.yaml" "$TEST_REPO_DIR"
	[[ "$output" == *"global"* ]] || [[ "$output" == *"validation/validators/gha/config"* ]]

	# Cleanup
	rm -f "$SHELL_CONFIG_DIR/lib/validation/validators/gha/config/test-gha-config.yaml"
}

# =============================================================================
# REPORTER TESTS
# =============================================================================

@test "reporter functions execute" {
	_source_gha_scan
	run _gha_log_header "Test"
	[ "$status" -eq 0 ]
	run _gha_log_scanner "*" "scanner" "1.0.0"
	[ "$status" -eq 0 ]
}

# =============================================================================
# CORE SCANNER TESTS
# =============================================================================

@test "gha_scan --help returns 0" {
	run bash -c "SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR' source '$GHA_SCAN_BIN' && gha_scan --help"
	[ "$status" -eq 0 ]
}

@test "gha_scan errors on unknown option" {
	run bash -c "SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR' source '$GHA_SCAN_BIN' && gha_scan --nope" 2>/dev/null
	[ "$status" -ne 0 ]
}
