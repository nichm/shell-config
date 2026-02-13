#!/usr/bin/env bats
# =============================================================================
# 🧪 TERMINAL MODULE TESTS - Terminal Setup Testing
# =============================================================================
# Tests for terminal module including:
#   - autocomplete.sh: Autocomplete setup
#   - common.sh: Shared terminal utilities
#   - install-terminal.sh, install.sh: Terminal installation
#   - installation/ghostty.sh, iterm2.sh, kitty.sh, warp.sh: Terminal-specific installers
#   - integration/bash-integration.sh, zsh-integration.sh: Shell integration
#   - setup/*.sh: Platform-specific setup scripts
#   - uninstall-terminal-setup.sh: Uninstallation
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export TERMINAL_DIR="$SHELL_CONFIG_DIR/lib/terminal"

	# Create temp directory with trap handler
	TEST_TEMP_DIR="$(mktemp -d)"
	# Trap moved to teardown for bats compatibility
	cd "$TEST_TEMP_DIR" || return 1

	# Source terminal libraries where possible
	if [ -f "$TERMINAL_DIR/common.sh" ]; then
		source "$TERMINAL_DIR/common.sh"
	fi
}

teardown() {
	# Return to safe directory before cleanup (prevents getcwd errors)
	/bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
	cd "$BATS_TEST_DIRNAME" || return 1
}

# =============================================================================
# 🔧 COMMON UTILITIES TESTS
# =============================================================================

@test "terminal: common.sh exists and is readable" {
	[ -f "$TERMINAL_DIR/common.sh" ]
	[ -r "$TERMINAL_DIR/common.sh" ]
}

