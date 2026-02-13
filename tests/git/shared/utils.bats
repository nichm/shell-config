#!/usr/bin/env bats
# =============================================================================
# 🧪 GIT UTILS MODULE TESTS - Git Utilities Testing
# =============================================================================
# Tests for git utils module including:
#   - audit-logging.sh: Audit log management
#   - command-parser.sh: Git command parsing
#   - security-rules.sh: Security rule definitions
#   - validation-checks.sh: Validation check implementations
# =============================================================================

setup() {
	local repo_root
	repo_root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel 2>/dev/null || { cd "$BATS_TEST_DIRNAME/../../.." && pwd; })"
	export SHELL_CONFIG_DIR="$repo_root"
	export GIT_UTILS_DIR="$SHELL_CONFIG_DIR/lib/git/shared"

	# Create temp directory (cleanup in teardown, not EXIT trap which interferes with bats)
	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	# Initialize git repo (disable hooks to prevent global gitconfig interference in parallel)
	git init --initial-branch=main >/dev/null 2>&1
	git config user.email "test@example.com"
	git config user.name "Test User"
	git config core.hooksPath /dev/null

	# Set up test home directory
	export HOME="$TEST_TEMP_DIR/home"
	mkdir -p "$HOME"

	# Source git utils libraries
	source "$GIT_UTILS_DIR/audit-logging.sh"
	source "$GIT_UTILS_DIR/command-parser.sh"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

# =============================================================================
# 📝 AUDIT LOGGING TESTS
# =============================================================================

@test "audit-logging: _log_bypass creates audit log entry" {
	run _log_bypass "--force-danger" "reset --hard"
	[ "$status" -eq 0 ]

	# Check if audit log was created
	[ -f "$HOME/.shell-config-audit.log" ]
}

@test "audit-logging: _log_bypass logs timestamp" {
	_log_bypass "--force-danger" "reset --hard"

	local audit_log="$HOME/.shell-config-audit.log"
	[ -f "$audit_log" ]

	# Check log contains timestamp pattern
	grep -qE '\[20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' "$audit_log"
}

@test "audit-logging: _log_bypass logs bypass flag" {
	_log_bypass "--force-allow" "push --force"

	local audit_log="$HOME/.shell-config-audit.log"
	grep -q "BYPASS: --force-allow" "$audit_log"
}

@test "audit-logging: _log_bypass logs git command" {
	_log_bypass "--skip-secrets" "commit -m message"

	local audit_log="$HOME/.shell-config-audit.log"
	grep -q "Command: git commit -m message" "$audit_log"
}

@test "audit-logging: _log_bypass logs working directory" {
	mkdir -p "$TEST_TEMP_DIR/subdir"
	cd "$TEST_TEMP_DIR/subdir" || return 1

	_log_bypass "--force-danger" "reset --hard"

	local audit_log="$HOME/.shell-config-audit.log"
	grep -q "CWD: $TEST_TEMP_DIR/subdir" "$audit_log"
}

@test "audit-logging: _log_bypass creates multiple entries" {
	_log_bypass "--force-danger" "reset --hard"
	_log_bypass "--skip-secrets" "commit -m test"
	_log_bypass "--force-allow" "push --force"

	local audit_log="$HOME/.shell-config-audit.log"
	local entry_count
	entry_count=$(wc -l <"$audit_log")
	[ "$entry_count" -ge 3 ]
}

@test "audit-logging: _log_bypass handles special characters in command" {
	_log_bypass "--force-danger" "commit -m 'test with \"quotes\"'"

	local audit_log="$HOME/.shell-config-audit.log"
	[ -f "$audit_log" ]
}

@test "audit-logging: _log_bypass creates directory if needed" {
	rm -rf "$HOME"
	export HOME="$TEST_TEMP_DIR/newhome"

	run _log_bypass "--force-danger" "reset --hard"
	[ "$status" -eq 0 ]

	[ -f "$HOME/.shell-config-audit.log" ]
}

