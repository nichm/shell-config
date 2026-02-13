#!/usr/bin/env bats
# =============================================================================
# Tests for lib/bin/command-enforce — Universal PATH-based command safety
# =============================================================================
# Verifies the busybox-style wrapper blocks dangerous commands in ALL shells
# (including non-interactive AI agent shells where function wrappers don't load).
# Sources the EXISTING command-safety engine — zero rule duplication.
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export ENFORCE="$SHELL_CONFIG_DIR/lib/bin/command-enforce"
	export BIN_DIR="$SHELL_CONFIG_DIR/lib/bin"
}

# Helper: check if output contains the blocked emoji
_is_blocked() {
	echo "$output" | grep -q "🛑"
}

# =============================================================================
# Script basics
# =============================================================================

@test "command-enforce: script exists and is executable" {
	[ -f "$ENFORCE" ]
	[ -x "$ENFORCE" ]
}

@test "command-enforce: valid bash syntax" {
	run bash -n "$ENFORCE"
	[ "$status" -eq 0 ]
}

@test "command-enforce: uses set -euo pipefail" {
	run grep -q 'set -euo pipefail' "$ENFORCE"
	[ "$status" -eq 0 ]
}

# =============================================================================
# Symlinks exist for all protected commands
# =============================================================================

@test "command-enforce: symlinks exist for python/pip" {
	for cmd in python python3 pip pip3; do
		[ -L "$BIN_DIR/$cmd" ]
		[ "$(readlink "$BIN_DIR/$cmd")" = "command-enforce" ]
	done
}

@test "command-enforce: symlinks exist for JS package managers" {
	for cmd in npm npx yarn pnpm bun; do
		[ -L "$BIN_DIR/$cmd" ]
		[ "$(readlink "$BIN_DIR/$cmd")" = "command-enforce" ]
	done
}

@test "command-enforce: symlinks exist for dangerous commands" {
	for cmd in chmod sudo dd mkfs sed find truncate; do
		[ -L "$BIN_DIR/$cmd" ]
		[ "$(readlink "$BIN_DIR/$cmd")" = "command-enforce" ]
	done
}

@test "command-enforce: symlinks exist for infra/containers" {
	for cmd in docker kubectl terraform gh; do
		[ -L "$BIN_DIR/$cmd" ]
		[ "$(readlink "$BIN_DIR/$cmd")" = "command-enforce" ]
	done
}

@test "command-enforce: symlinks exist for web/tech tools" {
	for cmd in nginx prettier wrangler supabase next; do
		[ -L "$BIN_DIR/$cmd" ]
		[ "$(readlink "$BIN_DIR/$cmd")" = "command-enforce" ]
	done
}

# =============================================================================
# UV enforcement: python/python3 (blanket block)
# =============================================================================

@test "command-enforce: blocks python3 -c" {
	run "$BIN_DIR/python3" -c "print(1)"
	_is_blocked
	[[ "$output" == *"uv run"* ]]
}

@test "command-enforce: blocks python3 script" {
	run "$BIN_DIR/python3" /dev/null
	_is_blocked
}

@test "command-enforce: blocks bare python3" {
	run "$BIN_DIR/python3"
	_is_blocked
}

@test "command-enforce: blocks python even without real binary" {
	run "$BIN_DIR/python" -c "print(1)"
	_is_blocked
}

# =============================================================================
# UV enforcement: pip/pip3 (blanket block)
# =============================================================================

@test "command-enforce: blocks pip3 install" {
	run "$BIN_DIR/pip3" install requests
	_is_blocked
	[[ "$output" == *"uv"* ]]
}

@test "command-enforce: blocks pip install" {
	run "$BIN_DIR/pip" install requests
	_is_blocked
}

# =============================================================================
# JS package managers (blanket block)
# =============================================================================

@test "command-enforce: blocks npm install" {
	run "$BIN_DIR/npm" install lodash
	_is_blocked
	[[ "$output" == *"bun"* ]]
}

@test "command-enforce: blocks npx" {
	run "$BIN_DIR/npx" create-react-app
	_is_blocked
}

@test "command-enforce: blocks yarn" {
	run "$BIN_DIR/yarn" add lodash
	_is_blocked
}

@test "command-enforce: blocks pnpm" {
	run "$BIN_DIR/pnpm" install lodash
	_is_blocked
}

