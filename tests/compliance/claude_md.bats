#!/usr/bin/env bats
# =============================================================================
# 🧪 CLAUDE.md COMPLIANCE TESTS
# =============================================================================
# Tests to ensure codebase follows CLAUDE.md mandatory patterns.
# These tests prevent regressions of fixed issues.
# =============================================================================

load ../test_helpers

setup() {
	setup_test_env

	local repo_root
	repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
	export SHELL_CONFIG_DIR="$repo_root"
}

teardown() {
	cleanup_test_env
}

# =============================================================================
# 📝 ERROR MESSAGE FORMAT (WHAT/WHY/HOW)
# =============================================================================

@test "COMPLIANCE: command-safety/init.sh has WHAT/WHY/HOW error format" {
	local init_file="$SHELL_CONFIG_DIR/lib/command-safety/init.sh"

	# Check for WHY in error messages
	run grep -c "echo.*WHY:" "$init_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	# Check for FIX in error messages
	run grep -c "echo.*FIX:" "$init_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

@test "COMPLIANCE: command-safety/engine/loader.sh has WHAT/WHY/HOW error format" {
	# matcher.sh is a pure data-driven engine with no user-facing errors.
	# loader.sh handles error reporting for the engine.
	local loader_file="$SHELL_CONFIG_DIR/lib/command-safety/engine/loader.sh"

	# Check for WHY in error messages
	run grep -c "echo.*WHY:" "$loader_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	# Check for FIX in error messages
	run grep -c "echo.*FIX:" "$loader_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

@test "COMPLIANCE: command-safety/engine/display.sh has WHAT/WHY/HOW error format" {
	local display_file="$SHELL_CONFIG_DIR/lib/command-safety/engine/display.sh"

	run grep -c "WHY:" "$display_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	run grep -c "FIX:" "$display_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

@test "COMPLIANCE: command-safety/engine/wrapper.sh has WHAT/WHY/HOW error format" {
	local wrapper_file="$SHELL_CONFIG_DIR/lib/command-safety/engine/wrapper.sh"

	run grep -c "WHY:" "$wrapper_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	run grep -c "FIX:" "$wrapper_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

@test "COMPLIANCE: pre-commit hook has WHAT/WHY/HOW error format" {
	local precommit_file="$SHELL_CONFIG_DIR/lib/git/hooks/pre-commit"

	# Check for WHY in error messages
	run grep -c "echo.*WHY:" "$precommit_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	# Check for FIX in error messages
	run grep -c "echo.*FIX:" "$precommit_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

# =============================================================================
# 🎨 SHARED COLORS LIBRARY
# =============================================================================

@test "COMPLIANCE: welcome/main.sh uses shared colors library" {
	local main_file="$SHELL_CONFIG_DIR/lib/welcome/main.sh"

	# Must source core/colors.sh
	run grep "source.*core/colors.sh" "$main_file"
	[ "$status" -eq 0 ]
}

@test "COMPLIANCE: pre-commit hook sources shared colors via bootstrap" {
	local precommit_file="$SHELL_CONFIG_DIR/lib/git/hooks/pre-commit"

	# Pre-commit sources hook-bootstrap.sh which in turn sources colors.sh
	run grep "source.*hook-bootstrap\|source.*COLORS_SCRIPT\|source.*colors.sh" "$precommit_file"
	[ "$status" -eq 0 ]
}

@test "COMPLIANCE: colors.sh has guard against multiple sourcing" {
	local colors_file="$SHELL_CONFIG_DIR/lib/core/colors.sh"

	# Must have a guard
	run grep "_SHELL_CONFIG_CORE_COLORS_LOADED" "$colors_file"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 📁 GITCONFIG PORTABLE PATH
# =============================================================================

@test "COMPLIANCE: gitconfig uses portable path (~) not hardcoded" {
	local gitconfig_file="$SHELL_CONFIG_DIR/config/gitconfig"

	# Should NOT have hardcoded /Users/username paths
	run grep -E "hooksPath = /Users/" "$gitconfig_file"
	[ "$status" -ne 0 ]

	# Should use ~ or $HOME (both are valid portable paths)
	run grep -E "hooksPath = (~|\\\$HOME)" "$gitconfig_file"
	[ "$status" -eq 0 ]
}

@test "COMPLIANCE: gitconfig does not leak developer usernames" {
	local gitconfig_file="$SHELL_CONFIG_DIR/config/gitconfig"

	# Should not have /Users/nick or similar hardcoded paths
	run grep -E "/Users/[a-z]+" "$gitconfig_file"
	[ "$status" -ne 0 ]
}

# =============================================================================
# 🔐 GITLEAKS OUTPUT VISIBILITY
# =============================================================================

@test "COMPLIANCE: pre-commit pipeline has gitleaks secrets check" {
	local checks_file="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

	# Should have gitleaks check function
	run grep "run_gitleaks_secrets_check" "$checks_file"
	[ "$status" -eq 0 ]

	# Should write errors to tmpdir marker file on failure
	run grep "gitleaks-errors" "$checks_file"
	[ "$status" -eq 0 ]
}

@test "COMPLIANCE: pre-commit display reports gitleaks failures" {
	local display_file="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-display.sh"

	# Should check for gitleaks error marker
	run grep "gitleaks-errors" "$display_file"
	[ "$status" -eq 0 ]

	# Should show actionable error message
	run grep -E "Secrets detected|gitleaks detect" "$display_file"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🧹 TRAP HANDLERS
# =============================================================================

@test "COMPLIANCE: test runner has trap for temp directory cleanup" {
	local runner_file="$SHELL_CONFIG_DIR/tests/run_all.sh"

	# Must have trap for cleanup
	run grep "trap.*rm.*result_dir" "$runner_file"
	[ "$status" -eq 0 ]
}

@test "COMPLIANCE: trap handlers include INT and TERM signals" {
	local runner_file="$SHELL_CONFIG_DIR/tests/run_all.sh"

	# Trap should include INT TERM for proper cleanup
	run grep -E "trap.*INT.*TERM|trap.*TERM.*INT" "$runner_file"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 📊 TERMINAL STATUS (replaces old Features Loaded section)
# =============================================================================

@test "COMPLIANCE: welcome shows terminal status section" {
	local main_file="$SHELL_CONFIG_DIR/lib/welcome/main.sh"

	# welcome_message must call terminal status display
	run grep "_welcome_show_terminal_status" "$main_file"
	[ "$status" -eq 0 ]
}

@test "COMPLIANCE: welcome calls git hooks status" {
	local main_file="$SHELL_CONFIG_DIR/lib/welcome/main.sh"

	# welcome_message must call git hooks status display
	run grep "_welcome_show_git_hooks_status" "$main_file"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 📐 FILE SIZE LIMITS
# =============================================================================

@test "COMPLIANCE: welcome/main.sh is under 600 lines" {
	local main_file="$SHELL_CONFIG_DIR/lib/welcome/main.sh"
	local line_count
	line_count=$(wc -l < "$main_file" | tr -d ' ')

	[ "$line_count" -lt 600 ]
}

@test "COMPLIANCE: pre-commit hook is under 600 lines" {
	local precommit_file="$SHELL_CONFIG_DIR/lib/git/hooks/pre-commit"
	local line_count
	line_count=$(wc -l < "$precommit_file" | tr -d ' ')

	[ "$line_count" -lt 600 ]
}

@test "COMPLIANCE: command-safety/init.sh is under 600 lines" {
	local init_file="$SHELL_CONFIG_DIR/lib/command-safety/init.sh"
	local line_count
	line_count=$(wc -l < "$init_file" | tr -d ' ')

	[ "$line_count" -lt 600 ]
}

# =============================================================================
# ⚡ PERFORMANCE OPTIMIZATION (Command Cache)
# =============================================================================

@test "COMPLIANCE: welcome modules use command_exists cache for performance" {
	local git_hooks_status="$SHELL_CONFIG_DIR/lib/welcome/git-hooks-status.sh"

	# Should source the command-cache module
	run grep -E "source.*command-cache\.sh" "$git_hooks_status"
	[ "$status" -eq 0 ]

	# Should use command_exists function (cached) instead of command -v
	run grep -c "command_exists" "$git_hooks_status"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

@test "COMPLIANCE: terminal setup sources command cache module" {
	local terminal_common="$SHELL_CONFIG_DIR/lib/terminal/common.sh"

	# Should source the command-cache module
	run grep -E "source.*command-cache\.sh" "$terminal_common"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🔒 STRICT MODE (Critical Scripts)
# =============================================================================

@test "COMPLIANCE: command-safety engine files do NOT use strict mode (sourced into interactive shell)" {
	local engine_dir="$SHELL_CONFIG_DIR/lib/command-safety/engine"

	# Engine files are sourced into interactive shells where set -e would
	# cause the shell to exit on any command failure. They MUST NOT use
	# set -euo pipefail. Each file should have a comment explaining why.
	for file in matcher.sh wrapper.sh registry.sh display.sh loader.sh utils.sh logging.sh; do
		local filepath="$engine_dir/$file"
		[[ -f "$filepath" ]] || continue

		# Must NOT have active set -euo pipefail
		run grep -E "^set -euo pipefail" "$filepath"
		[ "$status" -ne 0 ] || {
			echo "FAIL: $file has active 'set -euo pipefail' — breaks interactive shells" >&2
			return 1
		}

		# Must have comment explaining why no strict mode
		run grep -E "No set -euo pipefail|sourced into interactive" "$filepath"
		[ "$status" -eq 0 ] || {
			echo "FAIL: $file missing comment about why strict mode is disabled" >&2
			return 1
		}
	done
}

@test "COMPLIANCE: terminal install scripts use strict mode" {
	local install_script="$SHELL_CONFIG_DIR/lib/terminal/install.sh"

	# Should have strict mode enabled
	run grep -E "set -euo pipefail" "$install_script"
	[ "$status" -eq 0 ]
}
