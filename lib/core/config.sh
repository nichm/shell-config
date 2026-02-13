#!/usr/bin/env bash
# =============================================================================
# Configuration Loader Library
# =============================================================================
# This is the canonical implementation of configuration loading.
# All other scripts should source this file instead of duplicating code.
# Usage: source "$SHELL_CONFIG_DIR/lib/core/config.sh"
# Provides:
#   - shell_config_load_config(): Load configuration from files
#   - shell_config_validate_config(): Validate configuration values
#   - shell_config_show_config(): Display current configuration
# Config paths (in order of priority):
#   - ~/.config/shell-config/config.yml
#   - ~/.config/shell-config/config
#   - ~/.shell-config/config.yml
#   - ~/.shell-config/config
# Priority: Environment variables > YAML config > Simple config > Defaults
# =============================================================================

# Guard against multiple sourcing
[[ -n "${_SHELL_CONFIG_CORE_CONFIG_LOADED:-}" ]] && return 0
_SHELL_CONFIG_CORE_CONFIG_LOADED=1

# Ensure command_exists is available (sourced via init.sh/hook-bootstrap chain)
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# =============================================================================
# Configuration Paths
# =============================================================================

_XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
_SHELL_CONFIG_DIRS=("$_XDG_CONFIG_HOME/shell-config" "$HOME/.shell-config")
_SHELL_CONFIG_FILES=("$_XDG_CONFIG_HOME/shell-config/config" "$HOME/.shell-config.conf" "$HOME/.shell-config/config")
_SHELL_CONFIG_YAML_FILES=("$_XDG_CONFIG_HOME/shell-config/config.yml" "$HOME/.shell-config/config.yml")

# =============================================================================
# Default Values
# =============================================================================

_SHELL_CONFIG_DEFAULT_SECRETS_CACHE_TTL=300
_SHELL_CONFIG_DEFAULT_WELCOME_CACHE_TTL=60
_SHELL_CONFIG_DEFAULT_DOCTOR_CACHE_TTL=300
_SHELL_CONFIG_DEFAULT_WELCOME_ENABLED=true
_SHELL_CONFIG_DEFAULT_AUTOCOMPLETE_GUIDE=true
_SHELL_CONFIG_DEFAULT_SHORTCUTS=true
_SHELL_CONFIG_DEFAULT_WELCOME_STYLE=auto
_SHELL_CONFIG_DEFAULT_GIT_WRAPPER_ENABLED=true
_SHELL_CONFIG_DEFAULT_SECRETS_ENABLED=true
_SHELL_CONFIG_DEFAULT_COMMAND_SAFETY_ENABLED=true
_SHELL_CONFIG_DEFAULT_EZA_ENABLED=true
_SHELL_CONFIG_DEFAULT_RIPGREP_ENABLED=true
_SHELL_CONFIG_DEFAULT_GHLS_ENABLED=true
_SHELL_CONFIG_DEFAULT_SECURITY_ENABLED=true
_SHELL_CONFIG_DEFAULT_1PASSWORD_ENABLED=true
_SHELL_CONFIG_DEFAULT_AUTOCOMPLETE_ENABLED=false
_SHELL_CONFIG_DEFAULT_LOG_ROTATION=true

# =============================================================================
# Timeout Constants (configurable via environment)
# =============================================================================
# These constants control timeout values for various operations throughout
# the shell-config codebase. Users can customize these by setting the
# corresponding environment variables before sourcing shell-config.
# Validation: Timeouts must be positive integers between 1 and 120 seconds
# Default values are chosen based on typical operation durations
# =============================================================================

# 1Password CLI timeouts (seconds)
: "${SC_OP_TIMEOUT:=2}"      # Timeout for `op whoami` authentication check
: "${SC_OP_READ_TIMEOUT:=3}" # Timeout for `op read` secret retrieval

# Git hook timeouts (seconds)
: "${SC_HOOK_TIMEOUT:=30}"      # Standard timeout for most git hook operations
: "${SC_HOOK_TIMEOUT_LONG:=60}" # Extended timeout for long-running operations (tests, etc.)
: "${SC_GITLEAKS_TIMEOUT:=10}"  # Timeout for gitleaks secrets scanning

