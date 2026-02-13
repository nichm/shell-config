#!/usr/bin/env bats
# =============================================================================
# 🧪 WELCOME MAIN MODULE TESTS
# =============================================================================
# Tests for lib/welcome/main.sh - Core welcome message functionality
# =============================================================================

load ../test_helpers

setup() {
	# MUST set these before ANYTHING else to prevent welcome from running
	export WELCOME_MESSAGE_AUTORUN="false"
	export WELCOME_MESSAGE_ENABLED="false"

	setup_test_env

	local repo_root
	repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
	export SHELL_CONFIG_DIR="$repo_root"
	export WELCOME_DIR="$SHELL_CONFIG_DIR/lib/welcome"

	# Initialize colors needed by welcome modules
	export _WM_COLOR_RESET=$'\033[0m'
	export _WM_COLOR_BOLD=$'\033[1m'
	export _WM_COLOR_DIM=$'\033[2m'
	export _WM_COLOR_GREEN=$'\033[0;32m'
	export _WM_COLOR_RED=$'\033[0;31m'
	export _WM_COLOR_YELLOW=$'\033[0;33m'
	export _WM_COLOR_CYAN=$'\033[0;36m'
	export _WM_COLOR_GRAY=$'\033[0;90m'

	# Reset other welcome configuration
	export WELCOME_AUTOCOMPLETE_GUIDE="true"
	export WELCOME_SHORTCUTS="true"

	# Unset session tracking
	unset WELCOME_MESSAGE_SHOWN
}

teardown() {
	cleanup_test_env
}

# =============================================================================
# 📁 FILE EXISTENCE TESTS
# =============================================================================

@test "welcome main.sh exists" {
	[ -f "$WELCOME_DIR/main.sh" ]
}

@test "shortcuts.sh exists" {
	[ -f "$WELCOME_DIR/shortcuts.sh" ]
}

@test "shell-startup-time.sh exists" {
	[ -f "$WELCOME_DIR/shell-startup-time.sh" ]
}

@test "terminal-status.sh exists" {
	[ -f "$WELCOME_DIR/terminal-status.sh" ]
}

@test "git-hooks-status.sh exists" {
	[ -f "$WELCOME_DIR/git-hooks-status.sh" ]
}

@test "autocomplete-guide.sh exists" {
	[ -f "$WELCOME_DIR/autocomplete-guide.sh" ]
}

# =============================================================================
# 🔧 CONFIGURATION TESTS
# =============================================================================

@test "WELCOME_MESSAGE_ENABLED defaults to true" {
	# Unset all and check default behavior
	unset WELCOME_MESSAGE_ENABLED
	source "$WELCOME_DIR/main.sh"
	[ "$WELCOME_MESSAGE_ENABLED" == "true" ]
}

@test "WELCOME_AUTOCOMPLETE_GUIDE defaults to true" {
	unset WELCOME_AUTOCOMPLETE_GUIDE
	source "$WELCOME_DIR/main.sh"
	[ "$WELCOME_AUTOCOMPLETE_GUIDE" == "true" ]
}

@test "WELCOME_SHORTCUTS defaults to true" {
	unset WELCOME_SHORTCUTS
	source "$WELCOME_DIR/main.sh"
	[ "$WELCOME_SHORTCUTS" == "true" ]
}

