#!/usr/bin/env bash
# =============================================================================
# Platform Detection Library - OS and package manager detection
# =============================================================================
# EXCEPTION: This file uses raw `command -v` instead of command_exists because
# it is a bootstrap file that loads before command-cache.sh in init.sh.
#
# This is the canonical implementation of platform detection functions.
# All other scripts should source this file instead of duplicating code.
# Usage: source "$SHELL_CONFIG_DIR/lib/core/platform.sh"
# Provides:
#   - detect_os(): Detect operating system (macos, linux, wsl, bsd, windows)
#   - detect_architecture(): Detect CPU architecture (x86_64, arm64, etc.)
#   - detect_linux_distro(): Detect Linux distribution
#   - detect_package_manager(): Detect system package manager
#   - get_homebrew_prefix(): Get Homebrew installation path
#   - is_macos(), is_linux(), is_wsl(), is_bsd(): Convenience test functions
#   - platform_log_*(): Platform-aware logging functions
#   - pkg_install(): Platform-aware package installation
# =============================================================================

# Guard against multiple sourcing
[[ -n "${_SHELL_CONFIG_CORE_PLATFORM_LOADED:-}" ]] && return 0
_SHELL_CONFIG_CORE_PLATFORM_LOADED=1

# Try to load colors if available for logging functions
[[ -f "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/core/colors.sh" ]] \
    && source "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/core/colors.sh" 2>/dev/null

# =============================================================================
# OS Detection
# =============================================================================

detect_os() {
    local os="unknown"

    case "$(uname -s)" in
        Darwin)
            os="macos"
            ;;
        Linux*)
            # Check for WSL
            if [[ -f "/proc/version" ]] && grep -qi "microsoft\|wsl" "/proc/version" 2>/dev/null; then
                os="wsl"
            else
                os="linux"
            fi
            ;;
        FreeBSD | OpenBSD | NetBSD)
            os="bsd"
            ;;
        MINGW* | MSYS* | CYGWIN*)
            os="windows"
            ;;
        *)
            os="unknown"
            ;;
    esac

    echo "$os"
}

# Export OS detection globally
export SC_OS="${SC_OS:-$(detect_os)}"

# =============================================================================
# Architecture Detection
# =============================================================================

detect_architecture() {
    local arch="unknown"

    case "$(uname -m)" in
        x86_64 | amd64)
            arch="x86_64"
            ;;
        aarch64 | arm64)
            arch="arm64"
            ;;
        armv7l)
            arch="arm"
            ;;
        i386 | i686)
            arch="x86"
            ;;
        *)
            arch="unknown"
            ;;
    esac

    echo "$arch"
}

export SC_ARCH="${SC_ARCH:-$(detect_architecture)}"

# =============================================================================
# Linux Distribution Detection
# =============================================================================

detect_linux_distro() {
    [[ "$SC_OS" != "linux" && "$SC_OS" != "wsl" ]] && {
        echo "not-linux"
        return 0
    }

    if [[ -f "/etc/os-release" ]]; then
        source "/etc/os-release"
        echo "${ID:-unknown}"
        return 0
    fi

    if [[ -f "/etc/redhat-release" ]]; then
        echo "rhel"
        return 0
    fi

    if [[ -f "/etc/debian_version" ]]; then
        echo "debian"
        return 0
    fi

    echo "unknown"
}

export SC_LINUX_DISTRO="${SC_LINUX_DISTRO:-$(detect_linux_distro)}"

# =============================================================================
# Package Manager Detection
# =============================================================================

