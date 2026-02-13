#!/usr/bin/env bats
# =============================================================================
# Regression: Config Loading Tests
# =============================================================================
# Tests for lib/core/config.sh parsing and validation
#
# PR #98 review: Gemini found config parsing quote stripping with parameter
# expansion could introduce bugs. The regex->parameter expansion refactor
# needs to handle all quoting styles correctly.
#
# PR #96 review: Removing legacy aliases broke install-extras.sh.
# WELCOME_MESSAGE_STYLE backward compat alias was potentially missed.
#
# These tests ensure config parsing handles edge cases and defaults work.
# =============================================================================

setup() {
    export SHELL_CONFIG_DIR
    SHELL_CONFIG_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export CONFIG_LOADER="$SHELL_CONFIG_DIR/lib/core/config.sh"

    # Create temp config directory
    export TEST_TMPDIR="$BATS_TEST_TMPDIR/config_regression_$$"
    mkdir -p "$TEST_TMPDIR"

    # Clear config vars to prevent pollution between tests
    unset SHELL_CONFIG_WELCOME SHELL_CONFIG_COMMAND_SAFETY SHELL_CONFIG_GIT_WRAPPER
    unset SHELL_CONFIG_GHLS SHELL_CONFIG_EZA SHELL_CONFIG_FZF SHELL_CONFIG_RIPGREP
    unset SHELL_CONFIG_SECURITY SHELL_CONFIG_1PASSWORD SHELL_CONFIG_AUTOCOMPLETE
    unset SHELL_CONFIG_LOG_ROTATION SHELL_CONFIG_SECRETS_CACHE_TTL
    unset SHELL_CONFIG_WELCOME_CACHE_TTL SHELL_CONFIG_DOCTOR_CACHE_TTL
    unset SHELL_CONFIG_WELCOME_STYLE SHELL_CONFIG_AUTOCOMPLETE_GUIDE
    unset SHELL_CONFIG_SHORTCUTS
    unset WELCOME_MESSAGE_ENABLED WELCOME_AUTOCOMPLETE_GUIDE
    unset WELCOME_SHORTCUTS WELCOME_MESSAGE_STYLE
    unset _SHELL_CONFIG_CORE_CONFIG_LOADED
    unset _SHELL_CONFIG_CORE_COLORS_LOADED
    unset _SHELL_CONFIG_CORE_PLATFORM_LOADED
}

teardown() {
    cd "$BATS_TEST_DIRNAME" || return 1
    /bin/rm -rf "$TEST_TMPDIR"
}

# --- Quote stripping regression (PR #98) ---

@test "config: parses double-quoted values correctly" {
    local config_file="$TEST_TMPDIR/config"
    echo 'SHELL_CONFIG_WELCOME_STYLE="session"' > "$config_file"
    # Source config.sh, then unset vars and guard to re-parse fresh
    run bash -c "
        unset _SHELL_CONFIG_CORE_CONFIG_LOADED
        source '$CONFIG_LOADER'
        # Unset the auto-loaded value and guard, then re-parse
        unset SHELL_CONFIG_WELCOME_STYLE
        _load_config_simple '$config_file'
        echo \"\$SHELL_CONFIG_WELCOME_STYLE\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "session" ]
}

@test "config: parses single-quoted values correctly" {
    local config_file="$TEST_TMPDIR/config"
    echo "SHELL_CONFIG_WELCOME_STYLE='repo'" > "$config_file"
    run bash -c "
        unset _SHELL_CONFIG_CORE_CONFIG_LOADED
        source '$CONFIG_LOADER'
        unset SHELL_CONFIG_WELCOME_STYLE
        _load_config_simple '$config_file'
        echo \"\$SHELL_CONFIG_WELCOME_STYLE\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "repo" ]
}

@test "config: parses unquoted values correctly" {
    local config_file="$TEST_TMPDIR/config"
    echo "SHELL_CONFIG_WELCOME=true" > "$config_file"
    run bash -c "
        unset _SHELL_CONFIG_CORE_CONFIG_LOADED
        source '$CONFIG_LOADER'
        unset SHELL_CONFIG_WELCOME
        _load_config_simple '$config_file'
        echo \"\$SHELL_CONFIG_WELCOME\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "config: preserves spaces in quoted values" {
    local config_file="$TEST_TMPDIR/config"
    echo 'SHELL_CONFIG_WELCOME_STYLE="auto session"' > "$config_file"
    run bash -c "
        unset _SHELL_CONFIG_CORE_CONFIG_LOADED
        source '$CONFIG_LOADER'
        unset SHELL_CONFIG_WELCOME_STYLE
        _load_config_simple '$config_file'
        echo \"\$SHELL_CONFIG_WELCOME_STYLE\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "auto session" ]
}