@test "welcome_message_enabled respects false setting" {
	export WELCOME_MESSAGE_ENABLED="false"
	source "$WELCOME_DIR/main.sh"

	run welcome_message
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "welcome_message_enabled respects true setting" {
	export WELCOME_MESSAGE_ENABLED="true"
	source "$WELCOME_DIR/main.sh"

	run welcome_message
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

@test "welcome_message skips when already shown in session" {
	export WELCOME_MESSAGE_ENABLED="true"
	export WELCOME_MESSAGE_SHOWN="true"
	source "$WELCOME_DIR/main.sh"

	run welcome_message
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "welcome_message sets WELCOME_MESSAGE_SHOWN after display" {
	export WELCOME_MESSAGE_ENABLED="true"
	unset WELCOME_MESSAGE_SHOWN
	source "$WELCOME_DIR/main.sh"

	welcome_message >/dev/null 2>&1
	[ "$WELCOME_MESSAGE_SHOWN" == "true" ]
}

# =============================================================================
# 📦 HELPER FUNCTION TESTS
# =============================================================================

@test "_welcome_get_datetime returns formatted date" {
	source "$WELCOME_DIR/main.sh"

	run _welcome_get_datetime
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

@test "_welcome_get_datetime accepts custom format" {
	source "$WELCOME_DIR/main.sh"

	run _welcome_get_datetime "%Y-%m-%d"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
	# Should match YYYY-MM-DD pattern
	[[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}

@test "_welcome_terminal_supports_links returns status" {
	source "$WELCOME_DIR/main.sh"

	# Should return 0 or 1, not error
	run _welcome_terminal_supports_links
	[[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "_welcome_print_link outputs text" {
	source "$WELCOME_DIR/main.sh"

	run _welcome_print_link "/path/to/file" "link text"
	[ "$status" -eq 0 ]
	[[ "$output" == *"link text"* ]]
}

# =============================================================================
# 🎨 OUTPUT TESTS
# =============================================================================

@test "welcome_message shows greeting" {
	export WELCOME_MESSAGE_ENABLED="true"
	source "$WELCOME_DIR/main.sh"

	run welcome_message
	[ "$status" -eq 0 ]
	[[ "$output" == *"Hey"* ]]
}

@test "welcome_message shows date/time" {
	export WELCOME_MESSAGE_ENABLED="true"
	source "$WELCOME_DIR/main.sh"

	run welcome_message
	[ "$status" -eq 0 ]
	# Should contain day of week
	[[ "$output" == *"day"* ]] || [[ "$output" == *"Monday"* ]] || [[ "$output" == *"Tuesday"* ]] || [[ "$output" == *"Wednesday"* ]] || [[ "$output" == *"Thursday"* ]] || [[ "$output" == *"Friday"* ]] || [[ "$output" == *"Saturday"* ]] || [[ "$output" == *"Sunday"* ]]
}

# =============================================================================
# 🎨 CLAUDE.md COMPLIANCE TESTS (Regression Prevention)
# =============================================================================

@test "COMPLIANCE: main.sh sources shared colors library" {
	# Verify main.sh sources core/colors.sh instead of defining inline colors
	run grep -E "source.*core/colors\.sh" "$WELCOME_DIR/main.sh"
	[ "$status" -eq 0 ]
	[[ "$output" == *"core/colors.sh"* ]]
}

@test "COMPLIANCE: main.sh does NOT define inline color escape codes" {
	# Should NOT have inline color definitions like $'\033[0m'
	# The colors should come from sourced library, not inline
	run grep -q "\\$'\\\\033\[" "$WELCOME_DIR/main.sh"
	# grep -q should exit with 1 (not found), indicating success
	[ "$status" -eq 1 ]
}

@test "COMPLIANCE: welcome_message shows Terminal section" {
	export WELCOME_MESSAGE_ENABLED="true"
	source "$WELCOME_DIR/main.sh"

	run welcome_message
	[ "$status" -eq 0 ]
	# Terminal status grid replaces the old Features Loaded section
	[[ "$output" == *"Terminal"* ]]
}

@test "COMPLIANCE: colors are mapped from shared library" {
	source "$WELCOME_DIR/main.sh"

	# After sourcing, the _WM_COLOR_* variables should be set
	[ -n "$_WM_COLOR_RESET" ]
	[ -n "$_WM_COLOR_BOLD" ]
	[ -n "$_WM_COLOR_GREEN" ]
	[ -n "$_WM_COLOR_RED" ]
}

@test "COMPLIANCE: shared colors library guard is set after sourcing" {
	source "$WELCOME_DIR/main.sh"

	# The colors.sh guard should be set
	[ -n "${_SHELL_CONFIG_CORE_COLORS_LOADED:-}" ]
}
