#!/usr/bin/env bats
# =============================================================================
# test-coverage-validator.bats - Tests for test coverage validator
# =============================================================================

setup() {
    # Disable strict mode from sourced files so bats can manage errors
    set +e 2>/dev/null || true

    local repo_root
    repo_root="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
    export SHELL_CONFIG_DIR="$repo_root"

    # Source required modules
    source "$repo_root/lib/core/command-cache.sh"
    source "$repo_root/lib/validation/validators/typescript/test-coverage-validator.sh"

    # Re-enable bats error handling
    set +euo pipefail 2>/dev/null || true

    # Create temp directory for tests
    TEST_TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEST_TEMP_DIR"' INT TERM
    test_coverage_validator_reset
}

teardown() {
    /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "test-coverage-validator: reset clears all state" {
    _TEST_COVERAGE_MISSING=("test")
    _TEST_COVERAGE_WARNINGS=("test2")
    test_coverage_validator_reset
    [ ${#_TEST_COVERAGE_MISSING[@]} -eq 0 ]
    [ ${#_TEST_COVERAGE_WARNINGS[@]} -eq 0 ]
}

@test "test-coverage-validator: detects missing test file for .ts file" {
    # Create temp directory structure
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/utils.ts"

    validate_test_coverage_file "$tmpdir/utils.ts"
    # Should report missing test
    local error_count
    error_count=$(test_coverage_validator_error_count)
    [ "$error_count" -gt 0 ]

    rm -rf "$tmpdir"
}

@test "test-coverage-validator: finds existing .test.ts file" {
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/utils.ts"
    touch "$tmpdir/utils.test.ts"

    validate_test_coverage_file "$tmpdir/utils.ts"
    # Should not report missing test
    local error_count
    error_count=$(test_coverage_validator_error_count)
    [ "$error_count" -eq 0 ]

    rm -rf "$tmpdir"
}

@test "test-coverage-validator: finds existing .spec.ts file" {
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/utils.ts"
    touch "$tmpdir/utils.spec.ts"

    validate_test_coverage_file "$tmpdir/utils.ts"
    # Should not report missing test
    local error_count
    error_count=$(test_coverage_validator_error_count)
    [ "$error_count" -eq 0 ]

    rm -rf "$tmpdir"
}

@test "test-coverage-validator: skips config files" {
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/vite.config.ts"

    validate_test_coverage_file "$tmpdir/vite.config.ts"
    # Config files should not require tests
    local error_count
    error_count=$(test_coverage_validator_error_count)
    [ "$error_count" -eq 0 ]

    rm -rf "$tmpdir"
}

@test "test-coverage-validator: skips type definition files" {
    local tmpdir
    tmpdir=$(mktemp -d)
    touch "$tmpdir/types.d.ts"

    validate_test_coverage_file "$tmpdir/types.d.ts"
    # Type definition files should not require tests
    local error_count
    error_count=$(test_coverage_validator_error_count)
    [ "$error_count" -eq 0 ]

    rm -rf "$tmpdir"
}

@test "test-coverage-validator: warns about missing vitest coverage thresholds" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create vitest.config.ts without coverage thresholds
    cat > "$tmpdir/vitest.config.ts" << EOF
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    coverage: {
      reporter: ['text']
    }
  }
})
EOF

    _check_vitest_coverage_config "$tmpdir"

    # Should have warning about missing thresholds
    [ ${#_TEST_COVERAGE_WARNINGS[@]} -gt 0 ]

    rm -rf "$tmpdir"
}

@test "test-coverage-validator: accepts vitest with coverage thresholds" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create vitest.config.ts with coverage thresholds
    cat > "$tmpdir/vitest.config.ts" << EOF
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    coverage: {
      thresholds: {
        lines: 80,
        functions: 80
      }
    }
  }
})
EOF

    _check_vitest_coverage_config "$tmpdir"

    # Should not have warnings
    [ ${#_TEST_COVERAGE_WARNINGS[@]} -eq 0 ]

    rm -rf "$tmpdir"
}

@test "test-coverage-validator: warns about missing jest coverage thresholds" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create jest.config.js without coverage thresholds
    cat > "$tmpdir/jest.config.js" << EOF
module.exports = {
  collectCoverage: true,
  coverageReporters: ['text']
}
EOF

    _check_jest_coverage_config "$tmpdir"

    # Should have warning about missing thresholds
    [ ${#_TEST_COVERAGE_WARNINGS[@]} -gt 0 ]

    rm -rf "$tmpdir"
}

@test "test-coverage-validator: accepts jest with coverage thresholds" {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create jest.config.js with coverage thresholds
    cat > "$tmpdir/jest.config.js" << EOF
module.exports = {
  collectCoverage: true,
  coverageThreshold: {
    global: {
      lines: 80,
      functions: 80
    }
  }
}
EOF

    _check_jest_coverage_config "$tmpdir"

    # Should not have warnings
    [ ${#_TEST_COVERAGE_WARNINGS[@]} -eq 0 ]

    rm -rf "$tmpdir"
}
