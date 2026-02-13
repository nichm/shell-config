#!/usr/bin/env bash
# =============================================================================
# infra/benchmark-validator.sh - Performance benchmarking validator
# =============================================================================
# Wrapper for the consolidated benchmarking validator.
# Measures and validates performance metrics for various operations.
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/validation/validators/infra/benchmark-validator.sh"
#   validate_performance_metrics
# =============================================================================
set -euo pipefail

# Source the actual benchmark validator from the consolidated location
source "${SHELL_CONFIG_DIR:-${HOME}/.shell-config}/tools/benchmarking/benchmark-validator.sh"
