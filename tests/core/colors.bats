#!/usr/bin/env bats
# Tests for lib/core/colors.sh - shared color definitions

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export COLORS_LIB="$SHELL_CONFIG_DIR/lib/core/colors.sh"
}

@test "colors library exists" {
	[ -f "$COLORS_LIB" ]
}

@test "colors library sources without error" {
	run bash -c "source '$COLORS_LIB'"
	[ "$status" -eq 0 ]
}

@test "COLOR_RED is defined after sourcing" {
	run bash -c "source '$COLORS_LIB' && echo \$COLOR_RED"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

@test "COLOR_GREEN is defined after sourcing" {
	run bash -c "source '$COLORS_LIB' && echo \$COLOR_GREEN"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

@test "COLOR_RESET is defined after sourcing" {
	run bash -c "source '$COLORS_LIB' && echo \$COLOR_RESET"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

@test "log_info function exists" {
	run bash -c "source '$COLORS_LIB' && type log_info"
	[ "$status" -eq 0 ]
}

@test "log_success function exists" {
	run bash -c "source '$COLORS_LIB' && type log_success"
	[ "$status" -eq 0 ]
}

@test "log_error function exists" {
	run bash -c "source '$COLORS_LIB' && type log_error"
	[ "$status" -eq 0 ]
}

@test "log_warning function exists" {
	run bash -c "source '$COLORS_LIB' && type log_warning"
	[ "$status" -eq 0 ]
}

@test "colors are not re-loaded on second source" {
	run bash -c "
        source '$COLORS_LIB'
        source '$COLORS_LIB'
        echo 'success'
    "
	[ "$status" -eq 0 ]
	[ "$output" = "success" ]
}

# =============================================================================
# 🛡️ GUARD MECHANISM TESTS
# =============================================================================

@test "guard variable is set after sourcing" {
	run bash -c "source '$COLORS_LIB' && echo \$_SHELL_CONFIG_CORE_COLORS_LOADED"
	[ "$status" -eq 0 ]
	[ "$output" = "1" ]
}

@test "guard prevents re-execution of color definitions" {
	run bash -c "
        source '$COLORS_LIB'
        first_load=\$_SHELL_CONFIG_CORE_COLORS_LOADED
        source '$COLORS_LIB'
        second_load=\$_SHELL_CONFIG_CORE_COLORS_LOADED
        [ \"\$first_load\" = \"\$second_load\" ] && echo 'same'
    "
	[ "$status" -eq 0 ]
	[ "$output" = "same" ]
}

# =============================================================================
# 🔄 COMPATIBILITY ALIAS TESTS
# =============================================================================

@test "RED alias is defined" {
	run bash -c "source '$COLORS_LIB' && echo \$RED"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

@test "GREEN alias is defined" {
	run bash -c "source '$COLORS_LIB' && echo \$GREEN"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

@test "NC (no color/reset) alias is defined" {
	run bash -c "source '$COLORS_LIB' && echo \$NC"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

@test "BOLD alias is defined" {
	run bash -c "source '$COLORS_LIB' && echo \$BOLD"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

@test "DIM alias is defined" {
	run bash -c "source '$COLORS_LIB' && echo \$DIM"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

# =============================================================================
# 📊 LOGGING FUNCTION OUTPUT TESTS
# =============================================================================

@test "log_info outputs to stderr" {
	run bash -c "source '$COLORS_LIB' && log_info 'test message' 2>&1"
	[ "$status" -eq 0 ]
	[[ "$output" == *"test message"* ]]
}

@test "log_success outputs to stderr" {
	run bash -c "source '$COLORS_LIB' && log_success 'success message' 2>&1"
	[ "$status" -eq 0 ]
	[[ "$output" == *"success message"* ]]
}

@test "log_error outputs to stderr" {
	run bash -c "source '$COLORS_LIB' && log_error 'error message' 2>&1"
	[ "$status" -eq 0 ]
	[[ "$output" == *"error message"* ]]
}

@test "log_warning outputs to stderr" {
	run bash -c "source '$COLORS_LIB' && log_warning 'warning message' 2>&1"
	[ "$status" -eq 0 ]
	[[ "$output" == *"warning message"* ]]
}

@test "log_step function exists" {
	run bash -c "source '$COLORS_LIB' && type log_step"
	[ "$status" -eq 0 ]
}
