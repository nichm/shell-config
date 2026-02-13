#!/usr/bin/env bats
# =============================================================================
# Regression: Protected Paths Tests
# =============================================================================
# Tests for lib/core/protected-paths.sh
#
# PR #113 review: Gemini found weak assertions that accepted both status 0
# and status 1 for path traversal detection. Tests should strictly verify
# that protection blocks dangerous paths.
#
# Also found rm_wrapper test name contradicted implementation, and assertions
# allowed "No such file" errors to mask protection logic failures.
#
# These tests use strict assertions to prevent protection bypass.
# =============================================================================

setup() {
    export SHELL_CONFIG_DIR
    SHELL_CONFIG_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export PROTECTED_PATHS_LIB="$SHELL_CONFIG_DIR/lib/core/protected-paths.sh"

    # Create temp directory for test artifacts
    export TEST_TMPDIR="$BATS_TEST_TMPDIR/protected_paths_$$"
    mkdir -p "$TEST_TMPDIR"
}

teardown() {
    cd "$BATS_TEST_DIRNAME" || return 1
    /bin/rm -rf "$TEST_TMPDIR"
}

# --- Core protection (strict assertions) ---

@test "protected-paths: blocks ~/.ssh with status 0" {
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        get_protected_path_type \"\$HOME/.ssh\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "protected-path" ]
}

@test "protected-paths: blocks ~/.ssh subdirectories" {
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        get_protected_path_type \"\$HOME/.ssh/id_rsa\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "protected-path" ]
}

@test "protected-paths: blocks ~/.gnupg" {
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        get_protected_path_type \"\$HOME/.gnupg\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "protected-path" ]
}

@test "protected-paths: blocks ~/.config directory" {
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        get_protected_path_type \"\$HOME/.config\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "protected-path" ]
}

@test "protected-paths: identifies config files when not symlinked" {
    # Create real (non-symlinked) config files to test pattern matching
    # Note: On systems where .zshrc is symlinked, readlink -f resolves the
    # symlink and the resolved path won't match $HOME/.zshrc. This is a known
    # limitation documented in PR #113 review.
    local test_home="$TEST_TMPDIR/fakehome"
    mkdir -p "$test_home"
    touch "$test_home/.zshrc"
    run bash -c "
        export HOME='$test_home'
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        get_protected_path_type '$test_home/.zshrc'
    "
    [ "$status" -eq 0 ]
    [ "$output" = "config-file" ]
}

@test "protected-paths: identifies .bashrc as config file when not symlinked" {
    local test_home="$TEST_TMPDIR/fakehome"
    mkdir -p "$test_home"
    touch "$test_home/.bashrc"
    run bash -c "
        export HOME='$test_home'
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        get_protected_path_type '$test_home/.bashrc'
    "
    [ "$status" -eq 0 ]
    [ "$output" = "config-file" ]
}

@test "protected-paths: identifies .gitconfig as config file when not symlinked" {
    local test_home="$TEST_TMPDIR/fakehome"
    mkdir -p "$test_home"
    touch "$test_home/.gitconfig"
    run bash -c "
        export HOME='$test_home'
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        get_protected_path_type '$test_home/.gitconfig'
    "
    [ "$status" -eq 0 ]
    [ "$output" = "config-file" ]
}

@test "protected-paths: blocks macOS system paths" {
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        get_protected_path_type /System
    "
    [ "$status" -eq 0 ]
    [ "$output" = "macos-system-path" ]
}

@test "protected-paths: blocks /Applications" {
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        get_protected_path_type /Applications
    "
    [ "$status" -eq 0 ]
    [ "$output" = "macos-system-path" ]
}

@test "protected-paths: blocks Unix system paths" {
    for path in / /etc /usr /var /bin /sbin; do
        run bash -c "
            unset _CORE_PROTECTED_PATHS_LOADED
            source '$PROTECTED_PATHS_LIB'
            get_protected_path_type '$path'
        "
        [ "$status" -eq 0 ]
        [ "$output" = "system-path" ]
    done
}

# --- Traversal prevention regression (PR #113) ---

@test "SECURITY: blocks path traversal with .." {
    # PR #113: Assertion was too weak (accepted both 0 and 1)
    # Must STRICTLY return 0 (blocked) for traversal attempts
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        get_protected_path_type '/tmp/../../etc/passwd'
    "
    # Should be blocked - either as system-path (after resolution) or protected-path
    [ "$status" -eq 0 ]
}

@test "SECURITY: blocks paths with .. when readlink fails" {
    # If readlink fails AND path contains .., should block to prevent bypass
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        # Non-existent path with traversal that readlink can't resolve
        result=\$(get_protected_path_type '/nonexistent/../../../etc/passwd')
        echo \"result=\$result\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"protected-path"* ]]
}

# --- Temporary paths should NOT be blocked ---

@test "protected-paths: allows /tmp paths" {
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        get_protected_path_type /tmp/test-file.txt
    "
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "protected-paths: allows /var/folders (macOS temp)" {
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        get_protected_path_type /var/folders/xx/test
    "
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

# --- Flag skipping ---

@test "protected-paths: skips flags (starting with -)" {
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        get_protected_path_type '-rf'
    "
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

# --- is_protected convenience wrapper ---

@test "protected-paths: is_protected returns 0 for protected paths" {
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        is_protected \"\$HOME/.ssh\"
    "
    [ "$status" -eq 0 ]
}

@test "protected-paths: is_protected returns 1 for safe paths" {
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        is_protected /tmp/safe-file.txt
    "
    [ "$status" -eq 1 ]
}

@test "protected-paths: is_protected produces no stdout output" {
    run bash -c "
        unset _CORE_PROTECTED_PATHS_LOADED
        source '$PROTECTED_PATHS_LIB'
        is_protected \"\$HOME/.ssh\"
    "
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
