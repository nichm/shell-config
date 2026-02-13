#!/usr/bin/env bats
# =============================================================================
# Regression: File Scanner Tests
# =============================================================================
# Tests for lib/git/shared/file-scanner.sh
#
# PR #98 review: Converted file extension checks from O(n) case statement
# to O(1) associative array lookup. Need to ensure all previously supported
# extensions still work after the refactor.
#
# These tests verify:
# 1. All supported extensions are recognized
# 2. Unsupported extensions are rejected
# 3. Edge cases (no extension, dot files) are handled
# 4. Helper functions work correctly
# =============================================================================

setup() {
    export SHELL_CONFIG_DIR
    SHELL_CONFIG_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export FILE_SCANNER="$SHELL_CONFIG_DIR/lib/git/shared/file-scanner.sh"

    # Create temp directory for test files
    export TEST_TMPDIR="$BATS_TEST_TMPDIR/file_scanner_$$"
    mkdir -p "$TEST_TMPDIR"
}

teardown() {
    cd "$BATS_TEST_DIRNAME" || return 1
    /bin/rm -rf "$TEST_TMPDIR"
}

# --- get_file_extension ---

@test "file-scanner: extracts .ts extension" {
    run bash -c "source '$FILE_SCANNER'; get_file_extension 'src/app.ts'"
    [ "$status" -eq 0 ]
    [ "$output" = "ts" ]
}

@test "file-scanner: extracts .py extension" {
    run bash -c "source '$FILE_SCANNER'; get_file_extension 'script.py'"
    [ "$status" -eq 0 ]
    [ "$output" = "py" ]
}

@test "file-scanner: handles file with no extension" {
    run bash -c "source '$FILE_SCANNER'; get_file_extension 'Makefile'"
    [ "$status" -eq 0 ]
    # Files without an extension return empty string (no extension found)
    [ "$output" = "" ]
}

@test "file-scanner: handles nested path" {
    run bash -c "source '$FILE_SCANNER'; get_file_extension 'deep/nested/path/file.tsx'"
    [ "$status" -eq 0 ]
    [ "$output" = "tsx" ]
}

# --- is_supported_file: JavaScript/TypeScript family ---

@test "file-scanner: supports all JS/TS extensions" {
    local extensions=(js ts jsx tsx mjs cjs mts cts)
    for ext in "${extensions[@]}"; do
        run bash -c "source '$FILE_SCANNER'; is_supported_file 'file.$ext'"
        [ "$status" -eq 0 ]
    done
}

# --- is_supported_file: Python ---

@test "file-scanner: supports Python extensions" {
    for ext in py pyw; do
        run bash -c "source '$FILE_SCANNER'; is_supported_file 'script.$ext'"
        [ "$status" -eq 0 ]
    done
}

# --- is_supported_file: Shell ---

@test "file-scanner: supports shell extensions" {
    for ext in sh bash zsh; do
        run bash -c "source '$FILE_SCANNER'; is_supported_file 'script.$ext'"
        [ "$status" -eq 0 ]
    done
}

# --- is_supported_file: Config ---

@test "file-scanner: supports YAML and JSON" {
    for ext in yml yaml json; do
        run bash -c "source '$FILE_SCANNER'; is_supported_file 'config.$ext'"
        [ "$status" -eq 0 ]
    done
}

# --- is_supported_file: Other languages ---

@test "file-scanner: supports compiled language extensions" {
    for ext in go rs java kt scala c cpp h hpp cs swift rb php; do
        run bash -c "source '$FILE_SCANNER'; is_supported_file 'file.$ext'"
        [ "$status" -eq 0 ]
    done
}

# --- is_supported_file: Unsupported ---

@test "file-scanner: rejects unsupported extensions" {
    for ext in md txt png jpg pdf docx csv xml; do
        run bash -c "source '$FILE_SCANNER'; is_supported_file 'file.$ext'"
        [ "$status" -eq 1 ]
    done
}

# --- file_exists_and_readable ---

@test "file-scanner: file_exists_and_readable returns true for readable file" {
    local test_file="$TEST_TMPDIR/readable.txt"
    echo "test" > "$test_file"
    run bash -c "source '$FILE_SCANNER'; file_exists_and_readable '$test_file'"
    [ "$status" -eq 0 ]
}

@test "file-scanner: file_exists_and_readable returns false for missing file" {
    run bash -c "source '$FILE_SCANNER'; file_exists_and_readable '$TEST_TMPDIR/nonexistent.txt'"
    [ "$status" -eq 1 ]
}

@test "file-scanner: file_exists_and_readable returns false for directory" {
    run bash -c "source '$FILE_SCANNER'; file_exists_and_readable '$TEST_TMPDIR'"
    [ "$status" -eq 1 ]
}

# --- filter_supported_files ---

@test "file-scanner: filter_supported_files filters correctly" {
    # Create test files
    echo "test" > "$TEST_TMPDIR/app.ts"
    echo "test" > "$TEST_TMPDIR/readme.md"
    echo "test" > "$TEST_TMPDIR/script.sh"

    run bash -c "
        source '$FILE_SCANNER'
        filter_supported_files '$TEST_TMPDIR/app.ts' '$TEST_TMPDIR/readme.md' '$TEST_TMPDIR/script.sh'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"app.ts"* ]]
    [[ "$output" == *"script.sh"* ]]
    [[ "$output" != *"readme.md"* ]]
}
