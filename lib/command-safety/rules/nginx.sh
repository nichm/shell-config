#!/usr/bin/env bash
# =============================================================================
# ⚠️ NGINX RULES
# =============================================================================
# Safety rules for nginx web server operations.
# Disable: export COMMAND_SAFETY_DISABLE_NGINX=true
# =============================================================================

# shellcheck disable=SC2034

# --- nginx -s stop ---
_rule NGINX_STOP cmd="nginx" match="-s stop" \
    block="Stops ALL nginx processes — takes down ALL hosted websites immediately" \
    bypass="--force-nginx-stop"

_fix NGINX_STOP \
    "nginx -s reload  # Reload config with zero downtime" \
    "nginx -s quit    # Graceful stop — waits for connections"

# --- nginx -s quit ---
_rule NGINX_QUIT cmd="nginx" match="-s quit" \
    block="Gracefully stops nginx — still takes down all websites after connections close" \
    bypass="--force-nginx-quit"

_fix NGINX_QUIT \
    "nginx -s reload  # Reload config with zero downtime"

# --- nginx -s reload ---
_rule NGINX_RELOAD cmd="nginx" match="-s reload" \
    block="Reloads nginx config — run nginx -t first to validate syntax" \
    bypass="--force-nginx-reload" \
    emoji="⚠️"
