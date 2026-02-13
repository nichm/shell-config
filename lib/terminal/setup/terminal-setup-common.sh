#!/usr/bin/env bash
# =============================================================================
# 🔧 TERMINAL SETUP FUNCTIONS
# =============================================================================
# Shared functions for terminal setup scripts
# Usage: source "$SHELL_CONFIG_DIR/lib/terminal/setup/terminal-setup-common.sh"
# This library provides common functions used by:
#   - setup-macos-terminal.sh
#   - setup-ubuntu-terminal.sh
#   - setup-autocomplete-tools.sh
#   - uninstall-terminal-setup.sh
# Note: This file now sources from the consolidated lib/terminal/common.sh
# =============================================================================

# Exit if script is sourced more than once
[[ -n "${TERMINAL_SETUP_COMMON_LOADED:-}" ]] && return 0
TERMINAL_SETUP_COMMON_LOADED=1

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source from consolidated terminal common library
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================
# All installation tracking functions are now available via common.sh
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f track_installation is_installed list_installed_tools 2>/dev/null || true
fi
