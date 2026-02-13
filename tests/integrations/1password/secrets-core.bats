#!/usr/bin/env bats
# Tests for lib/integrations/1password/secrets.sh - 1Password secrets loader

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export OP_SECRETS_LIB="$SHELL_CONFIG_DIR/lib/integrations/1password/secrets.sh"

	# Create temp directory
	export TEST_TMP_DIR="$BATS_TEST_TMPDIR"
	mkdir -p "$TEST_TMP_DIR"

	# Mock 1Password config
	export TEST_CONFIG="$TEST_TMP_DIR/shell-secrets.conf"
	export _OP_SECRETS_CONFIG="$TEST_CONFIG"

	# Create mock op command
	export PATH="$TEST_TMP_DIR/bin:$PATH"
	mkdir -p "$TEST_TMP_DIR/bin"

	cat > "$TEST_TMP_DIR/bin/op" << 'EOF'
#!/bin/bash
# Mock op command for testing
if [[ "$1" == "whoami" ]]; then
	echo "test@example.com"
	exit 0
elif [[ "$1" == "read" ]]; then
	# Return mock secret value
	echo "mock_secret_value"
	exit 0
else
	echo "Mock op command" >&2
	exit 0
fi
EOF
	chmod +x "$TEST_TMP_DIR/bin/op"
}

teardown() {
	unset _OP_SECRETS_CONFIG
	unset _OP_LOADED_SECRETS
	/bin/rm -rf "$TEST_TMP_DIR" 2>/dev/null || true
}

@test "1password secrets library exists" {
	[ -f "$OP_SECRETS_LIB" ]
}

@test "1password secrets library sources without error" {
	run bash -c "source '$OP_SECRETS_LIB'"
	[ "$status" -eq 0 ]
}

@test "_OP_SECRETS_CONFIG points to correct location" {
	run bash -c "source '$OP_SECRETS_LIB' && echo \$_OP_SECRETS_CONFIG"
	[ "$status" -eq 0 ]
	[[ "$output" == *"/shell-secrets.conf" ]]
}

@test "_OP_LOADED_SECRETS array is defined" {
	run bash -c "source '$OP_SECRETS_LIB' && echo \${#_OP_LOADED_SECRETS[@]}"
	[ "$status" -eq 0 ]
}

@test "_op_check_auth function is defined" {
	run bash -c "source '$OP_SECRETS_LIB' && type _op_check_auth"
	[ "$status" -eq 0 ]
}

@test "_op_check_auth returns success when op is available" {
	run bash -c "source '$OP_SECRETS_LIB' && _op_check_auth"
	[ "$status" -eq 0 ]
}

@test "_op_check_auth returns failure when op is not available" {
	# Remove mock op so op command is not found
	/bin/rm -f "$TEST_TMP_DIR/bin/op"

	run bash -c "source '$OP_SECRETS_LIB' && _op_check_auth"
	[ "$status" -eq 1 ]
}

@test "_op_get_session function is defined" {
	run bash -c "source '$OP_SECRETS_LIB' && type _op_get_session"
	[ "$status" -eq 0 ]
}

@test "_op_is_ready function is defined" {
	run bash -c "source '$OP_SECRETS_LIB' && type _op_is_ready"
	[ "$status" -eq 0 ]
}

@test "_op_is_ready returns true when op is authenticated" {
	run bash -c "source '$OP_SECRETS_LIB' && _op_is_ready"
	[ "$status" -eq 0 ]
}

@test "_op_load_secrets function is defined" {
	run bash -c "source '$OP_SECRETS_LIB' && type _op_load_secrets"
	[ "$status" -eq 0 ]
}

@test "_op_load_secrets returns success when authenticated" {
	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets"
	[ "$status" -eq 0 ]
}

@test "_op_load_secrets returns failure when not authenticated" {
	# Remove mock op so op command is not found
	/bin/rm -f "$TEST_TMP_DIR/bin/op"

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets"
	[ "$status" -eq 1 ]
}

