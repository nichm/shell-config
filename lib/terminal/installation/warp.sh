#!/usr/bin/env bash
# =============================================================================
# 🚀 WARP TERMINAL INSTALLER
# =============================================================================
# Installs and configures Warp terminal emulator
# Supports: macOS (Homebrew), Linux (AppImage/Deb)
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/warp.sh" && install_warp
# =============================================================================
set -euo pipefail

# Load shared installer infrastructure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared-installer.sh
source "${SCRIPT_DIR}/shared-installer.sh"

# =============================================================================
# INSTALLED CHECK
# =============================================================================

is_warp_installed() {
    command_exists "warp" || [[ -d "/Applications/Warp.app" ]]
}

# =============================================================================
# macOS INSTALLATION
# =============================================================================

install_warp_macos() {
    _ti_ensure_homebrew || return 1

    if _ti_check_installed_brew "warp" "Warp" "true"; then
        [[ -d "/Applications/Warp.app" ]] && log_success "Warp.app found in /Applications"
        configure_warp
        return 0
    fi

    _ti_install_cask "warp" "Warp" || return 1

    if ! verify_app "Warp" "Warp terminal"; then
        log_error "Warp installation verification failed"
        return 1
    fi

    track_installation "warp" "success"
    configure_warp
}

# =============================================================================
# LINUX INSTALLATION
# =============================================================================

install_warp_linux() {
    log_info "Installing Warp on Linux..."

    if _ti_check_installed_cmd "warp" "Warp"; then
        configure_warp
        return 0
    fi

    local distro
    distro="$(detect_linux_distro)"

    case "$distro" in
        ubuntu | debian) _warp_install_linux_deb ;;
        *) _warp_install_linux_appimage ;;
    esac

    # Verify installation
    if command_exists "warp" || [[ -f "$HOME/.local/bin/warp" ]]; then
        log_success "Warp installed"
        track_installation "warp" "success"
        configure_warp
    else
        log_error "Warp installation verification failed"
        return 1
    fi
}

_warp_install_linux_deb() {
    log_warning "Warp .deb package must be downloaded manually"
    log_info "Please download from: https://app.warp.dev/download"
    log_info "Then install with: sudo dpkg -i warp_*.deb"
    return 1
}

_warp_install_linux_appimage() {
    local arch
    arch="$(detect_architecture)"

    if [[ "$arch" != "x86_64" ]]; then
        log_error "Warp AppImage is only available for x86_64"
        log_info "Current architecture: $(uname -m)"
        return 1
    fi

    log_warning "Warp AppImage not currently available"
    log_info "Please download Warp from: https://app.warp.dev/download"
    return 1
}

# =============================================================================
# CONFIGURATION
# =============================================================================

_warp_write_config() {
    local target_file="$1"
    cat >"$target_file" <<'EOF'
# Warp Terminal Configuration
# Note: Most Warp settings are configured through the UI

# Theme
theme:
  name: dark

# Font settings
font:
  family: JetBrains Mono
  size: 14

# Terminal behavior
terminal:
  shell: ""
  env:
    EDITOR: vim
    PAGER: less

# Features
features:
  ai_assistant: true
  blocks: true
  fuzzy_find: true

# Keybindings (custom)
keybindings: []
EOF
}

configure_warp() {
    log_info "Configuring Warp..."
    local warp_config_dir="$HOME/.warp"
    _ti_ensure_config_dir "$warp_config_dir"
    _ti_backup_and_write_config "$warp_config_dir/config.yaml" _warp_write_config
    log_info "Additional configuration available in Warp Settings (Cmd+,)"
}

# =============================================================================
# DESKTOP ENTRY (Linux)
# =============================================================================

_warp_create_desktop_entry() {
    [[ "$(detect_os)" != "linux" ]] && return 0

    local desktop_dir="$HOME/.local/share/applications"
    mkdir -p "$desktop_dir"

    cat >"${desktop_dir}/warp-terminal.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Warp Terminal
Comment=A modern, Rust-based terminal with AI integration
Exec=warp %F
Icon=warp
Terminal=false
Categories=System;TerminalEmulator;
StartupNotify=true
StartupWMClass=warp
EOF
    log_success "Desktop entry created at ${desktop_dir}/warp-terminal.desktop"
}

# =============================================================================
# MAIN
# =============================================================================

install_warp() {
    _ti_main_entry "Warp" install_warp_macos install_warp_linux
}

# =============================================================================
# UNINSTALL
# =============================================================================

uninstall_warp() {
    log_warning "Uninstalling Warp..."
    local os_type
    os_type="$(detect_os)"

    case "$os_type" in
        macos)
            _ti_uninstall_app "Warp"
            _ti_uninstall_cask "warp"
            ;;
        linux)
            _ti_remove_desktop_entry "warp-terminal.desktop"
            [[ -f "$HOME/Applications/Warp.AppImage" ]] && rm -f "$HOME/Applications/Warp.AppImage" && log_success "Removed AppImage"
            ;;
    esac

    if [[ "${WARP_PURGE_CONFIG:-}" == "true" ]]; then
        rm -rf "$HOME/.warp"
        log_success "Removed ~/.warp"
    else
        log_info "Skipping Warp config removal (set WARP_PURGE_CONFIG=true to remove)"
    fi

    log_success "Warp uninstalled"
}

# Export functions (bash only)
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f install_warp is_warp_installed configure_warp uninstall_warp 2>/dev/null || true
fi
