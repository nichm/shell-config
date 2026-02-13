#!/usr/bin/env bats
# =============================================================================
# Tests for lib/validation/shared/workflow-scanners.sh
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export SCANNERS_LIB="$SHELL_CONFIG_DIR/lib/validation/shared/workflow-scanners.sh"
	export COMMAND_CACHE_LIB="$SHELL_CONFIG_DIR/lib/core/command-cache.sh"
	export TEST_TMP="$BATS_TEST_TMPDIR/scanners-test"
	mkdir -p "$TEST_TMP"
}

teardown() {
	/bin/rm -rf "$TEST_TMP" 2>/dev/null || true
}

# =============================================================================
# LIBRARY LOADING
# =============================================================================

@test "workflow-scanners library exists" {
	[ -f "$SCANNERS_LIB" ]
}

@test "workflow-scanners sources without error" {
	run bash -c "source '$COMMAND_CACHE_LIB' 2>/dev/null; source '$SCANNERS_LIB'"
	[ "$status" -eq 0 ]
}

@test "workflow-scanners has source guard" {
	run bash -c "
		source '$COMMAND_CACHE_LIB' 2>/dev/null
		source '$SCANNERS_LIB'
		source '$SCANNERS_LIB'
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# FUNCTION DEFINITIONS
# =============================================================================

@test "_wf_check_tool function is defined" {
	run bash -c "source '$COMMAND_CACHE_LIB' 2>/dev/null; source '$SCANNERS_LIB' && type _wf_check_tool"
	[ "$status" -eq 0 ]
}

@test "_wf_get_tool_path function is defined" {
	run bash -c "source '$COMMAND_CACHE_LIB' 2>/dev/null; source '$SCANNERS_LIB' && type _wf_get_tool_path"
	[ "$status" -eq 0 ]
}

@test "_wf_get_version function is defined" {
	run bash -c "source '$COMMAND_CACHE_LIB' 2>/dev/null; source '$SCANNERS_LIB' && type _wf_get_version"
	[ "$status" -eq 0 ]
}

@test "_wf_find_config function is defined" {
	run bash -c "source '$COMMAND_CACHE_LIB' 2>/dev/null; source '$SCANNERS_LIB' && type _wf_find_config"
	[ "$status" -eq 0 ]
}

@test "_wf_run_actionlint function is defined" {
	run bash -c "source '$COMMAND_CACHE_LIB' 2>/dev/null; source '$SCANNERS_LIB' && type _wf_run_actionlint"
	[ "$status" -eq 0 ]
}

@test "_wf_run_zizmor function is defined" {
	run bash -c "source '$COMMAND_CACHE_LIB' 2>/dev/null; source '$SCANNERS_LIB' && type _wf_run_zizmor"
	[ "$status" -eq 0 ]
}

# =============================================================================
# TOOL DETECTION
# =============================================================================

@test "_wf_check_tool returns 0 for bash" {
	run bash -c "source '$COMMAND_CACHE_LIB' 2>/dev/null; source '$SCANNERS_LIB' && _wf_check_tool 'bash'"
	[ "$status" -eq 0 ]
}

@test "_wf_check_tool returns 1 for nonexistent tool" {
	run bash -c "source '$COMMAND_CACHE_LIB' 2>/dev/null; source '$SCANNERS_LIB' && _wf_check_tool 'nonexistent-tool-xyz'"
	[ "$status" -eq 1 ]
}

@test "_wf_check_tool finds tools in HOME/.local/bin" {
	mkdir -p "$TEST_TMP/local-bin"
	touch "$TEST_TMP/local-bin/fake-tool"
	chmod +x "$TEST_TMP/local-bin/fake-tool"

	run bash -c "
		export HOME='$TEST_TMP'
		mkdir -p '$TEST_TMP/.local/bin'
		cp '$TEST_TMP/local-bin/fake-tool' '$TEST_TMP/.local/bin/fake-tool'
		source '$COMMAND_CACHE_LIB' 2>/dev/null
		source '$SCANNERS_LIB'
		_wf_check_tool 'fake-tool'
	"
	[ "$status" -eq 0 ]
}

@test "_wf_get_tool_path returns path for existing tool" {
	run bash -c "source '$COMMAND_CACHE_LIB' 2>/dev/null; source '$SCANNERS_LIB' && _wf_get_tool_path 'bash'"
	[ "$status" -eq 0 ]
	[[ -n "$output" ]]
}

@test "_wf_get_tool_path returns empty for nonexistent tool" {
	run bash -c "source '$COMMAND_CACHE_LIB' 2>/dev/null; source '$SCANNERS_LIB' && _wf_get_tool_path 'nonexistent-tool-xyz'"
	[ "$status" -eq 0 ]
	[[ -z "$output" ]]
}

@test "_wf_get_version returns not installed for missing tool" {
	run bash -c "source '$COMMAND_CACHE_LIB' 2>/dev/null; source '$SCANNERS_LIB' && _wf_get_version 'nonexistent-tool-xyz'"
	[ "$status" -eq 0 ]
	[[ "$output" == "not installed" ]]
}

# =============================================================================
# CONFIG DISCOVERY
# =============================================================================

@test "_wf_find_config finds .github config" {
	mkdir -p "$TEST_TMP/repo/.github"
	touch "$TEST_TMP/repo/.github/actionlint.yaml"

	run bash -c "
		source '$COMMAND_CACHE_LIB' 2>/dev/null
		source '$SCANNERS_LIB'
		_wf_find_config 'actionlint.yaml' '$TEST_TMP/repo'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *".github/actionlint.yaml"* ]]
}

