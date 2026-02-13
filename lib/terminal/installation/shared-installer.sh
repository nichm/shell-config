#!/usr/bin/env bash
# =============================================================================
# 🔧 SHARED TERMINAL INSTALLER - Common functions for terminal installers
# =============================================================================
# Reduces ~1,600 lines of duplicated patterns across kitty, ghostty, iterm2,
# and warp installers into a single reusable module.
# Usage:
#   source "${SCRIPT_DIR}/shared-installer.sh"
# Provides:
#   - Homebrew management (_ti_ensure_homebrew)
#   - Config directory management (_ti_ensure_config_dir)
#   - Already-installed checks (_ti_check_installed_cmd, _ti_check_installed_cask)
#   - Install helpers (_ti_install_brew, _ti_install_cask, _ti_install_linux_pkg)
#   - Verification & tracking (_ti_verify_and_track, _ti_verify_app)
#   - Config management (_ti_backup_and_write_config)
#   - OS routing (_ti_main_entry, _ti_linux_pkg_router)
#   - Build from source (_ti_build_cmake)
#   - Uninstall helpers (_ti_uninstall_brew, _ti_uninstall_cask, etc.)
# =============================================================================

[[ -n "${_TERMINAL_SHARED_INSTALLER_LOADED:-}" ]] && return 0
readonly _TERMINAL_SHARED_INSTALLER_LOADED=1

# Source dependencies (correct path: installation/ -> terminal/ -> core/)
_TI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "${_TI_SCRIPT_DIR}/../common.sh"
# shellcheck source=../../core/traps.sh
source "${_TI_SCRIPT_DIR}/../../core/traps.sh"

# =============================================================================
# HOMEBREW
# =============================================================================

# Check if Homebrew is available
_ti_ensure_homebrew() {
    if command_exists "brew"; then
        return 0
    fi
    log_error "Homebrew is required but not installed"
    log_info "Install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    return 1
}

# =============================================================================
# CONFIG DIRECTORY
# =============================================================================

# Ensure a configuration directory exists
_ti_ensure_config_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_success "Created config directory: $dir"
    fi
}

# =============================================================================
# ALREADY-INSTALLED CHECKS
# =============================================================================

# Check if a command-line tool is already installed
# Returns 0 if installed (caller should skip), 1 if not installed
_ti_check_installed_cmd() {
    local binary="$1"
    local display_name="$2"
    local version_cmd="${3:-$binary --version}"

    if command_exists "$binary"; then
        log_warning "$display_name already installed"
        log_version "$display_name" "$version_cmd"
        track_installation "$binary" "skipped"
        return 0
    fi
    return 1
}

# Check if a brew package/cask is already installed
_ti_check_installed_brew() {
    local package="$1"
    local display_name="$2"
    local cask="${3:-false}"

    local list_cmd="brew list"
    [[ "$cask" == "true" ]] && list_cmd="brew list --cask"

    if $list_cmd "$package" &>/dev/null 2>&1; then
        log_warning "$display_name already installed"
        track_installation "$package" "skipped"
        return 0
    fi
    return 1
}

# Check if a macOS .app is already installed
_ti_check_installed_app() {
    local app_name="$1"
    local display_name="$2"

    if [[ -d "/Applications/${app_name}.app" ]]; then
        log_warning "$display_name already installed"
        track_installation "${app_name,,}" "skipped"
        return 0
    fi
    return 1
}

# =============================================================================
# INSTALLATION METHODS
# =============================================================================

# Install via brew (regular formula)
_ti_install_brew() {
    local package="$1"
    local display_name="$2"

    log_info "Downloading and installing $display_name..."
    if ! brew install "$package"; then
        log_error "Failed to install $display_name"
        return 1
    fi
    log_success "$display_name installed successfully"
}

# Install via brew cask
_ti_install_cask() {
    local cask_name="$1"
    local display_name="$2"

    log_info "Downloading and installing $display_name..."
    if ! brew install --cask "$cask_name"; then
        log_error "Failed to install $display_name"
        return 1
    fi
    log_success "$display_name installed"
}

