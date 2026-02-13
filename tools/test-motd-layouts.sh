#!/usr/bin/env bash
# =============================================================================
# test-motd-layouts.sh - V2-C with category dividers
# =============================================================================
# V2 flat + V2-C connector + category label rows within columns.
# Usage: bash tools/test-motd-layouts.sh
# =============================================================================
set -euo pipefail

export SHELL_CONFIG_DIR="${SHELL_CONFIG_DIR:-$HOME/.shell-config}"
source "$SHELL_CONFIG_DIR/lib/core/command-cache.sh"

R=$'\033[0m'  B=$'\033[1m'  D=$'\033[2m'
GR=$'\033[0;32m'  RD=$'\033[0;31m'  CN=$'\033[0;36m'

CW=20
BLANK=$(printf "%${CW}s" "")
_NL=$'\n'

_ok()   { printf "%s✓%s" "$GR" "$R"; }
_fail() { printf "%s✗%s" "$RD" "$R"; }
_chk()  { command -v "$1" >/dev/null 2>&1 && _ok || _fail; }
_fchk() { [[ -f "$1" ]] && _ok || _fail; }
_hchk() {
    local h="$HOME/.githooks/$1"
    [[ -L "$h" ]] && [[ "$(readlink "$h" 2>/dev/null)" == *"shell-config"* ]] && _ok || _fail
}
_vd="$SHELL_CONFIG_DIR/lib/validation/validators"
_sd="$SHELL_CONFIG_DIR/lib/git/shared"
_ga="$SHELL_CONFIG_DIR/lib/bin/gha-scan"

# Pre-compute checks
OK=$(_ok)
HC_PC=$(_hchk pre-commit) HC_PM=$(_hchk prepare-commit-msg)
HC_CM=$(_hchk commit-msg) HC_PO=$(_hchk post-commit)
HC_PP=$(_hchk pre-push)   HC_MG=$(_hchk pre-merge-commit)  HC_PM2=$(_hchk post-merge)
CK_SC=$(_chk shellcheck)  CK_OX=$(_chk oxlint)  CK_RU=$(_chk ruff)
CK_YA=$(_chk yamllint)    CK_SQ=$(_chk sqruff)   CK_HA=$(_chk hadolint)
CK_PR=$(_chk prettier)    CK_GL=$(_chk gitleaks)  CK_OG=$(_chk opengrep)
CK_AL=$(_chk actionlint)  CK_ZI=$(_chk zizmor)    CK_OC=$(_chk octoscan)
CK_PI=$(_chk pinact)      CK_PU=$(_chk poutine)   CK_BN=$(_chk bun)
CK_TS=$(_chk tsc)         CK_MY=$(_chk mypy)
FK_FL=$(_fchk "$_vd/core/file-validator.sh")
FK_SE=$(_fchk "$_vd/security/sensitive-files-validator.sh")
FK_VL=$(_fchk "$_sd/validation-loop.sh")
FK_IN=$(_fchk "$_vd/infra/infra-validator.sh")
FK_SY=$(_fchk "$_vd/core/syntax-validator.sh")
FK_GA=$(_fchk "$_ga")

