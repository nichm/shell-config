#!/usr/bin/env bash
set -euo pipefail
# Thin wrapper around toolchain-scanner.sh for validator discovery.
# Run with --help for full options.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/toolchain-scanner.sh" "$@"
