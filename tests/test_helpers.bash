#!/usr/bin/env bash
# =============================================================================
# 🧪 TEST HELPERS LIBRARY - Core Testing Utilities
# =============================================================================
# Core testing utilities that load all helper modules.
#
# Usage: In your .bats file:
#   load 'test_helpers'
#   setup() {
#       setup_test_env
#   }
#   teardown() {
#       cleanup_test_env
#   }
# =============================================================================

# Load all helper modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/mocks/git.bash"
source "$SCRIPT_DIR/helpers/mocks/op.bash"
source "$SCRIPT_DIR/helpers/mocks/validators.bash"
source "$SCRIPT_DIR/helpers/assertions.bash"

# =============================================================================
# 📁 TEST ENVIRONMENT SETUP
# =============================================================================

# Get the shell-config directory (works for both bats and direct bash)
# Handles tests in nested directories (tests/core/, tests/git/, etc.)
get_shell_config_dir() {
    if [[ -n "${BATS_TEST_DIRNAME:-}" ]]; then
        # Go up until we find the tests directory, then one more level
        local dir="$BATS_TEST_DIRNAME"
        while [[ -n "$dir" && "$(basename "$dir")" != "tests" ]]; do
            dir="$(dirname "$dir")"
        done
        # Now go up one more level from tests/ to get repo root
        echo "$(cd "$dir/.." && pwd)"
    else
        echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    fi
}

# Create a temporary test environment
setup_test_env() {
    # Create temp directory for test artifacts
    TEST_TEMP_DIR="${BATS_TEST_TMPDIR:-/tmp}/bats-test-$$"
    mkdir -p "$TEST_TEMP_DIR" || { echo "Failed to create TEST_TEMP_DIR" >&2; exit 1; }
    [[ -d "$TEST_TEMP_DIR" ]] || { echo "TEST_TEMP_DIR not a directory" >&2; exit 1; }

    # Create mock binaries directory
    MOCK_BIN_DIR="$TEST_TEMP_DIR/mock-bin"
    mkdir -p "$MOCK_BIN_DIR" || { echo "Failed to create MOCK_BIN_DIR" >&2; exit 1; }
    [[ -d "$MOCK_BIN_DIR" ]] || { echo "MOCK_BIN_DIR not a directory" >&2; exit 1; }

    # Add mock bin to PATH
    export PATH="$MOCK_BIN_DIR:$PATH"

    # Set test home directory
    TEST_HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$TEST_HOME"
    export HOME="$TEST_HOME"

    # Create XDG config directories
    export XDG_CONFIG_HOME="$TEST_HOME/.config"
    mkdir -p "$XDG_CONFIG_HOME"

    # Create cache directory
    export GIT_WRAPPER_CACHE_DIR="$TEST_HOME/.cache/git-wrapper"
    mkdir -p "$GIT_WRAPPER_CACHE_DIR"

    # Create test repository
    TEST_REPO_DIR="$TEST_TEMP_DIR/test-repo"
    mkdir -p "$TEST_REPO_DIR"
    cd "$TEST_REPO_DIR" || exit 1

    # Initialize git repo (using real git for setup)
    command git init -q --initial-branch=main
    command git config user.email "test@example.com"
    command git config user.name "Test User"

    # Export shell-config location
    SHELL_CONFIG_DIR="$(get_shell_config_dir)"
    export SHELL_CONFIG_DIR
    export TEST_REPO_DIR TEST_TEMP_DIR TEST_HOME MOCK_BIN_DIR
}

# Alias for backwards compatibility
setup_test_environment() {
    setup_test_env
}

