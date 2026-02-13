#!/usr/bin/env bats
# =============================================================================
# 🧪 GIT HOOKS STATUS MODULE TESTS
# =============================================================================
# Tests for lib/welcome/git-hooks-status.sh - Git hooks and validator checks
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
    
    # Source command-cache for command_exists
    source "$SHELL_CONFIG_DIR/lib/core/command-cache.sh"
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# 📁 FILE EXISTENCE TESTS
# =============================================================================

@test "git-hooks-status.sh exists" {
    [ -f "$WELCOME_DIR/git-hooks-status.sh" ]
}

@test "git-hooks-status.sh sources without error" {
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
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        source '$SHELL_CONFIG_DIR/lib/core/command-cache.sh'
        source '$WELCOME_DIR/git-hooks-status.sh'
    "
    [ "$status" -eq 0 ]
}

# =============================================================================
# 🔍 VALIDATOR PATH TESTS (Regression tests for PR #71 fix)
# =============================================================================

@test "syntax-validator.sh exists at correct path (core subdirectory)" {
    # Regression test: validator was incorrectly expected at root level
    [ -f "$SHELL_CONFIG_DIR/lib/validation/validators/core/syntax-validator.sh" ]
}

@test "file-validator.sh exists at correct path (core subdirectory)" {
    # Regression test: validator was incorrectly expected at root level
    [ -f "$SHELL_CONFIG_DIR/lib/validation/validators/core/file-validator.sh" ]
}

@test "security-validator.sh exists at correct path (security subdirectory)" {
    # Regression test: validator was incorrectly expected at root level
    [ -f "$SHELL_CONFIG_DIR/lib/validation/validators/security/security-validator.sh" ]
}

@test "sensitive-files-validator.sh exists at correct path (security subdirectory)" {
    # Regression test: validator was incorrectly expected at hooks directory
    [ -f "$SHELL_CONFIG_DIR/lib/validation/validators/security/sensitive-files-validator.sh" ]
}

@test "workflow-validator.sh exists at correct path (infra subdirectory)" {
    # Regression test: validator was incorrectly expected at root level
    [ -f "$SHELL_CONFIG_DIR/lib/validation/validators/infra/workflow-validator.sh" ]
}

@test "infra-validator.sh exists at correct path (infra subdirectory)" {
    # Regression test: validator was incorrectly expected at root level
    [ -f "$SHELL_CONFIG_DIR/lib/validation/validators/infra/infra-validator.sh" ]
}

@test "validation-loop.sh exists at correct path (git/shared)" {
    [ -f "$SHELL_CONFIG_DIR/lib/git/shared/validation-loop.sh" ]
}

@test "gha-scan exists at correct path" {
    [ -f "$SHELL_CONFIG_DIR/lib/bin/gha-scan" ]
}

# =============================================================================
# ✅ CHECK FUNCTION TESTS
# =============================================================================

@test "_gh_check_syntax_validator returns success when file exists" {
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _gh_check_syntax_validator
    [ "$status" -eq 0 ]
}

@test "_gh_check_file_validator returns success when file exists" {
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _gh_check_file_validator
    [ "$status" -eq 0 ]
}

@test "_gh_check_security_validator returns success when file exists" {
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _gh_check_security_validator
    [ "$status" -eq 0 ]
}

@test "_gh_check_workflow_validator returns success when file exists" {
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _gh_check_workflow_validator
    [ "$status" -eq 0 ]
}

@test "_gh_check_infra_validator returns success when file exists" {
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _gh_check_infra_validator
    [ "$status" -eq 0 ]
}

@test "_gh_check_file_length returns success when validator exists" {
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _gh_check_file_length
    [ "$status" -eq 0 ]
}

@test "_gh_check_sensitive_files returns success when validator exists" {
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _gh_check_sensitive_files
    [ "$status" -eq 0 ]
}

@test "_gh_check_validation_loop returns success when file exists" {
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _gh_check_validation_loop
    [ "$status" -eq 0 ]
}

@test "_gh_check_gha_scanner returns success when file exists" {
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _gh_check_gha_scanner
    [ "$status" -eq 0 ]
}

# =============================================================================
# 🛠️ TOOL CHECK TESTS
# =============================================================================

@test "_gh_check_shellcheck detects installed shellcheck" {
    skip_if_no_command shellcheck
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _gh_check_shellcheck
    [ "$status" -eq 0 ]
}

@test "_gh_check_gitleaks detects installed gitleaks" {
    skip_if_no_command gitleaks
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _gh_check_gitleaks
    [ "$status" -eq 0 ]
}

@test "_gh_check_actionlint detects installed actionlint" {
    skip_if_no_command actionlint
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _gh_check_actionlint
    [ "$status" -eq 0 ]
}

# =============================================================================
# 🎨 DISPLAY TESTS
# =============================================================================

@test "_welcome_show_git_hooks_status outputs grid format" {
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _welcome_show_git_hooks_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Git Hooks"* ]] || [[ "$output" == *"🪝"* ]]
}

@test "_welcome_show_git_hooks_status shows validators section" {
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _welcome_show_git_hooks_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"validators"* ]] || [[ "$output" == *"🔍"* ]]
}

@test "_welcome_show_git_hooks_status shows hooks section" {
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    run _welcome_show_git_hooks_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"hooks"* ]] || [[ "$output" == *"pre-commit"* ]]
}

# =============================================================================
# 🔒 HOOK SYMLINK TESTS (only if hooks are installed)
# =============================================================================

@test "git hooks are symlinked to shell-config" {
    local hooks_dir="$HOME/.githooks"
    
    # Skip if hooks dir doesn't exist
    [ -d "$hooks_dir" ] || skip "Git hooks not installed"
    
    source "$WELCOME_DIR/git-hooks-status.sh"
    
    # At least one hook should be configured
    local hook_count=0
    for hook in pre-commit commit-msg prepare-commit-msg post-commit pre-push pre-merge-commit post-merge; do
        if [[ -L "$hooks_dir/$hook" ]]; then
            ((hook_count++))
        fi
    done
    
    [ "$hook_count" -gt 0 ]
}
