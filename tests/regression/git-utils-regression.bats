#!/usr/bin/env bats
# =============================================================================
# Regression: Git Utils and Logging Fallback Tests
# =============================================================================
# Tests for lib/git/shared/git-utils.sh, lib/core/colors.sh, and
# lib/core/platform.sh
#
# PR #112 review: Removing duplicate functions created hard dependencies.
# - command_exists in git-utils.sh now depends on command-cache.sh
# - log_warning in reporters.sh now depends on colors.sh
# - Missing fallbacks could cause silent failures (violates fail-loudly)
#
# PR #95 review: SSH check unbound variable error with set -u
#
# These tests verify:
# 1. git-utils functions work standalone
# 2. colors.sh logging functions are always available
# 3. Fallback behaviors work when dependencies missing
# 4. Conventional commit type validation
# =============================================================================

setup() {
    export SHELL_CONFIG_DIR
    SHELL_CONFIG_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export GIT_UTILS="$SHELL_CONFIG_DIR/lib/git/shared/git-utils.sh"
    export COLORS="$SHELL_CONFIG_DIR/lib/core/colors.sh"
    export PLATFORM="$SHELL_CONFIG_DIR/lib/core/platform.sh"
    export COMMAND_CACHE="$SHELL_CONFIG_DIR/lib/core/command-cache.sh"
}

# =============================================================================
# Git Utils: Conventional commit types
# =============================================================================

@test "git-utils: validates 'feat' as valid conventional type" {
    run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        unset _GIT_HOOKS_COMMON_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$GIT_UTILS'
        is_valid_conventional_type 'feat'
    "
    [ "$status" -eq 0 ]
}

@test "git-utils: validates 'fix' as valid conventional type" {
    run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        unset _GIT_HOOKS_COMMON_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$GIT_UTILS'
        is_valid_conventional_type 'fix'
    "
    [ "$status" -eq 0 ]
}

@test "git-utils: rejects invalid conventional type" {
    run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        unset _GIT_HOOKS_COMMON_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$GIT_UTILS'
        is_valid_conventional_type 'invalid'
    "
    [ "$status" -eq 1 ]
}

@test "git-utils: validates all standard conventional types" {
    local types=(feat fix docs style refactor perf test chore ci build revert)
    for type in "${types[@]}"; do
        run bash -c "
            export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
            unset _GIT_HOOKS_COMMON_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
            source '$GIT_UTILS'
            is_valid_conventional_type '$type'
        "
        [ "$status" -eq 0 ]
    done
}

@test "git-utils: get_conventional_types_list returns comma-separated list" {
    run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        unset _GIT_HOOKS_COMMON_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$GIT_UTILS'
        get_conventional_types_list
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"feat"* ]]
    [[ "$output" == *"fix"* ]]
    [[ "$output" == *","* ]]
}

# =============================================================================
# Git Utils: Commit message validation
# =============================================================================

@test "git-utils: has_blank_line_after_subject detects blank line" {
    run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        unset _GIT_HOOKS_COMMON_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$GIT_UTILS'
        msg='feat: add feature

body text here'
        has_blank_line_after_subject \"\$msg\"
    "
    [ "$status" -eq 0 ]
}

@test "git-utils: has_blank_line_after_subject detects missing blank line" {
    run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        unset _GIT_HOOKS_COMMON_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$GIT_UTILS'
        msg='feat: add feature
body text without blank line'
        has_blank_line_after_subject \"\$msg\"
    "
    [ "$status" -eq 1 ]
}

@test "git-utils: strip_commit_comments removes comment lines" {
    run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        unset _GIT_HOOKS_COMMON_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$GIT_UTILS'
        msg='feat: add feature
# This is a comment
body text'
        strip_commit_comments \"\$msg\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"feat: add feature"* ]]
    [[ "$output" == *"body text"* ]]
    [[ "$output" != *"# This is a comment"* ]]
}

@test "git-utils: strip_commit_comments handles single-line message" {
    run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        unset _GIT_HOOKS_COMMON_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$GIT_UTILS'
        strip_commit_comments 'fix: simple fix'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"fix: simple fix"* ]]
}

# =============================================================================
# Colors: Logging functions availability (PR #112)
# =============================================================================

@test "colors: defines all logging functions" {
    run bash -c "
        unset _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$COLORS'
        type log_info && type log_success && type log_warning && type log_error && type log_step
    "
    [ "$status" -eq 0 ]
}

@test "colors: log_info produces output" {
    run bash -c "
        unset _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$COLORS'
        log_info 'test message'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"test message"* ]]
}

@test "colors: log_error produces output" {
    run bash -c "
        unset _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$COLORS'
        log_error 'error message'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"error message"* ]]
}