# Clean up test environment
cleanup_test_env() {
    # Return to safe directory before cleanup (prevents getcwd errors when
    # the current directory is inside TEST_TEMP_DIR which we're about to delete)
    if ! cd "$BATS_TEST_DIRNAME" 2>/dev/null; then
        echo "WARNING: Cannot cd to BATS_TEST_DIRNAME='$BATS_TEST_DIRNAME', using /tmp" >&2
        cd /tmp || true
    fi

    # Remove temp directory if it exists
    if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
        # Safety check: ensure TEST_TEMP_DIR is in a temp location
        case "$TEST_TEMP_DIR" in
            /tmp/*|/var/folders/*|"${BATS_TEST_TMPDIR:-}"*)
                rm -rf "$TEST_TEMP_DIR"
                ;;
            *)
                echo "ERROR: TEST_TEMP_DIR='$TEST_TEMP_DIR' not in temp location, refusing to delete" >&2
                ;;
        esac
    fi
}

# Alias for backwards compatibility
cleanup_test_environment() {
    cleanup_test_env
}

# =============================================================================
# 📁 TEST FILE CREATION
# =============================================================================

# Create a test file with specified content
create_test_file() {
    local file_path="$1"
    local content="${2:-test content}"
    mkdir -p "$(dirname "$file_path")"
    echo "$content" > "$file_path"
}

# Create multiple test files
create_test_files() {
    local count="$1"
    local prefix="${2:-file}"
    local extension="${3:-txt}"
    local content="${4:-test content}"

    for ((i = 1; i <= count; i++)); do
        create_test_file "${prefix}${i}.${extension}" "$content"
    done
}

# Create a staged test file in git
create_staged_file() {
    local file_name="$1"
    local content="${2:-test content}"
    create_test_file "$TEST_REPO_DIR/$file_name" "$content"
    (cd "$TEST_REPO_DIR" && command git add "$file_name")
}

# Alias for backwards compatibility
stage_test_file() {
    local filename="${1:-test.txt}"
    local content="${2:-test content}"
    create_test_file "$filename" "$content"
    git add "$filename"
}

# Create a test git repository
create_test_repo() {
    local repo_name="${1:-test-repo}"
    local initial_branch="${2:-main}"

    mkdir -p "$repo_name"
    cd "$repo_name" || return 1

    git init --initial-branch="$initial_branch" >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"

    create_test_file README.md "# Test Repository"
    git add README.md
    git commit -m "Initial commit" >/dev/null 2>&1
}

# Create a test dependency file (package.json, Cargo.toml, etc.)
create_dep_file() {
    local dep_type="$1"
    case "$dep_type" in
        package.json)
            cat > "$TEST_REPO_DIR/package.json" << 'EOF'
{
  "name": "test-project",
  "version": "1.0.0",
  "dependencies": {
    "lodash": "^4.17.21"
  }
}
EOF
            (cd "$TEST_REPO_DIR" && command git add package.json)
            ;;
        Cargo.toml)
            cat > "$TEST_REPO_DIR/Cargo.toml" << 'EOF'
[package]
name = "test-project"
version = "0.1.0"
[dependencies]
serde = "1.0"
EOF
            (cd "$TEST_REPO_DIR" && command git add Cargo.toml)
            ;;
    esac
}

# Create a large test file
create_large_file() {
    local file_name="$1"
    local size_mb="${2:-6}"
    dd if=/dev/zero of="$TEST_REPO_DIR/$file_name" bs=1048576 count="$size_mb" 2>/dev/null
    (cd "$TEST_REPO_DIR" && command git add "$file_name")
}

# Create many small test files (for large commit detection)
create_many_files() {
    local count="${1:-80}"
    local i

    for ((i = 1; i <= count; i++)); do
        echo "console.log('test $i');" > "$TEST_REPO_DIR/file-$i.js"
    done

    (cd "$TEST_REPO_DIR" && command git add *.js)
}

# Create a 1Password secrets config file
create_op_config() {
    local config_file="${1:-$XDG_CONFIG_HOME/shell-secrets.conf}"
    mkdir -p "$(dirname "$config_file")"
    cat > "$config_file" << 'EOF'
# Test 1Password secrets config
TEST_SECRET=op://Test/Vault/test
API_KEY=op://Test/Vault/api-key
# COMMENTED_SECRET=op://Test/Vault/ignored
EOF
}

# =============================================================================
# 🎯 TEST CONDITION HELPERS
# =============================================================================

# Check if command is available
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Skip test if command not available
skip_if_no_command() {
    local cmd="$1"
    if ! command_exists "$cmd"; then
        skip "$cmd not installed"
    fi
}

# Skip test if command is available
skip_if_command_exists() {
    local cmd="$1"
    if command_exists "$cmd"; then
        skip "$cmd is installed"
    fi
}

# Check if running in CI
is_ci() {
    [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${TRAVIS:-}" ]]
}

# Skip test if in CI
skip_if_ci() {
    if is_ci; then
        skip "Test skipped in CI environment"
    fi
}

# Skip test if not in CI
skip_if_not_ci() {
    if ! is_ci; then
        skip "Test only runs in CI environment"
    fi
}

# =============================================================================
# 🎪 TEST DATA GENERATORS
# =============================================================================

# Generate random string
random_string() {
    local length="${1:-16}"
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c "$length"
}

# Generate random email
random_email() {
    echo "$(random_string 8)@example.com"
}

# Generate random URL
random_url() {
    echo "https://example.com/$(random_string 8)"
}

# Generate test JSON
generate_test_json() {
    cat <<EOF
{
  "name": "$(random_string 8)",
  "version": "1.0.0",
  "description": "Test package"
}
EOF
}

# Generate test YAML
generate_test_yaml() {
    cat <<EOF
key1: value1
key2:
  nested: value2
  list:
    - item1
    - item2
EOF
}

# =============================================================================
# 🧹 CLEANUP HELPERS
# =============================================================================

# Remove all git repositories from test directory
cleanup_git_repos() {
    find . -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true
}

# Remove all test files matching pattern
cleanup_test_files() {
    local pattern="$1"
    rm -f $pattern 2>/dev/null || true
}

# Reset git index
reset_git_index() {
    git reset HEAD >/dev/null 2>&1 || true
}

# =============================================================================
# 📝 OUTPUT CAPTURE
# =============================================================================

# Capture stdout to file
capture_stdout() {
    local output_file="$1"
    shift
    "$@" >"$output_file"
}

# Capture stderr to file
capture_stderr() {
    local output_file="$1"
    shift
    "$@" 2>"$output_file"
}

# Capture both stdout and stderr
capture_all() {
    local output_file="$1"
    shift
    "$@" &>"$output_file"
}

# =============================================================================
# 🔍 DEBUG HELPERS
# =============================================================================

# Print debug message (only when BATS_VERBOSE is set)
debug_msg() {
    if [[ -n "${BATS_VERBOSE:-}" ]]; then
        echo "DEBUG: $*" >&3
    fi
}

# Print variable value (for debugging)
debug_var() {
    local var_name="$1"
    if [[ -n "${BATS_VERBOSE:-}" ]]; then
        echo "DEBUG: $var_name = ${!var_name}" >&3
    fi
}

# Print command output (for debugging)
debug_output() {
    if [[ -n "${BATS_VERBOSE:-}" ]] && [[ -n "${output:-}" ]]; then
        echo "DEBUG: output = $output" >&3
    fi
}

# =============================================================================
# 🎯 CONDITIONAL TESTS
# =============================================================================

# Run test only if condition is true
run_if() {
    local condition="$1"
    shift

    if eval "$condition"; then
        "$@"
    else
        skip "Condition not met: $condition"
    fi
}

# Run test only on macOS
run_on_macos() {
    if [[ "$(uname)" == "Darwin" ]]; then
        "$@"
    else
        skip "Test only runs on macOS"
    fi
}

# Run test only on Linux
run_on_linux() {
    if [[ "$(uname)" == "Linux" ]]; then
        "$@"
    else
        skip "Test only runs on Linux"
    fi
}

# =============================================================================
# 🔧 UTILITY FUNCTIONS
# =============================================================================

# Count lines in a file (excluding empty lines and comments)
count_effective_lines() {
    local file="$1"
    grep -vE '^\s*$|^\s*#' "$file" 2>/dev/null | wc -l | tr -d ' '
}

# Get file size in bytes
get_file_size() {
    local file="$1"
    if [[ -f "$file" ]]; then
        stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Check if a string contains a substring
string_contains() {
    local haystack="$1"
    local needle="$2"
    [[ "$haystack" == *"$needle"* ]]
}

# Check if a string starts with a prefix
string_starts_with() {
    local string="$1"
    local prefix="$2"
    [[ "$string" == "$prefix"* ]]
}

# Check if a string ends with a suffix
string_ends_with() {
    local string="$1"
    local suffix="$2"
    [[ "$string" == *"$suffix" ]]
}

# Strip ANSI escape codes from output
strip_ansi_codes() {
    local output="$1"
    echo "$output" | sed 's/\x1b\[[0-9;]*m//g'
}

# Run a shell function and capture output
run_shell_function() {
    local function_name="$1"
    shift
    "$function_name" "$@" 2>&1
}

# =============================================================================
# 📤 EXPORT ALL FUNCTIONS
# =============================================================================

# Export all helper functions for use in test files
export -f get_shell_config_dir
export -f setup_test_env setup_test_environment
export -f cleanup_test_env cleanup_test_environment
export -f create_mock_git create_mock_op mock_git mock_op
export -f create_mock_oxlint create_mock_ruff create_mock_shellcheck
export -f create_mock_yamllint create_mock_gitleaks
export -f mock_oxlint mock_shellcheck
export -f create_all_mocks
export -f create_test_file create_test_files create_staged_file stage_test_file
export -f create_test_repo create_dep_file create_large_file create_many_files
export -f create_op_config
export -f command_exists skip_if_no_command skip_if_command_exists
export -f is_ci skip_if_ci skip_if_not_ci
export -f random_string random_email random_url
export -f generate_test_json generate_test_yaml
export -f cleanup_git_repos cleanup_test_files reset_git_index
export -f capture_stdout capture_stderr capture_all
export -f debug_msg debug_var debug_output
export -f run_if run_on_macos run_on_linux
export -f count_effective_lines get_file_size
export -f string_contains string_starts_with string_ends_with
export -f strip_ansi_codes run_shell_function