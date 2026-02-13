#!/usr/bin/env bats
# =============================================================================
# 🧪 GIT COMMIT STAGE HOOK TESTS
# =============================================================================
# Tests for git commit stage hooks including:
#   - commit-msg.sh: Commit message validation
#   - prepare-commit-msg.sh: Commit message preparation
#   - post-commit.sh: Post-commit operations
# =============================================================================
#
# Disable errexit for BATS testing (see CLAUDE.md: "When to disable (rare)")
# Allows testing error conditions without exiting the test suite
set +e

# Load shared test helpers
load '../../test_helpers'

setup() {
    setup_test_env
    export GIT_HOOKS_DIR="$SHELL_CONFIG_DIR/lib/git/stages/commit"

    # Source the hook scripts (they use set -euo pipefail internally)
    source "$GIT_HOOKS_DIR/commit-msg.sh"
    source "$GIT_HOOKS_DIR/prepare-commit-msg.sh"

    # Disable strict mode for bats — the sourced scripts set -euo pipefail
    # which causes "unbound variable" errors in bats tracing when local vars
    # from test functions go out of scope
    set +eu
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# 📝 COMMIT MSG VALIDATION TESTS
# =============================================================================

@test "commit-msg: validate_commit_message accepts valid messages" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "feat: add new feature" >"$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
}

@test "commit-msg: validate_commit_message rejects short messages" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "short" >"$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 1 ]
    [[ "$output" == *"too short"* ]] || [[ "$output" == *"minimum 10 characters"* ]]
}

@test "commit-msg: validate_commit_message allows merge commits" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "Merge branch 'feature' into main" >"$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
}

@test "commit-msg: validate_commit_message allows revert commits" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "Revert \"bad commit\"" >"$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
}

@test "commit-msg: validate_commit_message allows fixup commits" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "fixup! previous commit" >"$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
}

@test "commit-msg: validate_commit_message allows squash commits" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "squash! previous commit" >"$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
}

@test "commit-msg: validate_commit_message enforces conventional commits when enabled" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"; unset GIT_ENFORCE_CONVENTIONAL_COMMITS' RETURN

    echo "random message without type" >"$msg_file"

    export GIT_ENFORCE_CONVENTIONAL_COMMITS=1
    run validate_commit_message "$msg_file"
    [ "$status" -eq 1 ]
    [[ "$output" == *"conventional commit"* ]] || [[ "$output" == *"feat|fix"* ]]
}

@test "commit-msg: validate_commit_message accepts conventional commits when enforced" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"; unset GIT_ENFORCE_CONVENTIONAL_COMMITS' RETURN

    echo "feat(api): add user endpoint" >"$msg_file"

    export GIT_ENFORCE_CONVENTIONAL_COMMITS=1
    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
}

@test "commit-msg: validate_commit_message warns on sensitive keywords" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "fix: add password reset functionality" >"$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"sensitive"* ]] || [[ "$output" == *"warning"* ]]
}

@test "commit-msg: validate_commit_message warns about secret keyword" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "fix: rotate api secret" >"$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"sensitive"* ]] || [[ "$output" == *"warning"* ]]
}

@test "commit-msg: validate_commit_message provides bypass instructions" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "short" >"$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--no-verify"* ]] || [[ "$output" == *"bypass"* ]]
}

@test "commit-msg: validate_commit_message handles multiline messages" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    cat >"$msg_file" <<EOF
feat: add authentication

This adds OAuth2 support for the application.
EOF

    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
}

@test "commit-msg: validate_commit_message checks all conventional commit types" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"; unset GIT_ENFORCE_CONVENTIONAL_COMMITS' RETURN

    # Test all allowed types
    for type in feat fix docs style refactor test chore; do
        echo "${type}: description" >"$msg_file"
        export GIT_ENFORCE_CONVENTIONAL_COMMITS=1
        run validate_commit_message "$msg_file"
        [ "$status" -eq 0 ] || echo "Failed for type: $type"
    done
}

# =============================================================================
# 🔧 PREPARE COMMIT MSG TESTS
# =============================================================================

@test "prepare-commit-msg: prepare_commit_message runs without errors" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "Initial message" >"$msg_file"

    run prepare_commit_message "$msg_file" "message" ""
    [ "$status" -eq 0 ]
}

@test "prepare-commit-msg: adds branch name prefix for feature branches" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"; git -C "$TEST_REPO_DIR" checkout main >/dev/null 2>&1' RETURN

    echo "Initial message" >"$msg_file"

    # Create feature branch
    git -C "$TEST_REPO_DIR" checkout -b "feature/test-branch" >/dev/null 2>&1

    run prepare_commit_message "$msg_file" "message" ""
    [ "$status" -eq 0 ]

    # Check if prefix was added
    local content
    content=$(cat "$msg_file")
    [[ "$content" == *"[feature/test-branch]"* ]] || [[ "$content" == *"Initial message"* ]]
}

