#!/usr/bin/env bats
# =============================================================================
# 🧪 WELCOME SHORTCUTS MODULE TESTS
# =============================================================================
# Tests for lib/welcome/shortcuts.sh - Alias quick reference
# =============================================================================

load ../test_helpers

setup() {
    # MUST set AUTORUN before anything else to prevent welcome from running
    export WELCOME_MESSAGE_AUTORUN="false"
    export WELCOME_MESSAGE_ENABLED="false"
    
    setup_test_env

    local repo_root
    repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export SHELL_CONFIG_DIR="$repo_root"
    export WELCOME_DIR="$SHELL_CONFIG_DIR/lib/welcome"
    
    # Initialize colors needed by welcome modules
    export _WM_COLOR_RESET=$'\033[0m'
    export _WM_COLOR_BOLD=$'\033[1m'
    export _WM_COLOR_DIM=$'\033[2m'
    export _WM_COLOR_GREEN=$'\033[0;32m'
    export _WM_COLOR_RED=$'\033[0;31m'
    export _WM_COLOR_YELLOW=$'\033[0;33m'
    export _WM_COLOR_CYAN=$'\033[0;36m'
    export _WM_COLOR_GRAY=$'\033[0;90m'
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# 📁 FILE EXISTENCE TESTS
# =============================================================================

@test "shortcuts.sh exists" {
    [ -f "$WELCOME_DIR/shortcuts.sh" ]
}

@test "shortcuts.sh sources without error" {
    run bash -c "
        _WM_COLOR_RESET='\033[0m'
        _WM_COLOR_BOLD='\033[1m'
        _WM_COLOR_DIM='\033[2m'
        _WM_COLOR_GREEN='\033[0;32m'
        _WM_COLOR_RED='\033[0;31m'
        _WM_COLOR_YELLOW='\033[0;33m'
        _WM_COLOR_CYAN='\033[0;36m'
        _WM_COLOR_GRAY='\033[0;90m'
        export _WM_COLOR_RESET _WM_COLOR_BOLD _WM_COLOR_DIM _WM_COLOR_GREEN _WM_COLOR_RED _WM_COLOR_YELLOW _WM_COLOR_CYAN _WM_COLOR_GRAY
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        source '$WELCOME_DIR/shortcuts.sh'
    "
    [ "$status" -eq 0 ]
}

# =============================================================================
# ⚙️ CONFIGURATION TESTS
# =============================================================================

@test "WELCOME_SHORTCUTS defaults to true" {
    source "$WELCOME_DIR/shortcuts.sh"
    [ "$WELCOME_SHORTCUTS" = "true" ]
}

@test "_welcome_show_shortcuts respects disabled setting" {
    source "$WELCOME_DIR/shortcuts.sh"
    export WELCOME_SHORTCUTS="false"
    
    run _welcome_show_shortcuts
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# =============================================================================
# 🔧 FUNCTION TESTS
# =============================================================================

@test "_shortcuts_get_vps_ip returns empty when no SSH config" {
    source "$WELCOME_DIR/shortcuts.sh"
    
    # With test HOME, no SSH config exists
    run _shortcuts_get_vps_ip
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "_print_shortcut outputs formatted shortcut" {
    source "$WELCOME_DIR/shortcuts.sh"
    
    run _print_shortcut "test" "Test description"
    [ "$status" -eq 0 ]
    # Should contain the shortcut name
    [[ "$output" == *"test"* ]]
}

@test "_welcome_show_shortcuts outputs when enabled" {
    source "$WELCOME_DIR/shortcuts.sh"
    export WELCOME_SHORTCUTS="true"
    
    run _welcome_show_shortcuts
    [ "$status" -eq 0 ]
    # Should have some output when enabled
    [ -n "$output" ]
}

# =============================================================================
# 📊 OUTPUT TESTS
# =============================================================================

@test "shortcuts shows Quick Shortcuts header" {
    source "$WELCOME_DIR/shortcuts.sh"
    export WELCOME_SHORTCUTS="true"
    
    run _welcome_show_shortcuts
    [ "$status" -eq 0 ]
    [[ "$output" == *"Shortcuts"* ]] || [[ "$output" == *"⌨"* ]]
}
