#!/usr/bin/env bash
# =============================================================================
# 🚀 ITERM2 TERMINAL INSTALLER
# =============================================================================
# Installs and configures iTerm2 terminal emulator
# Supports: macOS only
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/iterm2.sh" && install_iterm2
# =============================================================================
set -euo pipefail

# Load shared installer infrastructure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared-installer.sh
source "${SCRIPT_DIR}/shared-installer.sh"

# iTerm2 configuration
ITERM2_VERSION_STABLE="3.5.9"
ITERM2_VERSION_BETA="3.5.9beta1"
ITERM2_USE_BETA="${ITERM2_USE_BETA:-false}"

# =============================================================================
# INSTALLED CHECK
# =============================================================================

is_iterm2_installed() {
    [[ -d "/Applications/iTerm.app" ]]
}

# =============================================================================
# DOWNLOAD
# =============================================================================

_iterm2_download() {
    local temp_dir="$1"
    local version

    if [[ "$ITERM2_USE_BETA" == "true" ]]; then
        version="$ITERM2_VERSION_BETA"
        local url="https://iterm2.com/downloads/beta/iTerm2-${version}.zip"
    else
        version="$ITERM2_VERSION_STABLE"
        local url="https://iterm2.com/downloads/stable/iTerm2-${version}.zip"
    fi

    local zip_file="${temp_dir}/iTerm2.zip"
    log_info "Downloading iTerm2 ${version}..."

    if ! download_file "$url" "$zip_file"; then
        log_error "Failed to download iTerm2"
        return 1
    fi

    echo "$zip_file"
}

# =============================================================================
# INSTALL
# =============================================================================

install_iterm2() {
    log_step "iTerm2 Terminal Installation"

    local os_type
    os_type="$(detect_os)"

    if [[ "$os_type" != "macos" ]]; then
        log_error "iTerm2 is only available for macOS"
        log_info "Current OS: $(uname)"
        return 1
    fi

    # Check if already installed
    if _ti_check_installed_app "iTerm" "iTerm2"; then
        if [[ -f "/Applications/iTerm.app/Contents/Info.plist" ]]; then
            local version
            version=$(defaults read /Applications/iTerm.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo "unknown")
            log_success "iTerm2 version: ${version}"
        fi

        # Non-interactive reconfiguration via environment variable
        if [[ "${ITERM2_FORCE_CONFIG:-}" == "true" ]]; then
            configure_iterm2
            _iterm2_install_shell_integration
        fi
        return 0
    fi

    # Download and extract
    local temp_dir
    temp_dir=$(mktemp_dir_with_cleanup)

    local zip_file
    if ! zip_file=$(_iterm2_download "$temp_dir"); then
        return 1
    fi

    log_info "Extracting iTerm2..."
    if ! unzip -q "$zip_file" -d "$temp_dir"; then
        log_error "Failed to extract iTerm2"
        return 1
    fi

    # Copy to Applications
    local app_name="iTerm.app"
    if [[ ! -d "${temp_dir}/${app_name}" ]]; then
        log_error "iTerm2 app not found in archive"
        return 1
    fi

    # Remove existing installation if present
    [[ -d "/Applications/${app_name}" ]] && rm -rf "/Applications/${app_name}"

    log_info "Installing iTerm2 to /Applications..."
    if ! cp -R "${temp_dir}/${app_name}" "/Applications"; then
        log_error "Failed to copy iTerm2 to /Applications"
        return 1
    fi

    log_success "iTerm2 installed successfully"
    track_installation "iterm2" "success"

    configure_iterm2
    _iterm2_install_shell_integration

    log_info "You can now launch iTerm2 from Applications or Spotlight"
}

# =============================================================================
# CONFIGURE
# =============================================================================

configure_iterm2() {
    log_info "Configuring iTerm2..."

    # Set custom preferences folder
    defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$HOME/.config/iterm2"

    local iterm2_config_dir="$HOME/.config/iterm2"
    _ti_ensure_config_dir "$iterm2_config_dir"

    # Warn if running during configuration
    if pgrep -q "iTerm2"; then
        log_warning "iTerm2 is running. Some settings may not apply until restart."
    fi

    cat >"${iterm2_config_dir}/README.txt" <<'EOF'
iTerm2 Configuration Directory

iTerm2 stores its preferences in:
  ~/Library/Preferences/com.googlecode.iterm2.plist

For advanced configuration, use iTerm2's UI:
  1. Open iTerm2
  2. iTerm2 > Preferences > Profiles
  3. Customize colors, fonts, and settings
  4. Save profile as default

Key recommendations:
  - Enable Shell Integration: Preferences > Profiles > General > Command
  - Set custom color scheme: Preferences > Profiles > Colors
  - Configure hotkey window: Preferences > Keys > Hotkey
  - Enable mouse reporting: Preferences > Profiles > Terminal
EOF

    log_success "iTerm2 configuration directory created at ${iterm2_config_dir}"
}