# File size thresholds (bytes)
: "${SC_FILE_SIZE_LIMIT:=$((5 * 1024 * 1024))}" # 5MB - Large file threshold

# File length thresholds (lines)
: "${SC_FILE_LENGTH_DEFAULT:=600}" # Target file length
: "${SC_FILE_LENGTH_MAX:=800}"     # Maximum file length before split required

# =============================================================================
# Configuration Loading Functions
# =============================================================================

# Load simple key=value config file
# Handles quoted values with spaces/special characters
_load_config_simple() {
    local config_file="$1"
    local key value

    [[ -f "$config_file" ]] || return 0

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# || -z "${line// /}" ]] && continue
        [[ "$line" != *=* ]] && continue

        # Extract key and value
        key="${line%%=*}"
        value="${line#*=}"

        # Trim whitespace from key
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"

        # Preserve spaces in quoted values, strip quotes
        value="${value#"${value%%[![:space:]]*}"}" # ltrim
        # Optimized: Use parameter expansion instead of regex for better performance
        # Note: Only strip quotes if BOTH leading and trailing quotes match (e.g., "value" or 'value')
        # Values with mismatched quotes (e.g., "value or value') are left as-is
        if [[ "$value" == \"*\" && "$value" == *\" ]]; then
            value="${value:1:-1}" # Strip both leading and trailing double quotes
        elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
            value="${value:1:-1}" # Strip both leading and trailing single quotes
        else
            value="${value%"${value##*[![:space:]]}"}" # rtrim unquoted
        fi

        [[ -z "$key" ]] && continue

        # Add SHELL_CONFIG_ prefix if not present
        [[ "$key" != SHELL_CONFIG_* ]] && key="SHELL_CONFIG_${key}"

        # Set only if not already set (environment vars take precedence)
        # Cross-shell indirect expansion: bash uses ${!var}, zsh uses ${(P)var}
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            # shellcheck disable=SC2296  # zsh-specific indirect expansion
            [[ -z "${(P)key:-}" ]] && export "$key=$value"
        else
            [[ -z "${!key:-}" ]] && export "$key=$value"
        fi
    done <"$config_file"
}

# Load YAML config file (requires yq)
_load_config_yaml() {
    local config_file="$1"

    [[ -f "$config_file" ]] || return 0
    # Silent return: yq is optional, falls back to .conf files
    command_exists "yq" || return 0

    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue

        # Normalize key name
        # Cross-shell uppercase: bash uses ${var^^}, zsh uses ${(U)var}
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            # shellcheck disable=SC2296  # zsh-specific uppercase expansion
            key="${(U)key}"
        else
            key="${key^^}"
        fi
        key="${key//[-.]/_}"

        # Add SHELL_CONFIG_ prefix if not present
        [[ "$key" != SHELL_CONFIG_* ]] && key="SHELL_CONFIG_${key}"

        # Set only if not already set (environment vars take precedence)
        # Cross-shell indirect expansion: bash uses ${!var}, zsh uses ${(P)var}
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            # shellcheck disable=SC2296  # zsh-specific indirect expansion
            [[ -z "${(P)key:-}" ]] && export "$key=$value"
        else
            [[ -z "${!key:-}" ]] && export "$key=$value"
        fi
    done < <(yq eval '.. | select(kind == "scalar") | (path | join("_")) + "=" + .' "$config_file" 2>/dev/null || true)
}

# Apply defaults for unset values
_apply_config_defaults() {
    : "${SHELL_CONFIG_SECRETS_CACHE_TTL:=$_SHELL_CONFIG_DEFAULT_SECRETS_CACHE_TTL}"
    : "${SHELL_CONFIG_WELCOME_CACHE_TTL:=$_SHELL_CONFIG_DEFAULT_WELCOME_CACHE_TTL}"
    : "${SHELL_CONFIG_DOCTOR_CACHE_TTL:=$_SHELL_CONFIG_DEFAULT_DOCTOR_CACHE_TTL}"
    : "${SHELL_CONFIG_WELCOME:=$_SHELL_CONFIG_DEFAULT_WELCOME_ENABLED}"
    : "${SHELL_CONFIG_COMMAND_SAFETY:=$_SHELL_CONFIG_DEFAULT_COMMAND_SAFETY_ENABLED}"
    : "${SHELL_CONFIG_GIT_WRAPPER:=$_SHELL_CONFIG_DEFAULT_GIT_WRAPPER_ENABLED}"
    : "${SHELL_CONFIG_GHLS:=$_SHELL_CONFIG_DEFAULT_GHLS_ENABLED}"
    : "${SHELL_CONFIG_EZA:=$_SHELL_CONFIG_DEFAULT_EZA_ENABLED}"
    : "${SHELL_CONFIG_RIPGREP:=$_SHELL_CONFIG_DEFAULT_RIPGREP_ENABLED}"
    : "${SHELL_CONFIG_SECURITY:=$_SHELL_CONFIG_DEFAULT_SECURITY_ENABLED}"
    : "${SHELL_CONFIG_1PASSWORD:=$_SHELL_CONFIG_DEFAULT_1PASSWORD_ENABLED}"
    : "${SHELL_CONFIG_AUTOCOMPLETE:=$_SHELL_CONFIG_DEFAULT_AUTOCOMPLETE_ENABLED}"
    : "${SHELL_CONFIG_LOG_ROTATION:=$_SHELL_CONFIG_DEFAULT_LOG_ROTATION}"
    : "${SHELL_CONFIG_AUTOCOMPLETE_GUIDE:=$_SHELL_CONFIG_DEFAULT_AUTOCOMPLETE_GUIDE}"
    : "${SHELL_CONFIG_SHORTCUTS:=$_SHELL_CONFIG_DEFAULT_SHORTCUTS}"
    : "${SHELL_CONFIG_WELCOME_STYLE:=$_SHELL_CONFIG_DEFAULT_WELCOME_STYLE}"

    # Welcome module compatibility (deprecated - use SHELL_CONFIG_* above)
    : "${WELCOME_MESSAGE_ENABLED:=${SHELL_CONFIG_WELCOME}}"
    : "${WELCOME_AUTOCOMPLETE_GUIDE:=${SHELL_CONFIG_AUTOCOMPLETE_GUIDE}}"
    : "${WELCOME_SHORTCUTS:=${SHELL_CONFIG_SHORTCUTS}}"
    : "${WELCOME_MESSAGE_STYLE:=${SHELL_CONFIG_WELCOME_STYLE}}"
}

# Main config loader
shell_config_load_config() {
    # Try YAML configs first
    for f in "${_SHELL_CONFIG_YAML_FILES[@]}"; do
        [[ -f "$f" ]] && {
            _load_config_yaml "$f"
            break
        }
    done

    # Try simple configs
    for f in "${_SHELL_CONFIG_FILES[@]}"; do
        [[ -f "$f" ]] && {
            _load_config_simple "$f"
            break
        }
    done

    # Apply defaults for any unset values
    _apply_config_defaults
}

# Cross-shell indirect variable expansion helper
# Usage: value=$(_sc_indirect_ref "VAR_NAME")
_sc_indirect_ref() {
    local var_name="$1"
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # shellcheck disable=SC2296  # zsh-specific indirect expansion
        echo "${(P)var_name:-}"
    else
        echo "${!var_name:-}"
    fi
}

# Validate configuration values
shell_config_validate_config() {
    local errors=0

    # Validate boolean values
    for var in SHELL_CONFIG_WELCOME SHELL_CONFIG_COMMAND_SAFETY SHELL_CONFIG_GIT_WRAPPER \
        SHELL_CONFIG_GHLS SHELL_CONFIG_EZA SHELL_CONFIG_RIPGREP \
        SHELL_CONFIG_SECURITY SHELL_CONFIG_1PASSWORD SHELL_CONFIG_AUTOCOMPLETE SHELL_CONFIG_LOG_ROTATION; do
        local value
        value=$(_sc_indirect_ref "$var")
        [[ -n "$value" && "$value" != "true" && "$value" != "false" ]] && {
            echo "❌ $var: must be true/false" >&2
            ((errors++))
        }
    done

    # Validate integer values
    for var in SHELL_CONFIG_SECRETS_CACHE_TTL SHELL_CONFIG_WELCOME_CACHE_TTL SHELL_CONFIG_DOCTOR_CACHE_TTL; do
        local value
        value=$(_sc_indirect_ref "$var")
        [[ -n "$value" && ! "$value" =~ ^[0-9]+$ ]] && {
            echo "❌ $var: must be positive integer" >&2
            ((errors++))
        }
    done

    # Validate timeout values (must be positive integers between 1-120 seconds)
    for var in SC_OP_TIMEOUT SC_OP_READ_TIMEOUT SC_HOOK_TIMEOUT SC_HOOK_TIMEOUT_LONG SC_GITLEAKS_TIMEOUT; do
        local value
        value=$(_sc_indirect_ref "$var")
        if [[ -n "$value" ]]; then
            if [[ ! "$value" =~ ^[0-9]+$ ]]; then
                echo "❌ $var: must be positive integer (seconds)" >&2
                ((errors++))
            elif [[ "$value" -gt 120 ]]; then
                echo "⚠️  $var: timeout exceeds 120 seconds (unusual, but valid)" >&2
            fi
        fi
    done

    # Validate file size limit (must be positive integer)
    local size_limit="${SC_FILE_SIZE_LIMIT:-}"
    if [[ -n "$size_limit" ]]; then
        if [[ ! "$size_limit" =~ ^[0-9]+$ ]]; then
            echo "❌ SC_FILE_SIZE_LIMIT: must be positive integer (bytes)" >&2
            ((errors++))
        fi
    fi

    # Validate file length thresholds (must be positive integers)
    for var in SC_FILE_LENGTH_DEFAULT SC_FILE_LENGTH_MAX; do
        local value
        value=$(_sc_indirect_ref "$var")
        if [[ -n "$value" ]]; then
            if [[ ! "$value" =~ ^[0-9]+$ ]]; then
                echo "❌ $var: must be positive integer (lines)" >&2
                ((errors++))
            fi
        fi
    done

    # Validate welcome style
    local style="${SHELL_CONFIG_WELCOME_STYLE:-auto}"
    [[ "$style" != "auto" && "$style" != "repo" && "$style" != "folder" && "$style" != "session" ]] && {
        echo "❌ WELCOME_STYLE: invalid" >&2
        ((errors++))
    }

    return $errors
}

# Show configuration status
shell_config_show_config() {
    echo -e "\n📝 Shell-Config Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Find active config file
    local config_file=""
    for f in "${_SHELL_CONFIG_YAML_FILES[@]}" "${_SHELL_CONFIG_FILES[@]}"; do
        [[ -f "$f" ]] && {
            config_file="$f"
            break
        }
    done
    echo "Config: ${config_file:-None (defaults)}"

    # Display feature status
    echo -e "\nFeatures: welcome=${SHELL_CONFIG_WELCOME:-true} safety=${SHELL_CONFIG_COMMAND_SAFETY:-true} git=${SHELL_CONFIG_GIT_WRAPPER:-true}"
    echo "          ghls=${SHELL_CONFIG_GHLS:-true} eza=${SHELL_CONFIG_EZA:-true} rg=${SHELL_CONFIG_RIPGREP:-true}"
    echo "          security=${SHELL_CONFIG_SECURITY:-true} 1pass=${SHELL_CONFIG_1PASSWORD:-true} autocomplete=${SHELL_CONFIG_AUTOCOMPLETE:-false}"

    # Display cache settings
    echo -e "\nCache: secrets=${SHELL_CONFIG_SECRETS_CACHE_TTL:-300}s welcome=${SHELL_CONFIG_WELCOME_CACHE_TTL:-60}s"

    # Display welcome settings
    echo "Welcome: style=${SHELL_CONFIG_WELCOME_STYLE:-auto} guide=${SHELL_CONFIG_AUTOCOMPLETE_GUIDE:-true} shortcuts=${SHELL_CONFIG_SHORTCUTS:-true}"
}

# =============================================================================
# Auto-load Configuration
# =============================================================================

shell_config_load_config