@test "_wf_find_config finds root-level config" {
	mkdir -p "$TEST_TMP/repo"
	touch "$TEST_TMP/repo/actionlint.yaml"

	run bash -c "
		source '$COMMAND_CACHE_LIB' 2>/dev/null
		source '$SCANNERS_LIB'
		_wf_find_config 'actionlint.yaml' '$TEST_TMP/repo'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"repo/actionlint.yaml"* ]]
}

@test "_wf_find_config prefers .github over root" {
	mkdir -p "$TEST_TMP/repo/.github"
	touch "$TEST_TMP/repo/.github/actionlint.yaml"
	touch "$TEST_TMP/repo/actionlint.yaml"

	run bash -c "
		source '$COMMAND_CACHE_LIB' 2>/dev/null
		source '$SCANNERS_LIB'
		_wf_find_config 'actionlint.yaml' '$TEST_TMP/repo'
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *".github/actionlint.yaml"* ]]
}

@test "_wf_find_config returns empty for missing config" {
	mkdir -p "$TEST_TMP/repo"

	run bash -c "
		source '$COMMAND_CACHE_LIB' 2>/dev/null
		source '$SCANNERS_LIB'
		_wf_find_config 'nonexistent.yaml' '$TEST_TMP/repo'
	"
	[ "$status" -eq 0 ]
	[[ -z "$output" ]]
}

@test "_wf_find_config checks shell-config defaults for zizmor" {
	# Create a fake shell-config default
	local zizmor_dir="$SHELL_CONFIG_DIR/lib/validation/validators/gha/config"
	if [[ -f "$zizmor_dir/.zizmor.yml" ]]; then
		run bash -c "
			source '$COMMAND_CACHE_LIB' 2>/dev/null
			source '$SCANNERS_LIB'
			_wf_find_config '.zizmor.yml' '$TEST_TMP/repo'
		"
		[ "$status" -eq 0 ]
		[[ "$output" == *".zizmor.yml"* ]]
	else
		skip "No default zizmor config in shell-config"
	fi
}

# =============================================================================
# ACTIONLINT SCANNER
# =============================================================================

@test "_wf_run_actionlint returns 2 when actionlint not installed" {
	run bash -c "
		export PATH='$TEST_TMP/empty-bin'
		mkdir -p '$TEST_TMP/empty-bin'
		export HOME='$TEST_TMP'
		source '$COMMAND_CACHE_LIB' 2>/dev/null
		source '$SCANNERS_LIB'
		_wf_run_actionlint '/dev/null'
	"
	[ "$status" -eq 2 ]
	[[ "$output" == *"actionlint not installed"* ]]
}

# =============================================================================
# ZIZMOR SCANNER
# =============================================================================

@test "_wf_run_zizmor returns 2 when zizmor not installed" {
	run bash -c "
		export PATH='$TEST_TMP/empty-bin'
		mkdir -p '$TEST_TMP/empty-bin'
		export HOME='$TEST_TMP'
		source '$COMMAND_CACHE_LIB' 2>/dev/null
		source '$SCANNERS_LIB'
		_wf_run_zizmor '/dev/null'
	"
	[ "$status" -eq 2 ]
	[[ "$output" == *"zizmor not installed"* ]]
}