detect_package_manager() {
    local pkg_manager="none"

    case "$SC_OS" in
        macos)
            # NOTE: Using raw 'command -v' here (not command_exists) because this file
            # is sourced BEFORE command-cache.sh is available. This is intentional.
            if command -v brew >/dev/null 2>&1; then
                pkg_manager="brew"
            fi
            ;;
        linux | wsl)
            # Check for package managers in order of preference
            if command -v apt-get >/dev/null 2>&1; then
                pkg_manager="apt"
            elif command -v dnf >/dev/null 2>&1; then
                pkg_manager="dnf"
            elif command -v yum >/dev/null 2>&1; then
                pkg_manager="yum"
            elif command -v pacman >/dev/null 2>&1; then
                pkg_manager="pacman"
            elif command -v zypper >/dev/null 2>&1; then
                pkg_manager="zypper"
            elif command -v brew >/dev/null 2>&1; then
                pkg_manager="brew" # Linuxbrew
            fi
            ;;
        bsd)
            if command -v pkg >/dev/null 2>&1; then
                pkg_manager="pkg" # FreeBSD
            elif command -v pacman >/dev/null 2>&1; then
                pkg_manager="pacman" # Arch Linux BSD
            fi
            ;;
    esac

    echo "$pkg_manager"
}

export SC_PKG_MANAGER="${SC_PKG_MANAGER:-$(detect_package_manager)}"

# =============================================================================
# Homebrew Path Detection
# =============================================================================

get_homebrew_prefix() {
    local prefix=""

    # PERF: Use deterministic paths on macOS first (avoids ~99ms `brew --prefix` Ruby spawn)
    # The Homebrew install paths are fixed by architecture and have been stable since 2021.
    # Only fall back to `brew --prefix` if the expected path doesn't exist.
    case "$SC_OS" in
        macos)
            # Apple Silicon (arm64) → /opt/homebrew, Intel (x86_64) → /usr/local
            if [[ "$SC_ARCH" == "arm64" ]]; then
                prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
            else
                prefix="${HOMEBREW_PREFIX:-/usr/local}"
            fi
            # Verify the path exists; if not, try brew --prefix as last resort
            if [[ -d "$prefix/bin" ]]; then
                echo "$prefix"
                return 0
            fi
            ;;
        linux | wsl)
            # Linuxbrew paths - check environment var first
            prefix="${LINUXBREW_PREFIX:-"$HOME"/.linuxbrew}"
            # Fallback to system linuxbrew if user-local doesn't exist
            if [[ ! -d "$prefix" ]] && [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
                prefix="/home/linuxbrew/.linuxbrew"
            fi
            if [[ -d "$prefix/bin" ]]; then
                echo "$prefix"
                return 0
            fi
            ;;
    esac

    # Last resort: query brew directly (spawns Ruby, ~99ms on macOS)
    if command -v brew >/dev/null 2>&1; then
        prefix="$(brew --prefix 2>/dev/null || echo '')"
        [[ -n "$prefix" ]] && {
            echo "$prefix"
            return 0
        }
    fi

    echo "$prefix"
}

export SC_HOMEBREW_PREFIX="${SC_HOMEBREW_PREFIX:-$(get_homebrew_prefix)}"

# =============================================================================
# Convenience Test Functions
# =============================================================================

is_macos() { [[ "$SC_OS" == "macos" ]]; }
is_linux() { [[ "$SC_OS" == "linux" ]]; }
is_wsl() { [[ "$SC_OS" == "wsl" ]]; }
is_bsd() { [[ "$SC_OS" == "bsd" ]]; }
has_brew() { command -v brew >/dev/null 2>&1; }
has_apt() { command -v apt-get >/dev/null 2>&1; }

# =============================================================================
# Platform-Aware Logging
# =============================================================================

platform_log_info() {
    local msg="$1"
    local os_label="${SC_OS:-unknown}"
    if command -v log_info >/dev/null 2>&1; then
        log_info "[$os_label] $msg"
    else
        echo -e "ℹ️  [$os_label] $msg"
    fi
}

platform_log_warning() {
    local msg="$1"
    local os_label="${SC_OS:-unknown}"
    if command -v log_warning >/dev/null 2>&1; then
        log_warning "[$os_label] $msg"
    else
        echo -e "⚠️  [$os_label] $msg" >&2
    fi
}

