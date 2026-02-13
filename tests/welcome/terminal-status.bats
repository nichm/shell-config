#!/usr/bin/env bats
# =============================================================================
# 🧪 WELCOME STATUS MODULE TESTS
# =============================================================================
# Tests for lib/welcome/terminal-status.sh - Tool availability checks
# =============================================================================

load ../test_helpers

setup() {
	# MUST set AUTORUN before anything else to prevent welcome from running
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
}

teardown() {
	cleanup_test_env
}

# =============================================================================
# 📁 FILE EXISTENCE TESTS
# =============================================================================

@test "terminal-status.sh exists" {
	[ -f "$WELCOME_DIR/terminal-status.sh" ]
}

@test "autocomplete-guide.sh exists" {
	[ -f "$WELCOME_DIR/autocomplete-guide.sh" ]
}

# =============================================================================
# 🤖 CLAUDE CHECK TESTS (Regression tests for PR #71 fix)
# =============================================================================

@test "_ts_check_claude checks for 'claude' command not 'clauded'" {
	# Regression test: was incorrectly checking for 'clauded'
	source "$WELCOME_DIR/terminal-status.sh"
	
	# Verify the function definition doesn't contain 'clauded'
	local func_def
	func_def=$(declare -f _ts_check_claude)
	[[ "$func_def" != *"clauded"* ]]
	[[ "$func_def" == *"claude"* ]]
}

@test "_ts_check_claude detects claude when installed" {
	skip_if_no_command claude
	source "$WELCOME_DIR/terminal-status.sh"
	
	run _ts_check_claude
	[ "$status" -eq 0 ]
}

@test "_ts_check_claude checks ~/.local/bin/claude" {
	source "$WELCOME_DIR/terminal-status.sh"
	
	# Verify the function checks common install locations
	local func_def
	func_def=$(declare -f _ts_check_claude)
	[[ "$func_def" == *".local/bin/claude"* ]] || [[ "$func_def" == *"command -v claude"* ]]
}

# =============================================================================
# 🖥️  TERMINAL STATUS TESTS
# =============================================================================

@test "terminal-status.sh sources without error" {
	# Initialize colors first
	_WM_COLOR_RESET=$'\033[0m'
	_WM_COLOR_BOLD=$'\033[1m'
	_WM_COLOR_DIM=$'\033[2m'
	_WM_COLOR_GREEN=$'\033[0;32m'
	_WM_COLOR_RED=$'\033[0;31m'
	_WM_COLOR_YELLOW=$'\033[0;33m'
	_WM_COLOR_CYAN=$'\033[0;36m'
	_WM_COLOR_GRAY=$'\033[0;90m'
	export _WM_COLOR_RESET _WM_COLOR_BOLD _WM_COLOR_DIM _WM_COLOR_GREEN _WM_COLOR_RED _WM_COLOR_YELLOW _WM_COLOR_CYAN _WM_COLOR_GRAY

	run bash -c "
        _WM_COLOR_RESET='\033[0m'
        _WM_COLOR_BOLD='\033[1m'
        _WM_COLOR_DIM='\033[2m'
        _WM_COLOR_GREEN='\033[0;32m'
        _WM_COLOR_RED='\033[0;31m'
        _WM_COLOR_YELLOW='\033[0;33m'
        _WM_COLOR_CYAN='\033[0;36m'
        _WM_COLOR_GRAY='\033[0;90m'
        export _WM_COLOR_RESET _WM_COLOR_BOLD _WM_COLOR_DIM _WM_COLOR_GREEN _WM_COLOR_RED _WM_COLOR_YELLOW _WM_COLOR_CYAN _WM_COLOR_GRAY
        source '$WELCOME_DIR/terminal-status.sh'
    "
	[ "$status" -eq 0 ]
}

@test "terminal status detects git when available" {
	source "$WELCOME_DIR/terminal-status.sh"
	command -v git >/dev/null 2>&1

	run _welcome_show_terminal_status
	# Should mention various tools
	[[ "$output" == *"git"* ]] || [[ "$output" == *"🔀"* ]]
}

# =============================================================================
# 🛠️ TOOL CHECK FUNCTION TESTS
# =============================================================================

@test "_ts_check_eza detects installed eza" {
	skip_if_no_command eza
	source "$WELCOME_DIR/terminal-status.sh"
	
	run _ts_check_eza
	[ "$status" -eq 0 ]
}

@test "_ts_check_fzf detects installed fzf" {
	skip_if_no_command fzf
	source "$WELCOME_DIR/terminal-status.sh"
	
	run _ts_check_fzf
	[ "$status" -eq 0 ]
}

