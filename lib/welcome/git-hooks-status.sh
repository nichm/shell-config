#!/usr/bin/env bash
# =============================================================================
# git-hooks-status.sh - Column-based Git hooks pipeline display
# =============================================================================
# Shows all 7 git hook stages as columns with category dividers.
# Commit pipeline (4 cols) + connector + Push/Merge pipeline (3 cols).
# Config: Part of welcome message system
# NOTE: No set -euo pipefail — this file is sourced into interactive shells
# =============================================================================

[[ -z "${_WM_COLOR_RESET:-}" ]] && return 1

# Source command cache for optimized command checks
# shellcheck source=lib/core/command-cache.sh
source "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/core/command-cache.sh"

# Source hook-check utilities for consistent git hook validation
# shellcheck source=lib/git/shared/hook-check.sh
if [[ -f "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/git/shared/hook-check.sh" ]]; then
    source "${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/git/shared/hook-check.sh"
fi

# =============================================================================
# Check Functions
# =============================================================================

# Consolidated hook check — verifies symlink points to shell-config
# PERF: Direct symlink check avoids check_hook_symlink subshell
_gh_check_hook() {
    local hook_name="$1"
    local hook="$HOME/.githooks/$hook_name"
    [[ -L "$hook" ]] || return 1
    local target
    target=$(readlink "$hook" 2>/dev/null) || return 1
    [[ "$target" == *"shell-config"* ]]
}

# Validator/shared script paths
_gh_validator_dir="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/validation/validators"
_gh_shared_dir="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/git/shared"
_gh_gha_bin="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/bin/gha-scan"

# Individual validator checks (testable wrappers)
_gh_check_syntax_validator() { [[ -f "$_gh_validator_dir/core/syntax-validator.sh" ]]; }
_gh_check_file_validator() { [[ -f "$_gh_validator_dir/core/file-validator.sh" ]]; }
_gh_check_security_validator() { [[ -f "$_gh_validator_dir/security/security-validator.sh" ]]; }
_gh_check_workflow_validator() { [[ -f "$_gh_validator_dir/infra/workflow-validator.sh" ]]; }
_gh_check_infra_validator() { [[ -f "$_gh_validator_dir/infra/infra-validator.sh" ]]; }
_gh_check_file_length() { [[ -f "$_gh_validator_dir/core/file-validator.sh" ]]; }
_gh_check_sensitive_files() { [[ -f "$_gh_validator_dir/security/sensitive-files-validator.sh" ]]; }
_gh_check_validation_loop() { [[ -f "$_gh_shared_dir/validation-loop.sh" ]]; }
_gh_check_gha_scanner() { [[ -f "$_gh_gha_bin" ]]; }

# Individual tool checks (testable wrappers)
_gh_check_shellcheck() { command_exists "shellcheck"; }
_gh_check_gitleaks() { command_exists "gitleaks"; }
_gh_check_actionlint() { command_exists "actionlint"; }

# =============================================================================
# Cell Formatting — all produce exactly _GH_CW visible cells
# =============================================================================

_GH_CW=20