# =============================================================================
# Conditional blocks: dangerous flags only
# =============================================================================

@test "command-enforce: blocks chmod 777" {
	run "$BIN_DIR/chmod" 777 /dev/null
	_is_blocked
}

@test "command-enforce: allows chmod 755 (safe)" {
	run "$BIN_DIR/chmod" 755 /dev/null
	! _is_blocked
}

@test "command-enforce: blocks sed -i" {
	run "$BIN_DIR/sed" -i "s/a/b/" /dev/null
	_is_blocked
}

@test "command-enforce: allows sed without -i (safe)" {
	run "$BIN_DIR/sed" "s/a/b/" /dev/null
	! _is_blocked
}

@test "command-enforce: blocks find -delete" {
	run "$BIN_DIR/find" /tmp -name "__nonexistent__" -delete
	_is_blocked
}

@test "command-enforce: allows find without -delete (safe)" {
	run "$BIN_DIR/find" /tmp -maxdepth 0 -name "__nonexistent__"
	! _is_blocked
}

# =============================================================================
# Conditional blocks: docker
# =============================================================================

@test "command-enforce: blocks docker rm -f" {
	run "$BIN_DIR/docker" rm -f mycontainer
	_is_blocked
}

@test "command-enforce: allows docker ps (safe)" {
	run "$BIN_DIR/docker" ps
	! _is_blocked
}

# =============================================================================
# Conditional blocks: git tools
# =============================================================================

@test "command-enforce: blocks gh repo delete" {
	run "$BIN_DIR/gh" repo delete test-repo
	_is_blocked
}

@test "command-enforce: allows gh pr list (safe)" {
	run "$BIN_DIR/gh" pr list
	! _is_blocked
}

@test "command-enforce: blocks brew uninstall" {
	run "$BIN_DIR/brew" uninstall firefox
	_is_blocked
}

# =============================================================================
# Fast passthrough (--help / --version)
# =============================================================================

@test "command-enforce: python3 --version passes through" {
	run "$BIN_DIR/python3" --version
	[ "$status" -eq 0 ]
	[[ "$output" == *"Python"* ]]
}

@test "command-enforce: python3 -V passes through" {
	run "$BIN_DIR/python3" -V
	[ "$status" -eq 0 ]
}

@test "command-enforce: npm --version passes through" {
	run "$BIN_DIR/npm" --version
	[ "$status" -eq 0 ]
}

@test "command-enforce: docker --version passes through" {
	run "$BIN_DIR/docker" --version
	[ "$status" -eq 0 ]
	[[ "$output" == *"Docker"* ]]
}

# =============================================================================
# Bypass flags (per-command, from rule definitions)
# =============================================================================

@test "command-enforce: python3 --force-python3 passes through" {
	run "$BIN_DIR/python3" -c "print('bypassed')" --force-python3
	[ "$status" -eq 0 ]
	[[ "$output" == *"bypassed"* ]]
}

@test "command-enforce: bypass flag is stripped from args" {
	run "$BIN_DIR/python3" -c "import sys; print(sys.argv)" --force-python3
	[ "$status" -eq 0 ]
	[[ "$output" != *"--force-python3"* ]]
}

# =============================================================================
# Global disable
# =============================================================================

@test "command-enforce: PATH_ENFORCE_DISABLE=1 passes through python3" {
	PATH_ENFORCE_DISABLE=1 run "$BIN_DIR/python3" -c "print('disabled')"
	[ "$status" -eq 0 ]
	[[ "$output" == *"disabled"* ]]
}

@test "command-enforce: PATH_ENFORCE_DISABLE=1 passes through sed -i" {
	PATH_ENFORCE_DISABLE=1 run "$BIN_DIR/sed" -i "s/a/b/" /dev/null
	! _is_blocked
}

# =============================================================================
# Error message format
# =============================================================================

@test "command-enforce: block shows alternatives" {
	run "$BIN_DIR/python3" -c "print(1)"
	_is_blocked
	[[ "$output" == *"✅"* ]]
}

@test "command-enforce: block shows override instruction" {
	run "$BIN_DIR/python3" -c "print(1)"
	[[ "$output" == *"🔓"* ]]
}

@test "command-enforce: block shows docs link" {
	run "$BIN_DIR/python3" -c "print(1)"
	[[ "$output" == *"📚"* ]]
}
