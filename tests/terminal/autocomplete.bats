#!/usr/bin/env bats
# =============================================================================
# TERMINAL AUTOCOMPLETE TESTS
# =============================================================================
# Tests for lib/terminal/autocomplete.sh
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export AUTOCOMPLETE_FILE="$SHELL_CONFIG_DIR/lib/terminal/autocomplete.sh"
}

@test "autocomplete: file exists and is readable" {
	[ -f "$AUTOCOMPLETE_FILE" ]
	[ -r "$AUTOCOMPLETE_FILE" ]
}

@test "autocomplete: valid bash syntax" {
	run bash -n "$AUTOCOMPLETE_FILE"
	[ "$status" -eq 0 ]
}

@test "autocomplete: defines _setup_fzf function" {
	run grep -q '_setup_fzf()' "$AUTOCOMPLETE_FILE"
	[ "$status" -eq 0 ]
}

@test "autocomplete: defines _setup_zsh_autosuggestions function" {
	run grep -q '_setup_zsh_autosuggestions()' "$AUTOCOMPLETE_FILE"
	[ "$status" -eq 0 ]
}

@test "autocomplete: defines _setup_zsh_syntax_highlighting function" {
	run grep -q '_setup_zsh_syntax_highlighting()' "$AUTOCOMPLETE_FILE"
	[ "$status" -eq 0 ]
}

@test "autocomplete: defines _init_autocomplete function" {
	run grep -q '_init_autocomplete()' "$AUTOCOMPLETE_FILE"
	[ "$status" -eq 0 ]
}

@test "autocomplete: _setup_fzf sets FZF_DEFAULT_OPTS" {
	run grep -q 'FZF_DEFAULT_OPTS' "$AUTOCOMPLETE_FILE"
	[ "$status" -eq 0 ]
}

@test "autocomplete: _setup_fzf uses fd when available" {
	run grep -q 'FZF_DEFAULT_COMMAND.*fd' "$AUTOCOMPLETE_FILE"
	[ "$status" -eq 0 ]
}

@test "autocomplete: inshellisense is disabled by default" {
	# Per comment: "causes terminal flashing"
	run grep -q 'DISABLED' "$AUTOCOMPLETE_FILE"
	[ "$status" -eq 0 ]
}

@test "autocomplete: uses command_exists for tool checks" {
	run grep -q 'command_exists' "$AUTOCOMPLETE_FILE"
	[ "$status" -eq 0 ]
}

@test "autocomplete: has command_exists fallback" {
	run grep -q 'declare -f command_exists' "$AUTOCOMPLETE_FILE"
	[ "$status" -eq 0 ]
}

@test "autocomplete: supports both bash and zsh for fzf" {
	run grep -q 'BASH_VERSION' "$AUTOCOMPLETE_FILE"
	[ "$status" -eq 0 ]
	run grep -q 'ZSH_VERSION' "$AUTOCOMPLETE_FILE"
	[ "$status" -eq 0 ]
}
