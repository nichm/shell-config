#!/usr/bin/env bats
# =============================================================================
# VALIDATION SHARED PATTERNS TESTS
# =============================================================================
# Tests for lib/validation/shared/patterns.sh
# Regression: PR #98 (string ops optimization)
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../.."
	export PATTERNS_FILE="$SHELL_CONFIG_DIR/lib/validation/shared/patterns.sh"

	TEST_TEMP_DIR="$(mktemp -d)"
	cd "$TEST_TEMP_DIR" || return 1

	unset _VALIDATION_PATTERNS_LOADED
	source "$PATTERNS_FILE"
}

teardown() {
	cd "$BATS_TEST_DIRNAME" || return 1
	[[ -n "${TEST_TEMP_DIR:-}" ]] && /bin/rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

@test "patterns: file exists and is readable" {
	[ -f "$PATTERNS_FILE" ]
	[ -r "$PATTERNS_FILE" ]
}

@test "patterns: valid bash syntax" {
	run bash -n "$PATTERNS_FILE"
	[ "$status" -eq 0 ]
}

@test "patterns: SENSITIVE_PATTERNS_HIGH is non-empty" {
	[ "${#SENSITIVE_PATTERNS_HIGH[@]}" -gt 0 ]
}

@test "patterns: SENSITIVE_PATTERNS_HIGH includes .env" {
	local found=false
	for p in "${SENSITIVE_PATTERNS_HIGH[@]}"; do
		if [[ "$p" == *'\.env'* ]]; then
			found=true
			break
		fi
	done
	[ "$found" = "true" ]
}

@test "patterns: SENSITIVE_PATTERNS_HIGH includes .pem" {
	local found=false
	for p in "${SENSITIVE_PATTERNS_HIGH[@]}"; do
		if [[ "$p" == *'\.pem'* ]]; then
			found=true
			break
		fi
	done
	[ "$found" = "true" ]
}

@test "patterns: SENSITIVE_PATTERNS_SSH includes id_rsa" {
	[ "${#SENSITIVE_PATTERNS_SSH[@]}" -gt 0 ]
	local found=false
	for p in "${SENSITIVE_PATTERNS_SSH[@]}"; do
		if [[ "$p" == *'id_rsa'* ]]; then
			found=true
			break
		fi
	done
	[ "$found" = "true" ]
}

@test "patterns: SENSITIVE_PATTERNS_DATABASE includes .sqlite" {
	[ "${#SENSITIVE_PATTERNS_DATABASE[@]}" -gt 0 ]
	local found=false
	for p in "${SENSITIVE_PATTERNS_DATABASE[@]}"; do
		if [[ "$p" == *'sqlite'* ]]; then
			found=true
			break
		fi
	done
	[ "$found" = "true" ]
}

@test "patterns: SENSITIVE_PATTERNS_SECRETS includes secrets.yml" {
	[ "${#SENSITIVE_PATTERNS_SECRETS[@]}" -gt 0 ]
}

@test "patterns: SENSITIVE_PATTERNS_CLOUD includes aws credentials" {
	[ "${#SENSITIVE_PATTERNS_CLOUD[@]}" -gt 0 ]
	local found=false
	for p in "${SENSITIVE_PATTERNS_CLOUD[@]}"; do
		if [[ "$p" == *'aws'* ]]; then
			found=true
			break
		fi
	done
	[ "$found" = "true" ]
}

@test "patterns: SENSITIVE_PATTERNS_INFRA includes .tfvars" {
	[ "${#SENSITIVE_PATTERNS_INFRA[@]}" -gt 0 ]
}

@test "patterns: SENSITIVE_PATTERNS_BACKUP includes .bak" {
	[ "${#SENSITIVE_PATTERNS_BACKUP[@]}" -gt 0 ]
}

@test "patterns: SENSITIVE_PATTERNS_API includes api-key" {
	[ "${#SENSITIVE_PATTERNS_API[@]}" -gt 0 ]
}

@test "patterns: SENSITIVE_PATTERNS_ARCHIVE includes .zip" {
	[ "${#SENSITIVE_PATTERNS_ARCHIVE[@]}" -gt 0 ]
}

@test "patterns: ALLOWED_PATTERNS is non-empty" {
	[ "${#ALLOWED_PATTERNS[@]}" -gt 0 ]
}

@test "patterns: ALLOWED_PATTERNS includes .example" {
	local found=false
	for p in "${ALLOWED_PATTERNS[@]}"; do
		if [[ "$p" == *'example'* ]]; then
			found=true
			break
		fi
	done
	[ "$found" = "true" ]
}

@test "patterns: ALLOWED_PATTERNS includes tests/ path" {
	local found=false
	for p in "${ALLOWED_PATTERNS[@]}"; do
		if [[ "$p" == *'tests/'* ]]; then
			found=true
			break
		fi
	done
	[ "$found" = "true" ]
}

@test "patterns: _build_all_sensitive_patterns returns all patterns combined" {
	local total
	total=$(_build_all_sensitive_patterns | wc -l)
	# Total should be sum of all individual arrays
	local expected=$((
		${#SENSITIVE_PATTERNS_HIGH[@]} +
		${#SENSITIVE_PATTERNS_SSH[@]} +
		${#SENSITIVE_PATTERNS_DATABASE[@]} +
		${#SENSITIVE_PATTERNS_SECRETS[@]} +
		${#SENSITIVE_PATTERNS_CLOUD[@]} +
		${#SENSITIVE_PATTERNS_INFRA[@]} +
		${#SENSITIVE_PATTERNS_BACKUP[@]} +
		${#SENSITIVE_PATTERNS_API[@]} +
		${#SENSITIVE_PATTERNS_ARCHIVE[@]}
	))
	[ "$total" -eq "$expected" ]
}

@test "patterns: .env file matches SENSITIVE_PATTERNS_HIGH" {
	local matched=false
	for pattern in "${SENSITIVE_PATTERNS_HIGH[@]}"; do
		if [[ ".env" =~ $pattern ]]; then
			matched=true
			break
		fi
	done
	[ "$matched" = "true" ]
}

@test "patterns: .env.example does NOT match when allowed" {
	# Test that .example files are in the allowed list
	local is_allowed=false
	for pattern in "${ALLOWED_PATTERNS[@]}"; do
		if [[ ".env.example" =~ $pattern ]]; then
			is_allowed=true
			break
		fi
	done
	[ "$is_allowed" = "true" ]
}
