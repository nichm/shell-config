#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# framework-config-validator.sh - Framework configuration validation
# =============================================================================
# Validates framework configuration files:
#   - vite.config.ts / vite.config.js structure and plugins
#   - next.config.js / next.config.mjs configuration
#   - tsconfig.json strict mode settings
#   - ESLint configuration presence
# Usage:
#   source framework-config-validator.sh
#   validate_framework_config [repo_root]
# =============================================================================

# Prevent double-sourcing
[[ -n "${_FRAMEWORK_CONFIG_VALIDATOR_LOADED:-}" ]] && return 0
readonly _FRAMEWORK_CONFIG_VALIDATOR_LOADED=1

# Determine validation lib directory
if [[ -n "${VALIDATION_LIB_DIR:-}" ]]; then
    _FRAMEWORK_CONFIG_VALIDATOR_DIR="$VALIDATION_LIB_DIR"
elif [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _FRAMEWORK_CONFIG_VALIDATOR_DIR="$SHELL_CONFIG_DIR/lib/validation"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _FRAMEWORK_CONFIG_VALIDATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
    _FRAMEWORK_CONFIG_VALIDATOR_DIR="${HOME}/.shell-config/lib/validation"
fi

# Source shared utilities
source "$_FRAMEWORK_CONFIG_VALIDATOR_DIR/shared/reporters.sh"
source "$_FRAMEWORK_CONFIG_VALIDATOR_DIR/shared/file-operations.sh"

# Source command cache for performance
if [[ -f "$_FRAMEWORK_CONFIG_VALIDATOR_DIR/../../core/command-cache.sh" ]]; then
    source "$_FRAMEWORK_CONFIG_VALIDATOR_DIR/../../core/command-cache.sh"
fi

_FRAMEWORK_CONFIG_ERRORS=()
_FRAMEWORK_CONFIG_WARNINGS=()
_FRAMEWORK_CONFIG_DETAILS=()

# Reset validator state
framework_config_validator_reset() {
    _FRAMEWORK_CONFIG_ERRORS=()
    _FRAMEWORK_CONFIG_WARNINGS=()
    _FRAMEWORK_CONFIG_DETAILS=()
}

# Check TypeScript strict mode
# Usage: _check_tsconfig_strict_mode <repo_root>
_check_tsconfig_strict_mode() {
    local repo_root="$1"
    local tsconfig="$repo_root/tsconfig.json"

    [[ ! -f "$tsconfig" ]] && return 0

    # Check if strict mode is enabled
    # Silent return: jq is optional for tsconfig validation, falls back to grep
    if command_exists "jq"; then
        local strict
        strict=$(jq -r '.compilerOptions.strict // "false"' "$tsconfig" 2>/dev/null)

        if [[ "$strict" != "true" ]]; then
            _FRAMEWORK_CONFIG_WARNINGS+=("tsconfig.json")
            _FRAMEWORK_CONFIG_DETAILS+=("tsconfig.json - strict mode not enabled. WHY: Helps catch common errors early. FIX: Set \"strict\": true in compilerOptions.")
            return 1
        fi
    else
        # Fallback: grep check
        if ! grep -q '"strict"\s*:\s*true' "$tsconfig" 2>/dev/null; then
            _FRAMEWORK_CONFIG_WARNINGS+=("tsconfig.json")
            _FRAMEWORK_CONFIG_DETAILS+=("tsconfig.json - strict mode not enabled (recommended: \"strict\": true)")
            return 1
        fi
    fi

    return 0
}

# Check Vite configuration
# Usage: _check_vite_config <repo_root>
_check_vite_config() {
    local repo_root="$1"
    local vite_config=""
    local config_found=0

    # Look for vite config file
    for ext in ts js mts cjs; do
        local config_file="$repo_root/vite.config.$ext"
        if [[ -f "$config_file" ]]; then
            vite_config="$config_file"
            config_found=1
            break
        fi
    done

    [[ $config_found -eq 0 ]] && return 0

    # Check for required configuration
    local warnings=0

    # Check if plugins array exists
    if ! grep -q "plugins" "$vite_config" 2>/dev/null; then
        _FRAMEWORK_CONFIG_WARNINGS+=("vite.config")
        _FRAMEWORK_CONFIG_DETAILS+=("vite.config - No plugins configured (consider adding react/sw plugins)")
        ((warnings++))
    fi

    # Check for build optimization
    if ! grep -q "build" "$vite_config" 2>/dev/null; then
        _FRAMEWORK_CONFIG_WARNINGS+=("vite.config")
        _FRAMEWORK_CONFIG_DETAILS+=("vite.config - Build configuration missing (consider adding target and minify options)")
        ((warnings++))
    fi

    return $warnings
}

# Check Next.js configuration
# Usage: _check_nextjs_config <repo_root>
_check_nextjs_config() {
    local repo_root="$1"
    local next_config=""
    local config_found=0

    # Look for next config file
    for ext in js mjs cjs ts; do
        local config_file="$repo_root/next.config.$ext"
        if [[ -f "$config_file" ]]; then
            next_config="$config_file"
            config_found=1
            break
        fi
    done

    [[ $config_found -eq 0 ]] && return 0

    # Check for recommended configuration
    local warnings=0

    # Check for experimental features
    if ! grep -q "experimental" "$next_config" 2>/dev/null; then
        _FRAMEWORK_CONFIG_WARNINGS+=("next.config")
        _FRAMEWORK_CONFIG_DETAILS+=("next.config - Consider enabling experimental features for performance")
        ((warnings++))
    fi

    # Check for image optimization
    if ! grep -q "images" "$next_config" 2>/dev/null; then
        _FRAMEWORK_CONFIG_WARNINGS+=("next.config")
        _FRAMEWORK_CONFIG_DETAILS+=("next.config - Image optimization configuration missing (add images.domain or images.remotePatterns)")
        ((warnings++))
    fi

    return $warnings
}

# Check linter configuration (prefers oxlint which needs no config)
# Usage: _check_linter_config <repo_root>
_check_linter_config() {
    local repo_root="$1"

    # Check if using oxlint (preferred - needs no config file)
    if command_exists "oxlint" \
        || [[ -f "$repo_root/node_modules/.bin/oxlint" ]] \
        || grep -q '"oxlint"' "$repo_root/package.json" 2>/dev/null; then
        # oxlint found - no config needed, this is the preferred setup
        return 0
    fi

    # If not using oxlint, check for ESLint config
    local config_found=0

    # Look for eslint config file (flat config or legacy)
    local flat_configs=(
        "eslint.config.js"
        "eslint.config.mjs"
        "eslint.config.ts"
    )

    local legacy_configs=(
        ".eslintrc.js"
        ".eslintrc.cjs"
        ".eslintrc.json"
        ".eslintrc.yml"
        ".eslintrc.yaml"
    )

    # Check flat config first
    for config_file in "${flat_configs[@]}"; do
        local config_path="$repo_root/$config_file"
        if [[ -f "$config_path" ]]; then
            config_found=1
            break
        fi
    done

    # Check legacy config
    if [[ $config_found -eq 0 ]]; then
        for config_file in "${legacy_configs[@]}"; do
            local config_path="$repo_root/$config_file"
            if [[ -f "$config_path" ]]; then
                config_found=1
                break
            fi
        done
    fi

    # Check package.json for eslintConfig
    if [[ $config_found -eq 0 ]]; then
        local package_json="$repo_root/package.json"
        if [[ -f "$package_json" ]]; then
            # Silent return: jq is optional for package.json validation, falls back to grep
            if command_exists "jq"; then
                local has_eslint_config
                has_eslint_config=$(jq -r '.eslintConfig // "false"' "$package_json" 2>/dev/null)
                if [[ "$has_eslint_config" != "false" ]]; then
                    config_found=1
                fi
            fi
        fi
    fi

    # If using eslint but no config found, warn (not error)
    if [[ $config_found -eq 0 ]]; then
        # Only warn if eslint is actually being used
        if command_exists "eslint" \
            || [[ -f "$repo_root/node_modules/.bin/eslint" ]] \
            || grep -q '"eslint"' "$repo_root/package.json" 2>/dev/null; then
            _FRAMEWORK_CONFIG_WARNINGS+=("eslint.config")
            _FRAMEWORK_CONFIG_DETAILS+=("eslint.config - ESLint found but no configuration. FIX: Consider switching to oxlint (faster, zero-config) or add ESLint config.")
        fi
    fi

    return 0
}

# Check for oxlint or eslint availability (prefers oxlint)
# Usage: _check_lint_tools <repo_root>
_check_lint_tools() {
    local repo_root="$1"

    local has_oxlint=0
    local has_eslint=0

    # Check if oxlint is installed (preferred)
    if command_exists "oxlint"; then
        has_oxlint=1
    fi

    # Check locally in node_modules (preferred: oxlint first)
    if [[ -f "$repo_root/node_modules/.bin/oxlint" ]]; then
        has_oxlint=1
    fi

    # Check package.json devDependencies for oxlint (preferred)
    local package_json="$repo_root/package.json"
    if [[ -f "$package_json" ]]; then
        if command_exists "jq"; then
            if jq -e '(.devDependencies.oxlint // .dependencies.oxlint // null) != null' "$package_json" >/dev/null 2>&1; then
                has_oxlint=1
            fi
        elif grep -q '"oxlint"' "$package_json" 2>/dev/null; then
            has_oxlint=1
        fi
    fi

    # If oxlint found, we're done (it's preferred)
    if [[ $has_oxlint -eq 1 ]]; then
        return 0
    fi

    # Fall back to eslint check
    if command_exists "eslint"; then
        has_eslint=1
    fi

    if [[ -f "$repo_root/node_modules/.bin/eslint" ]]; then
        has_eslint=1
    fi

    if [[ -f "$package_json" ]]; then
        if command_exists "jq"; then
            if jq -e '(.devDependencies.eslint // .dependencies.eslint // null) != null' "$package_json" >/dev/null 2>&1; then
                has_eslint=1
            fi
        elif grep -q '"eslint"' "$package_json" 2>/dev/null; then
            has_eslint=1
        fi
    fi

    if [[ $has_eslint -eq 1 ]]; then
        return 0
    fi

    # No linter found - this is a warning, not an error
    # Recommend oxlint as the preferred choice
    _FRAMEWORK_CONFIG_WARNINGS+=("linter")
    _FRAMEWORK_CONFIG_DETAILS+=("linter - No linter found. FIX: Install oxlint (recommended) or eslint: npm install -D oxlint")
    return 0
}

# Validate framework configuration
# Usage: validate_framework_config [repo_root]
validate_framework_config() {
    framework_config_validator_reset

    local repo_root="${1:-.}"
    repo_root=$(cd "$repo_root" && pwd)

    # Check TypeScript config
    _check_tsconfig_strict_mode "$repo_root"

    # Check Vite config
    _check_vite_config "$repo_root"

    # Check Next.js config
    _check_nextjs_config "$repo_root"

    # Check for lint tools and config (prefers oxlint)
    _check_lint_tools "$repo_root"
    _check_linter_config "$repo_root"
}

# =============================================================================
# REPORTING
# =============================================================================

framework_config_validator_has_errors() {
    [[ ${#_FRAMEWORK_CONFIG_ERRORS[@]} -gt 0 ]]
}

framework_config_validator_has_warnings() {
    [[ ${#_FRAMEWORK_CONFIG_WARNINGS[@]} -gt 0 ]]
}

framework_config_validator_error_count() {
    echo "${#_FRAMEWORK_CONFIG_ERRORS[@]}"
}

framework_config_validator_warning_count() {
    echo "${#_FRAMEWORK_CONFIG_WARNINGS[@]}"
}

# Show errors with formatted output
framework_config_validator_show_errors() {
    if ! framework_config_validator_has_errors && ! framework_config_validator_has_warnings; then
        validation_log_success "Framework configuration check passed"
        return 0
    fi

    local exit_code=0

    # Show errors (blocking)
    if framework_config_validator_has_errors; then
        local count=${#_FRAMEWORK_CONFIG_ERRORS[@]}
        echo "" >&2
        validation_log_error "Framework configuration errors ($count issue(s)):"
        echo "" >&2

        for i in "${!_FRAMEWORK_CONFIG_ERRORS[@]}"; do
            echo "  ❌ ${_FRAMEWORK_CONFIG_ERRORS[$i]}" >&2
            [[ -n "${_FRAMEWORK_CONFIG_DETAILS[$i]:-}" ]] \
                && echo "     ${_FRAMEWORK_CONFIG_DETAILS[$i]}" >&2
        done

        echo "" >&2
        validation_bypass_hint "GIT_SKIP_FRAMEWORK_CONFIG_CHECK" "Fix config or bypass"
        echo "" >&2
        exit_code=1
    fi

    # Show warnings (non-blocking)
    if framework_config_validator_has_warnings; then
        local count=${#_FRAMEWORK_CONFIG_WARNINGS[@]}
        echo "" >&2
        validation_log_warning "Framework configuration warnings ($count issue(s)):"
        echo "" >&2

        # Deduplicate warnings
        local seen=()
        for i in "${!_FRAMEWORK_CONFIG_WARNINGS[@]}"; do
            local warning="${_FRAMEWORK_CONFIG_WARNINGS[$i]}"
            local detail="${_FRAMEWORK_CONFIG_DETAILS[$i]:-}"

            # Check if we've seen this warning
            local duplicate=0
            for s in "${seen[@]}"; do
                [[ "$s" == "$warning" ]] && duplicate=1 && break
            done

            [[ $duplicate -eq 0 ]] && echo "  ⚠️  $warning" >&2
            [[ -n "$detail" ]] && [[ $duplicate -eq 0 ]] && echo "     $detail" >&2

            seen+=("$warning")
        done

        echo "" >&2
    fi

    return $exit_code
}

# =============================================================================
# EXPORTS
# =============================================================================

if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f framework_config_validator_reset 2>/dev/null || true
    export -f validate_framework_config 2>/dev/null || true
    export -f framework_config_validator_has_errors 2>/dev/null || true
    export -f framework_config_validator_has_warnings 2>/dev/null || true
    export -f framework_config_validator_error_count 2>/dev/null || true
    export -f framework_config_validator_warning_count 2>/dev/null || true
    export -f framework_config_validator_show_errors 2>/dev/null || true
fi
