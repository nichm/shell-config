#!/usr/bin/env bats
# Tests for lib/core/doctor.sh - diagnostic command

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export DOCTOR_LIB="$SHELL_CONFIG_DIR/lib/core/doctor.sh"
}

@test "doctor library exists" {
	[ -f "$DOCTOR_LIB" ]
}

@test "doctor library sources without error" {
	run bash -c "source '$DOCTOR_LIB'"
	[ "$status" -eq 0 ]
}

@test "shell_config_doctor function exists after sourcing" {
	run bash -c "
        source '$DOCTOR_LIB'
        type shell_config_doctor
    "
	[ "$status" -eq 0 ]
}

@test "shell_config_doctor runs without error" {
	run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        source '$DOCTOR_LIB'
        shell_config_doctor
    "
	# Should complete (exit 0 if all checks pass, or >0 with warnings)
	# The output should contain "Shell-Config Doctor"
	[[ "$output" == *"Shell-Config Doctor"* ]]
}

@test "doctor checks for symlinks section" {
	run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        source '$DOCTOR_LIB'
        shell_config_doctor
    "
	[[ "$output" == *"Symlinks"* ]]
}

@test "doctor checks for dependencies section" {
	run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        source '$DOCTOR_LIB'
        shell_config_doctor
    "
	[[ "$output" == *"Dependencies"* ]]
}

@test "doctor checks for feature flags section" {
	run bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        source '$DOCTOR_LIB'
        shell_config_doctor
    "
	[[ "$output" == *"Feature Flags"* ]]
}

@test "shell-config-doctor alias is defined" {
	run bash -c "
        source '$DOCTOR_LIB'
        alias shell-config-doctor
    "
	[ "$status" -eq 0 ]
}