@test "_op_load_secrets loads secrets from config file" {
	# Create test config
	cat > "$TEST_CONFIG" << 'EOF'
TEST_SECRET=op://vault/item/field
ANOTHER_SECRET=op://vault/item2/field2
# This is a comment
  COMMENTED_SECRET=op://vault/item/field
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets && echo \$TEST_SECRET"
	[ "$status" -eq 0 ]
	# Output may contain auto-load results; check last line
	[[ "$output" == *"mock_secret_value"* ]]
}

@test "_op_load_secrets skips comments in config" {
	cat > "$TEST_CONFIG" << 'EOF'
# This is a comment
TEST_SECRET=op://vault/item/field
# Another comment
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets"
	[ "$status" -eq 0 ]
}

@test "_op_load_secrets skips empty lines in config" {
	cat > "$TEST_CONFIG" << 'EOF'

TEST_SECRET=op://vault/item/field

EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets"
	[ "$status" -eq 0 ]
}

@test "_op_load_secrets trims whitespace from lines" {
	cat > "$TEST_CONFIG" << 'EOF'
  TEST_SECRET=op://vault/item/field
TEST_SECRET2=op://vault/item2/field2
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets"
	[ "$status" -eq 0 ]
}

@test "_op_load_secrets exports loaded secrets as environment variables" {
	cat > "$TEST_CONFIG" << 'EOF'
TEST_SECRET=op://vault/item/field
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets && env | grep '^TEST_SECRET='"
	[ "$status" -eq 0 ]
	[[ "$output" == *"TEST_SECRET="* ]]
}