@test "colors: defines all color variables" {
    run bash -c "
        unset _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$COLORS'
        [[ -n \"\$COLOR_RED\" ]] && [[ -n \"\$COLOR_GREEN\" ]] && [[ -n \"\$COLOR_YELLOW\" ]] && [[ -n \"\$COLOR_RESET\" ]]
    "
    [ "$status" -eq 0 ]
}

@test "colors: defines compatibility aliases" {
    run bash -c "
        unset _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$COLORS'
        [[ -n \"\$RED\" ]] && [[ -n \"\$GREEN\" ]] && [[ -n \"\$NC\" ]] && [[ -n \"\$BOLD\" ]]
    "
    [ "$status" -eq 0 ]
}

# =============================================================================
# Git Utils: Fallback behavior when colors.sh missing (PR #112)
# =============================================================================

@test "git-utils: sources colors.sh directly (no inline fallback)" {
    run bash -c "
        # Verify that git-utils.sh sources colors.sh and provides colors
        unset _GIT_HOOKS_COMMON_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$GIT_UTILS'
        # Colors should be defined from sourced colors.sh
        [[ -n \"\$RED\" ]] && [[ -n \"\$GREEN\" ]] && [[ -n \"\$NC\" ]]
    "
    [ "$status" -eq 0 ]
}

@test "git-utils: log functions available from sourced colors.sh" {
    run bash -c "
        unset _GIT_HOOKS_COMMON_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$GIT_UTILS'
        log_warning 'test warning' 2>&1
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"test warning"* ]]
}

# =============================================================================
# Command Cache: Regression tests
# =============================================================================

@test "command-cache: command_exists finds bash" {
    run bash -c "
        unset _SHELL_CONFIG_COMMAND_CACHE_LOADED
        source '$COMMAND_CACHE'
        command_exists bash
    "
    [ "$status" -eq 0 ]
}

@test "command-cache: command_exists rejects nonexistent command" {
    run bash -c "
        unset _SHELL_CONFIG_COMMAND_CACHE_LOADED
        source '$COMMAND_CACHE'
        command_exists totally_nonexistent_command_12345
    "
    [ "$status" -eq 1 ]
}

@test "command-cache: command_exists errors on no arguments" {
    run bash -c "
        unset _SHELL_CONFIG_COMMAND_CACHE_LOADED
        source '$COMMAND_CACHE'
        command_exists
    "
    [ "$status" -eq 2 ]
    [[ "$output" == *"ERROR"* ]]
}

@test "command-cache: cache_clear resets cache" {
    run bash -c "
        unset _SHELL_CONFIG_COMMAND_CACHE_LOADED
        source '$COMMAND_CACHE'
        command_exists bash
        command_cache_clear
        command_cache_stats
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total cached: 0"* ]]
}

# =============================================================================
# Platform: Detection functions
# =============================================================================

@test "platform: detect_os returns a valid OS type" {
    run bash -c "
        unset _SHELL_CONFIG_CORE_PLATFORM_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$PLATFORM'
        os=\$(detect_os)
        [[ \"\$os\" == 'macos' || \"\$os\" == 'linux' || \"\$os\" == 'wsl' || \"\$os\" == 'bsd' || \"\$os\" == 'windows' || \"\$os\" == 'unknown' ]]
    "
    [ "$status" -eq 0 ]
}

@test "platform: is_macos returns true on macOS" {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        skip "Not running on macOS"
    fi
    run bash -c "
        unset _SHELL_CONFIG_CORE_PLATFORM_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$PLATFORM'
        is_macos
    "
    [ "$status" -eq 0 ]
}

@test "platform: detect_architecture returns valid arch" {
    run bash -c "
        unset _SHELL_CONFIG_CORE_PLATFORM_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED
        source '$PLATFORM'
        arch=\$(detect_architecture)
        [[ \"\$arch\" == 'x86_64' || \"\$arch\" == 'arm64' || \"\$arch\" == 'arm' || \"\$arch\" == 'x86' || \"\$arch\" == 'unknown' ]]
    "
    [ "$status" -eq 0 ]
}

@test "platform: exports SC_OS variable" {
    run bash -c "
        unset _SHELL_CONFIG_CORE_PLATFORM_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED SC_OS
        source '$PLATFORM'
        [[ -n \"\$SC_OS\" ]]
    "
    [ "$status" -eq 0 ]
}

@test "platform: exports SC_ARCH variable" {
    run bash -c "
        unset _SHELL_CONFIG_CORE_PLATFORM_LOADED _SHELL_CONFIG_CORE_COLORS_LOADED SC_ARCH
        source '$PLATFORM'
        [[ -n \"\$SC_ARCH\" ]]
    "
    [ "$status" -eq 0 ]
}