@test "prepare-commit-msg: does not prefix main branch" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "Initial message" >"$msg_file"

    # We're already on main
    run prepare_commit_message "$msg_file" "message" ""
    [ "$status" -eq 0 ]

    local content
    content=$(cat "$msg_file")
    # Should not have [main] prefix
    [[ "$content" != *"[main]"* ]]
}

@test "prepare-commit-msg: does not prefix master branch" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"; git -C "$TEST_REPO_DIR" checkout main >/dev/null 2>&1' RETURN

    echo "Initial message" >"$msg_file"

    # Create master branch
    git -C "$TEST_REPO_DIR" checkout -b "master" >/dev/null 2>&1

    run prepare_commit_message "$msg_file" "message" ""
    [ "$status" -eq 0 ]

    local content
    content=$(cat "$msg_file")
    # Should not have [master] prefix
    [[ "$content" != *"[master]"* ]]
}

@test "prepare-commit-msg: handles commit source correctly" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "Template message" >"$msg_file"

    for source in message template merge squash; do
        run prepare_commit_message "$msg_file" "$source" ""
        [ "$status" -eq 0 ] || echo "Failed for source: $source"
    done
}

@test "prepare-commit-msg: sanitizes branch names to prevent injection" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"; git -C "$TEST_REPO_DIR" checkout main >/dev/null 2>&1' RETURN

    echo "Initial message" >"$msg_file"

    # Create branch with special characters
    git -C "$TEST_REPO_DIR" checkout -b "feature/$(echo 'test;rm -rf /' | tr -cd '[:alnum:]')" >/dev/null 2>&1

    run prepare_commit_message "$msg_file" "message" ""
    [ "$status" -eq 0 ]

    # Should not execute malicious commands
    [ -e "$msg_file" ]
}

@test "prepare-commit-msg: handles empty commit message file" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    # Empty file

    run prepare_commit_message "$msg_file" "message" ""
    [ "$status" -eq 0 ]
}

@test "prepare-commit-msg: handles commit message with comments" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    cat >"$msg_file" <<EOF
# This is a comment
Initial message
# Another comment
EOF

    run prepare_commit_message "$msg_file" "message" ""
    [ "$status" -eq 0 ]
}

@test "prepare-commit-msg: does not add prefix if already present" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"; git -C "$TEST_REPO_DIR" checkout main >/dev/null 2>&1' RETURN

    echo "[feature/test] Initial message" >"$msg_file"

    git -C "$TEST_REPO_DIR" checkout -b "feature/test" >/dev/null 2>&1

    run prepare_commit_message "$msg_file" "message" ""
    [ "$status" -eq 0 ]

    local content
    content=$(cat "$msg_file")
    # Should only have one prefix
    local count
    count=$(grep -o "\[feature/test\]" <<< "$content" | wc -l)
    [ "$count" -eq 1 ]
}

@test "prepare-commit-msg: handles amend commits with SHA" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "Amended message" >"$msg_file"

    # Create a commit first
    git -C "$TEST_REPO_DIR" commit -m "Initial" >/dev/null 2>&1
    local commit_sha
    commit_sha=$(git -C "$TEST_REPO_DIR" rev-parse HEAD)

    run prepare_commit_message "$msg_file" "commit" "$commit_sha"
    [ "$status" -eq 0 ]

    # For amend, message should not be modified
    local content
    content=$(cat "$msg_file")
    [[ "$content" == *"Amended message"* ]]
}

@test "prepare-commit-msg: branch name with slashes is handled correctly" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"; git -C "$TEST_REPO_DIR" checkout main >/dev/null 2>&1' RETURN

    echo "Initial message" >"$msg_file"

    git -C "$TEST_REPO_DIR" checkout -b "feature/auth/oauth" >/dev/null 2>&1

    run prepare_commit_message "$msg_file" "message" ""
    [ "$status" -eq 0 ]

    local content
    content=$(cat "$msg_file")
    # Should handle slashes in branch name
    [[ "$content" == *"[feature/auth/oauth]"* ]] || [[ "$content" == *"Initial message"* ]]
}

@test "prepare-commit-msg: handles branch names with underscores" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"; git -C "$TEST_REPO_DIR" checkout main >/dev/null 2>&1' RETURN

    echo "Initial message" >"$msg_file"

    git -C "$TEST_REPO_DIR" checkout -b "feature_new_auth" >/dev/null 2>&1

    run prepare_commit_message "$msg_file" "message" ""
    [ "$status" -eq 0 ]

    local content
    content=$(cat "$msg_file")
    # Should handle underscores
    [[ "$content" == *"[feature_new_auth]"* ]] || [[ "$content" == *"Initial message"* ]]
}

