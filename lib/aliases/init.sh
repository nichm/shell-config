#!/usr/bin/env bash
# =============================================================================
# aliases/init.sh - Load shell-config alias modules
# =============================================================================
# Usage:
#   source "${SHELL_CONFIG_DIR}/lib/aliases/init.sh"
# =============================================================================

[[ -n "${_SHELL_CONFIG_ALIASES_INIT_LOADED:-}" ]] && return 0
_SHELL_CONFIG_ALIASES_INIT_LOADED=1

_aliases_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f "$_aliases_dir/core.sh" ]] && source "$_aliases_dir/core.sh"
[[ -f "$_aliases_dir/ai-cli.sh" ]] && source "$_aliases_dir/ai-cli.sh"
[[ -f "$_aliases_dir/git.sh" ]] && source "$_aliases_dir/git.sh"
[[ -f "$_aliases_dir/package-managers.sh" ]] && source "$_aliases_dir/package-managers.sh"
[[ -f "$_aliases_dir/formatting.sh" ]] && source "$_aliases_dir/formatting.sh"
[[ -f "$_aliases_dir/gha.sh" ]] && source "$_aliases_dir/gha.sh"
[[ -f "$_aliases_dir/1password.sh" ]] && source "$_aliases_dir/1password.sh"
[[ -f "$_aliases_dir/servers.sh" ]] && source "$_aliases_dir/servers.sh"

unset _aliases_dir
