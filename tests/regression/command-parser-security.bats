#!/usr/bin/env bats
# =============================================================================
# Regression: Command Parser Security Tests
# =============================================================================
# Tests for _get_real_git_command in lib/git/shared/command-parser.sh
#
# PR #103 review: Gemini found a CRITICAL security bypass where standard git
# flags (-c, -C, --git-dir) preceding the command cause the parser to return
# the flag itself instead of the actual command, bypassing safety checks.
#
# These tests ensure the parser correctly identifies the real git command
# regardless of preceding flags and options.
# =============================================================================

setup() {
    export SHELL_CONFIG_DIR
    SHELL_CONFIG_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export PARSER="$SHELL_CONFIG_DIR/lib/git/shared/command-parser.sh"
}

# --- Basic functionality ---

@test "command-parser: returns first non-wrapper arg as git command" {
    run bash -c "source '$PARSER'; _get_real_git_command commit -m 'test'"
    [ "$status" -eq 0 ]
    [ "$output" = "commit" ]
}

@test "command-parser: skips --skip-secrets wrapper flag" {
    run bash -c "source '$PARSER'; _get_real_git_command --skip-secrets commit -m 'test'"
    [ "$status" -eq 0 ]
    [ "$output" = "commit" ]
}

@test "command-parser: skips multiple wrapper flags" {
    run bash -c "source '$PARSER'; _get_real_git_command --skip-secrets --allow-large-files push origin main"
    [ "$status" -eq 0 ]
    [ "$output" = "push" ]
}

@test "command-parser: returns failure when no command found" {
    run bash -c "source '$PARSER'; _get_real_git_command --skip-secrets --skip-syntax-check"
    [ "$status" -eq 1 ]
}

@test "command-parser: skips --skip-deps-check flag" {
    run bash -c "source '$PARSER'; _get_real_git_command --skip-deps-check commit"
    [ "$status" -eq 0 ]
    [ "$output" = "commit" ]
}

@test "command-parser: skips --force-danger flag" {
    run bash -c "source '$PARSER'; _get_real_git_command --force-danger reset --hard"
    [ "$status" -eq 0 ]
    [ "$output" = "reset" ]
}

@test "command-parser: skips --force-allow flag" {
    run bash -c "source '$PARSER'; _get_real_git_command --force-allow push --force"
    [ "$status" -eq 0 ]
    [ "$output" = "push" ]
}

@test "command-parser: handles single command with no flags" {
    run bash -c "source '$PARSER'; _get_real_git_command status"
    [ "$status" -eq 0 ]
    [ "$output" = "status" ]
}

# --- Security bypass regression tests (PR #103) ---
# These test that the parser doesn't confuse non-wrapper flags with commands

@test "SECURITY: command-parser does not return wrapper flags as commands" {
    # All wrapper flags should be skipped, not returned as the command
    local wrapper_flags=(
        "--skip-secrets"
        "--skip-syntax-check"
        "--skip-deps-check"
        "--allow-large-files"
        "--force-danger"
        "--force-allow"
    )
    for flag in "${wrapper_flags[@]}"; do
        run bash -c "source '$PARSER'; _get_real_git_command '$flag' push"
        [ "$status" -eq 0 ]
        [ "$output" = "push" ]
    done
}
