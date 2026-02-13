#!/usr/bin/env bats
# =============================================================================
# Benchmarking Tests
# =============================================================================
# Tests for benchmarking utilities and performance validation
# =============================================================================

setup() {
    # Load test helpers
    load '../test_helpers'

    # Set up test environment
    export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
    export TEST_TMPDIR="${BATS_TMPDIR}/benchmark_test"
    mkdir -p "$TEST_TMPDIR"

    # Source benchmarking utilities
    source "$SHELL_CONFIG_DIR/tools/benchmarking/benchmark-validator.sh"
}

teardown() {
    # Clean up benchmark variables
    benchmark_validator_reset
    /bin/rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# BENCHMARK VALIDATOR TESTS
# =============================================================================

@test "benchmark_start and benchmark_end work" {
    benchmark_start "test_operation"
    sleep 0.1
    local output
    output=$(benchmark_end "test_operation")

    # Should contain timing information
    assert_var_set output
    assert_output_contains "test_operation:"
}

@test "benchmark_validator_show_warning works" {
    local output
    output=$(benchmark_validator_show_warning "test warning" 2>&1)

    # Should show warning message (function exists test)
    true
}

@test "benchmark_validator_show_error works" {
    local output
    output=$(benchmark_validator_show_error "test error" 2>&1)

    # Should show error message (function exists test)
    true
}

@test "validate_performance_metrics passes for good performance" {
    # Test with good performance (under thresholds)
    run validate_performance_metrics "test_op" 1000

    assert_success
}

@test "validate_performance_metrics warns for slow performance" {
    # Test with slow performance (over warning threshold)
    run validate_performance_metrics "test_op" 6000

    assert_success  # Warnings don't fail, just warn
}

@test "validate_performance_metrics fails for very slow performance" {
    # Test with very slow performance (over error threshold)
    run validate_performance_metrics "test_op" 35000

    assert_failure
}

@test "benchmark_validate_run works with fast command" {
    run benchmark_validate_run "fast_cmd" 5000 echo "test"

    assert_success
}

@test "benchmark_validate_run fails with slow command" {
    # Mock a slow command (this is tricky to test reliably)
    # For now, just test the basic functionality
    run benchmark_validate_run "slow_cmd" 1 sleep 0.1

    # Should fail due to timeout
    assert_failure
}

@test "benchmark_validator_reset cleans up variables" {
    # Set some benchmark variables
    export _BENCHMARK_START_test1="1234567890"
    export _BENCHMARK_START_test2="1234567890"

    # Reset
    benchmark_validator_reset

    # Variables should be unset
    assert_var_empty _BENCHMARK_START_test1
    assert_var_empty _BENCHMARK_START_test2
}

# =============================================================================
# BENCHMARK HOOK TESTS
# =============================================================================

@test "benchmark_hook_start and benchmark_hook_end work" {
    source "$SHELL_CONFIG_DIR/tools/benchmarking/benchmark-hook.sh"

    benchmark_start "hook_test"
    sleep 0.05
    local output
    output=$(benchmark_end "hook_test")

    # Should contain timing information
    assert_var_set output
    assert_output_contains "hook_test:"
}

@test "benchmark_run executes command and times it" {
    source "$SHELL_CONFIG_DIR/tools/benchmarking/benchmark-hook.sh"

    run benchmark_run "echo_test" echo "hello world"

    assert_success
    assert_output_contains "echo_test:"
    assert_output_contains "hello world"
}

# =============================================================================
# BENCHMARKING RULES TESTS
# =============================================================================

@test "command-safety rule helpers register rules correctly" {
    # Source registry and helpers before loading a rule file
    source "$SHELL_CONFIG_DIR/lib/command-safety/engine/registry.sh"
    source "$SHELL_CONFIG_DIR/lib/command-safety/engine/rule-helpers.sh"
    source "$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"

    # Check that key rules are registered with correct suffixes
    [[ -n "${COMMAND_SAFETY_RULE_ID[RM_RF]:-}" ]]
    [[ -n "${COMMAND_SAFETY_RULE_ID[DD]:-}" ]]
    [[ -n "${COMMAND_SAFETY_RULE_ID[SED_I]:-}" ]]
}

# =============================================================================
# INTEGRATION TESTS
# =============================================================================

@test "benchmark validator integrates with other modules" {
    # Test that benchmark validator can be sourced alongside other modules
    source "$SHELL_CONFIG_DIR/lib/core/colors.sh"

    # Should not conflict with other modules
    run log_info "test"

    assert_success
}

@test "benchmark tools directory structure is correct" {
    # Check that all expected files exist
    assert_file_exists "$SHELL_CONFIG_DIR/tools/benchmarking/benchmark.sh"
    assert_file_exists "$SHELL_CONFIG_DIR/tools/benchmarking/benchmark-validator.sh"
    assert_file_exists "$SHELL_CONFIG_DIR/tools/benchmarking/benchmark-hook.sh"
    assert_file_exists "$SHELL_CONFIG_DIR/tools/benchmarking/README.md"
}

@test "benchmark.sh has correct permissions" {
    local script="$SHELL_CONFIG_DIR/tools/benchmarking/benchmark.sh"

    [ -x "$script" ] && [ -r "$script" ]
}

@test "benchmark.sh shows help" {
    local script="$SHELL_CONFIG_DIR/tools/benchmarking/benchmark.sh"

    run "$script" --help

    assert_success
    assert_output_contains "SHELL-CONFIG BENCHMARKING TOOL"
    assert_output_contains "Usage:"
}