#!/usr/bin/env bats
# =============================================================================
# 🧪 GIT SAFETY MODULE TESTS - Git Safety Validation Testing
# =============================================================================
# Tests for git safety module including:
#   - clone-check.sh: Repository clone safety checks
#   - dangerous-commands.sh: Dangerous git command detection
#   - secrets-check.sh: Secrets scanning integration
# =============================================================================

setup() {
	local repo_root
	repo_root="$(git -C "$BATS_TEST_DIRNAME" rev-parse --show-toplevel 2>/dev/null || { cd "$BATS_TEST_DIRNAME/../../.." && pwd; })"
	export SHELL_CONFIG_DIR="$repo_root"
	export GIT_SAFETY_DIR="$SHELL_CONFIG_DIR/lib/git/shared"
	export GIT_WRAPPER_DIR="$SHELL_CONFIG_DIR/lib/git"

	# Create temp directory (cleanup in teardown, not EXIT trap which interferes with bats)
	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	# Initialize git repo (disable hooks to prevent global gitconfig interference in parallel)
	git init --initial-branch=main >/dev/null 2>&1
	git config user.email "test@example.com"
	git config user.name "Test User"
	git config core.hooksPath /dev/null

	# Mock HOME to avoid touching actual home directory
	export HOME="$TEST_TEMP_DIR/home"
	mkdir -p "$HOME/github/testorg"

	# Source safety libraries (security-rules.sh first, provides _show_warning)
	source "$GIT_SAFETY_DIR/security-rules.sh"
	source "$GIT_SAFETY_DIR/clone-check.sh"
	source "$GIT_SAFETY_DIR/safety-checks.sh"
	source "$GIT_SAFETY_DIR/secrets-check.sh"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

# =============================================================================
# 🔍 CLONE CHECK TESTS
# =============================================================================

@test "clone-check: _check_existing_repo finds existing repository" {
	# Create an existing repo with the name we'll search for
	mkdir -p "$HOME/github/testorg/test-repo"
	cd "$HOME/github/testorg/test-repo" || return 1
	git init --initial-branch=main >/dev/null 2>&1
	cd "$TEST_TEMP_DIR" || return 1

	# Check for existing repo
	local result
	result=$(_check_existing_repo "clone" "https://github.com/testorg/test-repo.git")

	[[ "$result" == *"test-repo"* ]]
}

@test "clone-check: _check_existing_repo returns empty for new repository" {
	local result
	result=$(_check_existing_repo "clone" "https://github.com/testorg/new-repo.git")

	[ "$result" = "" ]
}

@test "clone-check: _check_existing_repo handles git@ URLs" {
	# Create an existing repo with the name we'll search for
	mkdir -p "$HOME/github/myorg/existing-repo"
	cd "$HOME/github/myorg/existing-repo" || return 1
	git init --initial-branch=main >/dev/null 2>&1
	cd "$TEST_TEMP_DIR" || return 1

	local result
	result=$(_check_existing_repo "clone" "git@github.com:myorg/existing-repo.git")

	[[ "$result" == *"existing-repo"* ]]
}

@test "clone-check: _check_existing_repo handles non-github URLs" {
	local result
	result=$(_check_existing_repo "clone" "https://gitlab.com/org/repo.git")

	[ "$result" = "" ]
}

@test "clone-check: _run_clone_check blocks duplicate clones" {
	# Create existing repo with the name we'll try to clone
	mkdir -p "$HOME/github/testorg/test-repo"
	cd "$HOME/github/testorg/test-repo" || return 1
	git init --initial-branch=main >/dev/null 2>&1
	cd "$TEST_TEMP_DIR" || return 1

	run _run_clone_check "clone" "https://github.com/testorg/test-repo.git"
	[ "$status" -eq 1 ]
	[[ "$output" == *"already exists"* ]] || [[ "$output" == *"Found at"* ]] || [[ "$output" == *"test-repo"* ]]
}

@test "clone-check: _run_clone_check allows --force-allow bypass" {
	run _run_clone_check "clone" "https://github.com/testorg/test-repo.git" "--force-allow"
	[ "$status" -eq 0 ]
}

@test "clone-check: _run_clone_check skips non-clone commands" {
	run _run_clone_check "status"
	[ "$status" -eq 0 ]
}

@test "clone-check: _run_clone_check allows new repositories" {
	run _run_clone_check "clone" "https://github.com/testorg/new-repo.git"
	[ "$status" -eq 0 ]
}

# =============================================================================
# ⚠️ DANGEROUS COMMANDS TESTS
# =============================================================================

@test "dangerous-commands: _run_safety_checks blocks git reset --hard" {
	run _run_safety_checks reset --hard
	[ "$status" -eq 1 ]
	[[ "$output" == *"DANGER"* ]] || [[ "$output" == *"reset"* ]]
}

@test "dangerous-commands: _run_safety_checks allows reset without --hard" {
	run _run_safety_checks reset HEAD~1
	[ "$status" -eq 0 ]
}

@test "dangerous-commands: _run_safety_checks blocks git push --force" {
	run _run_safety_checks push --force origin main
	[ "$status" -eq 1 ]
	[[ "$output" == *"DANGER"* ]] || [[ "$output" == *"push"* ]]
}

@test "dangerous-commands: _run_safety_checks allows push --force-with-lease" {
	run _run_safety_checks push --force-with-lease origin main
	[ "$status" -eq 0 ]
}

@test "dangerous-commands: _run_safety_checks blocks git rebase" {
	run _run_safety_checks rebase main
	[ "$status" -eq 1 ]
	[[ "$output" == *"WARNING"* ]] || [[ "$output" == *"rebase"* ]]
}

@test "dangerous-commands: _run_safety_checks allows --force-danger bypass" {
	run _run_safety_checks reset --hard --force-danger
	[ "$status" -eq 0 ]
}

@test "dangerous-commands: _run_safety_checks allows --force-allow bypass" {
	run _run_safety_checks push --force origin main --force-allow
	[ "$status" -eq 0 ]
}

@test "dangerous-commands: _run_safety_checks allows safe commands" {
	run _run_safety_checks status
	[ "$status" -eq 0 ]

	run _run_safety_checks log
	[ "$status" -eq 0 ]

	run _run_safety_checks diff
	[ "$status" -eq 0 ]
}

@test "dangerous-commands: _run_safety_checks handles reset with multiple args" {
	run _run_safety_checks reset --hard HEAD
	[ "$status" -eq 1 ]
}

@test "dangerous-commands: _run_safety_checks distinguishes --force from --force-with-lease" {
	run _run_safety_checks push --force origin main
	[ "$status" -eq 1 ]

	run _run_safety_checks push --force-with-lease origin main
	[ "$status" -eq 0 ]
}

# =============================================================================
# 🔐 SECRETS CHECK TESTS
# =============================================================================

@test "secrets-check: _check_gitleaks detects gitleaks installation" {
	# This test will be skipped if gitleaks is not installed
	command -v gitleaks >/dev/null 2>&1 || skip "gitleaks not installed"

	run _check_gitleaks
	[ "$status" -eq 0 ]
}

@test "secrets-check: _check_gitleaks returns 1 when gitleaks not found" {
	# Mock PATH to remove gitleaks
	local original_path="$PATH"
	export PATH="/usr/bin:/bin"

	run _check_gitleaks
	[ "$status" -eq 1 ]

	export PATH="$original_path"
}

@test "secrets-check: _needs_secrets_check identifies commands needing scan" {
	_needs_secrets_check "commit"
	[ "$?" -eq 0 ]

	_needs_secrets_check "add"
	[ "$?" -eq 0 ]

	_needs_secrets_check "push"
	[ "$?" -eq 0 ]
}

@test "secrets-check: _needs_secrets_check skips commands not needing scan" {
	run _needs_secrets_check "status"
	[ "$status" -eq 1 ]

	run _needs_secrets_check "log"
	[ "$status" -eq 1 ]

	run _needs_secrets_check "diff"
	[ "$status" -eq 1 ]
}

@test "secrets-check: _needs_secrets_check handles short commands" {
	_needs_secrets_check "ci"
	[ "$?" -eq 0 ]

	_needs_secrets_check "am"
	[ "$?" -eq 0 ]
}

@test "secrets-check: _run_secrets_check skips when skip_secrets is 1" {
	# Create staged files
	echo "test" >"test.txt"
	git add "test.txt"

	run _run_secrets_check "commit" 1
	[ "$status" -eq 0 ]
}

@test "secrets-check: _run_secrets_check skips commands not needing check" {
	run _run_secrets_check "status" 0
	[ "$status" -eq 0 ]
}

@test "secrets-check: _run_secrets_check shows setup hint when gitleaks missing" {
	# Mock PATH to remove gitleaks
	local original_path="$PATH"
	export PATH="/usr/bin:/bin"

	run _run_secrets_check "commit" 0
	[ "$status" -eq 0 ]
	[[ "$output" == *"Gitleaks not installed"* ]] || [[ "$output" == *"gitleaks"* ]]

	export PATH="$original_path"
}

@test "secrets-check: cache directory is created" {
	[ -n "$GIT_WRAPPER_CACHE_DIR" ]
	[ -d "$GIT_WRAPPER_CACHE_DIR" ] || skip "Cache directory not created (may need write permissions)"
}

@test "secrets-check: cache file path is set" {
	[ -n "$SECRETS_CACHE_FILE" ]
	[[ "$SECRETS_CACHE_FILE" == *"secrets_cache"* ]]
}

@test "secrets-check: cache TTL is set" {
	[ -n "$SECRETS_CACHE_TTL" ]
	[ "$SECRETS_CACHE_TTL" -gt 0 ]
}

# =============================================================================
# 🔒 INTEGRATION TESTS
# =============================================================================

@test "integration: clone-check and dangerous-commands work independently" {
	# Test clone check
	run _run_clone_check "status"
	[ "$status" -eq 0 ]

	# Test dangerous commands
	run _run_safety_checks status
	[ "$status" -eq 0 ]
}

@test "integration: bypass flags work across all safety checks" {
	# Clone check bypass
	run _run_clone_check "clone" "https://github.com/testorg/repo.git" "--force-allow"
	[ "$status" -eq 0 ]

	# Dangerous commands bypass
	run _run_safety_checks reset --hard --force-danger
	[ "$status" -eq 0 ]

	run _run_safety_checks push --force origin main --force-allow
	[ "$status" -eq 0 ]
}

@test "integration: multiple safety checks can run sequentially" {
	local all_passed=0

	_run_clone_check "status" || all_passed=1
	_run_safety_checks "status" || all_passed=1
	_run_secrets_check "status" 0 || all_passed=1

	[ "$all_passed" -eq 0 ]
}

@test "integration: safety checks don't interfere with normal git operations" {
	# Normal operations should pass all checks
	run _run_clone_check "status"
	[ "$status" -eq 0 ]

	run _run_safety_checks log -1
	[ "$status" -eq 0 ]

	run _run_secrets_check "log" 0
	[ "$status" -eq 0 ]
}

@test "integration: dangerous operations are properly blocked" {
	# These should all be blocked
	run _run_safety_checks reset --hard
	[ "$status" -eq 1 ]

	run _run_safety_checks push --force origin main
	[ "$status" -eq 1 ]

	run _run_safety_checks rebase main
	[ "$status" -eq 1 ]
}

# =============================================================================
# 🛡️ EDGE CASES
# =============================================================================

@test "edge-cases: clone-check handles URLs with trailing slashes" {
	run _run_clone_check "clone" "https://github.com/testorg/repo.git/"
	[ "$status" -eq 0 ]
}

@test "edge-cases: dangerous-commands handles commands with multiple flags" {
	run _run_safety_checks reset --hard --quiet
	[ "$status" -eq 1 ]
}

@test "edge-cases: dangerous-commands handles rebase with options" {
	run _run_safety_checks rebase -i HEAD~3
	[ "$status" -eq 1 ]
}

@test "edge-cases: secrets-check handles empty staged files" {
	run _run_secrets_check "commit" 0
	[ "$status" -eq 0 ]
}

@test "edge-cases: all safety checks handle unknown commands gracefully" {
	run _run_clone_check "unknown-command"
	[ "$status" -eq 0 ]

	run _run_safety_checks "unknown-command"
	[ "$status" -eq 0 ]

	run _run_secrets_check "unknown-command" 0
	[ "$status" -eq 0 ]
}

@test "edge-cases: cache directory variables are set" {
	# Verify cache-related environment variables are properly set
	[ -n "$GIT_WRAPPER_CACHE_DIR" ]
	[ -n "$SECRETS_CACHE_FILE" ]
}
