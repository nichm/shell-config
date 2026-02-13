#!/usr/bin/env bats
# =============================================================================
# 🎨 EMOJI USAGE COMPLIANCE TESTS
# =============================================================================
# Tests to ensure emoji usage follows CLAUDE.md vocabulary standards.
# These tests prevent emoji inconsistencies and regressions.
# See: CLAUDE.md lines 611-679 (Emoji Vocabulary section)
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
# ❌ ERROR MESSAGE FORMAT (Critical)
# =============================================================================

@test "EMOJI: install.sh uses standardized error emoji prefixes" {
	local install_file="$SHELL_CONFIG_DIR/install.sh"

	# Check for ❌ ERROR with emoji prefix
	run grep -c 'echo.*❌.*ERROR:' "$install_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	# Check for ℹ️  WHY with emoji prefix (note the two spaces for alignment)
	run grep -c 'echo.*ℹ️.*WHY:' "$install_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	# Check for 💡 FIX with emoji prefix
	run grep -c 'echo.*💡.*FIX:' "$install_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

@test "EMOJI: 1password/secrets.sh uses standardized error format" {
	local secrets_file="$SHELL_CONFIG_DIR/lib/integrations/1password/secrets.sh"

	# Check for emoji-prefixed error messages
	run grep -c 'echo.*❌.*ERROR:' "$secrets_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	run grep -c 'echo.*ℹ️.*WHY:' "$secrets_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

@test "EMOJI: command-safety errors use proper emoji prefixes" {
	local init_file="$SHELL_CONFIG_DIR/lib/command-safety/init.sh"
	local loader_file="$SHELL_CONFIG_DIR/lib/command-safety/engine/loader.sh"

	# Check init.sh (user-facing error reporting)
	run grep -c 'echo.*❌.*ERROR:' "$init_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	# Check loader.sh (user-facing error reporting)
	# Note: matcher.sh is a pure data-driven engine with no error messages
	run grep -c 'echo.*❌.*ERROR:' "$loader_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

@test "EMOJI: git hooks use standardized error messages" {
	local precommit_display="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-display.sh"

	# Check for 🛑 blocked emoji (may use log_error or echo)
	run grep -c '🛑.*[Bb]lock' "$precommit_display"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

@test "EMOJI: pre-commit success uses rocket ship not party popper" {
	local precommit_file="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit.sh"

	# Should use 🚀 for "ship it" success (via log_success or echo)
	run grep '🚀' "$precommit_file"
	[ "$status" -eq 0 ]

	# Should NOT use 🎉 (old emoji)
	run grep '🎉' "$precommit_file"
	[ "$status" -ne 0 ]
}

# =============================================================================
# 📚 DOCUMENTATION LINKS
# =============================================================================

@test "EMOJI: command-safety docs use book stack emoji" {
	local display_file="$SHELL_CONFIG_DIR/lib/command-safety/engine/display.sh"

	# Should use 📚 for "Learn more" documentation links
	run grep 'echo.*📚.*Learn more' "$display_file"
	[ "$status" -eq 0 ]

	# Should NOT use 📖 (old emoji for this context)
	run grep 'echo.*📖.*Learn more' "$display_file"
	[ "$status" -ne 0 ]
}

# Note: 📖 is acceptable in autocomplete-guide.sh for inline link indicators
# This is documented in CLAUDE.md as semantically appropriate for "open book"

# =============================================================================
# 📐 FILE SIZE VALIDATION
# =============================================================================

@test "EMOJI: file length checks use triangle ruler emoji" {
	local precommit_checks="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"
	local git_hooks_status="$SHELL_CONFIG_DIR/lib/welcome/git-hooks-status.sh"

	# Should use 📐 for file length validation
	run grep -c '📐' "$precommit_checks"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	# Should NOT use 📏 (old emoji)
	run grep '📏' "$precommit_checks"
	[ "$status" -ne 0 ]

	# Check git-hooks-status.sh as well
	run grep -c '📐' "$git_hooks_status"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 📦 LARGE FILES AND DEPENDENCIES
# =============================================================================

@test "EMOJI: large file checks use package emoji" {
	local security_rules="$SHELL_CONFIG_DIR/lib/git/shared/security-rules.sh"

	# Should use 📦 for large files/dependencies
	run grep -c '📦' "$security_rules"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	# Should NOT use 📁 (old emoji)
	run grep '📁.*large file' "$security_rules"
	[ "$status" -ne 0 ]
}

# =============================================================================
# 🔗 SYMLINKS
# =============================================================================

@test "EMOJI: symlink operations use link emoji" {
	local ensure_symlink="$SHELL_CONFIG_DIR/lib/core/ensure-audit-symlink.sh"

	# Should use 🔗 for symlink success
	run grep 'echo.*🔗' "$ensure_symlink"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 💪 HEALTH AND STATUS
# =============================================================================

@test "EMOJI: doctor tool uses muscle emoji for all-healthy" {
	local doctor_file="$SHELL_CONFIG_DIR/lib/core/doctor.sh"

	# Should use 💪 for "all healthy" status
	run grep -c '💪' "$doctor_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

# =============================================================================
# 👋 WELCOME AND GOODBYE
# =============================================================================

@test "EMOJI: uninstall script uses waving hand for completion" {
	local uninstall_file="$SHELL_CONFIG_DIR/uninstall.sh"

	# Should use 👋 for goodbye/completion
	run grep -c '👋' "$uninstall_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

# =============================================================================
# 🔧 SETUP AND PROGRESS
# =============================================================================

@test "EMOJI: install script uses wrench for step progress" {
	local colors_file="$SHELL_CONFIG_DIR/lib/core/colors.sh"

	# log_step function body uses 🔧 (on the printf line inside the function)
	run grep -c '🔧' "$colors_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

# =============================================================================
# ⚡ PERFORMANCE AND FEATURES
# =============================================================================

@test "EMOJI: command cache uses lightning for performance features" {
	local cache_file="$SHELL_CONFIG_DIR/lib/core/command-cache.sh"

	# Should use ⚡ for performance/cache features
	run grep -c '⚡' "$cache_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

@test "EMOJI: terminal status uses lightning for safety counts" {
	local ts_file="$SHELL_CONFIG_DIR/lib/welcome/terminal-status.sh"

	# Should use ⚡ for safety summary line
	run grep -c '⚡' "$ts_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

# =============================================================================
# 🛡️ SECURITY MARKERS
# =============================================================================

@test "EMOJI: welcome uses shield for security features" {
	local hooks_status="$SHELL_CONFIG_DIR/lib/welcome/git-hooks-status.sh"

	# Should use 🛡 for security/protection features (gha-scan display)
	run grep -c '🛡' "$hooks_status"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

# =============================================================================
# 🔴 HIGH-RISK SECURITY MARKERS
# =============================================================================

@test "EMOJI: rm wrapper uses red circle for danger operations" {
	local rm_wrapper="$SHELL_CONFIG_DIR/lib/security/rm/wrapper.sh"

	# Should use 🔴 for DANGER/destructive operations
	run grep -c '🔴.*ERROR' "$rm_wrapper"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

# Note: This is acceptable deviation from standard ❌ ERROR format
# because 🔴 is semantically correct for destructive operations per CLAUDE.md

# =============================================================================
# 🩺 DIAGNOSTICS
# =============================================================================

@test "EMOJI: doctor tool uses stethoscope for diagnostics header" {
	local doctor_file="$SHELL_CONFIG_DIR/lib/core/doctor.sh"

	# Should use 🩺 for diagnostics
	run grep -c '🩺' "$doctor_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

# =============================================================================
# 🎨 TOOL ICONS
# =============================================================================

@test "EMOJI: formatting checks use art palette emoji" {
	# Check for 🎨 in formatting-related contexts
	local formatting_aliases="$SHELL_CONFIG_DIR/lib/aliases/formatting.sh"

	# May use art palette for formatting features
	run grep '🎨' "$formatting_aliases"
	# This is optional, so we don't assert status
}

@test "EMOJI: test coverage uses test tube emoji" {
	local precommit_checks="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-checks.sh"

	# Should use 🧪 for test coverage
	run grep -c '🧪' "$precommit_checks"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

# =============================================================================
# ⚠️ NON-BLOCKING WARNINGS
# =============================================================================

@test "EMOJI: config warnings use warning sign emoji" {
	local config_file="$SHELL_CONFIG_DIR/lib/core/config.sh"

	# Should use ⚠️ for non-blocking warnings
	run grep -c '⚠️' "$config_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

# =============================================================================
# 🔧 INTEGRATION-SPECIFIC EMOJIS
# =============================================================================

@test "EMOJI: eza integration uses folder emojis for tree display" {
	local eza_file="$SHELL_CONFIG_DIR/lib/integrations/eza.sh"

	# Should use folder emoji (📁, 📂, 🗂️) for tree commands
	run grep -c '📁\|📂\|🗂️' "$eza_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

# =============================================================================
# ✅ SUCCESS MARKERS
# =============================================================================

@test "EMOJI: command-safety display uses checkmark for alternatives" {
	local display_file="$SHELL_CONFIG_DIR/lib/command-safety/engine/display.sh"

	# Should use ✅ for safer alternatives
	run grep -c '✅' "$display_file"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

# =============================================================================
# 📊 COMPLIANCE: Test files use correct emojis
# =============================================================================

@test "EMOJI: test file headers use correct emojis" {
	# Check that test files use 📐 for file length, 📦 for large files
	local claude_md_test="$SHELL_CONFIG_DIR/tests/compliance/claude_md.bats"
	local hooks_test="$SHELL_CONFIG_DIR/tests/git/hooks.bats"
	local api_test="$SHELL_CONFIG_DIR/tests/validation/api.bats"

	# Should use 📐 for file size tests
	run grep -c '📐' "$claude_md_test"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	run grep -c '📐' "$hooks_test"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	run grep -c '📐' "$api_test"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}

@test "EMOJI: git wrapper tests use package emoji" {
	local wrapper_test="$SHELL_CONFIG_DIR/tests/git/wrapper.bats"
	local wrapper_int_test="$SHELL_CONFIG_DIR/tests/git/wrapper.integration.bats"

	# Should use 📦 for large file tests
	run grep -c '📦' "$wrapper_test"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]

	run grep -c '📦' "$wrapper_int_test"
	[ "$status" -eq 0 ]
	[ "$output" -ge 1 ]
}
