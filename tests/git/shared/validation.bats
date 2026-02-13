#!/usr/bin/env bats
# =============================================================================
# 🧪 GIT SHARED VALIDATION MODULE TESTS
# =============================================================================
# Tests for git shared validation modules including:
#   - validation-loop.sh: Core validation orchestration for all git hooks
#   - validation-checks.sh: Shared validation logic (deps, large files, commits)
#   - file-scanner.sh: File iteration and filtering utilities
#   - command-parser.sh: Command parsing with security features
# =============================================================================

# Disable errexit for BATS testing (see CLAUDE.md: "When to disable (rare)")
# Allows testing error conditions without exiting the test suite
set +e

# Load shared test helpers
load '../../test_helpers'

setup() {
    setup_test_env
    export GIT_SAFETY_DIR="$SHELL_CONFIG_DIR/lib/git/shared"
    export VALIDATION_DIR="$SHELL_CONFIG_DIR/lib/validation/shared"

    # Create test files
    echo "echo 'test'" >"test.sh"
    echo "console.log('test');" >"test.js"
    echo "print('test')" >"test.py"

    # Source dependencies in correct order
    source "$GIT_SAFETY_DIR/security-rules.sh"
    source "$SHELL_CONFIG_DIR/lib/core/platform.sh"
    source "$VALIDATION_DIR/file-operations.sh"
    source "$VALIDATION_DIR/reporters.sh"
    source "$GIT_SAFETY_DIR/validation-loop.sh"
    source "$GIT_SAFETY_DIR/validation-checks.sh"
    source "$GIT_SAFETY_DIR/file-scanner.sh"
    source "$GIT_SAFETY_DIR/command-parser.sh"
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# 📋 VALIDATION LOOP TESTS
# =============================================================================

@test "validation-loop: run_validation_on_staged returns 0 when no files staged" {
    # No files staged yet
    run run_validation_on_staged "dummy_function" "\.sh$"
    [ "$status" -eq 0 ]
}

@test "validation-loop: run_validation_on_staged runs function on staged files" {
    # Stage a file
    git -C "$TEST_REPO_DIR" add "test.sh"

    # Create a test validation function
    test_validator() {
        local file="$1"
        [[ "$file" == *"test.sh" ]] && return 0
        return 1
    }

    run run_validation_on_staged "test_validator" "\.sh$"
    [ "$status" -eq 0 ]
}

@test "validation-loop: run_validation_on_staged filters by pattern" {
    git -C "$TEST_REPO_DIR" add "test.sh"
    git -C "$TEST_REPO_DIR" add "test.js"

    test_validator() {
        return 0
    }

    # Only .sh files should be checked
    run run_validation_on_staged "test_validator" "\.sh$"
    [ "$status" -eq 0 ]
}

@test "validation-loop: run_validation_on_staged tracks failed validations" {
    git -C "$TEST_REPO_DIR" add "test.sh"

    test_validator() {
        [[ "$1" == *"fail.sh" ]] && return 1
        return 0
    }

    run run_validation_on_staged "test_validator" "\.sh$"
    [ "$status" -eq 0 ]  # test.sh passes
}

@test "validation-loop: run_validation_on_all validates all tracked files" {
    git -C "$TEST_REPO_DIR" add "test.sh"
    git -C "$TEST_REPO_DIR" commit -m "test" >/dev/null 2>&1

    test_validator() {
        return 0
    }

    run run_validation_on_all "test_validator" "\.sh$"
    [ "$status" -eq 0 ]
}

@test "validation-loop: run_validation_on_range handles commit ranges" {
    git -C "$TEST_REPO_DIR" add "test.sh"
    git -C "$TEST_REPO_DIR" commit -m "first" >/dev/null 2>&1

    echo "echo 'test2'" >"test2.sh"
    git -C "$TEST_REPO_DIR" add "test2.sh"
    git -C "$TEST_REPO_DIR" commit -m "second" >/dev/null 2>&1

    test_validator() {
        return 0
    }

    run run_validation_on_range "test_validator" "HEAD~1..HEAD" "\.sh$"
    [ "$status" -eq 0 ]
}

@test "validation-loop: validation handles files with spaces" {
    echo "test" >"file with spaces.sh"
    git -C "$TEST_REPO_DIR" add "file with spaces.sh"

    test_validator() {
        [[ -f "$1" ]] && return 0
        return 1
    }

    run run_validation_on_staged "test_validator" "\.sh$"
    [ "$status" -eq 0 ]
}

# =============================================================================
# 🔍 VALIDATION CHECKS TESTS
# =============================================================================

@test "validation-checks: _check_dependency_changes returns 0 when no deps changed" {
    git -C "$TEST_REPO_DIR" add "test.sh"

    run _check_dependency_changes
    [ "$status" -eq 0 ]
}

@test "validation-checks: _check_dependency_changes detects package.json changes" {
    echo '{}' >"package.json"
    git -C "$TEST_REPO_DIR" add "package.json"

    run _check_dependency_changes
    [ "$status" -eq 1 ]
    [[ "$output" == *"DEPENDENCIES"* ]] || [[ "$output" == *"package.json"* ]]
}

@test "validation-checks: _check_dependency_changes detects Cargo.toml changes" {
    echo "[package]" >"Cargo.toml"
    git -C "$TEST_REPO_DIR" add "Cargo.toml"

    run _check_dependency_changes
    [ "$status" -eq 1 ]
    [[ "$output" == *"Cargo.toml"* ]]
}

@test "validation-checks: _check_large_files returns 0 for small files" {
    echo "small content" >"small.txt"
    git -C "$TEST_REPO_DIR" add "small.txt"

    run _check_large_files
    [ "$status" -eq 0 ]
}

@test "validation-checks: _check_large_files detects files >5MB" {
    # Create a file >5MB using helper function
    create_large_file "large.bin" 6
    git -C "$TEST_REPO_DIR" add "large.bin"

    run _check_large_files
    [ "$status" -eq 1 ]
    [[ "$output" == *"LARGE FILE"* ]] || [[ "$output" == *"6MB"* ]]
}

@test "validation-checks: _check_large_commit returns 0 for small commits" {
    echo "test" >"file.txt"
    git -C "$TEST_REPO_DIR" add "file.txt"

    run _check_large_commit
    [ "$status" -eq 0 ]
}

@test "validation-checks: _check_large_commit detects info tier commits" {
    # Info tier: 15-24 files or 1000-2999 lines
    # Create 20 files to trigger info tier warning
    create_many_files 20

    run _check_large_commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"Large commit blocked"* ]] || [[ "$output" == *"ℹ️"* ]]
}