# =============================================================================
# SHELL INTEGRATION
# =============================================================================

_iterm2_install_shell_integration() {
    log_info "Installing iTerm2 shell integration..."

    local integration_dir="$HOME/.iterm2"
    _ti_ensure_config_dir "$integration_dir"

    # Download shell integration scripts
    local shells=("zsh" "bash")
    for shell in "${shells[@]}"; do
        local url="https://iterm2.com/shell_integration/${shell}"
        local file="${integration_dir}/shell_integration.${shell}"

        if download_file "$url" "$file"; then
            log_success "Downloaded ${shell} integration"
            _iterm2_add_shell_integration "$shell" "$file"
        else
            log_warning "Failed to download ${shell} integration"
        fi
    done

    # Install utilities (imgcat, imgls)
    local utilities_dir="${integration_dir}/utilities"
    mkdir -p "$utilities_dir"

    for util in imgcat imgls; do
        if download_file "https://iterm2.com/utilities/${util}" "${utilities_dir}/${util}"; then
            chmod +x "${utilities_dir}/${util}"
            log_success "Installed ${util} utility"
        fi
    done

    # Add utilities to PATH
    local zshrc="$HOME/.zshrc"
    if ! grep -q "iterm2/utilities" "$zshrc" 2>/dev/null; then
        {
            echo ""
            echo "# iTerm2 utilities"
            echo "export PATH=\"${utilities_dir}:\$PATH\""
        } >>"$zshrc"
        log_success "Added iTerm2 utilities to PATH"
    fi

    log_success "iTerm2 shell integration installed"
    log_warning "Restart your shell for integration to take effect"
}

_iterm2_add_shell_integration() {
    local shell="$1"
    local file="$2"

    case "$shell" in
        zsh)
            local rc="$HOME/.zshrc"
            if ! grep -q "shell_integration.zsh" "$rc" 2>/dev/null; then
                printf '\n# iTerm2 shell integration\nsource "%s"\n' "$file" >>"$rc"
                log_success "Added iTerm2 integration to .zshrc"
            fi
            ;;
        bash)
            local rc="$HOME/.bashrc"
            if ! grep -q "shell_integration.bash" "$rc" 2>/dev/null; then
                printf '\n# iTerm2 shell integration\nsource "%s"\n' "$file" >>"$rc"
                log_success "Added iTerm2 integration to .bashrc"
            fi
            ;;
    esac
}

# =============================================================================
# UNINSTALL
# =============================================================================

uninstall_iterm2() {
    log_warning "Uninstalling iTerm2..."

    _ti_uninstall_app "iTerm"

    # Remove shell integration references from .zshrc
    local zshrc="$HOME/.zshrc"
    if [[ -f "$zshrc" ]]; then
        if [[ "$(detect_os)" == "macos" ]]; then
            sed -i '' '/iTerm2 shell integration/d' "$zshrc"
            sed -i '' '/iterm2\/utilities/d' "$zshrc"
            sed -i '' '/shell_integration\.zsh/d' "$zshrc"
        else
            sed -i '/iTerm2 shell integration/d' "$zshrc"
            sed -i '/iterm2\/utilities/d' "$zshrc"
            sed -i '/shell_integration\.zsh/d' "$zshrc"
        fi
        log_success "Removed iTerm2 integration from .zshrc"
    fi

    if [[ "${ITERM2_PURGE_CONFIG:-}" == "true" ]]; then
        rm -rf "$HOME/.iterm2"
        log_success "Removed ~/.iterm2"
    else
        log_info "Skipping ~/.iterm2 removal (set ITERM2_PURGE_CONFIG=true to remove)"
    fi

    log_success "iTerm2 uninstalled"
}

# Export functions (bash only)
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f install_iterm2 is_iterm2_installed configure_iterm2 uninstall_iterm2 2>/dev/null || true
fi
