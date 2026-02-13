#!/usr/bin/env bash
# =============================================================================
# ⚠️ CLOUDFLARE (WRANGLER) RULES
# =============================================================================
# Safety rules for Cloudflare Workers CLI operations.
# Disable: export COMMAND_SAFETY_DISABLE_CLOUDFLARE=true
# Custom match functions:
#   _cs_match_wrangler_deploy_prod - deploy + (--env/-e) prod regex
# =============================================================================

# shellcheck disable=SC2034

# =============================================================================
# Custom match functions
# =============================================================================

# Match wrangler deploy --env prod (or -e prod or --env=prod)
_cs_match_wrangler_deploy_prod() {
    local args=("$@")
    [[ ${#args[@]} -eq 0 ]] && return 1

    # First arg must be "deploy"
    [[ "${args[0]}" != "deploy" ]] && return 1

    # Check for --env prod, --env=prod, or -e prod pattern
    local args_string="${args[*]}"
    [[ "$args_string" =~ (--env[=\ ]|-e\ )prod ]]
}

# =============================================================================
# Rule definitions
# =============================================================================

# --- wrangler delete ---
_rule WRANGLER_DELETE cmd="wrangler" match="delete" \
    block="Deletes worker or resource — irreversible" \
    bypass="--force-wrangler-delete"

_fix WRANGLER_DELETE \
    "wrangler deploy     # Deploy new version instead" \
    "wrangler rollback   # Rollback to previous version"

# --- wrangler publish (deprecated) ---
_rule WRANGLER_PUBLISH cmd="wrangler" match="publish" \
    block="Publishes directly to production — use wrangler deploy instead" \
    bypass="--force-wrangler-publish" \
    emoji="⚠️"

_fix WRANGLER_PUBLISH \
    "wrangler deploy  # Recommended deployment method"

# --- wrangler deploy --env prod ---
_rule WRANGLER_DEPLOY_PROD cmd="wrangler" match_fn="_cs_match_wrangler_deploy_prod" \
    block="Deploys worker to production environment" \
    bypass="--force-wrangler-deploy-prod" \
    emoji="⚠️"

_fix WRANGLER_DEPLOY_PROD \
    "wrangler deploy --env staging  # Deploy to staging first" \
    "wrangler dev                   # Test locally first"

# --- wrangler d1 delete ---
_rule WRANGLER_D1_DELETE cmd="wrangler" match="d1 delete" \
    block="Deletes D1 database — irreversible data loss" \
    bypass="--force-wrangler-d1-delete"

_fix WRANGLER_D1_DELETE \
    "wrangler d1 export <db>  # Export database before deletion"

# --- wrangler kv namespace delete ---
_rule WRANGLER_KV_DELETE cmd="wrangler" match="kv namespace delete" \
    block="Deletes KV namespace — irreversible data loss" \
    bypass="--force-wrangler-kv-delete"

_fix WRANGLER_KV_DELETE \
    "wrangler kv:key list --namespace-id=<id>  # List keys first"

# --- wrangler r2 bucket delete ---
_rule WRANGLER_R2_DELETE cmd="wrangler" match="r2 bucket delete" \
    block="Deletes R2 bucket — irreversible data loss" \
    bypass="--force-wrangler-r2-delete"

# --- wrangler secret delete ---
_rule WRANGLER_SECRET_DELETE cmd="wrangler" match="secret delete" \
    block="Deleting worker secrets may break production deployments" \
    bypass="--force-wrangler-secret-delete"

_fix WRANGLER_SECRET_DELETE \
    "wrangler secret list  # List secrets first" \
    "wrangler secret put   # Update secret instead of deleting"