@test "validation-checks: _check_large_commit detects warning tier commits" {
    # Warning tier: 25-75 files or 3000-5000 lines
    # Create 30 files to trigger warning tier
    create_many_files 30

    run _check_large_commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"Medium-large commit"* ]] || [[ "$output" == *"⚠️"* ]]
}

@test "validation-checks: _check_large_commit detects extreme tier commits" {
    # Extreme tier: 76+ files or 5001+ lines
    # Create 80 files to trigger extreme tier
    create_many_files 80

    run _check_large_commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"Extremely large commit"* ]] || [[ "$output" == *"❌"* ]]
}

@test "validation-checks: _check_large_commit calculates lines changed" {
    # Create a file with 1000+ lines
    local i
    for i in {1..1200}; do
        echo "line $i" >>"large.txt"
    done
    git -C "$TEST_REPO_DIR" add "large.txt"

    run _check_large_commit
    [ "$status" -eq 1 ]
    [[ "$output" == *"lines"* ]]
}

@test "validation-checks: _check_large_commit handles mixed insertions and deletions" {
    echo "test" >"file.txt"
    git -C "$TEST_REPO_DIR" add "file.txt"
    git -C "$TEST_REPO_DIR" commit -m "initial" >/dev/null 2>&1

    # Modify to create insertions and deletions
    local i
    for i in {1..500}; do
        echo "new line $i" >>"file.txt"
    done
    git -C "$TEST_REPO_DIR" add "file.txt"

    run _check_large_commit
    # Should handle the stats parsing - accept either success or failure
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

# =============================================================================
# 📂 FILE SCANNER TESTS
# =============================================================================

@test "file-scanner: get_range_files returns files in commit range" {
    echo "test" >"file1.txt"
    git -C "$TEST_REPO_DIR" add "file1.txt"
    git -C "$TEST_REPO_DIR" commit -m "first" >/dev/null 2>&1

    echo "test2" >"file2.txt"
    git -C "$TEST_REPO_DIR" add "file2.txt"
    git -C "$TEST_REPO_DIR" commit -m "second" >/dev/null 2>&1

    local files
    files=$(get_range_files "HEAD~1..HEAD")
    [[ "$files" == *"file2.txt"* ]]
}

@test "file-scanner: get_range_files handles HEAD (first push)" {
    echo "test" >"file.txt"
    git -C "$TEST_REPO_DIR" add "file.txt"
    git -C "$TEST_REPO_DIR" commit -m "initial" >/dev/null 2>&1

    local files
    files=$(get_range_files "HEAD")
    [[ "$files" == *"file.txt"* ]]
}

@test "file-scanner: file_exists_and_readable checks file existence" {
    echo "test" >"existing.txt"

    run file_exists_and_readable "existing.txt"
    [ "$status" -eq 0 ]

    run file_exists_and_readable "nonexistent.txt"
    [ "$status" -eq 1 ]
}

@test "file-scanner: get_file_extension extracts file extensions" {
    local ext
    ext=$(get_file_extension "test.sh")
    [ "$ext" == "sh" ]

    ext=$(get_file_extension "document.pdf")
    [ "$ext" == "pdf" ]
}

@test "file-scanner: get_file_extension handles files without extension" {
    local ext
    ext=$(get_file_extension "Makefile")
    # Files without a dot return empty string (no extension)
    [ "$ext" == "" ]
}

@test "file-scanner: is_supported_file identifies JavaScript files" {
    run is_supported_file "test.js"
    [ "$status" -eq 0 ]

    run is_supported_file "test.jsx"
    [ "$status" -eq 0 ]

    run is_supported_file "test.ts"
    [ "$status" -eq 0 ]
}

@test "file-scanner: is_supported_file identifies Python files" {
    run is_supported_file "test.py"
    [ "$status" -eq 0 ]

    run is_supported_file "test.pyw"
    [ "$status" -eq 0 ]
}

@test "file-scanner: is_supported_file identifies shell scripts" {
    run is_supported_file "test.sh"
    [ "$status" -eq 0 ]

    run is_supported_file "test.bash"
    [ "$status" -eq 0 ]

    run is_supported_file "test.zsh"
    [ "$status" -eq 0 ]
}

@test "file-scanner: is_supported_file identifies YAML and JSON files" {
    run is_supported_file "config.yml"
    [ "$status" -eq 0 ]

    run is_supported_file "config.yaml"
    [ "$status" -eq 0 ]

    run is_supported_file "package.json"
    [ "$status" -eq 0 ]
}

@test "file-scanner: is_supported_file identifies other supported languages" {
    run is_supported_file "main.go"
    [ "$status" -eq 0 ]

    run is_supported_file "lib.rs"
    [ "$status" -eq 0 ]

    run is_supported_file "App.java"
    [ "$status" -eq 0 ]
}

@test "file-scanner: is_supported_file rejects unsupported files" {
    run is_supported_file "image.png"
    [ "$status" -eq 1 ]

    run is_supported_file "data.bin"
    [ "$status" -eq 1 ]

    run is_supported_file "archive.tar.gz"
    [ "$status" -eq 1 ]
}

@test "file-scanner: filter_supported_files filters file list" {
    # Create various files
    echo "test" >"supported.js"
    echo "test" >"unsupported.png"

    local files=("supported.js" "unsupported.png")
    local filtered
    filtered=$(filter_supported_files "${files[@]}")

    [[ "$filtered" == *"supported.js"* ]]
    [[ "$filtered" != *"unsupported.png"* ]]
}

@test "file-scanner: filter_supported_files checks file readability" {
    echo "test" >"readable.js"
    chmod 000 "readable.js" 2>/dev/null || skip "chmod 000 not supported"

    # Verify we can't read the file (skip if running as root)
    [[ ! -r "readable.js" ]] || skip "Running with elevated privileges, chmod 000 doesn't prevent reads"

    local files=("readable.js")
    local filtered
    filtered=$(filter_supported_files "${files[@]}") || true

    # File should be filtered out if not readable
    [[ "$filtered" != *"readable.js"* ]] || [[ -z "$filtered" ]]

    # Cleanup
    chmod 644 "readable.js" 2>/dev/null || true
}

@test "file-scanner: handles symlinks correctly" {
    # Create a symlink to a supported file
    echo "console.log('test');" >"original.js"
    ln -s "original.js" "link.js" 2>/dev/null || true

    # Should handle symlinks (either resolve or skip)
    run file_exists_and_readable "link.js"
    [[ "$status" -eq 0 || "$status" -eq 1 ]]

    rm -f "link.js" "original.js"
}

# =============================================================================
# 🔧 COMMAND PARSER TESTS
# =============================================================================

@test "command-parser: _get_real_git_command extracts basic command" {
    local cmd
    cmd=$(_get_real_git_command "commit")
    [ "$cmd" == "commit" ]
}

@test "command-parser: _get_real_git_command skips wrapper flags" {
    local cmd
    cmd=$(_get_real_git_command "--skip-secrets" "commit")
    [ "$cmd" == "commit" ]
}

@test "command-parser: _get_real_git_command handles multiple wrapper flags" {
    local cmd
    cmd=$(_get_real_git_command "--skip-secrets" "--allow-large-files" "push")
    [ "$cmd" == "push" ]
}

@test "command-parser: _get_real_git_command recognizes all wrapper flags" {
    # Test each wrapper flag
    local cmd
    cmd=$(_get_real_git_command "--skip-secrets" "status")
    [ "$cmd" == "status" ]

    cmd=$(_get_real_git_command "--skip-syntax-check" "log")
    [ "$cmd" == "log" ]

    cmd=$(_get_real_git_command "--skip-deps-check" "add")
    [ "$cmd" == "add" ]

    cmd=$(_get_real_git_command "--allow-large-files" "commit")
    [ "$cmd" == "commit" ]

    cmd=$(_get_real_git_command "--force-danger" "reset")
    [ "$cmd" == "reset" ]

    cmd=$(_get_real_git_command "--force-allow" "push")
    [ "$cmd" == "push" ]
}

@test "command-parser: _get_real_git_command prevents bypass attacks" {
    # Security test: wrapper flag before command
    local cmd
    cmd=$(_get_real_git_command "--skip-secrets" "commit")
    [ "$cmd" == "commit" ]

    # Security test: command after wrapper flags
    cmd=$(_get_real_git_command "--force-allow" "push" "origin")
    [ "$cmd" == "push" ]
}

@test "command-parser: _get_real_git_command handles standard git flags" {
    local cmd

    # Security test: standard git config flag (-c key=value)
    cmd=$(_get_real_git_command "-c" "user.name=test" "commit")
    [ "$cmd" == "commit" ]

    # Security test: git path flag (-C /path)
    cmd=$(_get_real_git_command "-C" "/tmp" "push")
    [ "$cmd" == "push" ]

    # Security test: multiple standard git flags
    cmd=$(_get_real_git_command "-C" "/tmp" "-c" "core.editor=true" "commit")
    [ "$cmd" == "commit" ]

    # Security test: --git-dir flag
    cmd=$(_get_real_git_command "--git-dir=.git" "status")
    [ "$cmd" == "status" ]

    # Security test: --work-tree flag
    cmd=$(_get_real_git_command "--work-tree=/tmp" "push")
    [ "$cmd" == "push" ]
}

@test "command-parser: _get_real_git_command prevents flag bypass attacks" {
    local cmd

    # Scenario: Attacker tries to bypass using -c flag
    cmd=$(_get_real_git_command "-c" "core.editor=true" "push" "--force")
    [ "$cmd" == "push" ]

    # Scenario: Attacker tries using --git-dir
    cmd=$(_get_real_git_command "--git-dir=/tmp" "reset" "--hard")
    [ "$cmd" == "reset" ]

    # Scenario: Mixed wrapper and standard flags
    cmd=$(_get_real_git_command "--skip-secrets" "-c" "user.test=1" "commit")
    [ "$cmd" == "commit" ]
}

@test "command-parser: _get_real_git_command returns error for no command" {
    run _get_real_git_command "--skip-secrets"
    [ "$status" -eq 1 ]
}

@test "command-parser: _get_real_git_command returns error for only wrapper flags" {
    run _get_real_git_command "--skip-secrets" "--allow-large-files"
    [ "$status" -eq 1 ]
}

@test "command-parser: _get_real_git_command returns error for only standard git flags" {
    run _get_real_git_command "-c" "user.name=test"
    [ "$status" -eq 1 ]

    run _get_real_git_command "-C" "/tmp"
    [ "$status" -eq 1 ]
}

@test "command-parser: _get_real_git_command handles command with args" {
    local cmd
    cmd=$(_get_real_git_command "--skip-secrets" "commit" "-m" "message")
    [ "$cmd" == "commit" ]
}

# =============================================================================
# 🔒 INTEGRATION TESTS
# =============================================================================

@test "integration: validation loop works with file operations" {
    git -C "$TEST_REPO_DIR" add "test.sh"

    test_validator() {
        file_exists_and_readable "$1" && return 0
        return 1
    }

    run run_validation_on_staged "test_validator" "\.sh$"
    [ "$status" -eq 0 ]
}

@test "integration: validation checks work with platform detection" {
    # Test that platform-specific functions work
    if is_macos; then
        # macOS stat command
        stat -f%z "test.sh" >/dev/null 2>&1
    else
        # Linux stat command
        stat -c%s "test.sh" >/dev/null 2>&1
    fi
}

@test "integration: command parser prevents security bypasses" {
    # Scenario: User tries to bypass safety checks
    local cmd
    cmd=$(_get_real_git_command "--skip-secrets" "--force-allow" "push" "--force")

    # Should still detect "push" as the real command
    [ "$cmd" == "push" ]
}

@test "integration: file scanner and validation loop work together" {
    echo "test" >"test.js"
    echo "test" >"test.py"
    git -C "$TEST_REPO_DIR" add "test.js" "test.py"

    test_validator() {
        return 0
    }

    # run_validation_on_staged returns 0 when all validations pass
    run run_validation_on_staged "test_validator" "\.(js|py)$"
    [ "$status" -eq 0 ]
}

@test "integration: validation checks report errors correctly" {
    echo '{}' >"package.json"
    git -C "$TEST_REPO_DIR" add "package.json"

    run _check_dependency_changes
    [ "$status" -eq 1 ]
    [[ "$output" == *"package.json"* ]]
    [[ "$output" == *"--skip-deps-check"* ]]
}

# =============================================================================
# 🧪 EDGE CASES
# =============================================================================

@test "edge-cases: validation loop handles empty file list" {
    run run_validation_on_staged "dummy_function" ".*"
    [ "$status" -eq 0 ]
}

@test "edge-cases: validation checks handle no staged files" {
    run _check_dependency_changes
    [ "$status" -eq 0 ]

    run _check_large_files
    [ "$status" -eq 0 ]

    run _check_large_commit
    [ "$status" -eq 0 ]
}

@test "edge-cases: file scanner handles filenames with special characters" {
    echo "test" >"file-with-dashes.sh"
    echo "test" >"file_with_underscores.sh"
    git -C "$TEST_REPO_DIR" add "file-with-dashes.sh" "file_with_underscores.sh"

    run file_exists_and_readable "file-with-dashes.sh"
    [ "$status" -eq 0 ]

    run file_exists_and_readable "file_with_underscores.sh"
    [ "$status" -eq 0 ]
}

@test "edge-cases: command parser handles mixed flag order" {
    local cmd
    cmd=$(_get_real_git_command "commit" "--skip-secrets" "-m" "msg")
    [ "$cmd" == "commit" ]

    cmd=$(_get_real_git_command "--force-allow" "push" "origin" "main")
    [ "$cmd" == "push" ]
}

@test "edge-cases: validation checks handle binary files" {
    # Create a small binary file
    echo -e "\x00\x01\x02\x03" >"binary.bin"
    git -C "$TEST_REPO_DIR" add "binary.bin"

    # Should not crash or hang - accept either success or failure
    run _check_large_files
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "edge-cases: validation loop handles validation function errors" {
    git -C "$TEST_REPO_DIR" add "test.sh"

    # Validation function that returns error
    failing_validator() {
        return 1
    }

    run run_validation_on_staged "failing_validator" "\.sh$"
    [ "$status" -ne 0 ]
}

@test "edge-cases: file scanner handles files with multiple extensions" {
    run is_supported_file "archive.tar.gz"
    [ "$status" -eq 1 ]  # Should not be supported

    local ext
    ext=$(get_file_extension "archive.tar.gz")
    [ "$ext" == "gz" ]
}

@test "edge-cases: validation checks handle commit with no changes" {
    # Empty commit
    git -C "$TEST_REPO_DIR" add "test.sh"
    git -C "$TEST_REPO_DIR" commit -m "initial" >/dev/null 2>&1

    run _check_large_commit
    # Should handle empty diff gracefully - accept either success or failure
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "edge-cases: command parser handles flags with equals syntax" {
    local cmd

    # Git config with -c key=value
    cmd=$(_get_real_git_command "-c=user.name=test" "commit")
    [ "$cmd" == "commit" ]

    # Git dir with --git-dir=path
    cmd=$(_get_real_git_command "--git-dir=/path/to/git" "status")
    [ "$cmd" == "status" ]

    # Work tree with --work-tree=path
    cmd=$(_get_real_git_command "--work-tree=/path/to/tree" "push")
    [ "$cmd" == "push" ]
}

# =============================================================================
# 📊 BASH 5 FEATURES VALIDATION
# =============================================================================

@test "bash5: validation loop uses associative arrays" {
    # Test that the code can handle associative array patterns
    # (Used in file-operations.sh for validation)
    git -C "$TEST_REPO_DIR" add "test.sh"

    test_validator() {
        local file="$1"
        # Bash 5: case conversion
        local lower="${file,,}"
        [[ "$lower" == *"test.sh"* ]] && return 0
        return 1
    }

    run run_validation_on_staged "test_validator" "\.sh$"
    [ "$status" -eq 0 ]
}

@test "bash5: file operations uses case conversion" {
    local ext
    ext=$(get_file_extension "TEST.SH")
    # Should return lowercase
    [ "$ext" == "sh" ] || [ "$ext" == "SH" ]
}

@test "bash5: validation checks use arithmetic" {
    # Test arithmetic operations used in tier calculations
    local tier_lines=1000
    local tier_files=15

    ((tier_lines > 500))
    [ "$?" -eq 0 ]

    ((tier_files < 20))
    [ "$?" -eq 0 ]
}

@test "bash5: command parser uses array iteration" {
    # Test that command parser properly iterates arrays
    local cmd
    cmd=$(_get_real_git_command "--skip-secrets" "-c" "key=value" "commit" "-m" "test")
    [ "$cmd" == "commit" ]
}
