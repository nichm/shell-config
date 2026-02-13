#!/usr/bin/env bash
# =============================================================================
# ⚠️ SUPABASE & DATABASE RULES
# =============================================================================
# Safety rules for Supabase CLI and PostgreSQL operations.
# Disable: export COMMAND_SAFETY_DISABLE_SUPABASE=true
# Custom match functions:
#   _cs_match_pg_dump_gzip - Detects pipe in pg_dump args (silent corruption)
# =============================================================================

# shellcheck disable=SC2034

# =============================================================================
# Custom match functions
# =============================================================================

# Match pg_dump with pipe (|) in args — pipelines can fail silently
_cs_match_pg_dump_gzip() {
    local args_string="$*"
    [[ "$args_string" =~ \| ]]
}

# =============================================================================
# Supabase CLI rules
# =============================================================================

# --- supabase db reset ---
_rule SUPABASE_RESET cmd="supabase" match="db reset" \
    block="Wipes entire local database — irreversible data loss" \
    bypass="--force-supabase-reset"

_fix SUPABASE_RESET \
    "supabase migration up         # Apply specific migrations instead" \
    "supabase db push              # Push schema changes without reset" \
    "supabase db dump > backup.sql # Create backup first"

# --- supabase stop --no-backup ---
_rule SUPABASE_STOP cmd="supabase" match="stop --no-backup" \
    block="Deletes all local data volumes without creating a backup" \
    bypass="--force-supabase-stop"

_fix SUPABASE_STOP \
    "supabase stop        # Stop with backup preserved" \
    "supabase db dump     # Backup before stopping"

# --- supabase link ---
_rule SUPABASE_LINK cmd="supabase" match="link" \
    block="Links local project to remote Supabase project — verify correct environment" \
    bypass="--force-supabase-link" \
    emoji="⚠️"

_fix SUPABASE_LINK \
    "supabase projects list  # List available projects first"

# --- supabase db push ---
_rule SUPABASE_DB_PUSH cmd="supabase" match="db push" \
    block="Pushes local schema directly to remote database" \
    bypass="--force-supabase-push" \
    emoji="⚠️"

_fix SUPABASE_DB_PUSH \
    "supabase db diff       # See schema differences first" \
    "supabase migration new # Create tracked migration instead"

# --- supabase functions delete ---
_rule SUPABASE_FUNC_DELETE cmd="supabase" match="functions delete" \
    block="Deletes Edge Function from production — may break services" \
    bypass="--force-supabase-func-delete"

_fix SUPABASE_FUNC_DELETE \
    "supabase functions list  # List functions first"

# =============================================================================
# PostgreSQL rules
# =============================================================================

# --- pg_dump with gzip pipe ---
_rule PG_DUMP_GZIP cmd="pg_dump" match_fn="_cs_match_pg_dump_gzip" \
    block="Database dumps with pipelines can fail silently and corrupt backups" \
    bypass="--force-pg-pipeline" \
    emoji="⚠️"

_fix PG_DUMP_GZIP \
    "pg_dump -Fc <db> -f backup.dump  # Custom format, no pipe needed" \
    "pg_dump <db> > backup.sql        # Plain SQL without compression"
