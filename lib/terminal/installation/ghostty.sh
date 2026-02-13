#!/usr/bin/env bash
# =============================================================================
# 🚀 GHOSTTY TERMINAL INSTALLER
# =============================================================================
# Installs and configures Ghostty terminal emulator
# Supports: macOS (Homebrew), Linux (various package managers)
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/ghostty.sh" && install_ghostty
# =============================================================================
set -euo pipefail

# Load shared installer infrastructure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared-installer.sh
source "${SCRIPT_DIR}/shared-installer.sh"

# =============================================================================
# INSTALLED CHECK
# =============================================================================

is_ghostty_installed() {
    command_exists "ghostty"
}

# =============================================================================
# macOS INSTALLATION
# =============================================================================

install_ghostty_macos() {
    _ti_ensure_homebrew || return 1

    if _ti_check_installed_brew "ghostty" "Ghostty" "true"; then
        log_version "Ghostty" "ghostty --version 2>&1 | head -n 1 || echo 'installed'"
        return 0
    fi

    _ti_install_cask "ghostty" "Ghostty" || return 1

    if ! command_exists "ghostty"; then
        log_error "Ghostty installation verification failed"
        return 1
    fi

    log_version "Ghostty" "ghostty --version 2>&1 | head -n 1 || echo 'installed'"
    track_installation "ghostty" "success"
    configure_ghostty
}

# =============================================================================
# LINUX INSTALLATION
# =============================================================================

install_ghostty_linux() {
    log_info "Installing Ghostty on Linux..."

    if _ti_check_installed_cmd "ghostty" "Ghostty" "ghostty --version 2>&1 | head -n 1 || echo 'installed'"; then
        return 0
    fi

    _ti_linux_pkg_router "Ghostty" \
        _ghostty_install_build \
        _ghostty_install_build \
        _ghostty_install_pacman || return 1

    _ti_verify_and_track "ghostty" "Ghostty" "ghostty --version 2>&1 | head -n 1 || echo 'installed'" || return 1
    configure_ghostty
}

# APT/DNF: Build from source (shared logic, different deps)
_ghostty_install_build() {
    local pkg_manager
    pkg_manager="$(detect_package_manager)"

    local arch
    arch="$(detect_architecture)"
    if [[ "$arch" == "unknown" ]]; then
        log_error "Unsupported architecture: $(uname -m)"
        log_info "Ghostty for Linux supports x86_64 and arm64"
        return 1
    fi

    # Install build dependencies based on package manager
    log_info "Installing build dependencies..."
    case "$pkg_manager" in
        apt)
            sudo apt-get update -q
            sudo apt-get install -y \
                curl build-essential cmake libgtk-4-dev libadwaita-1-dev \
                libgdk-pixbuf-2.0-dev libpango1.0-dev libcairo2-dev \
                libglib2.0-dev libgraphene-1.0-dev libharfbuzz-dev \
                libxkbcommon-dev libselinux1-dev libsystemd-dev pkg-config
            ;;
        dnf)
            sudo dnf install -y \
                curl cmake gcc-c++ gtk4-devel libadwaita-devel \
                gdk-pixbuf2-devel pango-devel cairo-devel \
                glib2-devel graphene-devel harfbuzz-devel \
                libxkbcommon-devel systemd-devel pkg-config
            ;;
    esac

    _ti_build_cmake "https://github.com/mitchellh/ghostty.git" "Ghostty"
}

# Pacman: Install via AUR
_ghostty_install_pacman() {
    log_info "Installing Ghostty via AUR..."
    if command_exists "yay"; then
        yay -S --noconfirm ghostty
    elif command_exists "paru"; then
        paru -S --noconfirm ghostty
    else
        log_warning "No AUR helper found. Manual installation required."
        log_info "Install via yay: yay -S ghostty"
        return 1
    fi
}

# =============================================================================
# CONFIGURATION
# =============================================================================

_ghostty_write_config() {
    local target_file="$1"
    cat >"$target_file" <<'EOF'
# Ghostty Terminal Configuration
# Optimized for performance and shell integration

# Font configuration
font-family = JetBrains Mono
font-size = 14
font-feature = ss01
font-feature = ss02

# Theme
theme = dark

# Performance
resize-increment = 50
scrollback-limit = 10000

# Key bindings
keybind = cmd+enter=toggle_fullscreen
keybind = cmd+c=copy_to_clipboard
keybind = cmd+v=paste_from_clipboard

# Shell integration
shell-integration = detect

# Mouse settings
mouse-hide-while-typing = true
copy-on-select = false

# Window settings
window-padding-x = 8
window-padding-y = 8
window-decoration = true
window-theme = auto
window-width = 140
window-height = 40

# Tab settings
tab-width = 200

# Cursor style
cursor-style = block
cursor-style-unfocused = hollow

# Bell
audible-bell = false
visual-bell = true

# Behavior
quit-after-last-window-closed = true
EOF
}

configure_ghostty() {
    log_info "Configuring Ghostty..."
    local ghostty_config_dir="$HOME/.config/ghostty"
    _ti_ensure_config_dir "$ghostty_config_dir"
    _ti_backup_and_write_config "$ghostty_config_dir/config" _ghostty_write_config
}

# =============================================================================
# MAIN
# =============================================================================

install_ghostty() {
    _ti_main_entry "Ghostty" install_ghostty_macos install_ghostty_linux
}

# Export function (bash only)
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f install_ghostty is_ghostty_installed configure_ghostty 2>/dev/null || true
fi