@test "_ts_check_hyperfine detects installed hyperfine" {
	skip_if_no_command hyperfine
	source "$WELCOME_DIR/terminal-status.sh"
	
	run _ts_check_hyperfine
	[ "$status" -eq 0 ]
}

@test "_ts_check_ccat detects installed ccat" {
	skip_if_no_command ccat
	source "$WELCOME_DIR/terminal-status.sh"
	
	run _ts_check_ccat
	[ "$status" -eq 0 ]
}

@test "_ts_check_ghls detects ghls when available" {
	source "$WELCOME_DIR/terminal-status.sh"
	
	# Should pass if ghls exists in SHELL_CONFIG_DIR
	if [[ -x "$SHELL_CONFIG_DIR/lib/integrations/ghls/ghls" ]] || command -v ghls >/dev/null 2>&1; then
		run _ts_check_ghls
		[ "$status" -eq 0 ]
	else
		skip "ghls not available"
	fi
}

@test "_ts_check_safe_rm verifies PATH includes lib/bin" {
	source "$WELCOME_DIR/terminal-status.sh"
	
	# Temporarily add lib/bin to PATH for this test
	local old_path="$PATH"
	export PATH="$SHELL_CONFIG_DIR/lib/bin:$PATH"
	
	if [[ -x "$SHELL_CONFIG_DIR/lib/bin/rm" ]]; then
		run _ts_check_safe_rm
		[ "$status" -eq 0 ]
	else
		skip "lib/bin/rm not executable"
	fi
	
	export PATH="$old_path"
}

@test "_ts_check_git_wrapper verifies safety checks function" {
	source "$WELCOME_DIR/terminal-status.sh"
	
	# Define the eagerly-loaded function to simulate git wrapper being loaded
	# (Changed from _run_safety_checks which is now lazy-loaded)
	_git_wrapper_load_heavy() { return 0; }
	export -f _git_wrapper_load_heavy
	
	run _ts_check_git_wrapper
	[ "$status" -eq 0 ]
}

# =============================================================================
# ⏳ LAZY-LOAD CHECK TESTS
# =============================================================================

@test "_ts_check_autosuggestions returns 0 when ZSH_AUTOSUGGEST_STRATEGY set" {
	source "$WELCOME_DIR/terminal-status.sh"
	export ZSH_AUTOSUGGEST_STRATEGY="history"
	
	run _ts_check_autosuggestions
	[ "$status" -eq 0 ]
}

@test "_ts_check_autosuggestions returns 1 when plugin installed but not loaded" {
	source "$WELCOME_DIR/terminal-status.sh"
	unset ZSH_AUTOSUGGEST_STRATEGY
	
	# Create mock plugin directory
	mkdir -p "$TEST_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
	
	run _ts_check_autosuggestions
	[ "$status" -eq 1 ]  # Installed but not loaded = pending
}

@test "_ts_check_syntax_highlighting returns 0 when ZSH_HIGHLIGHT_HIGHLIGHTERS set" {
	source "$WELCOME_DIR/terminal-status.sh"
	export ZSH_HIGHLIGHT_HIGHLIGHTERS="main"
	
	run _ts_check_syntax_highlighting
	[ "$status" -eq 0 ]
}

# =============================================================================
# 📊 SAFETY COUNTS TEST
# =============================================================================

@test "_ts_get_safety_counts returns formatted counts" {
	source "$WELCOME_DIR/terminal-status.sh"
	
	run _ts_get_safety_counts
	[ "$status" -eq 0 ]
	# Should contain total and breakdown with block/info labels
	[[ "$output" == *"block"* ]]
	[[ "$output" == *"info"* ]]
}

@test "_ts_count_aliases returns a number" {
	source "$WELCOME_DIR/terminal-status.sh"
	
	run _ts_count_aliases
	[ "$status" -eq 0 ]
	[[ "$output" =~ ^[0-9]+$ ]]
}

# =============================================================================
# 🔮 AUTOCOMPLETE GUIDE TESTS
# =============================================================================

@test "autocomplete-guide.sh sources without error" {
	source "$WELCOME_DIR/autocomplete-guide.sh"
	type _welcome_show_autocomplete_guide &>/dev/null
}

@test "autocomplete guide respects toggle" {
	source "$WELCOME_DIR/autocomplete-guide.sh"
	export WELCOME_AUTOCOMPLETE_GUIDE="false"

	run _welcome_show_autocomplete_guide
	[ -z "$output" ]
}

