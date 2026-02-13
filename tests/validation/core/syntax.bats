#!/usr/bin/env bats
# Tests for lib/validation/validators/core/syntax-validator.sh - syntax validation for staged files

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export SYNTAX_LIB="$SHELL_CONFIG_DIR/lib/validation/validators/core/syntax-validator.sh"
}

@test "syntax library exists" {
	[ -f "$SYNTAX_LIB" ]
}

@test "syntax library sources without error" {
	run bash -c "source '$SYNTAX_LIB'"
	[ "$status" -eq 0 ]
}

@test "_get_validators_for_file returns oxlint for .js files" {
	run bash -c "source '$SYNTAX_LIB' && _get_validators_for_file 'test.js'"
	[ "$status" -eq 0 ]
	[[ "$output" == *"oxlint"* ]]
}

@test "_get_validators_for_file returns oxlint for .ts files" {
	run bash -c "source '$SYNTAX_LIB' && _get_validators_for_file 'test.ts'"
	[ "$status" -eq 0 ]
	[[ "$output" == *"oxlint"* ]]
}

@test "_get_validators_for_file returns ruff for .py files" {
	run bash -c "source '$SYNTAX_LIB' && _get_validators_for_file 'test.py'"
	[ "$status" -eq 0 ]
	[[ "$output" == *"ruff"* ]]
}

@test "_get_validators_for_file returns shellcheck for .sh files" {
	run bash -c "source '$SYNTAX_LIB' && _get_validators_for_file 'test.sh'"
	[ "$status" -eq 0 ]
	[[ "$output" == *"shellcheck"* ]]
}

@test "_get_validators_for_file returns yamllint for .yml files" {
	run bash -c "source '$SYNTAX_LIB' && _get_validators_for_file 'test.yml'"
	[ "$status" -eq 0 ]
	[[ "$output" == *"yamllint"* ]]
}

@test "_get_validators_for_file returns actionlint for GitHub workflow files" {
	run bash -c "source '$SYNTAX_LIB' && _get_validators_for_file '.github/workflows/test.yml'"
	[ "$status" -eq 0 ]
	[[ "$output" == *"actionlint"* ]]
}

@test "_get_validators_for_file returns empty for unknown extensions" {
	run bash -c "source '$SYNTAX_LIB' && _get_validators_for_file 'test.xyz'"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}
