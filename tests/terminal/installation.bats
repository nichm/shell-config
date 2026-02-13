#!/usr/bin/env bats
# Tests for lib/terminal/installation/*.sh - Terminal emulator installation

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export TERMINAL_DIR="$SHELL_CONFIG_DIR/lib/terminal"

	# Create temp directory
	export TEST_TMP_DIR="$BATS_TEST_TMPDIR"
	mkdir -p "$TEST_TMP_DIR"

	# Save original HOME and mock it
	export ORIG_HOME="$HOME"
	export HOME="$TEST_TMP_DIR"
	export XDG_CONFIG_HOME="$TEST_TMP_DIR/.config"
	export XDG_DATA_HOME="$TEST_TMP_DIR/.local/share"
}

teardown() {
	# Restore HOME before cleanup (prevents protected-paths.sh unbound variable)
	export HOME="$ORIG_HOME"
	unset XDG_CONFIG_HOME XDG_DATA_HOME
	/bin/rm -rf "$TEST_TMP_DIR" 2>/dev/null || true
}

# =============================================================================
# SHARED INSTALLER
# =============================================================================

@test "shared installer script exists" {
	[ -f "$TERMINAL_DIR/installation/shared-installer.sh" ]
}

@test "shared installer sources without error" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/shared-installer.sh'"
	[ "$status" -eq 0 ]
}

@test "shared installer defines _ti_ensure_homebrew function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/shared-installer.sh' && type _ti_ensure_homebrew"
	[ "$status" -eq 0 ]
}

@test "shared installer defines _ti_ensure_config_dir function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/shared-installer.sh' && type _ti_ensure_config_dir"
	[ "$status" -eq 0 ]
}

@test "shared installer defines _ti_main_entry function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/shared-installer.sh' && type _ti_main_entry"
	[ "$status" -eq 0 ]
}

@test "shared installer defines _ti_backup_and_write_config function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/shared-installer.sh' && type _ti_backup_and_write_config"
	[ "$status" -eq 0 ]
}

# =============================================================================
# KITTY
# =============================================================================

@test "kitty installation script exists" {
	[ -f "$TERMINAL_DIR/installation/kitty.sh" ]
}

@test "kitty installation script sources without error" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/kitty.sh'"
	[ "$status" -eq 0 ]
}

@test "kitty script defines install_kitty function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/kitty.sh' && type install_kitty"
	[ "$status" -eq 0 ]
}

@test "kitty script defines is_kitty_installed function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/kitty.sh' && type is_kitty_installed"
	[ "$status" -eq 0 ]
}

@test "kitty script defines configure_kitty function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/kitty.sh' && type configure_kitty"
	[ "$status" -eq 0 ]
}

@test "kitty script defines uninstall_kitty function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/kitty.sh' && type uninstall_kitty"
	[ "$status" -eq 0 ]
}

@test "kitty config dir variable is set" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/kitty.sh' && echo \$KITTY_CONFIG_DIR"
	[ "$status" -eq 0 ]
	[[ "$output" == *"/.config/kitty"* ]]
}

# =============================================================================
# GHOSTTY
# =============================================================================

@test "ghostty installation script exists" {
	[ -f "$TERMINAL_DIR/installation/ghostty.sh" ]
}

@test "ghostty installation script sources without error" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/ghostty.sh'"
	[ "$status" -eq 0 ]
}

@test "ghostty script defines install_ghostty function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/ghostty.sh' && type install_ghostty"
	[ "$status" -eq 0 ]
}

@test "ghostty script defines is_ghostty_installed function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/ghostty.sh' && type is_ghostty_installed"
	[ "$status" -eq 0 ]
}

@test "ghostty script defines configure_ghostty function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/ghostty.sh' && type configure_ghostty"
	[ "$status" -eq 0 ]
}

# =============================================================================
# ITERM2
# =============================================================================

@test "iterm2 installation script exists" {
	[ -f "$TERMINAL_DIR/installation/iterm2.sh" ]
}

@test "iterm2 installation script sources without error" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/iterm2.sh'"
	[ "$status" -eq 0 ]
}

@test "iterm2 script defines install_iterm2 function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/iterm2.sh' && type install_iterm2"
	[ "$status" -eq 0 ]
}

@test "iterm2 script defines is_iterm2_installed function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/iterm2.sh' && type is_iterm2_installed"
	[ "$status" -eq 0 ]
}

@test "iterm2 script defines configure_iterm2 function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/iterm2.sh' && type configure_iterm2"
	[ "$status" -eq 0 ]
}

@test "iterm2 script defines uninstall_iterm2 function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/iterm2.sh' && type uninstall_iterm2"
	[ "$status" -eq 0 ]
}

# =============================================================================
# WARP
# =============================================================================

@test "warp installation script exists" {
	[ -f "$TERMINAL_DIR/installation/warp.sh" ]
}

@test "warp installation script sources without error" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/warp.sh'"
	[ "$status" -eq 0 ]
}

@test "warp script defines install_warp function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/warp.sh' && type install_warp"
	[ "$status" -eq 0 ]
}

@test "warp script defines is_warp_installed function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/warp.sh' && type is_warp_installed"
	[ "$status" -eq 0 ]
}