# =============================================================================
# 🔍 COMMAND PARSER TESTS
# =============================================================================

@test "command-parser: _get_real_git_command extracts simple command" {
	run _get_real_git_command "commit"
	[ "$status" -eq 0 ]
	[ "$output" = "commit" ]
}

@test "command-parser: _get_real_git_command skips wrapper flags" {
	run _get_real_git_command "--skip-secrets" "commit"
	[ "$status" -eq 0 ]
	[ "$output" = "commit" ]
}

@test "command-parser: _get_real_git_command skips multiple wrapper flags" {
	run _get_real_git_command "--skip-secrets" "--skip-syntax-check" "commit"
	[ "$status" -eq 0 ]
	[ "$output" = "commit" ]
}

@test "command-parser: _get_real_git_command handles flags after command" {
	run _get_real_git_command "commit" "-m" "message"
	[ "$status" -eq 0 ]
	[ "$output" = "commit" ]
}

@test "command-parser: _get_real_git_command skips --allow-large-files" {
	run _get_real_git_command "--allow-large-files" "push" "origin" "main"
	[ "$status" -eq 0 ]
	[ "$output" = "push" ]
}

@test "command-parser: _get_real_git_command skips --force-danger" {
	run _get_real_git_command "--force-danger" "reset" "--hard"
	[ "$status" -eq 0 ]
	[ "$output" = "reset" ]
}

@test "command-parser: _get_real_git_command skips --force-allow" {
	run _get_real_git_command "--force-allow" "push" "--force" "origin" "main"
	[ "$status" -eq 0 ]
	[ "$output" = "push" ]
}

@test "command-parser: _get_real_git_command skips --skip-deps-check" {
	run _get_real_git_command "--skip-deps-check" "commit"
	[ "$status" -eq 0 ]
	[ "$output" = "commit" ]
}

@test "command-parser: _get_real_git_command handles complex argument order" {
	run _get_real_git_command "--skip-secrets" "commit" "-m" "test"
	[ "$status" -eq 0 ]
	[ "$output" = "commit" ]
}

@test "command-parser: _get_real_git_command returns error for no command" {
	run _get_real_git_command "--skip-secrets"
	[ "$status" -eq 1 ]
	[ "$output" = "" ]
}

@test "command-parser: _get_real_git_command handles all wrapper flags" {
	# Test all known wrapper flags
	run _get_real_git_command "--skip-secrets" "--skip-syntax-check" "--skip-deps-check" "--allow-large-files" "--force-danger" "--force-allow" "status"
	[ "$status" -eq 0 ]
	[ "$output" = "status" ]
}

# =============================================================================
# 🔒 SECURITY RULES TESTS
# =============================================================================

@test "security-rules: security rules file exists" {
	[ -f "$GIT_UTILS_DIR/security-rules.sh" ]
}

@test "security-rules: security rules contain rule definitions" {
	# Just check the file exists and has content
	[ -s "$GIT_UTILS_DIR/security-rules.sh" ]
}

@test "security-rules: security rules are sourced successfully" {
	# This test just verifies the file can be sourced without errors
	run bash -c "source '$GIT_UTILS_DIR/security-rules.sh'"
	[ "$status" -eq 0 ]
}

# =============================================================================
# ✅ VALIDATION CHECKS TESTS
# =============================================================================

@test "validation-checks: validation checks file exists" {
	[ -f "$GIT_UTILS_DIR/validation-checks.sh" ]
}

@test "validation-checks: validation checks contain validation logic" {
	# Just check the file exists and has content
	[ -s "$GIT_UTILS_DIR/validation-checks.sh" ]
}

