#!/usr/bin/env bash
# =============================================================================
# 🐱 KITTY TERMINAL INSTALLER
# =============================================================================
# Installs and configures Kitty terminal emulator
# Supports: macOS (Homebrew), Linux (APT, DNF, Pacman)
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/kitty.sh" && install_kitty
# =============================================================================
set -euo pipefail

[[ -n "${_KITTY_UNIFIED_LOADED:-}" ]] && return 0
readonly _KITTY_UNIFIED_LOADED=1

# Load shared installer infrastructure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared-installer.sh
source "${SCRIPT_DIR}/shared-installer.sh"

# Kitty configuration
KITTY_CONFIG_DIR="$HOME/.config/kitty"
KITTY_CONF="$KITTY_CONFIG_DIR/kitty.conf"
export KITTY_CONFIG_DIR KITTY_CONF

# =============================================================================
# INSTALLED CHECK
# =============================================================================

is_kitty_installed() {
    command_exists "kitty"
}

# =============================================================================
# macOS INSTALLATION
# =============================================================================

install_kitty_macos() {
    _ti_ensure_homebrew || return 1

    if _ti_check_installed_cmd "kitty" "Kitty" "kitty --version"; then
        configure_kitty
        return 0
    fi

    # Also check brew list (might be installed but not in PATH yet)
    if _ti_check_installed_brew "kitty" "Kitty"; then
        configure_kitty
        return 0
    fi

    _ti_install_brew "kitty" "Kitty" || return 1
    _ti_verify_and_track "kitty" "Kitty" "kitty --version" || return 1
    configure_kitty
}

# =============================================================================
# LINUX INSTALLATION
# =============================================================================

install_kitty_linux() {
    log_info "Installing Kitty on Linux..."

    if _ti_check_installed_cmd "kitty" "Kitty" "kitty --version"; then
        configure_kitty
        return 0
    fi

    _ti_linux_pkg_router "Kitty" \
        _kitty_install_apt \
        _kitty_install_dnf_or_pacman \
        _kitty_install_dnf_or_pacman || return 1

    # Post-installation setup
    if command_exists "kitty"; then
        _kitty_create_desktop_entry
        _kitty_install_terminfo
    fi
}

# APT: Custom install from GitHub releases (not in default repos)
_kitty_install_apt() {
    log_info "Installing Kitty via APT (GitHub release)..."

    sudo apt update || { log_error "Failed to update package list"; return 1; }
    sudo apt install -y curl ca-certificates || { log_error "Failed to install dependencies"; return 1; }

    local arch
    case "$(uname -m)" in
        x86_64) arch="x86_64" ;;
        aarch64) arch="arm64" ;;
        *) log_error "Unsupported architecture: $(uname -m)"; return 1 ;;
    esac

    local download_url="https://github.com/kovidgoyal/kitty/releases/latest/download/kitty-latest-${arch}.txz"
    local temp_dir
    temp_dir="$(mktemp_dir_with_cleanup)"

    log_info "Downloading Kitty..."
    curl -fsSL "$download_url" -o "${temp_dir}/kitty.txz" || { log_error "Download failed"; return 1; }

    log_info "Extracting Kitty..."
    tar -xf "${temp_dir}/kitty.txz" -C "$temp_dir" || { log_error "Extraction failed"; return 1; }

    sudo cp -r "${temp_dir}/kitty.app" /opt/kitty || { log_error "Install failed"; return 1; }
    sudo ln -sf /opt/kitty/bin/kitty /usr/local/bin/kitty || { log_error "Symlink failed"; return 1; }

    # Optional desktop integration
    sudo cp /opt/kitty/share/applications/kitty.desktop /usr/share/applications/ 2>/dev/null || true
    sudo cp -r /opt/kitty/share/icons /usr/share/ 2>/dev/null || true

    _ti_verify_and_track "kitty" "Kitty" "kitty --version" || return 1
    configure_kitty
}

# DNF/Pacman: Standard package manager install
_kitty_install_dnf_or_pacman() {
    _ti_install_linux_pkg "kitty" "Kitty" || return 1
    _ti_verify_and_track "kitty" "Kitty" "kitty --version" || return 1
    configure_kitty
}

# =============================================================================
# CONFIGURATION
# =============================================================================

