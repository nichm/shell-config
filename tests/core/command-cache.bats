#!/usr/bin/env bats
# Tests for lib/core/command-cache.sh - Command existence caching

load '../test_helpers'
setup() {
    # Set SHELL_CONFIG_DIR first, before setup_test_env which might override it
    local repo_root
    repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export SHELL_CONFIG_DIR="$repo_root"
    export COMMAND_CACHE_LIB="$SHELL_CONFIG_DIR/lib/core/command-cache.sh"
    
    # Now setup the test environment
    setup_test_env
}

teardown() {
    cleanup_test_env
}

@test "command-cache library exists" {
    [ -f "$COMMAND_CACHE_LIB" ]
}

@test "command-cache sources without error" {
    run bash -c "source '$COMMAND_CACHE_LIB' 2>/dev/null"
    [ "$status" -eq 0 ]
}

@test "command-cache is valid bash syntax" {
    run bash -n "$COMMAND_CACHE_LIB"
    [ "$status" -eq 0 ]
}

@test "command-cache defines command_exists function" {
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null
        type command_exists
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"command_exists"* ]]
}

@test "command-cache defines command_cache_clear function" {
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null
        type command_cache_clear
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"command_cache_clear"* ]]
}

@test "command-cache defines command_cache_stats function" {
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null
        type command_cache_stats
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"command_cache_stats"* ]]
}

@test "command_exists returns 0 for existing command (bash)" {
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null
        command_exists 'bash'
    "
    [ "$status" -eq 0 ]
}

@test "command_exists returns 1 for non-existent command" {
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null
        command_exists 'nonexistent-command-xyz123'
    "
    [ "$status" -eq 1 ]
}

@test "command_exists returns 2 when called without arguments" {
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null
        command_exists 2>&1
    "
    [ "$status" -eq 2 ]
    [[ "$output" == *"ERROR:"* ]]
    [[ "$output" == *"WHY:"* ]]
    [[ "$output" == *"FIX:"* ]]
}

@test "command_exists caches results for subsequent calls" {
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null

        # Clear cache first
        command_cache_clear

        # First call - should cache
        command_exists 'bash'

        # Check cache has 1 entry
        command_cache_stats | grep 'Total cached: 1'
    "
    [ "$status" -eq 0 ]
}

@test "command_cache_clear empties the cache" {
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null

        # Add some entries to cache
        command_exists 'bash'
        command_exists 'ls'

        # Clear cache
        command_cache_clear

        # Check cache is empty
        command_cache_stats | grep 'Total cached: 0'
    "
    [ "$status" -eq 0 ]
}

@test "command_cache_stats shows correct statistics" {
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null

        command_cache_clear

        # Check existing command
        command_exists 'bash'

        # Check non-existent command
        command_exists 'nonexistent-xyz123' || true

        # Get stats
        command_cache_stats
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"Command Cache Stats:"* ]]
    [[ "$output" == *"Total cached:"* ]]
    [[ "$output" == *"Found:"* ]]
    [[ "$output" == *"Not found:"* ]]
}

@test "command_exists handles multiple commands correctly" {
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null

        command_cache_clear

        # Test multiple commands
        command_exists 'bash' && echo 'bash found' || echo 'bash not found'
        command_exists 'ls' && echo 'ls found' || echo 'ls not found'
        command_exists 'nonexistent-xyz' && echo 'fake found' || echo 'fake not found'

        # Check stats
        command_cache_stats
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"bash found"* ]]
    [[ "$output" == *"ls found"* ]]
    [[ "$output" == *"fake not found"* ]]
}

@test "command-cache guard prevents multiple sourcing" {
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null

        # Check guard variable is set
        [[ -n \"\${_SHELL_CONFIG_COMMAND_CACHE_LOADED:-}\" ]] && echo 'guard set'

        # Source again - should not error
        source '$COMMAND_CACHE_LIB' 2>/dev/null
        echo 'resourced successfully'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"guard set"* ]]
    [[ "$output" == *"resourced successfully"* ]]
}

@test "command_exists performance: cached calls avoid subshell spawns" {
    # This test verifies the caching mechanism works
    # by checking that the cache doesn't grow on repeated calls
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null

        command_cache_clear

        # First call - populates cache
        command_exists 'bash'

        # Get cache size
        before_total=\${#_CMD_CACHE[@]}

        # Second call - uses cache
        command_exists 'bash'

        # Get cache size again
        after_total=\${#_CMD_CACHE[@]}

        # Both should show same count (cache not duplicated)
        if [[ \$before_total -eq \$after_total ]]; then
            echo 'cache_stable'
        else
            echo \"cache_grew: \$before_total -> \$after_total\"
        fi
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"cache_stable"* ]]
}

@test "command_exists handles command names with special characters gracefully" {
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null

        # Test that special characters don't break the function
        # (most will not exist, which is fine - we're testing robustness)
        command_exists 'git-log' || true
        command_exists 'npm.cmd' || true
    "
    [ "$status" -eq 0 ]
}

@test "command-cache associative array is Bash 5.x compatible" {
    run bash -c "
        source '$COMMAND_CACHE_LIB' 2>/dev/null

        # Verify associative array works by checking declare -p
        declare -p _CMD_CACHE 2>/dev/null && echo 'array exists'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"array exists"* ]]
}
