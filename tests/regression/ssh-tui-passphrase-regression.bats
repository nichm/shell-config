#!/usr/bin/env bats
# =============================================================================
# SSH TUI PASSPHRASE REGRESSION TESTS
# =============================================================================
# Prevents regression of: SSH passphrase prompts corrupting TUI tools (Claude
# Code, vim, etc.) when SSH agent is empty and a git subprocess triggers auth.
#
# Root cause: missing UseKeychain yes + no --apple-load-keychain at startup
# means SSH agent is empty and falls back to a terminal passphrase prompt that
# interleaves with TUI rendering and garbles the display.
#
# Fix (three-part):
#   1. UseKeychain yes in ssh-config.example (Host * block)
#   2. ssh-add --apple-load-keychain in lib/core/loaders/ssh.sh at shell startup
#   3. Absolute include path in gitconfig (relative path silently fails via symlink)
# =============================================================================

setup() {
    local repo_root
    repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export SHELL_CONFIG_DIR="$repo_root"
    export SSH_CONFIG_EXAMPLE="$SHELL_CONFIG_DIR/config/ssh-config.example"
}

# --- Template file existence and structure ---

@test "ssh-config.example: file exists and is readable" {
    [ -f "$SSH_CONFIG_EXAMPLE" ]
    [ -r "$SSH_CONFIG_EXAMPLE" ]
}

@test "ssh-config.example: has Host * catch-all block" {
    run grep -q '^Host \*' "$SSH_CONFIG_EXAMPLE"
    [ "$status" -eq 0 ]
}

# --- UseKeychain yes: the key fix ---
# Without this, SSH falls back to a terminal passphrase prompt that corrupts
# TUI apps (Claude Code, etc.) when their subprocesses trigger git/SSH auth.

@test "ssh-config.example: Host * block has UseKeychain yes" {
    run grep -q 'UseKeychain yes' "$SSH_CONFIG_EXAMPLE"
    [ "$status" -eq 0 ]
}

@test "ssh-config.example: UseKeychain yes appears after Host * (correct scope)" {
    local host_line usekeychain_line
    host_line=$(grep -n '^Host \*' "$SSH_CONFIG_EXAMPLE" | head -1 | cut -d: -f1)
    # Match only the indented directive, not comments containing the string
    usekeychain_line=$(grep -n '^ *UseKeychain yes' "$SSH_CONFIG_EXAMPLE" | head -1 | cut -d: -f1)
    [ -n "$host_line" ]
    [ -n "$usekeychain_line" ]
    [ "$usekeychain_line" -gt "$host_line" ]
}

@test "ssh-config.example: AddKeysToAgent yes is present" {
    run grep -q 'AddKeysToAgent yes' "$SSH_CONFIG_EXAMPLE"
    [ "$status" -eq 0 ]
}

# --- gh credential helper: HTTPS auth for GitHub (no SSH key needed) ---

@test "gitconfig: template includes credential helper comment for gh CLI" {
    local gitconfig="$SHELL_CONFIG_DIR/config/gitconfig"
    run grep -q "gh auth git-credential" "$gitconfig"
    [ "$status" -eq 0 ]
}

# --- gitconfig include: absolute path so symlink resolution works ---
# Git resolves [include] path relative to the symlink location (~/) not the
# real file location (~/.shell-config/config/). Relative "gitconfig.local"
# silently fails. Must use the absolute ~/.shell-config/config/gitconfig.local.

@test "gitconfig: include path is absolute (symlink-safe)" {
    local gitconfig="$SHELL_CONFIG_DIR/config/gitconfig"
    # Must NOT be the bare relative form that breaks when symlinked to ~/
    run grep -q '^\s*path = gitconfig\.local$' "$gitconfig"
    [ "$status" -ne 0 ]
}

@test "gitconfig: include path references shell-config directory" {
    local gitconfig="$SHELL_CONFIG_DIR/config/gitconfig"
    run grep -q 'path = .*shell-config.*gitconfig\.local' "$gitconfig"
    [ "$status" -eq 0 ]
}

# --- SSH loader: --apple-load-keychain at startup ---
# Without this, agent is empty on new shells even with UseKeychain yes in config.
# An empty agent causes TUI passphrase prompts when git subprocesses run.

@test "ssh.sh: exists and is readable" {
    local ssh_loader="$SHELL_CONFIG_DIR/lib/core/loaders/ssh.sh"
    [ -f "$ssh_loader" ]
    [ -r "$ssh_loader" ]
}

@test "ssh.sh: has valid bash syntax" {
    local ssh_loader="$SHELL_CONFIG_DIR/lib/core/loaders/ssh.sh"
    run bash -n "$ssh_loader"
    [ "$status" -eq 0 ]
}

@test "ssh.sh: calls --apple-load-keychain to pre-populate agent on macOS" {
    local ssh_loader="$SHELL_CONFIG_DIR/lib/core/loaders/ssh.sh"
    run grep -q 'apple-load-keychain' "$ssh_loader"
    [ "$status" -eq 0 ]
}

@test "ssh.sh: --apple-load-keychain is inside a Darwin/macOS guard" {
    local ssh_loader="$SHELL_CONFIG_DIR/lib/core/loaders/ssh.sh"
    # The call must be guarded by a Darwin or is_macos check to stay cross-platform
    run grep -q 'Darwin\|is_macos' "$ssh_loader"
    [ "$status" -eq 0 ]
}

@test "ssh.sh: does NOT use set -euo pipefail (sourced into interactive shell)" {
    local ssh_loader="$SHELL_CONFIG_DIR/lib/core/loaders/ssh.sh"
    run grep -q '^set -euo pipefail' "$ssh_loader"
    [ "$status" -ne 0 ]
}

@test "ssh.sh: supports SHELL_CONFIG_1PASSWORD_SSH=false opt-out" {
    local ssh_loader="$SHELL_CONFIG_DIR/lib/core/loaders/ssh.sh"
    run grep -q 'SHELL_CONFIG_1PASSWORD_SSH' "$ssh_loader"
    [ "$status" -eq 0 ]
}
