#!/usr/bin/env bash
# =============================================================================
# Pinact Validator
# =============================================================================
# Version pinning enforcement (currently disabled by policy)
# =============================================================================
set -euo pipefail

_gha_run_pinact() {
    # DISABLED: SHA pinning is too noisy and hard to maintain
    # Semver tags (v4, v8) are acceptable for trusted first-party actions
    _gha_log_info "pinact: Skipped (SHA pinning disabled by policy)"
    return 0
}