# Item cell: check(1) sp(1) emoji(2) sp(1) label+pad = _GH_CW
# Uses %b for check arg so \033 color codes are interpreted by printf
_gh_cell() {
    local check="$1" emoji="$2" label="$3"
    local p=$((_GH_CW - 5 - ${#label}))
    ((p < 0)) && p=0
    printf "%b %s %s%*s" "$check" "$emoji" "$label" "$p" ""
}

# Bold header cell: emoji(2) sp(1) label+pad = _GH_CW
_gh_hdr() {
    local emoji="$1" label="$2"
    local p=$((_GH_CW - 3 - ${#label}))
    ((p < 0)) && p=0
    printf "%b%s %s%b%*s" "${_WM_COLOR_BOLD}" "$emoji" "$label" "${_WM_COLOR_RESET}" "$p" ""
}

# Dim category label: emoji(2) sp(1) label+pad = _GH_CW
_gh_lbl() {
    local emoji="$1" label="$2"
    local p=$((_GH_CW - 3 - ${#label}))
    ((p < 0)) && p=0
    printf "%b%s %s%*s%b" "${_WM_COLOR_DIM}" "$emoji" "$label" "$p" "" "${_WM_COLOR_RESET}"
}

# Blank cell (replaces $BL subshell) — prints _GH_CW spaces directly
_gh_blank() {
    printf "%${_GH_CW}s" ""
}

# Section divider
_gh_div() {
    printf "  %b── %s %s ─────────────────────────────────────────────────────%b\n" \
        "${_WM_COLOR_DIM}" "$1" "$2" "${_WM_COLOR_RESET}"
}

# =============================================================================
# Main Display
# =============================================================================

_welcome_show_git_hooks_status() {
    local hooks_dir="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/git/hooks"
    local validators_dir="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/validation/validators"
    local gha_path="${SHELL_CONFIG_DIR:-$HOME/.shell-config}/lib/bin/gha-scan"
    local R="${_WM_COLOR_RESET}"
    local B="${_WM_COLOR_BOLD}"
    local D="${_WM_COLOR_DIM}"
    local ok="${_WM_COLOR_GREEN}✓${R}"
    local fail="${_WM_COLOR_RED}✗${R}"

    # ── Pre-compute all checks ──────────────────────────────────────

    # Hook installed status
    local _hk_pc _hk_pm _hk_cm _hk_po _hk_pp _hk_mg _hk_pm2
    _gh_check_hook "pre-commit"         && _hk_pc="$ok" || _hk_pc="$fail"
    _gh_check_hook "prepare-commit-msg" && _hk_pm="$ok" || _hk_pm="$fail"
    _gh_check_hook "commit-msg"         && _hk_cm="$ok" || _hk_cm="$fail"
    _gh_check_hook "post-commit"        && _hk_po="$ok" || _hk_po="$fail"
    _gh_check_hook "pre-push"           && _hk_pp="$ok" || _hk_pp="$fail"
    _gh_check_hook "pre-merge-commit"   && _hk_mg="$ok" || _hk_mg="$fail"
    _gh_check_hook "post-merge"         && _hk_pm2="$ok" || _hk_pm2="$fail"

    # Linter tools
    local _sc _ox _ru _ya _sq _ha
    command_exists "shellcheck" && _sc="$ok" || _sc="$fail"
    command_exists "oxlint"    && _ox="$ok" || _ox="$fail"
    command_exists "ruff"      && _ru="$ok" || _ru="$fail"
    command_exists "yamllint"  && _ya="$ok" || _ya="$fail"
    command_exists "sqruff"    && _sq="$ok" || _sq="$fail"
    command_exists "hadolint"  && _ha="$ok" || _ha="$fail"

    # Formatter tools
    local _pr
    command_exists "prettier" && _pr="$ok" || _pr="$fail"

    # Security tools
    local _gl _og _al _zi _oc _pi _pu _ga
    command_exists "gitleaks"   && _gl="$ok" || _gl="$fail"
    command_exists "opengrep"   && _og="$ok" || _og="$fail"
    command_exists "actionlint" && _al="$ok" || _al="$fail"
    command_exists "zizmor"     && _zi="$ok" || _zi="$fail"
    command_exists "octoscan"   && _oc="$ok" || _oc="$fail"
    command_exists "pinact"     && _pi="$ok" || _pi="$fail"
    command_exists "poutine"    && _pu="$ok" || _pu="$fail"
    [[ -f "$_gh_gha_bin" ]]    && _ga="$ok" || _ga="$fail"

    # Test & type checker tools
    local _bn _ts _my
    command_exists "bun"  && _bn="$ok" || _bn="$fail"
    command_exists "tsc"  && _ts="$ok" || _ts="$fail"
    command_exists "mypy" && _my="$ok" || _my="$fail"

    # Validator script files
    local _vfl _vse _vvl _vin _vsy
    [[ -f "$_gh_validator_dir/core/file-validator.sh" ]]              && _vfl="$ok" || _vfl="$fail"
    [[ -f "$_gh_validator_dir/security/sensitive-files-validator.sh" ]] && _vse="$ok" || _vse="$fail"
    [[ -f "$_gh_shared_dir/validation-loop.sh" ]]                      && _vvl="$ok" || _vvl="$fail"
    [[ -f "$_gh_validator_dir/infra/infra-validator.sh" ]]             && _vin="$ok" || _vin="$fail"
    [[ -f "$_gh_validator_dir/core/syntax-validator.sh" ]]             && _vsy="$ok" || _vsy="$fail"

    # ── Display ─────────────────────────────────────────────────────
    # PERF: All formatting functions (_gh_hdr, _gh_cell, _gh_lbl, _gh_blank) are
    # called DIRECTLY instead of via $(...) command substitution. This eliminates
    # ~70 subshell spawns (~140-210ms saved on macOS). The functions already write
    # to stdout via printf, so no capture is needed.

    printf "\n${B}🪝 Git Hooks & Validators${R}\n"

    # ════════════════════════════════════════════════════════════════
    # Commit Pipeline (4 columns)
    # ════════════════════════════════════════════════════════════════
    _gh_div "📝" "Commit Pipeline"

    # Stage headers
    printf "  "; _gh_hdr "🔒" "pre-commit"; _gh_hdr "✏️ " "prepare-msg"; _gh_hdr "💬" "commit-msg"; _gh_hdr "📋" "post-commit"; printf "\n"

    # Hook installed
    printf "  "; _gh_cell "$_hk_pc" "🪝" "installed"; _gh_cell "$_hk_pm" "🪝" "installed"; _gh_cell "$_hk_cm" "🪝" "installed"; _gh_cell "$_hk_po" "🪝" "installed"; printf "\n"

    # Category labels
    printf "  "; _gh_lbl "🐚" "linters"; _gh_lbl "✏️ " "message"; _gh_lbl "💬" "validation"; _gh_lbl "🔔" "audit"; printf "\n"

    # Row: first items in each column
    printf "  "; _gh_cell "$_sc" "🐚" "shellcheck"; _gh_cell "$_hk_pm" "🏷 " "branch→pfx"; _gh_cell "$_hk_cm" "📏" "subject≤72"; _gh_cell "$_hk_po" "🔔" "dep-audit"; printf "\n"

    # Rows: col1 + col3 content (col2, col4 blank)
    printf "  "; _gh_cell "$_ox" "📜" "oxlint"; _gh_blank; _gh_cell "$_hk_cm" "📝" "non-empty"; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_ru" "🐍" "ruff"; _gh_blank; _gh_cell "$_hk_cm" "✂️ " "trail-ws"; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_ya" "📋" "yamllint"; _gh_blank; _gh_cell "$_hk_cm" "📐" "conventional"; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_sq" "🗃 " "sqruff"; _gh_blank; _gh_cell "$_hk_cm" "📄" "body-length"; _gh_blank; printf "\n"

    # Rows: col1 only
    printf "  "; _gh_cell "$_ha" "🐳" "hadolint"; _gh_blank; _gh_blank; _gh_blank; printf "\n"

    # Category: validators
    printf "  "; _gh_lbl "📐" "validators"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_vfl" "📐" "file-length"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_vse" "🔐" "sensitive"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_vvl" "📈" "commit-size"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_vfl" "📦" "large-files"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_vfl" "📦" "dep-changes"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_vsy" "🔗" "circular-dep"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_vin" "🏗 " "infra"; _gh_blank; _gh_blank; _gh_blank; printf "\n"

    # Category: formatters
    printf "  "; _gh_lbl "🎨" "formatters"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_pr" "🎨" "prettier"; _gh_blank; _gh_blank; _gh_blank; printf "\n"

    # Category: security
    printf "  "; _gh_lbl "🔒" "security"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_gl" "🕵 " "gitleaks"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_og" "🔎" "opengrep"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_al" "🎬" "actionlint"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_zi" "🛡 " "zizmor"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_oc" "🐙" "octoscan"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_pi" "📌" "pinact"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_pu" "🍟" "poutine"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_ga" "📡" "gha-scan"; _gh_blank; _gh_blank; _gh_blank; printf "\n"

    # Category: tests & types
    printf "  "; _gh_lbl "🧪" "tests & types"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_bn" "🧪" "bun test"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_ts" "🧬" "tsc"; _gh_blank; _gh_blank; _gh_blank; printf "\n"
    printf "  "; _gh_cell "$_my" "🐍" "mypy"; _gh_blank; _gh_blank; _gh_blank; printf "\n"

    # ════════════════════════════════════════════════════════════════
    # Connector — inline arrow flow
    # ════════════════════════════════════════════════════════════════
    printf "\n  %b⤷  commit done → next:%b  🚀 %bpush%b  %b/%b  🔀 %bmerge%b\n\n" \
        "$D" "$R" "$B" "$R" "$D" "$R" "$B" "$R"

    # ════════════════════════════════════════════════════════════════
    # Push & Merge Pipeline (3 columns)
    # ════════════════════════════════════════════════════════════════
    _gh_div "🚀" "Push & Merge Pipeline"

    # Stage headers
    printf "  "; _gh_hdr "🚀" "pre-push"; _gh_hdr "🔀" "pre-merge"; _gh_hdr "🔄" "post-merge"; printf "\n"

    # Hook installed
    printf "  "; _gh_cell "$_hk_pp" "🪝" "installed"; _gh_cell "$_hk_mg" "🪝" "installed"; _gh_cell "$_hk_pm2" "🪝" "installed"; printf "\n"

    # Category labels
    printf "  "; _gh_lbl "🧪" "tests"; _gh_lbl "🔀" "integrity"; _gh_lbl "📦" "auto-install"; printf "\n"

    # Row: first items
    printf "  "; _gh_cell "$_bn" "🧪" "bun test"; _gh_cell "$_hk_mg" "🔀" "conflict-scan"; _gh_cell "$_hk_pm2" "📦" "bun/npm/yarn"; printf "\n"

    # Row: col2 category + col3
    printf "  "; _gh_blank; _gh_lbl "🧪" "tests"; _gh_cell "$_hk_pm2" "📦" "pip/poetry"; printf "\n"

    printf "  "; _gh_blank; _gh_cell "$_bn" "🧪" "bun test"; _gh_cell "$_hk_pm2" "📦" "cargo fetch"; printf "\n"

    # Row: col3 only
    printf "  "; _gh_blank; _gh_blank; _gh_cell "$_hk_pm2" "📦" "go mod dl"; printf "\n"
    printf "  "; _gh_blank; _gh_blank; _gh_cell "$_hk_pm2" "📦" "bundle"; printf "\n"
    printf "  "; _gh_blank; _gh_blank; _gh_cell "$_hk_pm2" "📦" "composer"; printf "\n"

    # Summary with clickable links
    printf "\n  "
    printf '\e]8;;cursor://file%s\e\\' "$hooks_dir"
    printf "🪝 ${_WM_COLOR_CYAN}hooks/${R}"
    printf '\e]8;;\e\\'
    printf "  %b│%b  " "${_WM_COLOR_GRAY}" "${R}"
    printf '\e]8;;cursor://file%s\e\\' "$validators_dir"
    printf "🔍 ${_WM_COLOR_CYAN}validators/${R}"
    printf '\e]8;;\e\\'
    printf "  %b│%b  " "${_WM_COLOR_GRAY}" "${R}"
    printf '\e]8;;cursor://file%s\e\\' "$gha_path"
    printf "📡 ${_WM_COLOR_CYAN}gha-scan${R}"
    printf '\e]8;;\e\\\n'
}
