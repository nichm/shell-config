#!/usr/bin/env bats
# =============================================================================
# Tests for lib/validation/validators/security/sensitive-files-validator.sh
# =============================================================================

setup() {
	export SHELL_CONFIG_DIR="$BATS_TEST_DIRNAME/../../.."
	export VALIDATOR_LIB="$SHELL_CONFIG_DIR/lib/validation/validators/security/sensitive-files-validator.sh"
	export TEST_TMP="$BATS_TEST_TMPDIR/sensitive-test"
	mkdir -p "$TEST_TMP"

	# Source logging stubs (validator uses log_error/log_warning)
	source "$SHELL_CONFIG_DIR/lib/core/logging.sh" 2>/dev/null || true
}

teardown() {
	/bin/rm -rf "$TEST_TMP" 2>/dev/null || true
}

# =============================================================================
# LIBRARY LOADING
# =============================================================================

@test "sensitive-files-validator exists" {
	[ -f "$VALIDATOR_LIB" ]
}

@test "sensitive-files-validator is valid bash syntax" {
	run bash -n "$VALIDATOR_LIB"
	[ "$status" -eq 0 ]
}

@test "sensitive-files-validator sources without error" {
	run bash -c "
		# Stub log functions
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# FUNCTION DEFINITIONS
# =============================================================================

@test "validate_sensitive_files function is defined" {
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		type validate_sensitive_files
	"
	[ "$status" -eq 0 ]
}

@test "sensitive_files_validator_reset function is defined" {
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		type sensitive_files_validator_reset
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# ENVIRONMENT FILE DETECTION
# =============================================================================

@test "detects .env file" {
	touch "$TEST_TMP/.env"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/.env'
	"
	[ "$status" -eq 1 ]
}

@test "detects .env.local file" {
	touch "$TEST_TMP/.env.local"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/.env.local'
	"
	[ "$status" -eq 1 ]
}

@test "detects .env.production file" {
	touch "$TEST_TMP/.env.production"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/.env.production'
	"
	[ "$status" -eq 1 ]
}

# =============================================================================
# PRIVATE KEY DETECTION
# =============================================================================

@test "detects .key file" {
	touch "$TEST_TMP/server.key"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/server.key'
	"
	[ "$status" -eq 1 ]
}

@test "detects .pem file" {
	touch "$TEST_TMP/cert.pem"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/cert.pem'
	"
	[ "$status" -eq 1 ]
}

@test "detects id_rsa file" {
	touch "$TEST_TMP/id_rsa"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/id_rsa'
	"
	[ "$status" -eq 1 ]
}

@test "detects id_ed25519 file" {
	touch "$TEST_TMP/id_ed25519"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/id_ed25519'
	"
	[ "$status" -eq 1 ]
}

# =============================================================================
# PASSWORD/SECRET FILE DETECTION
# =============================================================================

@test "detects password file" {
	touch "$TEST_TMP/password.txt"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/password.txt'
	"
	[ "$status" -eq 1 ]
}

@test "detects secret file" {
	touch "$TEST_TMP/secret.json"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/secret.json'
	"
	[ "$status" -eq 1 ]
}

@test "detects credential file" {
	touch "$TEST_TMP/credentials.yml"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/credentials.yml'
	"
	[ "$status" -eq 1 ]
}

@test "detects token file" {
	touch "$TEST_TMP/token.txt"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/token.txt'
	"
	[ "$status" -eq 1 ]
}

# =============================================================================
# DATABASE FILE DETECTION
# =============================================================================

@test "detects .db file (warning, not violation)" {
	touch "$TEST_TMP/data.db"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/data.db'
	"
	# db files are warnings, not violations (return 0)
	[ "$status" -eq 0 ]
}

@test "detects .sqlite file (warning, not violation)" {
	touch "$TEST_TMP/data.sqlite"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/data.sqlite'
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# SAFE FILES
# =============================================================================

@test "allows normal source file" {
	touch "$TEST_TMP/main.sh"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/main.sh'
	"
	[ "$status" -eq 0 ]
}

@test "allows README.md" {
	touch "$TEST_TMP/README.md"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/README.md'
	"
	[ "$status" -eq 0 ]
}

@test "allows .env.example" {
	# .env.example matches .env* pattern but is commonly safe
	# This tests the current behavior - .env* catches all
	touch "$TEST_TMP/.env.example"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/.env.example'
	"
	# Current implementation catches ALL .env* files
	[ "$status" -eq 1 ]
}

# =============================================================================
# MULTIPLE FILES
# =============================================================================

@test "counts multiple violations" {
	touch "$TEST_TMP/.env"
	touch "$TEST_TMP/server.key"
	touch "$TEST_TMP/secret.json"
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/.env' '$TEST_TMP/server.key' '$TEST_TMP/secret.json'
	"
	[ "$status" -eq 3 ]
}

@test "skips nonexistent files" {
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		validate_sensitive_files '$TEST_TMP/nonexistent.env'
	"
	[ "$status" -eq 0 ]
}

# =============================================================================
# VALIDATOR INTERFACE
# =============================================================================

@test "sensitive_files_validator_reset succeeds" {
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		sensitive_files_validator_reset
	"
	[ "$status" -eq 0 ]
}

@test "sensitive_files_validator_show_errors succeeds" {
	run bash -c "
		log_error() { echo \"ERROR: \$*\" >&2; }
		log_warning() { echo \"WARN: \$*\" >&2; }
		source '$VALIDATOR_LIB'
		sensitive_files_validator_show_errors
	"
	[ "$status" -eq 0 ]
}
