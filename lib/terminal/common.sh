#!/usr/bin/env bash
# =============================================================================
# 🔧 TERMINAL COMMON FUNCTIONS (Consolidated)
# =============================================================================
# Shared functions for terminal setup and installation scripts
# Usage: source "$SHELL_CONFIG_DIR/lib/terminal/common.sh"
# This library provides:
#   - Platform detection (sources from lib/core/platform.sh)
#   - Logging functions (sources from lib/core/colors.sh)
#   - Terminal-specific utilities
#   - Installation tracking
# =============================================================================

# Exit if script is sourced more than once
[[ -n "${TERMINAL_COMMON_LOADED:-}" ]] && return 0
TERMINAL_COMMON_LOADED=1

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source canonical implementations from lib/core/
# shellcheck source=../core/colors.sh
source "$SCRIPT_DIR/../core/colors.sh"
# shellcheck source=../core/platform.sh
source "$SCRIPT_DIR/../core/platform.sh"
# shellcheck source=../core/command-cache.sh
source "$SCRIPT_DIR/../core/command-cache.sh"

# =============================================================================
# VERSION LOGGING
# =============================================================================
log_version() {
    local tool_name="$1"
    local version_command="$2"
    local version

    version=$(eval "$version_command" 2>/dev/null || echo "unknown")

    if [[ "$version" != "unknown" && -n "$version" ]]; then
        log_success "${tool_name} ${version}"
    else
        log_warning "${tool_name} (version unknown)"
    fi
}

# =============================================================================
# VERIFICATION FUNCTIONS
# =============================================================================
verify_directory() {
    local dir_path="$1"
    local display_name="${2:-$dir_path}"

    if [[ -d "$dir_path" ]]; then
        log_success "$display_name directory exists"
        return 0
    else
        log_error "$display_name directory not found"
        return 1
    fi
}

verify_app() {
    local app_name="$1"
    local display_name="${2:-$app_name}"

    # Platform-specific verification
    if [[ "$(detect_os)" == "macos" ]]; then
        # macOS: Check for .app bundle in /Applications
        if [[ -d "/Applications/${app_name}.app" ]]; then
            log_success "$display_name installed in /Applications"
            return 0
        else
            log_error "$display_name not found in /Applications"
            return 1
        fi
    else
        # Linux/Other: Check if command is available in PATH
        if command_exists "$app_name"; then
            log_success "$display_name is available in PATH"
            return 0
        else
            log_error "$display_name not found in PATH"
            return 1
        fi
    fi
}

# =============================================================================
# BACKUP FUNCTIONS
# =============================================================================
create_backup() {
    local file="$1"
    local backup_dir="${2:-$HOME/.terminal-backups}"

    if [[ -f "$file" ]]; then
        mkdir -p "$backup_dir"
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local backup
        backup="${backup_dir}/$(basename "$file").${timestamp}"
        cp "$file" "$backup"
        log_info "Backed up $file to $backup"
        echo "$backup"
    fi
}

# =============================================================================
# DOWNLOAD UTILITIES
# =============================================================================
download_file() {
    local url="$1"
    local dest="$2"

    if command_exists "curl"; then
        curl -fsSL -o "$dest" "$url"
    elif command_exists "wget"; then
        wget -O "$dest" "$url"
    else
        log_error "Neither curl nor wget found"
        return 1
    fi
}

verify_checksum() {
    local file="$1"
    local expected_checksum="$2"
    local actual_checksum

    # Try sha256sum first (standard on Linux)
    if command_exists "sha256sum"; then
        actual_checksum=$(sha256sum "$file" | cut -d' ' -f1)
    # Fall back to shasum (available on macOS)
    elif command_exists "shasum"; then
        actual_checksum=$(shasum -a 256 "$file" | cut -d' ' -f1)
    else
        log_warning "sha256sum or shasum not found, skipping checksum verification"
        return 0
    fi

    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        log_success "Checksum verified"
        return 0
    else
        log_error "Checksum mismatch"
        log_error "Expected: $expected_checksum"
        log_error "Actual:   $actual_checksum"
        return 1
    fi
}

# =============================================================================
# ZSH PLUGIN MANAGEMENT
# =============================================================================

# Check if a plugin is in the plugins array
plugin_exists_in_zshrc() {
    local plugin_name="$1"
    local zshrc="${2:-$HOME/.zshrc}"

    # Use grep -qE for early exit optimization (Bash 5+)
    grep -qE "^plugins=.*\b${plugin_name}\b" "$zshrc" 2>/dev/null
}

# Add a plugin to the plugins array in .zshrc
add_zsh_plugin() {
    local plugin_name="$1"
    local zshrc="${2:-$HOME/.zshrc}"

    # Check if plugins line exists
    if grep -q '^plugins=' "$zshrc" 2>/dev/null; then
        # Check if plugin is already in the list
        if plugin_exists_in_zshrc "$plugin_name" "$zshrc"; then
            log_info "Plugin $plugin_name already in plugins array"
            return 0
        fi

        # Add plugin to existing array
        log_info "Adding $plugin_name to plugins array in .zshrc"
        # Platform-aware sed backup (macOS requires empty string for -i)
        if [[ "$(detect_os)" == "macos" ]]; then
            sed -i ''.bak "s/^plugins=\(.*\)/plugins=\1 $plugin_name/" "$zshrc"
        else
            sed -i.bak "s/^plugins=\(.*\)/plugins=\1 $plugin_name/" "$zshrc"
        fi
        rm -f "${zshrc}.bak"
    else
        # Create plugins line
        log_info "Creating plugins array with $plugin_name in .zshrc"
        echo "plugins=($plugin_name)" >>"$zshrc"
    fi
}

# =============================================================================
# INSTALLATION TRACKING
# =============================================================================

# Track installation of a tool
track_installation() {
    local tool_name="$1"
    local version="${2:-unknown}"
    local install_file="$HOME/.shell-config-installed"

    mkdir -p "$(dirname "$install_file")"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $tool_name | $version" >>"$install_file"
}

# Check if tool was previously installed
is_installed() {
    local tool_name="$1"
    local install_file="$HOME/.shell-config-installed"

    [[ -f "$install_file" ]] && grep -q "| $tool_name |" "$install_file"
}

# List all installed tools
list_installed_tools() {
    local install_file="$HOME/.shell-config-installed"

    if [[ -f "$install_file" ]]; then
        echo -e "\n📦 Installed Tools:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$install_file"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        log_info "No installation tracking file found"
    fi
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f log_version verify_directory verify_app create_backup 2>/dev/null || true
    export -f download_file verify_checksum 2>/dev/null || true
    export -f plugin_exists_in_zshrc add_zsh_plugin 2>/dev/null || true
    export -f track_installation is_installed list_installed_tools 2>/dev/null || true
fi
