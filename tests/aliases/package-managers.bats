#!/usr/bin/env bats
# =============================================================================
# ALIAS TESTS: Package manager shortcuts
# =============================================================================
# Tests for lib/aliases/package-managers.sh
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export ALIAS_FILE="$SHELL_CONFIG_DIR/lib/aliases/package-managers.sh"
}

@test "package-managers aliases: file exists and is readable" {
	[ -f "$ALIAS_FILE" ]
	[ -r "$ALIAS_FILE" ]
}

@test "package-managers aliases: valid bash syntax" {
	run bash -n "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "package-managers aliases: sources without error" {
	run bash -c "source '$ALIAS_FILE'"
	[ "$status" -eq 0 ]
}

@test "package-managers aliases: has idempotent load guard" {
	run grep -q '_SHELL_CONFIG_ALIASES_PACKAGE_MANAGERS_LOADED' "$ALIAS_FILE"
	[ "$status" -eq 0 ]
}

@test "package-managers aliases: defines bun aliases" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias bi && alias ba && alias bx
	"
	[ "$status" -eq 0 ]
}

@test "package-managers aliases: bi is bun install" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias bi
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"bun install"* ]]
}

@test "package-managers aliases: defines uv/python aliases" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias upip && alias ua && alias ur
	"
	[ "$status" -eq 0 ]
}

@test "package-managers aliases: pip redirects to uv pip" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias pip
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"uv pip"* ]]
}

@test "package-managers aliases: defines wrangler aliases" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias wr && alias wrd && alias wrp
	"
	[ "$status" -eq 0 ]
}

@test "package-managers aliases: defines supabase aliases" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias sb && alias sbstart && alias sbstop
	"
	[ "$status" -eq 0 ]
}

@test "package-managers aliases: bdev runs bun run dev" {
	run bash -c "
		shopt -s expand_aliases
		source '$ALIAS_FILE'
		alias bdev
	"
	[ "$status" -eq 0 ]
	[[ "$output" == *"bun run dev"* ]]
}

@test "package-managers aliases: double-source is idempotent" {
	run bash -c "
		source '$ALIAS_FILE'
		source '$ALIAS_FILE'
	"
	[ "$status" -eq 0 ]
}
