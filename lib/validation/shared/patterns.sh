#!/usr/bin/env bash
# Regex patterns for sensitive file detection (dependency-free)
set -euo pipefail

# Prevent double-sourcing - but allow if arrays are empty (e.g., in new process)
# Arrays can't be exported across processes, so we check actual array content
if [[ -n "${_VALIDATION_PATTERNS_LOADED:-}" ]] && [[ ${#SENSITIVE_PATTERNS_HIGH[@]} -gt 0 ]]; then
    return 0
fi
_VALIDATION_PATTERNS_LOADED=1

# Patterns ordered by frequency for performance
readonly -a SENSITIVE_PATTERNS_HIGH=(
    '\.env$'            # Single .env files (most common)
    '\.env\..*$'        # .env.*, .env.local, .env.production
    '\.pem$'            # Certificate/key files
    '\.key$'            # Private keys
    '\.envrc$'          # Direnv files
    'credentials\.json' # Generic credentials
    '\.crt$'            # Certificates
)

# SSH and certificates
readonly -a SENSITIVE_PATTERNS_SSH=(
    '^id_rsa$'
    '^id_ed25519$'
    '^id_ecdsa$'
    '^id_dsa$'
    '^id_ecdsa_sk$'
    '^id_ed25519_sk$'
    'ssh_host_.*_key$'
    '^authorized_keys$'
    '^known_hosts$'
    '^ssh_config$'
    '\.ssh/config$'
    '\.p12$'
    '\.pfx$'
    '\.cer$'
    '\.der$'
    '\.csr$'
    '\.crl$'
)

# Database files
readonly -a SENSITIVE_PATTERNS_DATABASE=(
    '\.db$'
    '\.sqlite$'
    '\.sqlite3$'
    '^database\.yml$'
    '^database\.yaml$'
    '^database\.json$'
    '^database\.conf$'
    'my\.cnf'
    '\.my\.cnf'
    'pgpass$'
    '\.pgpass$'
)

# Secrets and credentials
readonly -a SENSITIVE_PATTERNS_SECRETS=(
    '.*secret.*\.json'
    '.*secret.*\.yml'
    '.*secret.*\.yaml'
    '.*secret.*\.txt'
    '.*secret.*\.xml'
    '.*password.*\.json'
    '.*password.*\.yml'
    '.*password.*\.yaml'
    '.*password.*\.txt'
    '.*password.*\.xml'
    '^secrets\.yml$'
    '^secrets\.yaml$'
    '^secrets\.json$'
    '^secrets\.xml$'
    '^secrets\.conf$'
    'credentials\.yml'
    'credentials\.yaml'
    'credentials\.xml'
    'creds\.json'
    'creds\.yml'
    'creds\.yaml'
    '.*auth.*\.json'
    '.*auth.*\.yml'
    '.*auth.*\.yaml'
    '.*token.*\.json'
    '.*token.*\.txt'
)

# Cloud provider credentials
readonly -a SENSITIVE_PATTERNS_CLOUD=(
    '\.aws/credentials'
    '\.aws/config'
    'aws-credentials\.json'
    'gcp-service-account.*\.json'
    '.*service-account.*\.json'
    'azure-credentials\.json'
    '.*azure.*auth.*\.json'
    '\.gcloud/credentials'
    'application_default_credentials\.json'
    'heroku-credentials\.json'
    'digitalocean.*\.json'
    'cloudflare.*\.json'
)

# Infrastructure files
readonly -a SENSITIVE_PATTERNS_INFRA=(
    '\.tfvars$'
    '\.tfstate$'
    '\.tfstate\.backup$'
    'kubeconfig.*'
    '.*\.kubeconfig'
    '\.kube/config'
    'ansible-vault.*'
    '.*vault.*\.yml'
    '.*vault.*\.yaml'
    '.*vault.*\.pass'
)

# Backup and temp files
readonly -a SENSITIVE_PATTERNS_BACKUP=(
    '\.backup$'
    '\.bak$'
    '\.old$'
    '\.save$'
    '\.tmp$'
    '\.swp$'
    '~$'
    'backup-.*\.sql'
    '.*backup\.sql'
    'dump\.sql'
    '.*\.sql\.gz$'
)

# API keys and tokens
readonly -a SENSITIVE_PATTERNS_API=(
    'api-key.*\..*'
    'apikey\..*'
    'api_key\..*'
    'api-token.*\..*'
    'apitoken\..*'
    'api_token\..*'
    '.*api.*secret.*\..*'
    '.*private.*key.*\..*'
    'oauth.*\.json'
    'jwt.*\.key'
)

# Archives (may contain sensitive data)
readonly -a SENSITIVE_PATTERNS_ARCHIVE=(
    '\.zip$'
    '\.tar$'
    '\.tar\.gz$'
    '\.tgz$'
    '\.rar$'
    '\.7z$'
    'secret.*\.zip'
    'credentials.*\.zip'
    'keys.*\.zip'
)

# =============================================================================
# ALLOWED PATTERNS (Exceptions)
# =============================================================================
# Files matching these patterns are permitted even if they match sensitive patterns

# shellcheck disable=SC2034  # Used by security-validator.sh after sourcing
readonly -a ALLOWED_PATTERNS=(
    '\.example$'
    '\.sample$'
    '\.template$'
    '\.dist$'
    '\.default$'
    '^tests/'
    '^test/'
    '^fixtures/'
    '^examples/'
    '^docs/'
)

# =============================================================================
# COMBINED PATTERNS ARRAY
# =============================================================================
# For backwards compatibility and simple iteration

_build_all_sensitive_patterns() {
    local -a all_patterns=()
    all_patterns+=("${SENSITIVE_PATTERNS_HIGH[@]}")
    all_patterns+=("${SENSITIVE_PATTERNS_SSH[@]}")
    all_patterns+=("${SENSITIVE_PATTERNS_DATABASE[@]}")
    all_patterns+=("${SENSITIVE_PATTERNS_SECRETS[@]}")
    all_patterns+=("${SENSITIVE_PATTERNS_CLOUD[@]}")
    all_patterns+=("${SENSITIVE_PATTERNS_INFRA[@]}")
    all_patterns+=("${SENSITIVE_PATTERNS_BACKUP[@]}")
    all_patterns+=("${SENSITIVE_PATTERNS_API[@]}")
    all_patterns+=("${SENSITIVE_PATTERNS_ARCHIVE[@]}")
    printf '%s\n' "${all_patterns[@]}"
}

# Export function for subshells
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f _build_all_sensitive_patterns 2>/dev/null || true
fi
