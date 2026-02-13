#!/usr/bin/env bash
# =============================================================================
# security/sensitive-files-validator.sh - Sensitive filename detection validator
# =============================================================================
# Detects potentially sensitive files that should not be committed:
#   - .env files
#   - Private keys
#   - Password files
#   - Secrets files
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/validation/validators/security/sensitive-files-validator.sh"
#   validate_sensitive_files
# =============================================================================
set -euo pipefail

# Prevent double-sourcing
[[ -n "${_SENSITIVE_FILES_VALIDATOR_LOADED:-}" ]] && return 0
readonly _SENSITIVE_FILES_VALIDATOR_LOADED=1

# Validate files for sensitive filenames
validate_sensitive_files() {
    local files=("$@")
    local violations=0

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            # Check filename patterns for sensitive content
            local basename
            basename=$(basename "$file")

            case "$basename" in
                # Environment files
                .env*)
                    sensitive_files_validator_show_error "Sensitive file detected: $file"
                    echo "   💡 Environment files should not be committed" >&2
                    echo "   💡 Use .env.example for templates" >&2
                    violations=$((violations + 1))
                    ;;
                # Private keys
                *.key | *.pem | *.crt | *.p12 | *.pfx | id_rsa* | id_ed25519* | id_dsa*)
                    sensitive_files_validator_show_error "Private key file detected: $file"
                    echo "   💡 Private keys should not be committed" >&2
                    violations=$((violations + 1))
                    ;;
                # Password/secret files
                *password* | *secret* | *credential* | *auth* | *token*)
                    sensitive_files_validator_show_error "Potential secrets file detected: $file"
                    echo "   💡 Files with 'password/secret/credential/auth/token' should be reviewed" >&2
                    violations=$((violations + 1))
                    ;;
                # Database files
                *.db | *.sqlite | *.sqlite3)
                    sensitive_files_validator_show_warning "Database file detected: $file"
                    echo "   💡 Database files may contain sensitive data" >&2
                    ;;
            esac
        fi
    done

    return $violations
}

# Validator interface functions
sensitive_files_validator_reset() {
    # Reset any internal state if needed
    return 0
}

sensitive_files_validator_show_errors() {
    # This validator handles its own error display
    return 0
}

sensitive_files_validator_show_warning() {
    log_warning "Sensitive Files: $1"
}

sensitive_files_validator_show_error() {
    log_error "Sensitive Files: $1"
}
