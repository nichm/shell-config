#!/usr/bin/env bats
# =============================================================================
# Tests for lib/core/protected-paths.sh
# =============================================================================

load ../test_helpers

setup() {
    setup_test_env

    local repo_root
    repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export SHELL_CONFIG_DIR="$repo_root"

    # Source the protected paths module
    source "$SHELL_CONFIG_DIR/lib/core/protected-paths.sh"
}

teardown() {
    cleanup_test_env
}

@test "is_protected blocks ~/.ssh deletion" {
    run is_protected "$HOME/.ssh"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks ~/.ssh/* deletion" {
    run is_protected "$HOME/.ssh/config"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks ~/.gnupg deletion" {
    run is_protected "$HOME/.gnupg"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks ~/.gnupg/* deletion" {
    run is_protected "$HOME/.gnupg/gpg.conf"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks ~/.shell-config deletion" {
    run is_protected "$HOME/.shell-config"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks ~/.shell-config/* deletion" {
    run is_protected "$HOME/.shell-config/lib"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks ~/.config deletion" {
    run is_protected "$HOME/.config"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks ~/.config/* deletion" {
    run is_protected "$HOME/.config/nvim"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks ~/.zshrc deletion" {
    run is_protected "$HOME/.zshrc"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks ~/.bashrc deletion" {
    run is_protected "$HOME/.bashrc"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks ~/.gitconfig deletion" {
    run is_protected "$HOME/.gitconfig"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks /etc deletion" {
    run is_protected "/etc"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks /usr deletion" {
    run is_protected "/usr"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks / deletion" {
    run is_protected "/"
    [ "$status" -eq 0 ]
}

@test "is_protected blocks macOS system paths" {
    run is_protected "/System"
    [ "$status" -eq 0 ]

    run is_protected "/Library"
    [ "$status" -eq 0 ]

    run is_protected "/Applications"
    [ "$status" -eq 0 ]
}

@test "is_protected allows regular files in home" {
    run is_protected "$HOME/Documents/file.txt"
    [ "$status" -eq 1 ]

    run is_protected "$HOME/Downloads/file.zip"
    [ "$status" -eq 1 ]
}

@test "is_protected allows /tmp deletion" {
    run is_protected "/tmp/file"
    [ "$status" -eq 1 ]
}

@test "is_protected skips flags" {
    run is_protected "-f"
    [ "$status" -eq 1 ]

    run is_protected "-rf"
    [ "$status" -eq 1 ]

    run is_protected "--force"
    [ "$status" -eq 1 ]
}

@test "get_protected_path_type returns protected-path for ~/.ssh" {
    run get_protected_path_type "$HOME/.ssh"
    [ "$status" -eq 0 ]
    [ "$output" = "protected-path" ]
}

@test "get_protected_path_type returns config-file for ~/.zshrc" {
    run get_protected_path_type "$HOME/.zshrc"
    [ "$status" -eq 0 ]
    [ "$output" = "config-file" ]
}

@test "get_protected_path_type returns system-path for /etc" {
    run get_protected_path_type "/etc"
    [ "$status" -eq 0 ]
    [ "$output" = "system-path" ]
}

@test "get_protected_path_type returns macos-system-path for /System" {
    run get_protected_path_type "/System"
    [ "$status" -eq 0 ]
    [ "$output" = "macos-system-path" ]
}

@test "get_protected_path_type returns non-zero for unprotected paths" {
    run get_protected_path_type "$HOME/Documents/file.txt"
    [ "$status" -eq 1 ]
    [ "$output" = "" ]
}

@test "is_protected is a wrapper that discards output" {
    run is_protected "$HOME/.ssh"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "PROTECTED_SSH_DIR constant is defined" {
    [ -n "${PROTECTED_SSH_DIR:-}" ]
    [ "$PROTECTED_SSH_DIR" = "$HOME/.ssh" ]
}

@test "PROTECTED_GNUPG_DIR constant is defined" {
    [ -n "${PROTECTED_GNUPG_DIR:-}" ]
    [ "$PROTECTED_GNUPG_DIR" = "$HOME/.gnupg" ]
}

@test "PROTECTED_SHELL_CONFIG_DIR constant is defined" {
    [ -n "${PROTECTED_SHELL_CONFIG_DIR:-}" ]
    [ "$PROTECTED_SHELL_CONFIG_DIR" = "$HOME/.shell-config" ]
}

@test "PROTECTED_CONFIG_DIR constant is defined" {
    [ -n "${PROTECTED_CONFIG_DIR:-}" ]
    [ "$PROTECTED_CONFIG_DIR" = "$HOME/.config" ]
}

# =============================================================================
# 🔒 CRITICAL: Symlink Resolution Tests
# =============================================================================

@test "is_protected resolves symlinks to ~/.ssh" {
    # Use real (non-mocked) HOME for symlink tests — the mocked HOME under
    # /tmp gets resolved to /private/tmp by readlink -f on macOS, causing
    # path mismatches against $HOME in get_protected_path_type
    local real_home
    real_home="$(eval echo ~"$USER")"
    local link_path="$TEST_TEMP_DIR/test_ssh_link"
    ln -s "$real_home/.ssh" "$link_path"

    HOME="$real_home" run get_protected_path_type "$link_path"
    [ "$status" -eq 0 ]
    [ "$output" = "protected-path" ]

    /bin/rm "$link_path"
}

@test "is_protected resolves symlinks to /etc" {
    local link_path="$TEST_TEMP_DIR/test_etc_link"
    ln -s "/etc" "$link_path"

    run get_protected_path_type "$link_path"
    [ "$status" -eq 0 ]
    [ "$output" = "system-path" ]

    /bin/rm "$link_path"
}

@test "is_protected resolves symlink chains to protected paths" {
    local real_home
    real_home="$(eval echo ~"$USER")"
    local link1="$TEST_TEMP_DIR/link1"
    local link2="$TEST_TEMP_DIR/link2"

    # Create chain: link2 -> link1 -> ~/.ssh
    ln -s "$real_home/.ssh" "$link1"
    ln -s "$link1" "$link2"

    HOME="$real_home" run get_protected_path_type "$link2"
    [ "$status" -eq 0 ]
    [ "$output" = "protected-path" ]

    /bin/rm "$link1" "$link2"
}

@test "is_protected handles circular symlinks safely" {
    local link1="$TEST_TEMP_DIR/circular1"
    local link2="$TEST_TEMP_DIR/circular2"

    # Create circular symlink: link1 -> link2 -> link1
    ln -s "$link2" "$link1"
    ln -s "$link1" "$link2"

    # Should not hang or crash - readlink -f detects cycles
    run get_protected_path_type "$link1"
    # readlink -f behavior varies: GNU coreutils detects cycles, BSD may not
    # Should either return failure (cycle detected) or non-zero
    [ "$status" -ne 0 ]

    rm "$link1" "$link2"
}

# =============================================================================
# 🔒 CRITICAL: Directory Traversal Prevention Tests
# =============================================================================

@test "is_protected blocks directory traversal with .. to protected paths" {
    # Test path with .. that resolves to protected directory
    # This should be detected as protected after resolution
    run get_protected_path_type "$TEST_TEMP_DIR/../../$HOME/.ssh"
    # Should reliably detect this as a protected path (directory traversal attack)
    [ "$status" -eq 0 ]
    [ "$output" = "protected-path" ]
}

@test "is_protected blocks suspicious paths with .. when readlink fails" {
    # Create a suspicious path with .. that doesn't exist (readlink will fail)
    # The function should block this to prevent bypass attempts
    local suspicious_path="/tmp/nonexistent/../home/.ssh"
    run get_protected_path_type "$suspicious_path"
    # Should block to prevent potential bypass
    [ "$status" -eq 0 ]
    [ "$output" = "protected-path" ]
}

# =============================================================================
# 🔒 CRITICAL: Non-Existent Path Pattern Tests
# =============================================================================

@test "is_protected protects non-existent paths matching protected patterns" {
    # Even if the path doesn't exist, the pattern should match
    run get_protected_path_type "$HOME/.ssh/nonexistent_key"
    [ "$status" -eq 0 ]
    [ "$output" = "protected-path" ]
}

@test "is_protected does not protect non-existent arbitrary paths" {
    run is_protected "/nonexistent/path/to/file"
    [ "$status" -eq 1 ]
}

# =============================================================================
# 🧪 EDGE CASE: Relative Path Tests
# =============================================================================

@test "is_protected protects relative .ssh from home directory" {
    # Change to home directory
    local old_pwd="$PWD"
    cd "$HOME" || return 1

    run get_protected_path_type ".ssh"
    [ "$status" -eq 0 ]
    [ "$output" = "protected-path" ]

    cd "$old_pwd" || return 1
}

@test "is_protected protects relative .config from home directory" {
    local old_pwd="$PWD"
    cd "$HOME" || return 1

    run get_protected_path_type ".config"
    [ "$status" -eq 0 ]
    [ "$output" = "protected-path" ]

    cd "$old_pwd" || return 1
}

@test "is_protected does not protect relative paths from other directories" {
    # From temp directory, relative .ssh should not be protected
    local old_pwd="$PWD"
    cd "$TEST_TEMP_DIR" || return 1

    run is_protected ".ssh"
    [ "$status" -eq 1 ]

    cd "$old_pwd" || return 1
}

# =============================================================================
# 🧪 EDGE CASE: macOS-Specific Tests
# =============================================================================

@test "is_protected blocks /private/etc (macOS symlink to /etc)" {
    run get_protected_path_type "/private/etc"
    [ "$status" -eq 0 ]
    [ "$output" = "system-path" ]
}

@test "is_protected blocks /private/var (macOS symlink to /var)" {
    run get_protected_path_type "/private/var"
    [ "$status" -eq 0 ]
    [ "$output" = "system-path" ]
}

@test "is_protected allows macOS temp directories" {
    run is_protected "/var/folders/123"
    [ "$status" -eq 1 ]

    run is_protected "/private/var/folders/456"
    [ "$status" -eq 1 ]
}

@test "is_protected allows macOS private temp directories" {
    run is_protected "/private/tmp/test_file"
    [ "$status" -eq 1 ]
}

# =============================================================================
# 🧪 EDGE CASE: Additional System Paths
# =============================================================================

@test "is_protected blocks /bin subdirectories" {
    run get_protected_path_type "/bin/sh"
    [ "$status" -eq 0 ]
    [ "$output" = "system-path" ]
}

@test "is_protected blocks /sbin subdirectories" {
    run get_protected_path_type "/sbin/ifconfig"
    [ "$status" -eq 0 ]
    [ "$output" = "system-path" ]
}

@test "is_protected blocks /var subdirectories" {
    run get_protected_path_type "/var/log"
    [ "$status" -eq 0 ]
    [ "$output" = "system-path" ]
}

# =============================================================================
# 🔒 SECURITY: Additional Config Files
# =============================================================================

@test "is_protected blocks ~/.zshenv" {
    run get_protected_path_type "$HOME/.zshenv"
    [ "$status" -eq 0 ]
    [ "$output" = "config-file" ]
}

@test "is_protected blocks all four config files with correct type" {
    run get_protected_path_type "$HOME/.zshrc"
    [ "$output" = "config-file" ]

    run get_protected_path_type "$HOME/.zshenv"
    [ "$output" = "config-file" ]

    run get_protected_path_type "$HOME/.bashrc"
    [ "$output" = "config-file" ]

    run get_protected_path_type "$HOME/.gitconfig"
    [ "$output" = "config-file" ]
}