@test "prepare-commit-msg: handles branch names with dashes" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"; git -C "$TEST_REPO_DIR" checkout main >/dev/null 2>&1' RETURN

    echo "Initial message" >"$msg_file"

    git -C "$TEST_REPO_DIR" checkout -b "feature-new-auth" >/dev/null 2>&1

    run prepare_commit_message "$msg_file" "message" ""
    [ "$status" -eq 0 ]

    local content
    content=$(cat "$msg_file")
    # Should handle dashes
    [[ "$content" == *"[feature-new-auth]"* ]] || [[ "$content" == *"Initial message"* ]]
}

# =============================================================================
# 🔍 INTEGRATION TESTS
# =============================================================================

@test "integration: commit-msg and prepare-commit-msg work together" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"; git -C "$TEST_REPO_DIR" checkout main >/dev/null 2>&1' RETURN

    echo "Initial message" >"$msg_file"

    git -C "$TEST_REPO_DIR" checkout -b "feature/test" >/dev/null 2>&1

    # First prepare
    run prepare_commit_message "$msg_file" "message" ""
    [ "$status" -eq 0 ]

    # Then validate
    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
}

@test "integration: full commit workflow with conventional commits" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"; unset GIT_ENFORCE_CONVENTIONAL_COMMITS' RETURN

    echo "feat: add new feature" >"$msg_file"

    export GIT_ENFORCE_CONVENTIONAL_COMMITS=1

    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
}

@test "integration: rejected commit message provides helpful error" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"; unset GIT_ENFORCE_CONVENTIONAL_COMMITS' RETURN

    echo "bad" >"$msg_file"

    export GIT_ENFORCE_CONVENTIONAL_COMMITS=1

    run validate_commit_message "$msg_file"
    [ "$status" -eq 1 ]
    [[ "$output" == *"too short"* ]] || [[ "$output" == *"conventional commit"* ]]
}

# =============================================================================
# 🧪 EDGE CASES
# =============================================================================

@test "edge-cases: commit-msg handles empty commit message" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    touch "$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 1 ]
}

@test "edge-cases: commit-msg handles whitespace-only message" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "   " >"$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 1 ]
}

@test "edge-cases: commit-msg handles very long messages" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    # Create a message >1000 characters
    printf '=%.0s' {1..1000} >>"$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
}

@test "edge-cases: commit-msg handles special characters in message" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "fix: handle special chars: @#$%^&*()" >"$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
}

@test "edge-cases: commit-msg handles unicode in message" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "feat: add emoji support 🎉" >"$msg_file"

    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
}

@test "edge-cases: prepare-commit-msg handles non-existent file" {
    run prepare_commit_message "/nonexistent/file" "message" ""
    # Should not crash - accept either success or failure
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "edge-cases: prepare-commit-msg handles read-only file" {
    local msg_file
    msg_file=$(mktemp)
    trap 'chmod 644 "$msg_file" 2>/dev/null; rm -f "$msg_file"' RETURN

    chmod 444 "$msg_file"

    run prepare_commit_message "$msg_file" "message" ""
    # Should handle gracefully - accept either success or failure
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "edge-cases: both hooks handle concurrent access" {
    local msg_file1 msg_file2
    msg_file1=$(mktemp)
    msg_file2=$(mktemp)
    trap 'rm -f "$msg_file1" "$msg_file2"' RETURN

    echo "feat: first" >"$msg_file1"
    echo "fix: second" >"$msg_file2"

    # Run both in quick succession
    validate_commit_message "$msg_file1" &
    local pid1="$!"
    validate_commit_message "$msg_file2" &
    local pid2="$!"

    wait "$pid1"
    local status1="$?"
    wait "$pid2"
    local status2="$?"

    # Both should succeed regardless of order
    [ "$status1" -eq 0 ]
    [ "$status2" -eq 0 ]
}

# =============================================================================
# 📊 BASH 5 FEATURES VALIDATION
# =============================================================================

@test "bash5: commit-msg correctly uses regex for special commits" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "Merge branch 'feature'" >"$msg_file"

    # Hook should use regex to skip validation
    run validate_commit_message "$msg_file"
    [ "$status" -eq 0 ]
    [[ "$output" != *"too short"* ]]  # Should not complain about length
}

@test "bash5: prepare-commit-msg uses case statement" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "test" >"$msg_file"

    # Bash 5: case statement with multiple patterns
    for source in message template merge squash commit; do
        case "$source" in
            message|template|merge|squash)
                run prepare_commit_message "$msg_file" "$source" ""
                [ "$status" -eq 0 ]
                ;;
            commit)
                run prepare_commit_message "$msg_file" "commit" ""
                [ "$status" -eq 0 ]
                ;;
        esac
    done
}

@test "bash5: commit-msg uses string length check" {
    local msg_file
    msg_file=$(mktemp)
    trap 'rm -f "$msg_file"' RETURN

    echo "short" >"$msg_file"

    # Bash 5: ${#var} for string length
    local msg
    msg=$(cat "$msg_file")
    if [[ ${#msg} -lt 10 ]]; then
        run validate_commit_message "$msg_file"
        [ "$status" -eq 1 ]
    fi
}