# Cell helpers — all produce exactly CW visible cells
# Item: check(1) sp(1) emoji(2) sp(1) label+pad = CW
_c() { local p=$((CW-5-${#3})); ((p<0))&&p=0; printf "%s %s %s%*s" "$1" "$2" "$3" "$p" ""; }
# Header: B+emoji(2) sp(1) label+R+pad = CW
_h() { local p=$((CW-3-${#2})); ((p<0))&&p=0; printf "%s%s %s%s%*s" "$B" "$1" "$2" "$R" "$p" ""; }
# Label: D+emoji(2) sp(1) label+pad+R = CW  (dim category row)
_l() { local p=$((CW-3-${#2})); ((p<0))&&p=0; printf "%s%s %s%*s%s" "$D" "$1" "$2" "$p" "" "$R"; }
# Divider for top-level sections
_div() { printf "  %s── %s %s ─────────────────────────────────────────────────────%s\\n" "$D" "$1" "$2" "$R"; }

# Paste N columns side-by-side (variable height)
_paste() {
    local nc=$1; shift
    local -a A=() B2=() C=() D2=()
    ((nc>=1)) && readarray -t A  <<< "$1"
    ((nc>=2)) && readarray -t B2 <<< "$2"
    ((nc>=3)) && readarray -t C  <<< "${3:-}"
    ((nc>=4)) && readarray -t D2 <<< "${4:-}"
    local mx=${#A[@]}
    ((${#B2[@]}>mx)) && mx=${#B2[@]}; ((${#C[@]}>mx)) && mx=${#C[@]}; ((${#D2[@]}>mx)) && mx=${#D2[@]}
    for ((r=0;r<mx;r++)); do
        printf "  "
        ((nc>=1)) && printf "%s" "${A[$r]:-$BLANK}"
        ((nc>=2)) && printf "%s" "${B2[$r]:-$BLANK}"
        ((nc>=3)) && printf "%s" "${C[$r]:-$BLANK}"
        ((nc>=4)) && printf "%s" "${D2[$r]:-$BLANK}"
        printf "\\n"
    done
}

# ── Terminal section ──
_terminal() {
    printf "%s🖥️  Terminal%s\\n" "$B" "$R"
    _div "🔒" "Security"
    printf "  %s 🔐 %-12s%s 🔑 %-12s%s 🗑  %-12s%s 🔀 %-12s\\n" "$OK" "1pass" "$OK" "ssh" "$OK" "rm" "$OK" "git"
    _div "🔧" "Tools"
    printf "  %s 📁 %-12s%s 🔍 %-12s%s 🤖 %-12s%s 🐱 %-12s\\n" "$(_chk eza)" "eza" "$(_chk fzf)" "fzf" "$(_chk claude)" "claude" "$(_chk ccat)" "ccat"
    printf "  %s 🔮 %-12s%s ⏱  %-12s%s 📊 %-12s%s 🐚 %-12s\\n" "$(_chk is)" "inshell" "$(_chk hyperfine)" "hyperfine" "$OK" "ghls" "$OK" "zsh-safe"
    _div "🐚" "Zsh Plugins"
    printf "  %s 💡 %-12s%s 🎨 %-12s\\n\\n" "$OK" "suggest" "$OK" "syntax"
}

# ── Column builders with category labels ──

_col1() {
    local c=""
    c+="$(_h "🔒" "pre-commit")${_NL}"
    c+="$(_c "$HC_PC" "🪝" "installed")${_NL}"
    # linters
    c+="$(_l "🐚" "linters")${_NL}"
    c+="$(_c "$CK_SC" "🐚" "shellcheck")${_NL}"
    c+="$(_c "$CK_OX" "📜" "oxlint")${_NL}"
    c+="$(_c "$CK_RU" "🐍" "ruff")${_NL}"
    c+="$(_c "$CK_YA" "📋" "yamllint")${_NL}"
    c+="$(_c "$CK_SQ" "🗃 " "sqruff")${_NL}"
    c+="$(_c "$CK_HA" "🐳" "hadolint")${_NL}"
    # validators
    c+="$(_l "📐" "validators")${_NL}"
    c+="$(_c "$FK_FL" "📐" "file-length")${_NL}"
    c+="$(_c "$FK_SE" "🔐" "sensitive")${_NL}"
    c+="$(_c "$FK_VL" "📊" "commit-size")${_NL}"
    c+="$(_c "$FK_FL" "📦" "large-files")${_NL}"
    c+="$(_c "$FK_FL" "📦" "dep-changes")${_NL}"
    c+="$(_c "$FK_SY" "🔗" "circular-dep")${_NL}"
    c+="$(_c "$FK_IN" "🏗 " "infra")${_NL}"
    # formatters
    c+="$(_l "🎨" "formatters")${_NL}"
    c+="$(_c "$CK_PR" "🎨" "prettier")${_NL}"
    # security
    c+="$(_l "🔒" "security")${_NL}"
    c+="$(_c "$CK_GL" "🕵 " "gitleaks")${_NL}"
    c+="$(_c "$CK_OG" "🔎" "opengrep")${_NL}"
    c+="$(_c "$CK_AL" "🎬" "actionlint")${_NL}"
    c+="$(_c "$CK_ZI" "🛡 " "zizmor")${_NL}"
    c+="$(_c "$CK_OC" "🐙" "octoscan")${_NL}"
    c+="$(_c "$CK_PI" "📌" "pinact")${_NL}"
    c+="$(_c "$CK_PU" "🍟" "poutine")${_NL}"
    c+="$(_c "$FK_GA" "🛡 " "gha-scan")${_NL}"
    # tests & types
    c+="$(_l "🧪" "tests & types")${_NL}"
    c+="$(_c "$CK_BN" "🧪" "bun test")${_NL}"
    c+="$(_c "$CK_TS" "📋" "tsc")${_NL}"
    c+="$(_c "$CK_MY" "🐍" "mypy")"
    printf "%s" "$c"
}

_col2() {
    local c=""
    c+="$(_h "✏️ " "prepare-msg")${_NL}"
    c+="$(_c "$HC_PM" "🪝" "installed")${_NL}"
    c+="$(_l "✏️ " "message")${_NL}"
    c+="$(_c "$OK" "🏷 " "branch→pfx")"
    printf "%s" "$c"
}

_col3() {
    local c=""
    c+="$(_h "💬" "commit-msg")${_NL}"
    c+="$(_c "$HC_CM" "🪝" "installed")${_NL}"
    c+="$(_l "💬" "validation")${_NL}"
    c+="$(_c "$OK" "📏" "subject≤72")${_NL}"
    c+="$(_c "$OK" "📝" "non-empty")${_NL}"
    c+="$(_c "$OK" "✂️ " "trail-ws")${_NL}"
    c+="$(_c "$OK" "📐" "conventional")${_NL}"
    c+="$(_c "$OK" "📄" "body-length")"
    printf "%s" "$c"
}

_col4() {
    local c=""
    c+="$(_h "📋" "post-commit")${_NL}"
    c+="$(_c "$HC_PO" "🪝" "installed")${_NL}"
    c+="$(_l "📋" "audit")${_NL}"
    c+="$(_c "$OK" "📋" "dep-audit")"
    printf "%s" "$c"
}

_colP1() {
    local c=""
    c+="$(_h "🚀" "pre-push")${_NL}"
    c+="$(_c "$HC_PP" "🪝" "installed")${_NL}"
    c+="$(_l "🧪" "tests")${_NL}"
    c+="$(_c "$CK_BN" "🧪" "bun test")"
    printf "%s" "$c"
}

_colP2() {
    local c=""
    c+="$(_h "🔀" "pre-merge")${_NL}"
    c+="$(_c "$HC_MG" "🪝" "installed")${_NL}"
    c+="$(_l "🔀" "integrity")${_NL}"
    c+="$(_c "$OK" "🔀" "conflict-scan")${_NL}"
    c+="$(_l "🧪" "tests")${_NL}"
    c+="$(_c "$CK_BN" "🧪" "bun test")"
    printf "%s" "$c"
}

_colP3() {
    local c=""
    c+="$(_h "🔄" "post-merge")${_NL}"
    c+="$(_c "$HC_PM2" "🪝" "installed")${_NL}"
    c+="$(_l "📦" "auto-install")${_NL}"
    c+="$(_c "$OK" "📦" "bun/npm/yarn")${_NL}"
    c+="$(_c "$OK" "📦" "pip/poetry")${_NL}"
    c+="$(_c "$OK" "📦" "cargo fetch")${_NL}"
    c+="$(_c "$OK" "📦" "go mod dl")${_NL}"
    c+="$(_c "$OK" "📦" "bundle")${_NL}"
    c+="$(_c "$OK" "📦" "composer")"
    printf "%s" "$c"
}

# Connector: V2-C inline arrow flow
_conn() {
    printf "\\n  %s⤷  commit done → next:%s  🚀 %spush%s  %s/%s  🔀 %smerge%s\\n\\n" "$D" "$R" "$B" "$R" "$D" "$R" "$B" "$R"
}

# ── Output ──
_terminal
printf "%s🪝 Git Hooks & Validators%s\\n" "$B" "$R"
_div "📝" "Commit Pipeline"
_paste 4 "$(_col1)" "$(_col2)" "$(_col3)" "$(_col4)"
_conn
_div "🚀" "Push & Merge Pipeline"
_paste 3 "$(_colP1)" "$(_colP2)" "$(_colP3)"
echo
