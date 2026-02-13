#!/usr/bin/env bash
# =============================================================================
# doctor.sh - Shell-config diagnostic and health check tool
# =============================================================================
# Comprehensive diagnostic tool for shell-config installation. Checks
# symlinks, command availability, versions, and configuration status.
# Provides actionable feedback for troubleshooting issues.
# Dependencies:
#   - git, gh, fzf, rg, eza, trash (optional - for version checks)
# Environment Variables:
#   _SHELL_CONFIG_DOCTOR_LOADED - Guard against double-loading
# Checks Performed:
#   - Symlink integrity (bin commands, config files, git hooks)
#   - Command availability and versions
#   - Installation directory status
#   - Configuration file existence
# Usage:
#   Source this file from shell init - loads automatically
#   Run diagnostics: shell-config-doctor
# Output:
#   Color-coded status (✅ ok, ❌ error, ⚠️  warning)
#   Version information for available commands
#   Symlink targets and broken link detection
# =============================================================================

[[ -n "${_SHELL_CONFIG_DOCTOR_LOADED:-}" ]] && return 0
_SHELL_CONFIG_DOCTOR_LOADED=1

# Source canonical colors library
# shellcheck source=colors.sh
source "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/core/colors.sh"

# Source command cache for optimized command checks
# shellcheck source=command-cache.sh
source "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/core/command-cache.sh"

# Source hook-check utilities for git hook validation
if [[ -f "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/git/shared/hook-check.sh" ]]; then
    source "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/git/shared/hook-check.sh"
fi

_doctor_check_symlink() {
    local path="$1" name="$2"
    if [[ -L "$path" ]] && [[ -e "$path" ]]; then
        printf '  ✅ %s → %s\n' "$name" "$(readlink "$path")"
        return 0
    elif [[ -L "$path" ]]; then
        printf '  ❌ %s (broken symlink)\n' "$name"
        return 1
    elif [[ -e "$path" ]]; then
        printf '  ⚠️  %s (exists but not symlinked)\n' "$name"
        return 1
    else
        printf '  ❌ %s (missing)\n' "$name"
        return 1
    fi
}

_doctor_check_hook_symlink() {
    local hook_name="$1"
    local hook_path="${HOME}/.githooks/${hook_name}"

    if command_exists "check_hook_symlink"; then
        # Use shared hook-check module
        local status
        status=$(check_hook_symlink "$hook_name")
        case "$status" in
            valid)
                printf '  ✅ %s → %s\n' "$hook_name" "$(readlink "$hook_path")"
                return 0
                ;;
            missing)
                printf '  ❌ %s (missing)\n' "$hook_name"
                return 1
                ;;
            wrong_target)
                printf '  ⚠️  %s (wrong target: %s)\n' "$hook_name" "$(readlink "$hook_path")"
                return 1
                ;;
            file_not_symlink)
                printf '  ⚠️  %s (exists but not symlinked)\n' "$hook_name"
                return 1
                ;;
        esac
    else
        # Fallback to basic check
        _doctor_check_symlink "$hook_path" "$hook_name"
    fi
}

_doctor_check_cmd() {
    local cmd="$1" note="${2:-}" version=""
    if command_exists "$cmd"; then
        case "$cmd" in
            git | gh | fzf | rg) version=$($cmd --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1) ;;
            eza) version=$($cmd --version 2>/dev/null | head -1 | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1) ;;
            trash) version="installed" ;;
        esac
        [[ -n "$version" ]] && printf '  ✅ %s (%s)\n' "$cmd" "$version" || printf '  ✅ %s\n' "$cmd"
        return 0
    else
        [[ -n "$note" ]] && printf '  ❌ %s (%s)\n' "$cmd" "$note" || printf '  ❌ %s\n' "$cmd"
        return 1
    fi
}

_doctor_check_feature_flag() {
    local description="$2"
    local value="${!1:-true}"
    [[ "$value" == "true" ]] && printf '  ✅ %s\n' "$description" || printf '  ⚪ %s (disabled)\n' "$description"
}

