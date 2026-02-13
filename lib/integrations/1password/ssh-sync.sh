#!/usr/bin/env bash
# =============================================================================
# 🔐 1Password SSH Key Sync
# =============================================================================
# Finds local SSH keys and imports them to 1Password vault
# Usage:
#   1password-ssh-sync          # List keys, prompt to import
#   1password-ssh-sync --list   # Just list keys (no import)
#   1password-ssh-sync --import # Import all without prompting
# =============================================================================

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

set -euo pipefail

# Source shared protected paths for SSH_DIR constant
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../core/protected-paths.sh"

SSH_DIR="${PROTECTED_SSH_DIR}"
VAULT="${OP_VAULT:-Personal}" # Override with OP_VAULT env var

# Source shared colors library
source "$SCRIPT_DIR/../core/colors.sh"

# 1Password-specific log wrappers (use shared colors)
_log() { echo -e "${BLUE}[1P-SSH]${NC} $*"; }
_success() { echo -e "${GREEN}✓${NC} $*"; }
_warn() { echo -e "${YELLOW}⚠${NC} $*"; }
_error() { echo -e "${RED}✗${NC} $*"; }

# Get or create 1Password session token (persists in environment)
_op_get_session() {
    # Check if op command exists
    # Silent return: internal helper, caller provides WHAT/WHY/FIX error message
    command_exists "op" || return 1

    # First, check for any existing session tokens in environment
    local account_shorthand=""
    local session_var=""
    local session_token=""

    # Look for existing OP_SESSION_* variables
    while IFS= read -r var || [[ -n "$var" ]]; do
        [[ -z "$var" ]] && continue
        session_var="$var"
        account_shorthand="${var#OP_SESSION_}"
        session_token="${!var:-}"

        # Verify existing session is still valid
        if [[ -n "$session_token" ]]; then
            # Export to ensure it's available (even if already set)
            export "$session_var=$session_token"
            # Test if session is valid
            if op whoami &>/dev/null 2>&1; then
                return 0
            fi
            # Session expired, clear it
            unset "$session_var"
        fi
    done < <(env | grep -o '^OP_SESSION_[^=]*' 2>/dev/null || true)

    # No valid session found - get account info and sign in
    account_shorthand=$(op account list --format=json 2>/dev/null \
        | jq -r '.[0].shorthand // .[0].user_uuid // empty' 2>/dev/null) || return 1

    [[ -z "$account_shorthand" ]] && return 1

    session_var="OP_SESSION_${account_shorthand}"

    # Sign in (will prompt once per login, uses Touch ID/Biometric if available)
    # Try with account first, fallback to without if that fails
    session_token=$(op signin --account "$account_shorthand" --raw 2>/dev/null) \
        || session_token=$(op signin --raw 2>/dev/null) || return 1

    if [[ -n "$session_token" ]]; then
        # Export globally so it persists for all subsequent commands
        export "$session_var=$session_token"
        return 0
    fi

    return 1
}

# Check prerequisites
_check_prereqs() {
    if ! command_exists "op"; then
        echo "❌ ERROR: 1Password CLI not installed" >&2
        echo "ℹ️  WHY: SSH key sync requires the 1Password CLI tool" >&2
        echo "💡 FIX: brew install 1password-cli" >&2
        exit 1
    fi

    # Get or create session (this handles authentication)
    if ! _op_get_session; then
        echo "❌ ERROR: Not signed in to 1Password CLI" >&2
        echo "ℹ️  WHY: Cannot access vault without authenticated session" >&2
        echo "💡 FIX: Run 'op signin' then retry" >&2
        exit 1
    fi
}

# Get list of SSH private keys in ~/.ssh/
_find_local_keys() {
    # Validate SSH directory exists
    if [[ ! -d "$SSH_DIR" ]]; then
        _warn "SSH directory not found: $SSH_DIR"
        return 0
    fi

    local keys=()
    for key in "$SSH_DIR"/id_*; do
        # Skip if glob didn't match
        [[ -e "$key" ]] || continue
        # Skip public keys and config files
        [[ "$key" == *.pub ]] && continue
        [[ "$key" == *config* ]] && continue
        [[ "$key" == *known_hosts* ]] && continue
        [[ "$key" == *authorized_keys* ]] && continue
        # Verify it's actually a private key
        if head -1 "$key" 2>/dev/null | grep -q "PRIVATE KEY"; then
            keys+=("$key")
        fi
    done
    printf '%s\n' "${keys[@]}"
}

# Get list of SSH keys already in 1Password
_find_1p_keys() {
    op item list --categories "SSH Key" --format=json 2>/dev/null \
        | jq -r '.[].title' 2>/dev/null || true
}

# Import a key to 1Password
_import_key() {
    local key_path="$1"
    local key_name
    key_name=$(basename "$key_path")

    _log "Importing $key_name..."

    if op item create \
        --category "SSH Key" \
        --title "$key_name" \
        --vault "$VAULT" \
        "private key[file]=$key_path" &>/dev/null; then
        _success "Imported: $key_name"
        return 0
    else
        _error "Failed to import: $key_name"
        return 1
    fi
}

# Main
main() {
    local mode="${1:-interactive}"

    _check_prereqs

    _log "Scanning $SSH_DIR for SSH keys..."

    local local_keys
    local_keys=$(_find_local_keys)

    if [[ -z "$local_keys" ]]; then
        _warn "No SSH private keys found in $SSH_DIR"
        exit 0
    fi

    _log "Found local keys:"
    echo "$local_keys" | while read -r key; do
        echo "  - $(basename "$key")"
    done

    # Get keys already in 1Password
    local op_keys
    op_keys=$(_find_1p_keys)

    echo ""
    _log "Keys already in 1Password:"
    if [[ -n "$op_keys" ]]; then
        echo "$op_keys" | while read -r key; do
            echo "  - $key"
        done
    else
        echo "  (none)"
    fi

    if [[ "$mode" == "--list" ]]; then
        exit 0
    fi

    echo ""

    # Find keys not yet in 1Password
    local to_import=()
    while read -r key_path; do
        local key_name
        key_name=$(basename "$key_path")
        if ! grep -qF "$key_name" <<<"$op_keys"; then
            to_import+=("$key_path")
        fi
    done <<<"$local_keys"

    if [[ ${#to_import[@]} -eq 0 ]]; then
        _success "All local keys are already in 1Password!"
        exit 0
    fi

    _log "Keys to import: ${#to_import[@]}"
    for key in "${to_import[@]}"; do
        echo "  - $(basename "$key")"
    done

    if [[ "$mode" == "--import" ]] || [[ "${OP_SSH_IMPORT_CONFIRM:-}" == "true" ]]; then
        for key in "${to_import[@]}"; do
            _import_key "$key"
        done
    else
        echo "❌ ERROR: Refusing to import SSH keys without confirmation" >&2
        echo "ℹ️  WHY: SSH key import modifies your 1Password vault" >&2
        echo "💡 FIX: Run with --import flag, or set OP_SSH_IMPORT_CONFIRM=true" >&2
        return 1
    fi
}

main "$@"
