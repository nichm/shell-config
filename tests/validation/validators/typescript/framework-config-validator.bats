#!/usr/bin/env bats
# =============================================================================
# framework-config-validator.bats - Tests for framework configuration validator
# =============================================================================

setup() {
    # Disable strict mode from sourced files so bats can manage errors
    set +e 2>/dev/null || true

    local repo_root
    repo_root="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
    export SHELL_CONFIG_DIR="$repo_root"

    # Source required modules
    source "$repo_root/lib/core/command-cache.sh"
    source "$repo_root/lib/validation/validators/typescript/framework-config-validator.sh"

    # Re-enable bats error handling
    set +euo pipefail 2>/dev/null || true

    # Create temp directory for tests
    TEST_TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEST_TEMP_DIR"' INT TERM
    framework_config_validator_reset
}

teardown() {
    /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "framework-config-validator: reset clears all state" {
    _FRAMEWORK_CONFIG_ERRORS=("test")
    _FRAMEWORK_CONFIG_WARNINGS=("test2")
    framework_config_validator_reset
    [ ${#_FRAMEWORK_CONFIG_ERRORS[@]} -eq 0 ]
    [ ${#_FRAMEWORK_CONFIG_WARNINGS[@]} -eq 0 ]
}

@test "framework-config-validator: detects missing tsconfig strict mode" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create tsconfig.json without strict mode
    cat > "$tmpdir/tsconfig.json" << EOF
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext"
  }
}
EOF

    _check_tsconfig_strict_mode "$tmpdir"
    # Should have warning
    [ ${#_FRAMEWORK_CONFIG_WARNINGS[@]} -gt 0 ]

    rm -rf "$tmpdir"
}

@test "framework-config-validator: accepts tsconfig with strict mode" {
    local tmpdir
    tmpdir=$(mktemp -d)

    cat > "$tmpdir/tsconfig.json" << EOF
{
  "compilerOptions": {
    "strict": true
  }
}
EOF

    _check_tsconfig_strict_mode "$tmpdir"
    # Should not have warnings
    [ ${#_FRAMEWORK_CONFIG_WARNINGS[@]} -eq 0 ]

    rm -rf "$tmpdir"
}

@test "framework-config-validator: warns about missing linter" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create package.json without linter
    cat > "$tmpdir/package.json" << EOF
{
  "name": "test",
  "version": "1.0.0"
}
EOF

    _check_lint_tools "$tmpdir"
    # Should have warning (not error) recommending oxlint
    [ ${#_FRAMEWORK_CONFIG_WARNINGS[@]} -gt 0 ]

    rm -rf "$tmpdir"
}

@test "framework-config-validator: reports when has_errors returns correct status" {
    _FRAMEWORK_CONFIG_ERRORS=()
    framework_config_validator_has_errors
    [ $? -eq 1 ]

    _FRAMEWORK_CONFIG_ERRORS=("test")
    framework_config_validator_has_errors
    [ $? -eq 0 ]
}

@test "framework-config-validator: reports when has_warnings returns correct status" {
    _FRAMEWORK_CONFIG_WARNINGS=()
    framework_config_validator_has_warnings
    [ $? -eq 1 ]

    _FRAMEWORK_CONFIG_WARNINGS=("test")
    framework_config_validator_has_warnings
    [ $? -eq 0 ]
}

@test "framework-config-validator: warns about missing vite plugins" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create vite.config.js without plugins
    cat > "$tmpdir/vite.config.js" << EOF
export default {
  build: {
    target: 'esnext'
  }
}
EOF

    _check_vite_config "$tmpdir"

    # Should have warning about missing plugins
    [ ${#_FRAMEWORK_CONFIG_WARNINGS[@]} -gt 0 ]

    rm -rf "$tmpdir"
}

@test "framework-config-validator: warns about missing vite build config" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create vite.config.js without build section
    cat > "$tmpdir/vite.config.js" << EOF
export default {
  plugins: []
}
EOF

    _check_vite_config "$tmpdir"

    # Should have warning about missing build config
    [ ${#_FRAMEWORK_CONFIG_WARNINGS[@]} -gt 0 ]

    rm -rf "$tmpdir"
}

@test "framework-config-validator: warns about missing next experimental features" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create next.config.js without experimental section
    cat > "$tmpdir/next.config.js" << EOF
module.exports = {
  images: {
    domains: ['example.com']
  }
}
EOF

    _check_nextjs_config "$tmpdir"

    # Should have warning about missing experimental features
    [ ${#_FRAMEWORK_CONFIG_WARNINGS[@]} -gt 0 ]

    rm -rf "$tmpdir"
}

@test "framework-config-validator: warns about missing next images config" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create next.config.js without images section
    cat > "$tmpdir/next.config.js" << EOF
module.exports = {
  experimental: {
    serverActions: true
  }
}
EOF

    _check_nextjs_config "$tmpdir"

    # Should have warning about missing images config
    [ ${#_FRAMEWORK_CONFIG_WARNINGS[@]} -gt 0 ]

    rm -rf "$tmpdir"
}
