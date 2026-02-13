#!/usr/bin/env bash
# =============================================================================
# ⚠️ DOCKER RULES
# =============================================================================
# Safety rules for Docker container operations.
# Disable: export COMMAND_SAFETY_DISABLE_DOCKER=true
# =============================================================================

# shellcheck disable=SC2034

# --- docker rm -f ---
_rule DOCKER_RM_F cmd="docker" match="rm -f|rm --force" \
    block="Force removing containers loses ALL container state — no graceful shutdown" \
    bypass="--force-docker-rm"

_fix DOCKER_RM_F \
    "docker stop <c> && docker rm <c>  # Graceful shutdown" \
    "docker commit <c> <image>          # Save state first"
