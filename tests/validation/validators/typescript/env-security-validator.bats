#!/usr/bin/env bats
# =============================================================================
# env-security-validator.bats - Tests for environment variable security validator
# =============================================================================

setup() {
    # Disable strict mode from sourced files so bats can manage errors
    set +e 2>/dev/null || true
    
    local repo_root
    repo_root="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
    export SHELL_CONFIG_DIR="$repo_root"
    
    # Source required modules
    source "$repo_root/lib/core/command-cache.sh"
    source "$repo_root/lib/validation/validators/typescript/env-security-validator.sh"
    
    # Re-enable bats error handling
    set +euo pipefail 2>/dev/null || true
    
    # Create temp directory for tests
    TEST_TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEST_TEMP_DIR"' INT TERM
    env_security_validator_reset
}

teardown() {
    /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "env-security-validator: reset clears all errors and warnings" {
    _ENV_SECURITY_ERRORS=("test")
    _ENV_SECURITY_WARNINGS=("test2")
    env_security_validator_reset
    [ ${#_ENV_SECURITY_ERRORS[@]} -eq 0 ]
    [ ${#_ENV_SECURITY_WARNINGS[@]} -eq 0 ]
}

@test "env-security-validator: detects NEXT_PUBLIC_ with key pattern" {
    # Create temporary file with suspicious pattern
    local test_file
    test_file=$(mktemp)
    echo 'const apiKey = process.env.NEXT_PUBLIC_API_KEY;' > "$test_file"

    validate_env_security_file "$test_file"
    env_security_validator_has_errors

    rm -f "$test_file"
}

@test "env-security-validator: allows safe NEXT_PUBLIC_ variables" {
    local test_file
    test_file=$(mktemp)
    echo 'const title = process.env.NEXT_PUBLIC_SITE_TITLE;' > "$test_file"

    validate_env_security_file "$test_file"
    # Should not have errors for safe patterns
    local error_count
    error_count=$(env_security_validator_error_count)
    [ "$error_count" -eq 0 ]

    rm -f "$test_file"
}

@test "env-security-validator: reports when has_errors returns correct status" {
    _ENV_SECURITY_ERRORS=()
    env_security_validator_has_errors
    [ $? -eq 1 ]

    _ENV_SECURITY_ERRORS=("test")
    env_security_validator_has_errors
    [ $? -eq 0 ]
}

@test "env-security-validator: reports when has_warnings returns correct status" {
    _ENV_SECURITY_WARNINGS=()
    env_security_validator_has_warnings
    [ $? -eq 1 ]

    _ENV_SECURITY_WARNINGS=("test")
    env_security_validator_has_warnings
    [ $? -eq 0 ]
}

@test "env-security-validator: detects .env file not in .gitignore" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create .env.local file
    touch "$tmpdir/.env.local"

    # Create .gitignore without .env.local
    echo "node_modules" > "$tmpdir/.gitignore"

    # Initialize git repo
    cd "$tmpdir" || return
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    git config core.hooksPath /dev/null

    _check_env_files "$tmpdir"

    # Should have warning about .gitignore
    [ ${#_ENV_SECURITY_WARNINGS[@]} -gt 0 ]

    cd - || return
    rm -rf "$tmpdir"
}

@test "env-security-validator: detects committed .env file" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create .env.local file
    echo "SECRET=value" > "$tmpdir/.env.local"

    # Initialize git repo and commit .env.local
    cd "$tmpdir" || return
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    git config core.hooksPath /dev/null
    git add .env.local
    git commit -m "Add .env.local"

    _check_env_files "$tmpdir"

    # Should have error about committed .env file
    [ ${#_ENV_SECURITY_ERRORS[@]} -gt 0 ]

    cd - || return
    rm -rf "$tmpdir"
}

@test "env-security-validator: warns when .env.example missing" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create .env file
    touch "$tmpdir/.env"

    _check_env_example "$tmpdir"

    # Should have warning about missing .env.example
    [ ${#_ENV_SECURITY_WARNINGS[@]} -gt 0 ]

    rm -rf "$tmpdir"
}
