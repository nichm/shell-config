#!/usr/bin/env bash
# =============================================================================
# aliases/package-managers.sh - Package manager and tool shortcuts
# =============================================================================
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/aliases/package-managers.sh"
# =============================================================================

[[ -n "${_SHELL_CONFIG_ALIASES_PACKAGE_MANAGERS_LOADED:-}" ]] && return 0
_SHELL_CONFIG_ALIASES_PACKAGE_MANAGERS_LOADED=1

# Bun package manager
alias bi='bun install'
alias ba='bun add'
alias bad='bun add -D'
alias br='bun remove'
alias bx='bunx'
alias bdev='bun run dev'
alias bbuild='bun run build'
alias bstart='bun run start'
alias btest='bun run test'
alias blint='bun run lint'
alias bformat='bun run format'
alias btype='bun run typecheck'
alias bclean='bun run clean'
alias bup='bun update'
alias bls='bun pm ls'
alias boutdated='bun pm outdated'
alias bcache='bun pm cache rm'
alias bw='bun -w'
alias bwi='bun -w install'
alias bwr='bun -w run'

# UV package manager (Python)
alias pip='uv pip'
alias upip='uv pip install'
alias ua='uv add'
alias uad='uv add --dev'
alias uvremove='uv remove'
alias ur='uv run'
alias uvx='uvx'
alias uvenv='uv venv'
alias upython='uv python'
alias uvsync='uv sync'
alias ulock='uv lock'
alias ulockup='uv lock --upgrade'

# Cloudflare Wrangler (Cloudflare Workers)
alias wr='wrangler'
alias wrd='wrangler dev'
alias wrp='wrangler deploy'
alias wrdeploy='wrangler deploy'
alias wrtail='wrangler tail'
alias wrsecret='wrangler secret'
alias wrpages='wrangler pages'
alias wrkv='wrangler kv'
alias wrr2='wrangler r2'
alias wrd1='wrangler d1'

# Supabase
alias sb='supabase'
alias sbstart='supabase start'
alias sbstop='supabase stop'
alias sbstatus='supabase status'
alias sbdb='supabase db'
alias sbmigrate='supabase migration'
alias sbgen='supabase gen'
alias sbfn='supabase functions'
alias sblink='supabase link'
