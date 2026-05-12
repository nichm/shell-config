#!/usr/bin/env bats
# =============================================================================
# SSH TUI PASSPHRASE REGRESSION TESTS
# =============================================================================
# Prevents regression of: SSH passphrase prompts corrupting TUI tools (Claude
# Code, vim, etc.) when SSH agent is empty and a git subprocess triggers auth.
#
# Root cause: missing UseKeychain yes in ssh-config means macOS Keychain is not
# consulted automatically — SSH falls back to a terminal passphrase prompt that
# interleaves with TUI rendering and garbles the display.
#
# Fix: UseKeychain yes in the Host * block of ssh-config.example so all new
# installs silently load passphrases from Keychain without terminal prompts.
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