# Install via Linux package manager (apt/dnf/pacman)
_ti_install_linux_pkg() {
    local package="$1"
    local display_name="$2"
    local pkg_manager
    pkg_manager="$(detect_package_manager)"

    case "$pkg_manager" in
        apt)
            log_info "Installing $display_name via APT..."
            sudo apt-get install -y "$package" || { log_error "Failed to install $display_name via APT"; return 1; }
            ;;
        dnf)
            log_info "Installing $display_name via DNF..."
            sudo dnf install -y "$package" || { log_error "Failed to install $display_name via DNF"; return 1; }
            ;;
        pacman)
            log_info "Installing $display_name via Pacman..."
            sudo pacman -S --noconfirm "$package" || { log_error "Failed to install $display_name via Pacman"; return 1; }
            ;;
        *)
            log_error "Unsupported package manager: $pkg_manager"
            return 1
            ;;
    esac
    log_success "$display_name installed successfully"
}

# =============================================================================
# BUILD FROM SOURCE (cmake)
# =============================================================================

# Clone and build a project from source using cmake
_ti_build_cmake() {
    local repo_url="$1"
    local display_name="$2"

    local build_dir
    build_dir=$(mktemp_dir_with_cleanup)

    log_info "Cloning $display_name repository..."
    if ! git clone "$repo_url" "$build_dir"; then
        log_error "Failed to clone $display_name repository"
        return 1
    fi

    cd "$build_dir" || { log_error "Failed to enter build directory"; return 1; }

    log_info "Building $display_name (this may take a while)..."
    if ! cmake -B build; then
        log_error "CMake configuration failed"
        cd - >/dev/null || true
        return 1
    fi

    if ! cmake --build build; then
        log_error "Build failed"
        cd - >/dev/null || true
        return 1
    fi

    log_info "Installing $display_name..."
    if ! sudo cmake --install build; then
        log_error "Installation failed"
        cd - >/dev/null || true
        return 1
    fi

    cd - >/dev/null || true
    log_success "$display_name built and installed from source"
}

# =============================================================================
# VERIFICATION & TRACKING
# =============================================================================

# Verify a command exists and track installation
_ti_verify_and_track() {
    local binary="$1"
    local display_name="$2"
    local version_cmd="${3:-$binary --version}"

    if ! command_exists "$binary"; then
        log_error "$display_name installation verification failed"
        return 1
    fi

    log_success "$display_name installed successfully"
    log_version "$display_name" "$version_cmd"
    track_installation "$binary" "installed"
}

# Verify a macOS .app exists
_ti_verify_app() {
    local app_name="$1"
    local display_name="$2"

    if [[ -d "/Applications/${app_name}.app" ]]; then
        log_success "$display_name installed in /Applications"
        return 0
    fi
    log_error "$display_name not found in /Applications"
    return 1
}

# =============================================================================
# CONFIG MANAGEMENT
# =============================================================================

# Backup existing config file and write new config via callback
# Usage: _ti_backup_and_write_config "$config_file" _my_write_func
_ti_backup_and_write_config() {
    local config_file="$1"
    local write_func="$2"

    if [[ -f "$config_file" ]]; then
        local backup
        backup=$(create_backup "$config_file")
        log_info "Existing config backed up to: $backup"
    fi

    "$write_func" "$config_file"
    log_success "Configuration created at $config_file"
}

# =============================================================================
# MAIN ENTRY ROUTER
# =============================================================================

# Standard main entry point for terminal installers
# Usage: _ti_main_entry "Kitty" install_kitty_macos [install_kitty_linux]
_ti_main_entry() {
    local display_name="$1"
    local macos_func="$2"
    local linux_func="${3:-}"

    log_step "$display_name Terminal Installation"

    local os_type
    os_type="$(detect_os)"

    case "$os_type" in
        macos)
            "$macos_func"
            ;;
        linux)
            if [[ -n "$linux_func" ]]; then
                "$linux_func"
            else
                log_error "$display_name is not available for Linux"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported operating system: $(uname)"
            log_info "$display_name supports macOS and Linux"
            return 1
            ;;
    esac
}

