#!/usr/bin/env bash
# =============================================================================
# ⚠️ NEXT.JS RULES
# =============================================================================
# Safety rules for Next.js build operations.
# Disable: export COMMAND_SAFETY_DISABLE_NEXTJS=true
# =============================================================================

# shellcheck disable=SC2034

# --- next build --no-lint ---
_rule NEXT_BUILD_NO_LINT cmd="next" match="build --no-lint" \
    block="Building without lint checks may introduce bugs into production" \
    bypass="--force-next-no-lint" \
    emoji="⚠️"

_fix NEXT_BUILD_NO_LINT \
    "bun run lint  # Run lint separately first"