_kitty_write_default_config() {
    local target_file="$1"
    cat >"$target_file" <<'EOT'
# Kitty Terminal Configuration
# Optimized for performance and usability

# Font configuration
font_family      JetBrains Mono
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        14.0
disable_ligatures never

# Cursor configuration
cursor_shape     block
cursor_blink_interval     0.5
cursor_stop_blinking_after 15.0

# Scrollback
scrollback_lines 10000
scrollback_pager less --chop-long-lines --RAW-CONTROL-CHARS +INPUT_LINE_NUMBER

# Mouse
mouse_hide_wait  3.0
copy_on_select   clipboard
strip_trailing_spaces never

# Performance
repaint_delay    10
input_delay 3
sync_to_monitor yes

# Bell
enable_audio_bell no
visual_bell_duration 0.2
window_alert_on_bell yes
bell_on_tab yes

# Window layout
remember_window_size  yes
initial_window_width  140c
initial_window_height 40c

# Tab bar
tab_bar_edge bottom
tab_bar_style powerline
tab_powerline_style slanted
tab_bar_min_tabs 2

# Colors (Base16 One Dark theme)
foreground #abb2bf
background #282c34
cursor #abb2bf
color0 #1e2127
color1 #e06c75
color2 #98c379
color3 #d19a66
color4 #61afef
color5 #c678dd
color6 #56b6c2
color7 #5c6370
color8 #4b5263
color9 #e06c75
color10 #98c379
color11 #d19a66
color12 #61afef
color13 #c678dd
color14 #56b6c2
color15 #abb2bf
selection_foreground #282c34
selection_background #abb2bf

# URL detection
url_style curly
url_prefixes http https file ftp gemini irc gopher mailto news git
detect_urls yes

# Shell integration
shell_integration enabled

# Terminal features
allow_remote_control yes
enable_layouts yes
EOT
}

configure_kitty() {
    log_info "Configuring Kitty..."
    _ti_ensure_config_dir "$KITTY_CONFIG_DIR"
    _ti_backup_and_write_config "$KITTY_CONF" _kitty_write_default_config

    # Legacy symlink for backward compatibility
    local legacy_config_dir="$HOME/.kitty"
    if [[ ! -e "$legacy_config_dir" ]]; then
        ln -s "$KITTY_CONFIG_DIR" "$legacy_config_dir"
        log_info "Created legacy symlink: $legacy_config_dir -> $KITTY_CONFIG_DIR"
    fi

    _kitty_create_session
}

_kitty_create_session() {
    local session_file="$KITTY_CONFIG_DIR/session.conf"
    cat >"$session_file" <<'EOT'
# Kitty Startup Session
# Uncomment and customize as needed
# tab --title "Home" zsh
# tab --title "Work" cd ~/work && zsh
# tab --title "Projects" cd ~/projects && zsh
EOT
    log_info "Kitty session file created at $session_file"
}

# =============================================================================
# TERMINFO & DESKTOP ENTRY
# =============================================================================

_kitty_install_terminfo() {
    log_info "Installing Kitty terminfo entries..."
    if command_exists "tic"; then
        local kitty_terminfo="/usr/share/kitty/terminfo/kitty.terminfo"
        local kitty_modded="/usr/share/kitty/terminfo/kitty-modded.terminfo"
        [[ -f "$kitty_terminfo" ]] && tic "$kitty_terminfo" && log_success "Installed kitty terminfo"
        [[ -f "$kitty_modded" ]] && tic "$kitty_modded" && log_success "Installed kitty-modded terminfo"
    else
        log_warning "tic not found, skipping terminfo installation"
    fi
}

_kitty_create_desktop_entry() {
    [[ "$(detect_os)" != "linux" ]] && return 0

    local desktop_dir="$HOME/.local/share/applications"
    mkdir -p "$desktop_dir"

    if [[ ! -f "${desktop_dir}/kitty.desktop" ]]; then
        cat >"${desktop_dir}/kitty.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Kitty Terminal
Comment=Fast, feature-rich, GPU based terminal emulator
Exec=kitty
Icon=kitty
Terminal=false
Categories=System;TerminalEmulator;Emulator;
EOF
        log_success "Desktop entry created at ${desktop_dir}/kitty.desktop"
    fi
}

# =============================================================================
# UNINSTALL
# =============================================================================

uninstall_kitty() {
    log_warning "Uninstalling Kitty..."
    local os_type
    os_type="$(detect_os)"

    case "$os_type" in
        macos) _ti_uninstall_brew "kitty" ;;
        linux)
            _ti_uninstall_linux_pkg "kitty"
            _ti_remove_desktop_entry "kitty.desktop"
            ;;
    esac

    _ti_log_config_preserved "$KITTY_CONFIG_DIR" "Kitty"
    [[ -L "$HOME/.kitty" ]] && rm -f "$HOME/.kitty" && log_success "Removed ~/.kitty symlink"
    log_success "Kitty uninstalled"
}

# =============================================================================
# MAIN
# =============================================================================

install_kitty() {
    _ti_main_entry "Kitty" install_kitty_macos install_kitty_linux
}

# Export functions (bash only)
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f install_kitty install_kitty_macos install_kitty_linux 2>/dev/null || true
    export -f is_kitty_installed configure_kitty uninstall_kitty 2>/dev/null || true
fi