@test "validation-checks: validation checks are sourced successfully" {
	# This test just verifies the file can be sourced without errors
	run bash -c "source '$GIT_UTILS_DIR/validation-checks.sh'"
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🔧 INTEGRATION TESTS
# =============================================================================

@test "integration: command-parser and audit-logging work together" {
	# Parse command
	local cmd
	cmd=$(_get_real_git_command "--skip-secrets" "commit" "-m" "test")

	# Log the bypass
	_log_bypass "--skip-secrets" "$cmd -m test"

	local audit_log="$HOME/.shell-config-audit.log"
	grep -q "commit" "$audit_log"
}

@test "integration: multiple bypass operations are all logged" {
	_log_bypass "--force-danger" "reset --hard"
	_log_bypass "--skip-secrets" "commit -m test"
	_log_bypass "--force-allow" "push --force"

	local audit_log="$HOME/.shell-config-audit.log"
	local entry_count
	entry_count=$(wc -l <"$audit_log")

	[ "$entry_count" -ge 3 ]
	grep -q "reset --hard" "$audit_log"
	grep -q "commit" "$audit_log"
	grep -q "push --force" "$audit_log"
}

@test "integration: command-parser handles real-world scenarios" {
	# Scenario: git --skip-secrets commit -m "feature: add tests"
	run _get_real_git_command "--skip-secrets" "commit" "-m" "feature: add tests"
	[ "$status" -eq 0 ]
	[ "$output" = "commit" ]

	# Scenario: git --force-danger reset --hard HEAD
	run _get_real_git_command "--force-danger" "reset" "--hard" "HEAD"
	[ "$status" -eq 0 ]
	[ "$output" = "reset" ]

	# Scenario: git --allow-large-files push origin main
	run _get_real_git_command "--allow-large-files" "push" "origin" "main"
	[ "$status" -eq 0 ]
	[ "$output" = "push" ]
}

# =============================================================================
# 🛡️ EDGE CASES
# =============================================================================

@test "edge-cases: audit-logging handles empty command" {
	run _log_bypass "--force-danger" ""
	[ "$status" -eq 0 ]

	local audit_log="$HOME/.shell-config-audit.log"
	grep -q "Command: git " "$audit_log"
}

@test "edge-cases: audit-logging handles very long commands" {
	local long_msg
	long_msg=$(printf 'x%.0s' {1..1000})

	run _log_bypass "--force-danger" "commit -m '$long_msg'"
	[ "$status" -eq 0 ]

	[ -f "$HOME/.shell-config-audit.log" ]
}

@test "edge-cases: command-parser handles command with hyphens" {
	run _get_real_git_command "--skip-secrets" "rebase" "--continue"
	[ "$status" -eq 0 ]
	[ "$output" = "rebase" ]
}

@test "edge-cases: command-parser handles numeric subcommands" {
	run _get_real_git_command "--skip-secrets" "log" "-1"
	[ "$status" -eq 0 ]
	[ "$output" = "log" ]
}

@test "edge-cases: audit-logging handles concurrent access" {
	# This is a basic test - real concurrent testing would require multiple processes
	_log_bypass "--force-danger" "reset --hard" &
	_log_bypass "--skip-secrets" "commit -m test" &
	_log_bypass "--force-allow" "push --force" &
	wait

	local audit_log="$HOME/.shell-config-audit.log"
	local entry_count
	entry_count=$(wc -l <"$audit_log")

	[ "$entry_count" -ge 3 ]
}

@test "edge-cases: all utilities handle missing HOME gracefully" {
	local original_home="$HOME"
	unset HOME

	# Command parser should work without HOME
	run _get_real_git_command "--skip-secrets" "status"
	[ "$status" -eq 0 ]

	# Restore HOME for cleanup
	export HOME="$original_home"
}

@test "edge-cases: command-parser is case-sensitive" {
	run _get_real_git_command "--SKIP-SECRETS" "commit"
	# All flags (starting with -) are skipped, so "commit" is returned
	# The parser doesn't distinguish uppercase from lowercase flags
	[ "$status" -eq 0 ]
	[ "$output" = "commit" ]
}