platform_log_error() {
    local msg="$1"
    local os_label="${SC_OS:-unknown}"
    if command -v log_error >/dev/null 2>&1; then
        log_error "[$os_label] $msg"
    else
        echo -e "❌ [$os_label] $msg" >&2
    fi
}

platform_log_success() {
    local msg="$1"
    local os_label="${SC_OS:-unknown}"
    if command -v log_success >/dev/null 2>&1; then
        log_success "[$os_label] $msg"
    else
        echo -e "✅ [$os_label] $msg"
    fi
}

# =============================================================================
# Package Manager Helpers
# =============================================================================

pkg_install() {
    local pkg="$1"
    local pkg_mgr="${SC_PKG_MANAGER:-none}"

    if [[ -z "$pkg" ]]; then
        platform_log_error "No package specified"
        return 1
    fi

    case "$pkg_mgr" in
        brew)
            platform_log_info "Installing $pkg via Homebrew..."
            brew install "$pkg"
            ;;
        apt)
            platform_log_info "Installing $pkg via apt..."
            sudo apt-get update -qq && sudo apt-get install -y "$pkg"
            ;;
        dnf)
            platform_log_info "Installing $pkg via dnf..."
            sudo dnf install -y "$pkg"
            ;;
        yum)
            platform_log_info "Installing $pkg via yum..."
            sudo yum install -y "$pkg"
            ;;
        pacman)
            platform_log_info "Installing $pkg via pacman..."
            sudo pacman -S --noconfirm "$pkg"
            ;;
        zypper)
            platform_log_info "Installing $pkg via zypper..."
            sudo zypper install -y "$pkg"
            ;;
        pkg)
            platform_log_info "Installing $pkg via pkg..."
            sudo pkg install -y "$pkg"
            ;;
        none)
            platform_log_error "No package manager found"
            return 1
            ;;
        *)
            platform_log_error "Unsupported package manager: $pkg_mgr"
            return 1
            ;;
    esac
}

pkg_update() {
    local pkg_mgr="${SC_PKG_MANAGER:-none}"

    case "$pkg_mgr" in
        brew)
            platform_log_info "Updating Homebrew packages..."
            brew update
            ;;
        apt)
            platform_log_info "Updating apt packages..."
            sudo apt-get update -qq
            ;;
        dnf)
            platform_log_info "Updating dnf packages..."
            sudo dnf check-update || true
            ;;
        yum)
            platform_log_info "Updating yum packages..."
            sudo yum check-update || true
            ;;
        pacman)
            platform_log_info "Updating pacman packages..."
            sudo pacman -Sy
            ;;
        zypper)
            platform_log_info "Updating zypper packages..."
            sudo zypper refresh
            ;;
        pkg)
            platform_log_info "Updating pkg packages..."
            sudo pkg update
            ;;
        none)
            platform_log_error "No package manager found"
            return 1
            ;;
        *)
            platform_log_error "Unsupported package manager: $pkg_mgr"
            return 1
            ;;
    esac
}

# =============================================================================
# Platform Information Display
# =============================================================================

platform_info() {
    echo -e "\n📋 Platform Information"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "OS:           ${SC_OS:-unknown}"
    echo "Architecture: ${SC_ARCH:-unknown}"
    echo "Distro:       ${SC_LINUX_DISTRO:-N/A}"
    echo "Package Mgr:  ${SC_PKG_MANAGER:-none}"
    echo "Homebrew:     ${SC_HOMEBREW_PREFIX:-not installed}"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# =============================================================================
# Export Functions
# =============================================================================

# Export functions for use in subshells (bash only)
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f detect_os detect_architecture detect_linux_distro detect_package_manager get_homebrew_prefix 2>/dev/null || true
    export -f is_macos is_linux is_wsl is_bsd has_brew has_apt 2>/dev/null || true
    export -f platform_log_info platform_log_warning platform_log_error platform_log_success 2>/dev/null || true
    export -f pkg_install pkg_update platform_info 2>/dev/null || true
fi