# Route Linux installation to the correct package manager handler
# Usage: _ti_linux_pkg_router "Kitty" apt_func dnf_func pacman_func
_ti_linux_pkg_router() {
    local display_name="$1"
    local apt_func="${2:-}"
    local dnf_func="${3:-}"
    local pacman_func="${4:-}"

    local pkg_manager
    pkg_manager="$(detect_package_manager)"

    case "$pkg_manager" in
        apt)
            [[ -n "$apt_func" ]] && { "$apt_func"; return $?; }
            log_error "$display_name installation not supported for APT"
            return 1
            ;;
        dnf)
            [[ -n "$dnf_func" ]] && { "$dnf_func"; return $?; }
            log_error "$display_name installation not supported for DNF"
            return 1
            ;;
        pacman)
            [[ -n "$pacman_func" ]] && { "$pacman_func"; return $?; }
            log_error "$display_name installation not supported for Pacman"
            return 1
            ;;
        *)
            log_error "Unsupported Linux distribution for $display_name"
            log_info "Please install $display_name manually"
            return 1
            ;;
    esac
}

# =============================================================================
# UNINSTALL HELPERS
# =============================================================================

# Uninstall via Homebrew (regular formula)
_ti_uninstall_brew() {
    local package="$1"
    if command_exists "brew"; then
        brew uninstall "$package" 2>/dev/null || true
        log_success "Removed $package from Homebrew"
    fi
}

# Uninstall via Homebrew cask
_ti_uninstall_cask() {
    local cask_name="$1"
    if command_exists "brew"; then
        brew uninstall --cask "$cask_name" 2>/dev/null || true
        log_success "Removed $cask_name from Homebrew"
    fi
}

# Uninstall via Linux package manager
_ti_uninstall_linux_pkg() {
    local package="$1"
    if command_exists "apt-get"; then
        sudo apt-get remove -y "$package" 2>/dev/null || true
    elif command_exists "dnf"; then
        sudo dnf remove -y "$package" 2>/dev/null || true
    elif command_exists "pacman"; then
        sudo pacman -R --noconfirm "$package" 2>/dev/null || true
    fi
    log_success "Removed $package package"
}

# Remove a macOS .app
_ti_uninstall_app() {
    local app_name="$1"
    if [[ -d "/Applications/${app_name}.app" ]]; then
        rm -rf "/Applications/${app_name}.app"
        log_success "Removed ${app_name}.app"
    fi
}

# Remove desktop entry (Linux)
_ti_remove_desktop_entry() {
    local entry_file="$1"
    local desktop_file="$HOME/.local/share/applications/${entry_file}"
    if [[ -f "$desktop_file" ]]; then
        rm -f "$desktop_file"
        log_success "Removed desktop entry: $entry_file"
    fi
}

# Log config preservation message
_ti_log_config_preserved() {
    local config_dir="$1"
    local display_name="$2"
    if [[ -d "$config_dir" ]]; then
        log_info "$display_name configuration was not removed: $config_dir"
        log_info "To remove it, run: rm -rf \"$config_dir\""
    fi
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f _ti_ensure_homebrew _ti_ensure_config_dir 2>/dev/null || true
    export -f _ti_check_installed_cmd _ti_check_installed_brew _ti_check_installed_app 2>/dev/null || true
    export -f _ti_install_brew _ti_install_cask _ti_install_linux_pkg 2>/dev/null || true
    export -f _ti_build_cmake 2>/dev/null || true
    export -f _ti_verify_and_track _ti_verify_app 2>/dev/null || true
    export -f _ti_backup_and_write_config 2>/dev/null || true
    export -f _ti_main_entry _ti_linux_pkg_router 2>/dev/null || true
    export -f _ti_uninstall_brew _ti_uninstall_cask _ti_uninstall_linux_pkg 2>/dev/null || true
    export -f _ti_uninstall_app _ti_remove_desktop_entry _ti_log_config_preserved 2>/dev/null || true
fi