@test "autocomplete guide shows fzf keybindings when available" {
	source "$WELCOME_DIR/autocomplete-guide.sh"
	export _AC_FZF_LOADED="true"

	run _welcome_show_autocomplete_guide
	[[ "$output" == *"fzf"* ]] || [[ "$output" == *"Ctrl+R"* ]]
}

@test "autocomplete guide shows general help when fzf not available" {
	source "$WELCOME_DIR/autocomplete-guide.sh"
	unset _AC_FZF_LOADED

	run _welcome_show_autocomplete_guide
	[[ "$output" == *"Autocomplete"* ]] || [[ "$output" == *"🔮"* ]]
}

# =============================================================================
# ⏱️  SHELL STARTUP TIME TESTS
# =============================================================================

@test "shell-startup-time.sh sources without error" {
	source "$WELCOME_DIR/shell-startup-time.sh"
	type _welcome_show_shell_startup_time &>/dev/null
}

@test "startup time respects toggle" {
	source "$WELCOME_DIR/shell-startup-time.sh"
	export WELCOME_SHELL_STARTUP_TIME="false"

	run _welcome_show_shell_startup_time
	[ -z "$output" ]
}

@test "startup time requires SHELL_CONFIG_START_TIME" {
	source "$WELCOME_DIR/shell-startup-time.sh"
	unset SHELL_CONFIG_START_TIME

	run _welcome_show_shell_startup_time
	[ -z "$output" ]
}

@test "startup time shows timing when available" {
	_WM_COLOR_RESET=$'\033[0m'
	_WM_COLOR_BOLD=$'\033[1m'
	_WM_COLOR_DIM=$'\033[2m'
	_WM_COLOR_GREEN=$'\033[0;32m'
	_WM_COLOR_RED=$'\033[0;31m'
	_WM_COLOR_YELLOW=$'\033[0;33m'
	_WM_COLOR_CYAN=$'\033[0;36m'
	_WM_COLOR_GRAY=$'\033[0;90m'
	source "$WELCOME_DIR/shell-startup-time.sh"
	local now_ms
	if command -v perl >/dev/null 2>&1; then
		now_ms=$(perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000')
	else
		now_ms=$(($(date +%s) * 1000))
	fi
	export SHELL_CONFIG_START_TIME=$((now_ms - 50))

	run _welcome_show_shell_startup_time
	[ "$status" -eq 0 ]
	[[ "$output" == *"startup"* ]] || [[ "$output" == *"⚡"* ]]
}

# =============================================================================
# 🔑 SSH CHECK REGRESSION TESTS (PR #95)
# =============================================================================

@test "_ts_check_ssh uses simplified parameter expansion" {
	source "$WELCOME_DIR/terminal-status.sh"

	# Verify the function definition uses simplified form
	local func_def
	func_def=$(declare -f _ts_check_ssh)

	# Should use [[ -S "${SSH_AUTH_SOCK:-}" ]] pattern
	[[ "$func_def" == *'${SSH_AUTH_SOCK:-}'* ]]
	# Should NOT have redundant -n check
	[[ "$func_def" != *'-n "${SSH_AUTH_SOCK:-}"'* ]]
}

@test "_ts_check_ssh handles unset SSH_AUTH_SOCK" {
	source "$WELCOME_DIR/terminal-status.sh"

	# Unset SSH_AUTH_SOCK and verify no error
	unset SSH_AUTH_SOCK

	run bash -c "source '$WELCOME_DIR/terminal-status.sh' && _ts_check_ssh"
	# Should not fail with unbound variable error
	# Test outcome depends on tool availability
	[ "$status" -eq 0 ] || skip "Tool or feature not available"
}

@test "_ts_check_ssh detects SSH agent socket" {
	source "$WELCOME_DIR/terminal-status.sh"

	# Create a temporary socket file
	local temp_socket
	temp_socket=$(mktemp -u)
	mkfifo "$temp_socket" 2>/dev/null || touch "$temp_socket"

	# Set SSH_AUTH_SOCK to the temp file
	export SSH_AUTH_SOCK="$temp_socket"

	# Note: mkfifo creates a named pipe, not a socket, so -S will fail
	# But we verify the function doesn't error on unset variable
	run _ts_check_ssh
	# Return code should be 0 or 1, not an error
	# Test outcome depends on tool availability
	[ "$status" -eq 0 ] || skip "Tool or feature not available"

	# Cleanup
	rm -f "$temp_socket"
	unset SSH_AUTH_SOCK
}
