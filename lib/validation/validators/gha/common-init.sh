#!/usr/bin/env bash
# =============================================================================
# GHA Validator Common Initialization
# =============================================================================
# Shared header logic for GitHub Actions validators
# =============================================================================
set -euo pipefail

# Load shared workflow scanners (bash/zsh compatible)
if [[ -n "${SHELL_CONFIG_DIR:-}" ]]; then
    _GHA_SCANNER_BASE="$SHELL_CONFIG_DIR/lib/validation"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _GHA_SCANNER_BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
    _GHA_SCANNER_BASE="${HOME}/.shell-config/lib/validation"
fi
source "$_GHA_SCANNER_BASE/shared/workflow-scanners.sh"