@test "config: skips comment lines" {
    local config_file="$TEST_TMPDIR/config"
    cat > "$config_file" << 'EOF'
# This is a comment
SHELL_CONFIG_WELCOME=true
  # Indented comment
SHELL_CONFIG_EZA=false
EOF
    run bash -c "
        unset _SHELL_CONFIG_CORE_CONFIG_LOADED
        source '$CONFIG_LOADER'
        unset SHELL_CONFIG_WELCOME SHELL_CONFIG_EZA
        _load_config_simple '$config_file'
        echo \"\$SHELL_CONFIG_WELCOME:\$SHELL_CONFIG_EZA\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "true:false" ]
}

@test "config: skips empty lines" {
    local config_file="$TEST_TMPDIR/config"
    printf 'SHELL_CONFIG_WELCOME=true\n\n\nSHELL_CONFIG_EZA=false\n' > "$config_file"
    run bash -c "
        unset _SHELL_CONFIG_CORE_CONFIG_LOADED
        source '$CONFIG_LOADER'
        unset SHELL_CONFIG_WELCOME SHELL_CONFIG_EZA
        _load_config_simple '$config_file'
        echo \"\$SHELL_CONFIG_WELCOME:\$SHELL_CONFIG_EZA\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "true:false" ]
}

# --- Default values regression (PR #96) ---

@test "config: all boolean defaults are set correctly" {
    run bash -c "
        unset _SHELL_CONFIG_CORE_CONFIG_LOADED
        source '$CONFIG_LOADER'
        echo \"W=\$SHELL_CONFIG_WELCOME\"
        echo \"CS=\$SHELL_CONFIG_COMMAND_SAFETY\"
        echo \"GW=\$SHELL_CONFIG_GIT_WRAPPER\"
        echo \"E=\$SHELL_CONFIG_EZA\"
        echo \"R=\$SHELL_CONFIG_RIPGREP\"
        echo \"S=\$SHELL_CONFIG_SECURITY\"
        echo \"AC=\$SHELL_CONFIG_AUTOCOMPLETE\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"W=true"* ]]
    [[ "$output" == *"CS=true"* ]]
    [[ "$output" == *"GW=true"* ]]
    [[ "$output" == *"E=true"* ]]
    [[ "$output" == *"R=true"* ]]
    [[ "$output" == *"S=true"* ]]
    [[ "$output" == *"AC=false"* ]]
}

@test "config: backward compat WELCOME_MESSAGE_STYLE is set" {
    # PR #96 regression: ensure backward compat alias is maintained
    run bash -c "
        unset _SHELL_CONFIG_CORE_CONFIG_LOADED
        source '$CONFIG_LOADER'
        echo \"\$WELCOME_MESSAGE_STYLE\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "auto" ]
}

@test "config: env vars take precedence over config file" {
    local config_file="$TEST_TMPDIR/config"
    echo "SHELL_CONFIG_WELCOME=true" > "$config_file"
    run bash -c "
        export SHELL_CONFIG_WELCOME=false
        unset _SHELL_CONFIG_CORE_CONFIG_LOADED
        source '$CONFIG_LOADER'
        _load_config_simple '$config_file'
        echo \"\$SHELL_CONFIG_WELCOME\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]
}

@test "config: adds SHELL_CONFIG_ prefix to unprefixed keys" {
    local config_file="$TEST_TMPDIR/config"
    echo "WELCOME=false" > "$config_file"
    run bash -c "
        unset _SHELL_CONFIG_CORE_CONFIG_LOADED
        source '$CONFIG_LOADER'
        unset SHELL_CONFIG_WELCOME
        _load_config_simple '$config_file'
        echo \"\$SHELL_CONFIG_WELCOME\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]
}

# --- Validation regression ---

@test "config: validates welcome_style rejects invalid values" {
    run bash -c "
        unset _SHELL_CONFIG_CORE_CONFIG_LOADED
        source '$CONFIG_LOADER'
        export SHELL_CONFIG_WELCOME_STYLE=invalid_style
        shell_config_validate_config 2>&1
    "
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid"* ]]
}

@test "config: validates welcome_style accepts all valid values" {
    for style in auto repo folder session; do
        run bash -c "
            unset _SHELL_CONFIG_CORE_CONFIG_LOADED
            source '$CONFIG_LOADER'
            export SHELL_CONFIG_WELCOME_STYLE='$style'
            shell_config_validate_config
        "
        [ "$status" -eq 0 ]
    done
}