shell_config_doctor() {
    printf '\n🩺 %bShell-Config Doctor%b\n' "${COLOR_BOLD}" "${COLOR_RESET}"
    printf '%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n\n' "${COLOR_DIM}" "${COLOR_RESET}"
    local errors=0 warnings=0

    # Symlinks (all config files managed by install.sh)
    printf '%b🔗 Symlinks:%b\n' "${COLOR_BOLD}" "${COLOR_RESET}"
    _doctor_check_symlink "$HOME/.shell-config" "$HOME/.shell-config" || ((errors++))
    _doctor_check_symlink "$HOME/.zshrc" "$HOME/.zshrc" || ((warnings++))
    _doctor_check_symlink "$HOME/.zshenv" "$HOME/.zshenv" || ((warnings++))
    _doctor_check_symlink "$HOME/.zprofile" "$HOME/.zprofile" || ((warnings++))
    _doctor_check_symlink "$HOME/.bashrc" "$HOME/.bashrc" || ((warnings++))
    _doctor_check_symlink "$HOME/.gitconfig" "$HOME/.gitconfig" || ((warnings++))
    _doctor_check_symlink "$HOME/.ssh/config" "$HOME/.ssh/config" || ((warnings++))
    _doctor_check_symlink "$HOME/.ripgreprc" "$HOME/.ripgreprc" || ((warnings++))
    printf '\n'

    # Dependencies
    printf '%b📦 Dependencies:%b\n' "${COLOR_BOLD}" "${COLOR_RESET}"
    _doctor_check_cmd git "required" || ((errors++))
    _doctor_check_cmd eza "optional"
    _doctor_check_cmd fzf "optional"
    _doctor_check_cmd rg "optional"
    _doctor_check_cmd gitleaks "optional"
    _doctor_check_cmd trash "optional"
    _doctor_check_cmd gh "optional"
    _doctor_check_cmd bun "optional"
    _doctor_check_cmd shellcheck "optional"
    printf '\n'

    # Feature flags
    printf '%b🎛️  Feature Flags:%b\n' "${COLOR_BOLD}" "${COLOR_RESET}"
    _doctor_check_feature_flag "SHELL_CONFIG_WELCOME" "Welcome message"
    _doctor_check_feature_flag "SHELL_CONFIG_COMMAND_SAFETY" "Command safety"
    _doctor_check_feature_flag "SHELL_CONFIG_GIT_WRAPPER" "Git wrapper"
    _doctor_check_feature_flag "SHELL_CONFIG_GHLS" "GHLS statusline"
    _doctor_check_feature_flag "SHELL_CONFIG_EZA" "Eza aliases"
    _doctor_check_feature_flag "SHELL_CONFIG_RIPGREP" "Ripgrep aliases"
    _doctor_check_feature_flag "SHELL_CONFIG_SECURITY" "Security hardening"
    _doctor_check_feature_flag "SHELL_CONFIG_LOG_ROTATION" "Log rotation"
    printf '\n'

    # Gitleaks (secret detection)
    printf '%b🔐 Secret Detection:%b\n' "${COLOR_BOLD}" "${COLOR_RESET}"
    if command_exists "gitleaks"; then
        local version config_file
        version=$(gitleaks version 2>/dev/null | head -1)
        config_file="$SHELL_CONFIG_DIR/lib/validation/validators/security/config/gitleaks.toml"
        printf '  ✅ Gitleaks: %s\n' "$version"
        if [[ -f "$config_file" ]]; then
            printf '  ✅ Config: lib/validation/validators/security/config/gitleaks.toml\n'
        else
            printf '  ⚠️  Config missing: %s\n' "$config_file"
            ((warnings++))
        fi
    else
        printf '  ⚠️  Gitleaks not installed (brew install gitleaks)\n'
        ((warnings++))
    fi
    echo ""

    # Log rotation
    printf '%b📊 Log Files:%b\n' "${COLOR_BOLD}" "${COLOR_RESET}"
    if [[ -f "$SHELL_CONFIG_DIR/lib/core/logging.sh" ]]; then
        source "$SHELL_CONFIG_DIR/lib/core/logging.sh" 2>/dev/null
        command_exists "_log_rotation_status" && _log_rotation_status | sed 's/^/  /' || echo "  Log rotation: not configured"
    else
        echo "  Log rotation: not configured"
    fi
    echo ""

    # Performance
    printf '%b⚡ Performance:%b\n' "${COLOR_BOLD}" "${COLOR_RESET}"
    if [[ -n "$SHELL_CONFIG_DIR" ]] && [[ -f "$SHELL_CONFIG_DIR/init.sh" ]]; then
        local script_count
        read -r script_count < <(find "$SHELL_CONFIG_DIR/lib" -name "*.sh" -type f 2>/dev/null | wc -l)
        script_count=${script_count:-0}
        echo "  Scripts: ~$script_count  Dir: $SHELL_CONFIG_DIR"
    fi
    echo ""

    # Summary
    printf '%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n' "${COLOR_DIM}" "${COLOR_RESET}"
    [[ $errors -eq 0 ]] && [[ $warnings -eq 0 ]] && printf '%b💪 All checks passed!%b\n' "${COLOR_GREEN}" "${COLOR_RESET}" \
        || [[ $errors -eq 0 ]] && printf '%b⚠️  %s warning(s)%b\n' "${COLOR_YELLOW}" "$warnings" "${COLOR_RESET}" \
        || printf '%b❌ %s error(s), %s warning(s)%b\n' "${COLOR_RED}" "$errors" "$warnings" "${COLOR_RESET}"
    echo ""
    return $errors
}

alias shell-config-doctor='shell_config_doctor'