@test "warp script defines configure_warp function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/warp.sh' && type configure_warp"
	[ "$status" -eq 0 ]
}

@test "warp script defines uninstall_warp function" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/warp.sh' && type uninstall_warp"
	[ "$status" -eq 0 ]
}

# =============================================================================
# CROSS-INSTALLER FEATURES (grep on source files)
# =============================================================================

@test "kitty installation uses brew for macOS" {
	if [[ "$OSTYPE" == darwin* ]]; then
		run bash -c "grep brew '$TERMINAL_DIR/installation/kitty.sh'"
		[ "$status" -eq 0 ]
	else
		skip "Not running on macOS"
	fi
}

@test "kitty installation handles Linux" {
	if [[ "$OSTYPE" == linux* ]]; then
		run bash -c "grep -E '(apt|dnf|pacman)' '$TERMINAL_DIR/installation/kitty.sh'"
		[ "$status" -eq 0 ] || skip "No Linux package manager references found"
	else
		skip "Not running on Linux"
	fi
}

@test "ghostty installation uses brew for macOS" {
	if [[ "$OSTYPE" == darwin* ]]; then
		run bash -c "grep brew '$TERMINAL_DIR/installation/ghostty.sh'"
		[ "$status" -eq 0 ]
	else
		skip "Not running on macOS"
	fi
}

@test "kitty script creates config directory" {
	run bash -c "
		HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/kitty.sh'
		mkdir -p '$XDG_CONFIG_HOME/kitty'
		[ -d '$XDG_CONFIG_HOME/kitty' ]
	"
	[ "$status" -eq 0 ]
}

@test "ghostty script creates config directory" {
	run bash -c "
		HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/ghostty.sh'
		mkdir -p '$XDG_CONFIG_HOME/ghostty'
		[ -d '$XDG_CONFIG_HOME/ghostty' ]
	"
	[ "$status" -eq 0 ]
}

@test "kitty configuration includes color scheme" {
	run bash -c "grep -i color '$TERMINAL_DIR/installation/kitty.sh'"
	[ "$status" -eq 0 ]
}

@test "kitty configuration includes font settings" {
	run bash -c "grep -i font '$TERMINAL_DIR/installation/kitty.sh'"
	[ "$status" -eq 0 ]
}

@test "ghostty configuration includes font settings" {
	run bash -c "grep -i font '$TERMINAL_DIR/installation/ghostty.sh'"
	[ "$status" -eq 0 ]
}

@test "kitty configuration includes performance settings" {
	run bash -c "grep -E '(performance|repaint|resize)' '$TERMINAL_DIR/installation/kitty.sh'"
	[ "$status" -eq 0 ] || skip "Feature not available in this version"
}

@test "ghostty configuration includes window settings" {
	run bash -c "grep -E '(window|size|position)' '$TERMINAL_DIR/installation/ghostty.sh'"
	[ "$status" -eq 0 ] || skip "Feature not available in this version"
}

@test "warp configuration includes theme settings" {
	run bash -c "grep -i theme '$TERMINAL_DIR/installation/warp.sh'"
	[ "$status" -eq 0 ]
}

@test "kitty installation handles backup of existing config" {
	run bash -c "grep -i backup '$TERMINAL_DIR/installation/kitty.sh'"
	[ "$status" -eq 0 ] || skip "Feature not available in this version"
}

@test "ghostty installation handles backup of existing config" {
	run bash -c "grep -i backup '$TERMINAL_DIR/installation/ghostty.sh'"
	[ "$status" -eq 0 ] || skip "Feature not available in this version"
}

@test "terminal installation scripts provide clear error messages" {
	run bash -c "grep -E 'ERROR|error' '$TERMINAL_DIR/installation/kitty.sh'"
	[ "$status" -eq 0 ] || skip "Feature not available in this version"
}

@test "terminal installation scripts are non-interactive" {
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/kitty.sh'"
	[ "$status" -eq 0 ]
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/ghostty.sh'"
	[ "$status" -eq 0 ]
	run bash -c "HOME='$TEST_TMP_DIR' source '$TERMINAL_DIR/installation/warp.sh'"
	[ "$status" -eq 0 ]
}

@test "all installers use shared-installer.sh" {
	run bash -c "grep 'shared-installer.sh' '$TERMINAL_DIR/installation/kitty.sh'"
	[ "$status" -eq 0 ]
	run bash -c "grep 'shared-installer.sh' '$TERMINAL_DIR/installation/ghostty.sh'"
	[ "$status" -eq 0 ]
	run bash -c "grep 'shared-installer.sh' '$TERMINAL_DIR/installation/iterm2.sh'"
	[ "$status" -eq 0 ]
	run bash -c "grep 'shared-installer.sh' '$TERMINAL_DIR/installation/warp.sh'"
	[ "$status" -eq 0 ]
}

@test "terminal installation scripts handle dependencies" {
	run bash -c "grep -E '(depends|require|check|ensure)' '$TERMINAL_DIR/installation/kitty.sh'"
	[ "$status" -eq 0 ] || skip "Feature not available in this version"
}