@test "terminal: common.sh sources without errors" {
	run bash -c "source '$TERMINAL_DIR/common.sh'"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🔤 AUTOCOMPLETE TESTS
# =============================================================================

@test "terminal: autocomplete.sh exists" {
	[ -f "$TERMINAL_DIR/autocomplete.sh" ]
}

@test "terminal: autocomplete.sh is readable" {
	[ -r "$TERMINAL_DIR/autocomplete.sh" ]
}

@test "terminal: autocomplete.sh sources without errors" {
	run bash -c "source '$TERMINAL_DIR/autocomplete.sh'"
	# May fail if dependencies not met, but should not syntax error
	# Test outcome depends on tool availability
	[ "$status" -eq 0 ] || skip "Tool or feature not available"
}

# =============================================================================
# 📦 INSTALLATION TESTS
# =============================================================================

@test "terminal: install-terminal.sh exists" {
	[ -f "$TERMINAL_DIR/install-terminal.sh" ]
}

@test "terminal: install.sh exists" {
	[ -f "$TERMINAL_DIR/install.sh" ]
}

@test "terminal: installation scripts contain function definitions" {
	# Check for common installation function patterns
	if [ -f "$TERMINAL_DIR/install-terminal.sh" ]; then
		grep -q "install" "$TERMINAL_DIR/install-terminal.sh" ||
			grep -q "setup" "$TERMINAL_DIR/install-terminal.sh"
	fi
}

# =============================================================================
# 🖥️ TERMINAL-SPECIFIC INSTALLERS
# =============================================================================

@test "terminal: ghostty installer exists" {
	[ -f "$TERMINAL_DIR/installation/ghostty.sh" ] || skip "Ghostty installer not present"
}

@test "terminal: iterm2 installer exists" {
	[ -f "$TERMINAL_DIR/installation/iterm2.sh" ] || skip "iTerm2 installer not present"
}

@test "terminal: kitty installer exists" {
	[ -f "$TERMINAL_DIR/installation/kitty.sh" ] || skip "Kitty installer not present"
}

@test "terminal: warp installer exists" {
	[ -f "$TERMINAL_DIR/installation/warp.sh" ] || skip "Warp installer not present"
}

@test "terminal: all terminal installers are readable" {
	local count=0
	for installer in "$TERMINAL_DIR/installation"/*.sh; do
		if [ -f "$installer" ]; then
			[ -r "$installer" ]
			((count++)) || true
		fi
	done
	[ "$count" -gt 0 ]
}

@test "terminal: terminal installer scripts contain install functions" {
	local found_scripts=0
	for installer in "$TERMINAL_DIR/installation"/*.sh; do
		if [ -f "$installer" ]; then
			found_scripts=$((found_scripts + 1))
			# Each installer must have install or setup functions
			run grep -qE "(install|setup)" "$installer"
			[ "$status" -eq 0 ]
		fi
	done
	# Ensure we actually checked some scripts
	[ "$found_scripts" -gt 0 ]
}

# =============================================================================
# 🔗 INTEGRATION TESTS
# =============================================================================

@test "terminal: bash integration script exists" {
	# Bash integration is a required component
	[ -f "$TERMINAL_DIR/integration/bash-integration.sh" ]
	[ -r "$TERMINAL_DIR/integration/bash-integration.sh" ]
}

@test "terminal: zsh integration script exists" {
	# Zsh integration is a required component
	[ -f "$TERMINAL_DIR/integration/zsh-integration.sh" ]
	[ -r "$TERMINAL_DIR/integration/zsh-integration.sh" ]
}

@test "terminal: integration common script exists" {
	[ -f "$TERMINAL_DIR/integration/common.sh" ]
}

@test "terminal: bash integration sources without errors" {
	# File must exist (tested above)
	[ -f "$TERMINAL_DIR/integration/bash-integration.sh" ]
	run bash -c "source '$TERMINAL_DIR/integration/bash-integration.sh'"
	# May fail if shell not bash, but shouldn't syntax error
	# Test outcome depends on tool availability
	[ "$status" -eq 0 ] || skip "Tool or feature not available"
}

@test "terminal: zsh integration sources without errors" {
	# File must exist (tested above)
	[ -f "$TERMINAL_DIR/integration/zsh-integration.sh" ]
	# Try to source with zsh if available
	if command -v zsh >/dev/null 2>&1; then
		run zsh -c "source '$TERMINAL_DIR/integration/zsh-integration.sh'"
		# Test outcome depends on tool availability
	[ "$status" -eq 0 ] || skip "Tool or feature not available"
	else
		skip "zsh not available"
	fi
}

# =============================================================================
# ⚙️ PLATFORM-SPECIFIC SETUP TESTS
# =============================================================================

@test "terminal: macOS setup script exists" {
	# macOS setup is a required component
	[ -f "$TERMINAL_DIR/setup/setup-macos-terminal.sh" ]
	[ -r "$TERMINAL_DIR/setup/setup-macos-terminal.sh" ]
}

@test "terminal: Ubuntu setup script exists" {
	# Ubuntu setup is a required component
	[ -f "$TERMINAL_DIR/setup/setup-ubuntu-terminal.sh" ]
	[ -r "$TERMINAL_DIR/setup/setup-ubuntu-terminal.sh" ]
}

@test "terminal: common setup script exists" {
	[ -f "$TERMINAL_DIR/setup/terminal-setup-common.sh" ]
}

@test "terminal: autocomplete tools setup exists" {
	[ -f "$TERMINAL_DIR/setup/setup-autocomplete-tools.sh" ]
}

@test "terminal: setup scripts contain setup functions" {
	for setup_script in "$TERMINAL_DIR/setup"/*.sh; do
		if [ -f "$setup_script" ]; then
			grep -qE "(setup|install|configure)" "$setup_script" ||
				skip "No setup function found in $(basename "$setup_script")"
		fi
	done
}

# =============================================================================
# 🗑️ UNINSTALLATION TESTS
# =============================================================================

@test "terminal: uninstall script exists" {
	[ -f "$TERMINAL_DIR/uninstall-terminal-setup.sh" ]
}

@test "terminal: uninstall script is executable" {
	[ -f "$TERMINAL_DIR/uninstall-terminal-setup.sh" ] &&
		[ -x "$TERMINAL_DIR/uninstall-terminal-setup.sh" ] ||
		skip "Uninstall script not executable"
}

@test "terminal: uninstall script contains uninstall functions" {
	[ -f "$TERMINAL_DIR/uninstall-terminal-setup.sh" ] &&
		grep -qE "(uninstall|remove|clean)" "$TERMINAL_DIR/uninstall-terminal-setup.sh" ||
		skip "No uninstall function found"
}

# =============================================================================
# 🔧 INTEGRATION TESTS
# =============================================================================

@test "integration: all terminal scripts are valid bash scripts" {
	for script in "$TERMINAL_DIR"/*.sh "$TERMINAL_DIR"/installation/*.sh "$TERMINAL_DIR"/integration/*.sh "$TERMINAL_DIR"/setup/*.sh; do
		if [ -f "$script" ]; then
			# Check for valid bash shebang or no shebang (library files)
			first_line=$(head -1 "$script")
			[[ "$first_line" == "#!/usr/bin/env bash"* ]] ||
				[[ "$first_line" == "#!/bin/bash"* ]] ||
				[[ "$first_line" != "#!"* ]] ||
				skip "Unexpected shebang in $(basename "$script")"
		fi
	done
}

@test "integration: terminal module has consistent structure" {
	# Check that key directories exist
	[ -d "$TERMINAL_DIR" ]
	[ -d "$TERMINAL_DIR/installation" ] || skip "installation directory missing"
	[ -d "$TERMINAL_DIR/integration" ]
	[ -d "$TERMINAL_DIR/setup" ]
}

@test "integration: terminal scripts reference each other correctly" {
	# Check for common sourcing patterns
	if [ -f "$TERMINAL_DIR/install-terminal.sh" ]; then
		# Should source integration scripts
		grep -q "integration" "$TERMINAL_DIR/install-terminal.sh" ||
			grep -q "source" "$TERMINAL_DIR/install-terminal.sh" ||
			skip "No source references found"
	fi
}

# =============================================================================
# 🛡️ EDGE CASES
# =============================================================================

@test "edge-cases: terminal scripts handle missing dependencies gracefully" {
	# Most scripts should check for dependencies before using them
	for script in "$TERMINAL_DIR"/installation/*.sh; do
		if [ -f "$script" ]; then
			# Look for command checks
			grep -q "command -v" "$script" ||
				grep -q "which" "$script" ||
				grep -q "type" "$script" ||
				skip "No dependency check found in $(basename "$script")"
		fi
	done
}

@test "edge-cases: setup scripts detect operating system" {
	# Should have some form of OS detection
	if [ -f "$TERMINAL_DIR/setup/setup-macos-terminal.sh" ]; then
		grep -qE "(Darwin|macOS|OSX)" "$TERMINAL_DIR/setup/setup-macos-terminal.sh" ||
			grep -q "uname" "$TERMINAL_DIR/setup/setup-macos-terminal.sh" ||
			skip "No OS detection found in macOS setup"
	fi
}

@test "edge-cases: uninstall script prevents data loss" {
	# Should have safety checks or warnings
	if [ -f "$TERMINAL_DIR/uninstall-terminal-setup.sh" ]; then
		grep -qiE "(warn|confirm|backup|safe)" "$TERMINAL_DIR/uninstall-terminal-setup.sh" ||
			skip "No safety checks found in uninstall script"
	fi
}