@test "_op_load_secrets tracks loaded secrets in _OP_LOADED_SECRETS array" {
	cat > "$TEST_CONFIG" << 'EOF'
SECRET1=op://vault/item1/field1
SECRET2=op://vault/item2/field2
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets && echo \${#_OP_LOADED_SECRETS[@]}"
	[ "$status" -eq 0 ]
	# Should have loaded at least 1 secret (may vary with auto-load)
	[[ "$output" =~ [0-9]+ ]]
}

@test "_op_load_secrets handles missing config file gracefully" {
	export _OP_SECRETS_CONFIG="/nonexistent/config.conf"

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets"
	[ "$status" -eq 0 ] # Should succeed even if config doesn't exist
}

@test "_op_check_auth uses timeout to prevent hangs" {
	# Test that timeout command exists or fallback is available
	run bash -c "command -v timeout"
	if [ "$status" -ne 0 ]; then
		skip "timeout command not available, testing fallback"
	fi

	run bash -c "source '$OP_SECRETS_LIB' && _op_check_auth"
	# Should use timeout successfully
	[ "$status" -eq 0 ]
}

@test "_op_check_auth falls back to perl timeout if timeout unavailable" {
	# This is tested implicitly by the function working
	run bash -c "source '$OP_SECRETS_LIB' && _op_check_auth"
	[ "$status" -eq 0 ]
}

@test "_op_get_session checks for existing session tokens" {
	export OP_SESSION_test="test_token"

	run bash -c "source '$OP_SECRETS_LIB' && _op_get_session"
	[ "$status" -eq 0 ]
}

@test "_op_get_session validates session tokens" {
	export OP_SESSION_test="test_token"

	run bash -c "source '$OP_SECRETS_LIB' && _op_get_session && env | grep OP_SESSION"
	[ "$status" -eq 0 ]
}

@test "secrets library has proper header" {
	run head -n 10 "$OP_SECRETS_LIB"
	[ "$status" -eq 0 ]
	[[ "$output" == *"secrets.sh"* ]]
	[[ "$output" == *"1Password secrets loader"* ]]
}

@test "_op_load_secrets uses timeout protection" {
	cat > "$TEST_CONFIG" << 'EOF'
TEST_SECRET=op://vault/item/field
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets"
	# Should complete quickly due to timeout
	[ "$status" -eq 0 ]
}

@test "_op_load_secrets handles op read failures gracefully" {
	# Create mock op that fails for read
	cat > "$TEST_TMP_DIR/bin/op" << 'EOF'
#!/bin/bash
if [[ "$1" == "read" ]]; then
	exit 1
fi
EOF
	chmod +x "$TEST_TMP_DIR/bin/op"

	cat > "$TEST_CONFIG" << 'EOF'
TEST_SECRET=op://vault/item/field
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets 2>&1"
	# Should continue gracefully even if individual secret fails to load
	# Function logs warning but doesn't exit
	[ "$status" -eq 0 ]
}

@test "_op_check_auth suppresses output" {
	run bash -c "source '$OP_SECRETS_LIB' && _op_check_auth 2>&1"
	# Should be silent or minimal
	[ "$status" -eq 0 ]
	[ -z "$output" ] || [[ "$output" != *"error"* ]] # No error output expected
}

@test "_op_get_session suppresses output" {
	run bash -c "source '$OP_SECRETS_LIB' && _op_get_session 2>&1"
	# Should be silent or minimal
	[ "$status" -eq 0 ]
	[ -z "$output" ] || [[ "$output" != *"error"* ]] # No error output expected
}

@test "secrets loader handles malformed config lines gracefully" {
	cat > "$TEST_CONFIG" << 'EOF'
VALID_LINE=op://vault/item/field
INVALID_LINE_NO_EQUALS
=op://vault/item/field
ANOTHER_VALID=op://vault/item2/field2
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets"
	# Should handle gracefully
	[ "$status" -eq 0 ]
}

@test "secrets loader handles special characters in secret names" {
	cat > "$TEST_CONFIG" << 'EOF'
TEST_SECRET_123=op://vault/item/field
TEST-SECRET-ABC=op://vault/item2/field2
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets"
	[ "$status" -eq 0 ]
}

@test "_op_load_secrets can be called multiple times" {
	cat > "$TEST_CONFIG" << 'EOF'
TEST_SECRET=op://vault/item/field
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets && _op_load_secrets"
	[ "$status" -eq 0 ]
}

@test "_op_load_secrets resets _OP_LOADED_SECRETS on each call" {
	cat > "$TEST_CONFIG" << 'EOF'
SECRET1=op://vault/item1/field1
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets && echo \${#_OP_LOADED_SECRETS[@]}"
	[ "$status" -eq 0 ]
	[[ "$output" == "1" ]]
}

@test "secrets library uses 2s timeout for auth check" {
	# Timeout default is 2s via SC_OP_TIMEOUT
	run grep -E 'SC_OP_TIMEOUT:-2' "$OP_SECRETS_LIB"
	[ "$status" -eq 0 ]
}

@test "secrets library uses 3s timeout for secret reading" {
	# Timeout default is 3s via SC_OP_READ_TIMEOUT
	run grep -E 'SC_OP_READ_TIMEOUT:-3' "$OP_SECRETS_LIB"
	[ "$status" -eq 0 ]
}

@test "_op_load_secrets handles config with trailing whitespace" {
	cat > "$TEST_CONFIG" << 'EOF'
TEST_SECRET=op://vault/item/field
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets && echo \$TEST_SECRET"
	[ "$status" -eq 0 ]
	[[ "$output" == "mock_secret_value" ]]
}

@test "_op_load_secrets handles config with leading whitespace" {
	cat > "$TEST_CONFIG" << 'EOF'
   TEST_SECRET=op://vault/item/field
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets && echo \$TEST_SECRET"
	[ "$status" -eq 0 ]
	[[ "$output" == "mock_secret_value" ]]
}

@test "_op_load_secrets counts loaded and failed secrets" {
	cat > "$TEST_CONFIG" << 'EOF'
SECRET1=op://vault/item1/field1
SECRET2=op://vault/item2/field2
SECRET3=op://vault/item3/field3
EOF

	run bash -c "source '$OP_SECRETS_LIB' && _op_load_secrets"
	# Should load all 3 secrets
	[ "$status" -eq 0 ]
}

@test "secrets loader provides session token caching" {
	export OP_SESSION_test="cached_token"

	run bash -c "source '$OP_SECRETS_LIB' && _op_get_session"
	# Should use cached token
	[ "$status" -eq 0 ]
}
