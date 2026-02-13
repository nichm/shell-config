#!/usr/bin/env bash
# =============================================================================
# integrations/ghls/colors.sh - Color definitions for ghls output
# =============================================================================
# Shared color constants used by the ghls command for consistent styling.
# This file is meant to be sourced by other ghls scripts.
# Usage:
#   source "$GHLS_DIR/colors.sh"
# =============================================================================

# shellcheck disable=SC2034  # These variables are used by sourcing scripts

# Colors and formatting
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly RESET='\033[0m'
readonly CYAN='\033[38;5;39m'
readonly GREEN='\033[38;5;34m'
readonly YELLOW='\033[38;5;208m'
readonly BLUE='\033[38;5;33m'

# Git colors (from single-ghls.sh)
readonly BRANCH_COLOR_HAS_PR='\033[38;5;34m'
readonly BRANCH_COLOR_NO_PR='\033[38;5;208m'
readonly STAGED_COLOR='\033[38;5;193m'
readonly UNTRACKED_COLOR='\033[38;5;208m'
readonly COMMITTED_COLOR='\033[38;5;147m'
readonly SEP_COLOR='\033[38;5;245m'
readonly PHASE_SEP='\033[38;5;240m'
readonly GREEN_ADD='\033[38;5;34m'
readonly RED_DEL='\033[38;5;196m'
