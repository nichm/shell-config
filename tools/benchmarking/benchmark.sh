#!/usr/bin/env bash
# =============================================================================
# 🚀 SHELL-CONFIG BENCHMARKING TOOL
# =============================================================================
# Comprehensive performance benchmarking suite for shell-config using hyperfine
# 100% function coverage organized by file structure
#
# Usage:
#   ./benchmark.sh [MODE] [OPTIONS]
#
# Modes:
#   startup     Shell initialization & welcome message (default)
#   functions   Detailed function-level benchmarks
#   git         Git operations and wrapper overhead
#   validation  File validation & pre-commit checks
#   all         Run all benchmark suites
#   quick       Fast smoke test (minimal runs)
#
# Options:
#   -r, --runs N      Number of benchmark runs (default: 8)
#   -w, --warmup N    Warmup runs before benchmarking (default: 3)
#   -o, --output FILE Export CSV results to file
#   -q, --quiet       Minimal output
#   -v, --verbose     Show hyperfine details
#   -h, --help        Show this help
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SHELL_CONFIG_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CSV_FILE="${SCRIPT_DIR}/benchmark-results.csv"

# Defaults
RUNS=8
WARMUP=3
QUIET=false
VERBOSE=false
MODE="startup"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Thresholds (ms) - function-level
GREAT_THRESHOLD=5
MID_THRESHOLD=20
OK_THRESHOLD=50

# Thresholds (ms) - real-world operations
REAL_GREAT=50
REAL_MID=150
REAL_OK=500

# Counters
COUNTER_FILE=$(mktemp)
echo "0 0 0 0 0" > "$COUNTER_FILE"

cleanup() { rm -f "$COUNTER_FILE" /tmp/benchmark-test.txt 2>/dev/null; }
trap cleanup EXIT INT TERM

# =============================================================================
# Helper Functions
# =============================================================================

log_header() {
    [[ "$QUIET" == "true" ]] && return
    printf "\n%s═══════════════════════════════════════════════════════════════%s\n" "${BOLD}${BLUE}" "${NC}"
    printf "%s  %s%s\n" "${BOLD}${BLUE}" "$1" "${NC}"
    printf "%s═══════════════════════════════════════════════════════════════%s\n\n" "${BOLD}${BLUE}" "${NC}"
}

log_section() {
    [[ "$QUIET" == "true" ]] && return
    printf "\n%s── %s ──%s\n\n" "${BOLD}${CYAN}" "$1" "${NC}"
}

log_subsection() {
    [[ "$QUIET" == "true" ]] && return
    printf "\n  %s▸ %s%s\n" "${DIM}" "$1" "${NC}"
}

log_info() { [[ "$QUIET" == "true" ]] || echo "${BLUE}ℹ️  $1${NC}"; }
log_error() { echo "${RED}❌ $1${NC}" >&2; }

parse_mean_ms() {
    local json="$1"
    local mean
    mean=$(echo "$json" | grep -oE '"mean":[[:space:]]*[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?' | head -1 | sed 's/"mean":[[:space:]]*//')
    if [[ ! "$mean" =~ ^[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$ ]]; then
        echo "FAILED"
        return 1
    fi
    echo "$mean" | awk '{printf "%.2f", $1 * 1000}'
}

update_counters() {
    local field="$1"
    local total great mid ok slow
    read -r total great mid ok slow < "$COUNTER_FILE"
    total=$((total + 1))
    case "$field" in
        great) great=$((great + 1)) ;;
        mid) mid=$((mid + 1)) ;;
        ok) ok=$((ok + 1)) ;;
        slow) slow=$((slow + 1)) ;;
    esac
    echo "$total $great $mid $ok $slow" > "$COUNTER_FILE"
}

rate_perf() {
    local ms="$1" threshold_great="$2" threshold_mid="$3" threshold_ok="$4"
    local ms_int
    ms_int=$(printf "%.0f" "$ms" 2>/dev/null || echo "0")
    if (( ms_int < threshold_great )); then
        echo "GREAT"; update_counters great
    elif (( ms_int < threshold_mid )); then
        echo "MID"; update_counters mid
    elif (( ms_int < threshold_ok )); then
        echo "OK"; update_counters ok
    else
        echo "SLOW"; update_counters slow
    fi
}

run_bench() {
    local name="$1"
    local cmd="$2"
    local category="${3:-general}"
    local threshold_great="${4:-$GREAT_THRESHOLD}"
    local threshold_mid="${5:-$MID_THRESHOLD}"
    local threshold_ok="${6:-$OK_THRESHOLD}"

    printf "  %-55s " "$name"

    local result mean_ms rating
    if result=$(hyperfine --warmup "$WARMUP" --runs "$RUNS" --shell zsh --export-json /dev/stdout "$cmd" 2>/dev/null); then
        mean_ms=$(parse_mean_ms "$result")
        rating=$(rate_perf "$mean_ms" "$threshold_great" "$threshold_mid" "$threshold_ok")
        case "$rating" in
            GREAT) echo "${GREEN}${mean_ms}ms${NC} [${GREEN}$rating${NC}]" ;;
            MID)   echo "${YELLOW}${mean_ms}ms${NC} [${YELLOW}$rating${NC}]" ;;
            OK)    echo "${YELLOW}${mean_ms}ms${NC} [${YELLOW}$rating${NC}]" ;;
            SLOW)  echo "${RED}${mean_ms}ms${NC} [${RED}$rating${NC}]" ;;
        esac
        echo "$name,$mean_ms,$rating,$category" >> "$CSV_FILE"
    else
        echo "${RED}FAILED${NC}"
        echo "$name,FAILED,FAILED,$category" >> "$CSV_FILE"
        local total great mid ok slow
        read -r total great mid ok slow < "$COUNTER_FILE"
        echo "$((total + 1)) $great $mid $ok $slow" > "$COUNTER_FILE"
    fi
}

run_real() {
    run_bench "$1" "$2" "$3" "$REAL_GREAT" "$REAL_MID" "$REAL_OK"
}

init_csv() {
    echo "Function,Time_ms,Rating,Category" > "$CSV_FILE"
}

# =============================================================================
# STARTUP BENCHMARKS
# =============================================================================

benchmark_startup() {
    log_section "Shell Startup Times"
    run_real "zsh (no config)" "zsh --no-rcs -c 'exit'" "startup"
    run_real "zsh -i (full startup)" "zsh -i -c 'exit' 2>/dev/null" "startup"
    run_real "source init.sh only" "source $SHELL_CONFIG_DIR/init.sh 2>/dev/null" "startup"

    log_section "Welcome Message"
    local src="cd $SHELL_CONFIG_DIR && source lib/core/colors.sh && source lib/core/platform.sh && source lib/welcome/main.sh"
    run_real "welcome_message (full)" "$src && welcome_message >/dev/null 2>&1" "welcome"
    run_real "node version detection" "node --version 2>/dev/null || true" "welcome"
    run_real "python version detection" "python3 --version 2>/dev/null || true" "welcome"

    log_section "Feature Flag Impact"
    local all_disabled="export SHELL_CONFIG_WELCOME=false SHELL_CONFIG_COMMAND_SAFETY=false SHELL_CONFIG_GIT_WRAPPER=false SHELL_CONFIG_GHLS=false SHELL_CONFIG_EZA=false SHELL_CONFIG_RIPGREP=false SHELL_CONFIG_SECURITY=false SHELL_CONFIG_1PASSWORD=false SHELL_CONFIG_LOG_ROTATION=false"
    run_real "minimal_init (all disabled)" "zsh -c '$all_disabled; source $SHELL_CONFIG_DIR/init.sh 2>/dev/null'" "startup"

    log_section "Per-Feature Flag Isolation (each feature disabled individually)"
    local base="source $SHELL_CONFIG_DIR/init.sh 2>/dev/null"
    run_real "without WELCOME" "zsh -c 'export SHELL_CONFIG_WELCOME=false; $base'" "startup/flags"
    run_real "without COMMAND_SAFETY" "zsh -c 'export SHELL_CONFIG_COMMAND_SAFETY=false; $base'" "startup/flags"
    run_real "without GIT_WRAPPER" "zsh -c 'export SHELL_CONFIG_GIT_WRAPPER=false; $base'" "startup/flags"
    run_real "without GHLS" "zsh -c 'export SHELL_CONFIG_GHLS=false; $base'" "startup/flags"
    run_real "without EZA" "zsh -c 'export SHELL_CONFIG_EZA=false; $base'" "startup/flags"
    run_real "without RIPGREP" "zsh -c 'export SHELL_CONFIG_RIPGREP=false; $base'" "startup/flags"
    run_real "without SECURITY" "zsh -c 'export SHELL_CONFIG_SECURITY=false; $base'" "startup/flags"
    run_real "without 1PASSWORD" "zsh -c 'export SHELL_CONFIG_1PASSWORD=false; $base'" "startup/flags"
    run_real "without LOG_ROTATION" "zsh -c 'export SHELL_CONFIG_LOG_ROTATION=false; $base'" "startup/flags"

    log_section "Zsh Completion System"
    run_real "compinit (cold)" "zsh --no-rcs -c 'autoload -Uz compinit && compinit'" "startup/compinit"
    run_real "compinit (warm, cached zcompdump)" "zsh --no-rcs -c 'autoload -Uz compinit && compinit -C'" "startup/compinit"
}

# =============================================================================
# GIT BENCHMARKS
# =============================================================================

benchmark_git() {
    log_section "Git Native Commands"
    run_bench "git status --porcelain" "cd $SHELL_CONFIG_DIR && git status --porcelain" "git"
    run_bench "git branch --show-current" "cd $SHELL_CONFIG_DIR && git branch --show-current" "git"
    run_bench "git log -5 --oneline" "cd $SHELL_CONFIG_DIR && git log -5 --oneline" "git"
    run_bench "git diff --stat" "cd $SHELL_CONFIG_DIR && git diff --stat HEAD~1..HEAD" "git"

    log_section "Git Wrapper Overhead"
    local src="cd $SHELL_CONFIG_DIR && source lib/core/colors.sh && source lib/core/platform.sh && source lib/git/wrapper.sh"
    run_bench "git status (via wrapper)" "$src && git status --porcelain 2>/dev/null || true" "git-wrapped"
    run_bench "git branch (via wrapper)" "$src && git branch --show-current 2>/dev/null || true" "git-wrapped"

    log_section "Git Statusline (GHLS)"
    local ghls_src="cd $SHELL_CONFIG_DIR && source lib/core/colors.sh && source lib/integrations/ghls/statusline.sh"
    run_bench "git_statusline" "$ghls_src && git_statusline >/dev/null" "ghls"
}

# =============================================================================
# FUNCTION-LEVEL BENCHMARKS - ORGANIZED BY FILE STRUCTURE
# =============================================================================

benchmark_functions() {
    local D="$SHELL_CONFIG_DIR"
    local test_file="$D/lib/core/colors.sh"
    local workflow_file="$D/.github/workflows/ci.yml"

    # =========================================================================
    # lib/aliases/*.sh
    # =========================================================================
    log_section "lib/aliases/ - Alias Definitions"

    log_subsection "lib/aliases/init.sh"
    run_bench "source aliases/init.sh" "source $D/lib/aliases/init.sh 2>/dev/null || true" "aliases"

    log_subsection "lib/aliases/core.sh"
    run_bench "source aliases/core.sh" "source $D/lib/aliases/core.sh 2>/dev/null || true" "aliases"

    log_subsection "lib/aliases/git.sh"
    run_bench "source aliases/git.sh" "source $D/lib/aliases/git.sh 2>/dev/null || true" "aliases"

    log_subsection "lib/aliases/formatting.sh"
    run_bench "source aliases/formatting.sh" "source $D/lib/aliases/formatting.sh 2>/dev/null || true" "aliases"

    log_subsection "lib/aliases/gha.sh"
    run_bench "source aliases/gha.sh" "source $D/lib/aliases/gha.sh 2>/dev/null || true" "aliases"

    log_subsection "lib/aliases/1password.sh"
    run_bench "source aliases/1password.sh" "source $D/lib/aliases/1password.sh 2>/dev/null || true" "aliases"

    log_subsection "lib/aliases/ai-cli.sh"
    run_bench "source aliases/ai-cli.sh" "source $D/lib/aliases/ai-cli.sh 2>/dev/null || true" "aliases"

    log_subsection "lib/aliases/package-managers.sh"
    run_bench "source aliases/package-managers.sh" "source $D/lib/aliases/package-managers.sh 2>/dev/null || true" "aliases"

    # =========================================================================
    # lib/core/*.sh
    # =========================================================================
    log_section "lib/core/ - Core Functions"

    log_subsection "lib/core/colors.sh"
    local colors="source $D/lib/core/colors.sh"
    run_bench "log_info" "$colors && log_info 'test' >/dev/null" "core/colors"
    run_bench "log_success" "$colors && log_success 'test' >/dev/null" "core/colors"
    run_bench "log_error" "$colors && log_error 'test' >/dev/null 2>&1" "core/colors"
    run_bench "log_warning" "$colors && log_warning 'test' >/dev/null" "core/colors"
    run_bench "log_step" "$colors && log_step 'test' >/dev/null" "core/colors"

    log_subsection "lib/core/platform.sh"
    local platform="source $D/lib/core/platform.sh"
    run_bench "detect_os" "$platform && detect_os" "core/platform"
    run_bench "detect_architecture" "$platform && detect_architecture" "core/platform"
    run_bench "detect_linux_distro" "$platform && detect_linux_distro 2>/dev/null || true" "core/platform"
    run_bench "detect_package_manager" "$platform && detect_package_manager" "core/platform"
    run_bench "get_homebrew_prefix" "$platform && get_homebrew_prefix" "core/platform"
    run_bench "command_exists" "$platform && source $D/lib/core/command-cache.sh && command_exists bash" "core/platform"
    run_bench "is_macos" "$platform && is_macos" "core/platform"
    run_bench "is_linux" "$platform && is_linux" "core/platform"
    run_bench "is_wsl" "$platform && is_wsl" "core/platform"
    run_bench "is_bsd" "$platform && is_bsd" "core/platform"
    run_bench "has_brew" "$platform && has_brew" "core/platform"
    run_bench "has_apt" "$platform && has_apt" "core/platform"
    run_bench "platform_info" "$platform && platform_info >/dev/null" "core/platform"

    log_subsection "lib/core/config.sh"
    local config="source $D/lib/core/config.sh"
    run_bench "shell_config_load_config" "$config && shell_config_load_config 2>/dev/null || true" "core/config"
    run_bench "shell_config_validate_config" "$config && shell_config_validate_config 2>/dev/null || true" "core/config"
    run_bench "shell_config_show_config" "$config && shell_config_show_config >/dev/null 2>&1 || true" "core/config"

    log_subsection "lib/core/logging.sh"
    local logging="source $D/lib/core/logging.sh"
    run_bench "atomic_write" "$logging && echo 'test' | atomic_write /tmp/benchmark-test.txt 2>/dev/null || true" "core/logging"
    run_bench "atomic_append" "$logging && echo 'test' | atomic_append /tmp/benchmark-test.txt 2>/dev/null || true" "core/logging"
    run_bench "atomic_append_from_stdin" "$logging && echo 'test' | atomic_append_from_stdin /tmp/benchmark-test.txt 2>/dev/null || true" "core/logging"
    run_bench "_rotate_log" "$logging && _rotate_log /tmp/benchmark-test.txt 2>/dev/null || true" "core/logging"
    run_bench "_log_rotation_status" "$logging && _log_rotation_status >/dev/null 2>&1 || true" "core/logging"

    log_subsection "lib/core/doctor.sh"
    local doctor="source $D/lib/core/doctor.sh"
    run_bench "shell_config_doctor" "$doctor && shell_config_doctor >/dev/null 2>&1" "core/doctor"

    log_subsection "lib/core/paths.sh"
    run_bench "source core/paths.sh" "source $D/lib/core/paths.sh 2>/dev/null || true" "core/paths"

    log_subsection "lib/core/loaders/fnm.sh"
    run_bench "source loaders/fnm.sh" "source $D/lib/core/loaders/fnm.sh 2>/dev/null || true" "core/loaders"

    log_subsection "lib/core/loaders/ssh.sh"
    run_bench "source loaders/ssh.sh" "source $D/lib/core/loaders/ssh.sh 2>/dev/null || true" "core/loaders"

    log_subsection "lib/core/loaders/completions.sh"
    run_bench "source loaders/completions.sh" "source $D/lib/core/loaders/completions.sh 2>/dev/null || true" "core/loaders"

    # =========================================================================
    # lib/command-safety/**/*.sh
    # =========================================================================
    log_section "lib/command-safety/ - Command Safety Engine"

    log_subsection "lib/command-safety/engine.sh"
    local cs_engine="source $D/lib/command-safety/engine.sh"
    run_bench "command_safety_init" "$cs_engine && command_safety_init >/dev/null 2>&1 || true" "command-safety"

    log_subsection "lib/command-safety/engine/display.sh"
    local cs_display="source $D/lib/core/colors.sh && source $D/lib/command-safety/engine/display.sh"
    run_bench "_show_rule_message" "$cs_display && _show_rule_message 'test' 'info' '⏱️' 'msg' >/dev/null 2>&1 || true" "command-safety"
    run_bench "_show_alternatives" "$cs_display && _show_alternatives 2>/dev/null || true" "command-safety"

    log_subsection "lib/command-safety/engine/utils.sh"
    local cs_utils="source $D/lib/command-safety/engine/utils.sh"
    run_bench "_has_bypass_flag" "$cs_utils && _has_bypass_flag 'test --force'" "command-safety"
    run_bench "_has_danger_flags" "$cs_utils && _has_danger_flags 'test --force'" "command-safety"
    run_bench "_in_git_repo" "$cs_utils && _in_git_repo" "command-safety"

    log_subsection "lib/command-safety/engine/matcher.sh"
    local cs_matcher="source $D/lib/command-safety/engine/matcher.sh"
    run_bench "_check_command_rules" "$cs_matcher && _check_command_rules 'git push' 2>/dev/null || true" "command-safety"

    log_subsection "lib/command-safety/engine/registry.sh"
    local cs_registry="source $D/lib/command-safety/engine/registry.sh"
    run_bench "command_safety_register_rule" "$cs_registry && command_safety_register_rule test 2>/dev/null || true" "command-safety"

    log_subsection "lib/command-safety/engine/wrapper.sh"
    local cs_wrapper="source $D/lib/command-safety/engine/wrapper.sh"
    run_bench "_get_all_protected_commands" "$cs_wrapper && _get_all_protected_commands 2>/dev/null || true" "command-safety"

    log_subsection "lib/command-safety/rules/*.sh (loading)"
    run_bench "source rules/dangerous-commands.sh" "source $D/lib/command-safety/rules/dangerous-commands.sh 2>/dev/null || true" "command-safety"
    run_bench "source rules/git.sh" "source $D/lib/command-safety/rules/git.sh 2>/dev/null || true" "command-safety"
    run_bench "source rules/package-managers.sh" "source $D/lib/command-safety/rules/package-managers.sh 2>/dev/null || true" "command-safety"
    run_bench "source rules/docker.sh" "source $D/lib/command-safety/rules/docker.sh 2>/dev/null || true" "command-safety"
    run_bench "source rules/supabase.sh" "source $D/lib/command-safety/rules/supabase.sh 2>/dev/null || true" "command-safety"

    # =========================================================================
    # lib/git/**/*.sh
    # =========================================================================
    log_section "lib/git/ - Git Integration"

    log_subsection "lib/git/wrapper.sh"
    local git_wrapper="source $D/lib/git/wrapper.sh"
    run_bench "source git/wrapper.sh" "$git_wrapper 2>/dev/null || true" "git/wrapper"

    log_subsection "lib/git/shared/git-utils.sh"
    local git_utils="source $D/lib/git/shared/git-utils.sh"
    run_bench "is_valid_conventional_type" "$git_utils && is_valid_conventional_type 'feat'" "git/shared"
    run_bench "get_conventional_types_list" "$git_utils && get_conventional_types_list" "git/shared"
    run_bench "detect_nodejs_package_manager" "$git_utils && detect_nodejs_package_manager 2>/dev/null || true" "git/shared"
    run_bench "command_exists" "$git_utils && command_exists bash" "git/shared"
    run_bench "has_blank_line_after_subject" "$git_utils && echo 'test' | has_blank_line_after_subject 2>/dev/null || true" "git/shared"

    log_subsection "lib/git/shared/file-scanner.sh"
    local file_scanner="source $D/lib/git/shared/file-scanner.sh"
    run_bench "is_supported_file" "$file_scanner && is_supported_file '$test_file'" "git/shared"
    run_bench "filter_supported_files" "$file_scanner && echo '$test_file' | filter_supported_files" "git/shared"

    log_subsection "lib/git/shared/reporters.sh"
    local git_reporters="source $D/lib/core/colors.sh && source $D/lib/git/shared/reporters.sh"
    run_bench "report_hook_start" "$git_reporters && report_hook_start 'test' >/dev/null" "git/shared"
    run_bench "report_hook_success" "$git_reporters && report_hook_success 'test' >/dev/null" "git/shared"
    run_bench "report_info" "$git_reporters && report_info 'test' >/dev/null" "git/shared"
    run_bench "hook_fail" "$git_reporters && hook_fail 'test' 2>/dev/null || true" "git/shared"

    log_subsection "lib/git/shared/validation-loop.sh"
    local val_loop="cd $D && source lib/core/colors.sh && source lib/validation/shared/file-operations.sh && source lib/git/shared/validation-loop.sh"
    run_bench "_portable_timeout" "$val_loop && _portable_timeout 1 true" "git/shared"
    run_bench "run_validation_on_staged" "$val_loop && run_validation_on_staged true 2>/dev/null || true" "git/shared"

    log_subsection "lib/git/shared/secrets-check.sh"
    local secrets_check="source $D/lib/git/shared/secrets-check.sh"
    run_bench "_check_gitleaks" "$secrets_check && _check_gitleaks 2>/dev/null || true" "git/shared"
    run_bench "_needs_secrets_check" "$secrets_check && _needs_secrets_check 2>/dev/null || true" "git/shared"

    log_subsection "lib/git/stages/commit/pre-commit.sh"
    run_bench "source pre-commit.sh" "source $D/lib/git/stages/commit/pre-commit.sh 2>/dev/null || true" "git/stages"

    log_subsection "lib/git/stages/commit/pre-commit-checks.sh"
    local precommit_checks="cd $D && source lib/core/colors.sh && source lib/validation/shared/file-operations.sh && source lib/validation/shared/reporters.sh && source lib/validation/shared/config.sh && source lib/git/stages/commit/pre-commit-checks.sh"
    run_bench "run_file_length_check" "$precommit_checks && run_file_length_check 2>/dev/null || true" "git/stages"
    run_bench "run_sensitive_files_check" "$precommit_checks && run_sensitive_files_check 2>/dev/null || true" "git/stages"
    run_bench "run_syntax_validation" "$precommit_checks && run_syntax_validation 2>/dev/null || true" "git/stages"

    log_subsection "lib/git/stages/commit/commit-msg.sh"
    local commit_msg="source $D/lib/git/stages/commit/commit-msg.sh"
    run_bench "validate_commit_message" "$commit_msg && validate_commit_message 'test: message' 2>/dev/null || true" "git/stages"

    log_subsection "lib/git/stages/push/pre-push.sh"
    run_bench "source pre-push.sh" "source $D/lib/git/stages/push/pre-push.sh 2>/dev/null || true" "git/stages"

    log_subsection "lib/git/hooks/check-file-length.sh"
    local hook_file_length="cd $D && source lib/core/colors.sh && source lib/validation/shared/file-operations.sh && source lib/git/hooks/check-file-length.sh"
    run_bench "check_file_length_main" "$hook_file_length && check_file_length_main 2>/dev/null || true" "git/hooks"

    log_subsection "lib/git/hooks/check-sensitive-filenames.sh"
    local hook_sensitive="cd $D && source lib/core/colors.sh && source lib/validation/shared/file-operations.sh && source lib/git/hooks/check-sensitive-filenames.sh"
    run_bench "check_sensitive_filenames_main" "$hook_sensitive && check_sensitive_filenames_main 2>/dev/null || true" "git/hooks"

    # =========================================================================
    # lib/integrations/**/*.sh
    # =========================================================================
    log_section "lib/integrations/ - Tool Integrations"

    log_subsection "lib/integrations/ripgrep.sh"
    local rg="source $D/lib/integrations/ripgrep.sh"
    run_bench "source ripgrep.sh" "$rg 2>/dev/null || true" "integrations/ripgrep"
    run_bench "rgfunc definition check" "$rg && type rgfunc >/dev/null 2>&1 || true" "integrations/ripgrep"
    run_bench "rgcode definition check" "$rg && type rgcode >/dev/null 2>&1 || true" "integrations/ripgrep"
    run_bench "rgtest definition check" "$rg && type rgtest >/dev/null 2>&1 || true" "integrations/ripgrep"

    log_subsection "lib/integrations/eza.sh"
    run_bench "source eza.sh" "source $D/lib/integrations/eza.sh 2>/dev/null || true" "integrations/eza"

    log_subsection "lib/integrations/ghls/statusline.sh"
    local ghls_statusline="cd $D && source lib/core/colors.sh && source lib/integrations/ghls/statusline.sh"
    run_bench "git_statusline" "$ghls_statusline && git_statusline >/dev/null" "integrations/ghls"
    run_bench "_show_statusline_if_git" "$ghls_statusline && _show_statusline_if_git >/dev/null 2>&1 || true" "integrations/ghls"

    log_subsection "lib/integrations/ghls/status.sh"
    local ghls_status="cd $D && source lib/core/colors.sh && source lib/integrations/ghls/status.sh"
    run_bench "get_folder_status_enhanced" "$ghls_status && get_folder_status_enhanced . >/dev/null 2>&1 || true" "integrations/ghls"

    log_subsection "lib/integrations/ghls/auto.sh"
    run_bench "source ghls/auto.sh" "source $D/lib/integrations/ghls/auto.sh 2>/dev/null || true" "integrations/ghls"

    log_subsection "lib/integrations/1password/secrets.sh"
    local op_secrets="source $D/lib/integrations/1password/secrets.sh"
    run_bench "_op_check_auth" "$op_secrets && _op_check_auth 2>/dev/null || true" "integrations/1password"
    run_bench "_op_is_ready" "$op_secrets && _op_is_ready 2>/dev/null || true" "integrations/1password"
    run_bench "_op_load_secrets" "$op_secrets && _op_load_secrets 2>/dev/null || true" "integrations/1password"

    log_subsection "lib/integrations/1password/diagnose.sh"
    run_bench "source 1password/diagnose.sh" "source $D/lib/integrations/1password/diagnose.sh 2>/dev/null || true" "integrations/1password"

    # =========================================================================
    # lib/security/**/*.sh
    # =========================================================================
    log_section "lib/security/ - Security Features"

    log_subsection "lib/security/init.sh"
    run_bench "source security/init.sh" "source $D/lib/security/init.sh 2>/dev/null || true" "security"

    log_subsection "lib/security/audit.sh"
    run_bench "source security/audit.sh" "source $D/lib/security/audit.sh 2>/dev/null || true" "security"

    log_subsection "lib/security/hardening.sh"
    run_bench "source security/hardening.sh" "source $D/lib/security/hardening.sh 2>/dev/null || true" "security"

    log_subsection "lib/security/rm/wrapper.sh"
    local rm_wrapper="source $D/lib/security/rm/wrapper.sh"
    run_bench "source rm/wrapper.sh" "$rm_wrapper 2>/dev/null || true" "security/rm"

    log_subsection "lib/security/rm/audit.sh"
    run_bench "source rm/audit.sh" "source $D/lib/security/rm/audit.sh 2>/dev/null || true" "security/rm"

    log_subsection "lib/security/filesystem/protect.sh"
    run_bench "source filesystem/protect.sh" "source $D/lib/security/filesystem/protect.sh 2>/dev/null || true" "security/filesystem"

    log_subsection "lib/security/trash/trash.sh"
    run_bench "source trash/trash.sh" "source $D/lib/security/trash/trash.sh 2>/dev/null || true" "security/trash"

    # =========================================================================
    # lib/terminal/**/*.sh
    # =========================================================================
    log_section "lib/terminal/ - Terminal Setup"

    log_subsection "lib/terminal/autocomplete.sh"
    local autocomplete="source $D/lib/terminal/autocomplete.sh"
    run_bench "source autocomplete.sh" "$autocomplete 2>/dev/null || true" "terminal"
    run_bench "_init_autocomplete" "$autocomplete && _init_autocomplete 2>/dev/null || true" "terminal"

    log_subsection "lib/terminal/install.sh"
    run_bench "source terminal/install.sh" "source $D/lib/terminal/install.sh 2>/dev/null || true" "terminal"

    log_subsection "lib/terminal/installation/kitty.sh"
    run_bench "source installation/kitty.sh" "source $D/lib/terminal/installation/kitty.sh 2>/dev/null || true" "terminal/installation"

    log_subsection "lib/terminal/installation/ghostty.sh"
    run_bench "source installation/ghostty.sh" "source $D/lib/terminal/installation/ghostty.sh 2>/dev/null || true" "terminal/installation"

    log_subsection "lib/terminal/installation/iterm2.sh"
    run_bench "source installation/iterm2.sh" "source $D/lib/terminal/installation/iterm2.sh 2>/dev/null || true" "terminal/installation"

    # =========================================================================
    # lib/validation/**/*.sh
    # =========================================================================
    log_section "lib/validation/ - Validation Framework"

    log_subsection "lib/validation/shared/file-operations.sh"
    local file_ops="source $D/lib/validation/shared/file-operations.sh"
    run_bench "count_file_lines" "$file_ops && count_file_lines '$test_file'" "validation/shared"
    run_bench "get_file_extension" "$file_ops && get_file_extension '$test_file'" "validation/shared"
    run_bench "get_filename" "$file_ops && get_filename '$test_file'" "validation/shared"
    run_bench "is_shell_script" "$file_ops && is_shell_script '$test_file'" "validation/shared"
    run_bench "is_yaml_file" "$file_ops && is_yaml_file '$test_file'" "validation/shared"
    run_bench "is_json_file" "$file_ops && is_json_file '$test_file'" "validation/shared"
    run_bench "is_github_workflow" "$file_ops && is_github_workflow '$workflow_file'" "validation/shared"
    run_bench "get_file_hash" "$file_ops && get_file_hash '$test_file'" "validation/shared"
    run_bench "is_binary_file" "$file_ops && is_binary_file '$test_file'" "validation/shared"
    run_bench "get_staged_files" "$file_ops && get_staged_files 2>/dev/null || true" "validation/shared"
    run_bench "get_modified_files" "$file_ops && get_modified_files 2>/dev/null || true" "validation/shared"
    run_bench "find_repo_root" "$file_ops && find_repo_root" "validation/shared"
    run_bench "is_text_file" "$file_ops && is_text_file '$test_file'" "validation/shared"
    run_bench "file_exists_and_readable" "$file_ops && file_exists_and_readable '$test_file'" "validation/shared"
    run_bench "should_validate_file" "$file_ops && should_validate_file '$test_file'" "validation/shared"
    run_bench "get_file_size_bytes" "$file_ops && get_file_size_bytes '$test_file'" "validation/shared"
    run_bench "is_file_too_large" "$file_ops && is_file_too_large '$test_file'" "validation/shared"

    log_subsection "lib/validation/shared/config.sh"
    local val_config="source $D/lib/validation/shared/config.sh"
    run_bench "get_language_limit" "$val_config && get_language_limit 'sh'" "validation/shared"
    run_bench "get_thresholds" "$val_config && get_thresholds" "validation/shared"

    log_subsection "lib/validation/shared/reporters.sh"
    local reporters="source $D/lib/core/colors.sh && source $D/lib/validation/shared/reporters.sh"
    run_bench "validation_log_info" "$reporters && validation_log_info 'test' >/dev/null" "validation/shared"
    run_bench "validation_log_success" "$reporters && validation_log_success 'test' >/dev/null" "validation/shared"
    run_bench "validation_log_warning" "$reporters && validation_log_warning 'test' >/dev/null" "validation/shared"
    run_bench "validation_log_error" "$reporters && validation_log_error 'test' >/dev/null 2>&1" "validation/shared"
    run_bench "validation_report_summary" "$reporters && validation_report_summary 0 0 0 >/dev/null 2>&1 || true" "validation/shared"

    log_subsection "lib/validation/shared/patterns.sh"
    local patterns="source $D/lib/validation/shared/patterns.sh"
    run_bench "_build_all_sensitive_patterns" "$patterns && _build_all_sensitive_patterns 2>/dev/null || true" "validation/shared"

    log_subsection "lib/validation/core.sh"
    local val_core="cd $D && source lib/core/colors.sh && source lib/validation/shared/file-operations.sh && source lib/validation/shared/reporters.sh && source lib/validation/shared/config.sh && source lib/validation/core.sh"
    run_bench "validation_reset_all" "$val_core && validation_reset_all" "validation/core"
    run_bench "validate_file" "$val_core && validate_file '$test_file' 2>/dev/null || true" "validation/core"
    run_bench "validation_has_issues" "$val_core && validation_has_issues" "validation/core"
    run_bench "check_file_length" "$val_core && check_file_length '$test_file' 2>/dev/null || true" "validation/core"
    run_bench "check_sensitive_filenames" "$val_core && check_sensitive_filenames '$test_file' 2>/dev/null || true" "validation/core"

    log_subsection "lib/validation/api.sh"
    local api="cd $D && source lib/core/colors.sh && source lib/validation/shared/file-operations.sh && source lib/validation/shared/reporters.sh && source lib/validation/shared/config.sh && source lib/validation/api.sh"
    run_bench "validator_api_run" "$api && validator_api_run --help >/dev/null 2>&1 || true" "validation/api"
    run_bench "validator_api_version" "$api && validator_api_version >/dev/null 2>&1 || true" "validation/api"
    run_bench "validator_api_status" "$api && validator_api_status >/dev/null 2>&1 || true" "validation/api"

    log_subsection "lib/validation/validators/core/file-validator.sh"
    local file_val="cd $D && source lib/core/colors.sh && source lib/validation/shared/file-operations.sh && source lib/validation/shared/reporters.sh && source lib/validation/shared/config.sh && source lib/validation/validators/core/file-validator.sh"
    run_bench "file_validator_reset" "$file_val && file_validator_reset" "validation/validators"
    run_bench "validate_file_length" "$file_val && validate_file_length '$test_file'" "validation/validators"
    run_bench "validate_files_length" "$file_val && validate_files_length '$test_file' 2>/dev/null || true" "validation/validators"
    run_bench "file_validator_has_violations" "$file_val && file_validator_has_violations" "validation/validators"
    run_bench "file_validator_warning_count" "$file_val && file_validator_warning_count" "validation/validators"
    run_bench "file_validator_extreme_count" "$file_val && file_validator_extreme_count" "validation/validators"

    log_subsection "lib/validation/validators/core/syntax-validator.sh"
    local syntax_val="cd $D && source lib/core/colors.sh && source lib/validation/shared/file-operations.sh && source lib/validation/shared/reporters.sh && source lib/validation/shared/config.sh && source lib/validation/validators/core/syntax-validator.sh"
    run_bench "syntax_validator_reset" "$syntax_val && syntax_validator_reset" "validation/validators"
    run_bench "validate_syntax" "$syntax_val && validate_syntax '$test_file'" "validation/validators"
    run_bench "validate_files_syntax" "$syntax_val && validate_files_syntax '$test_file' 2>/dev/null || true" "validation/validators"
    run_bench "syntax_validator_has_errors" "$syntax_val && syntax_validator_has_errors" "validation/validators"
    run_bench "syntax_validator_error_count" "$syntax_val && syntax_validator_error_count" "validation/validators"

    log_subsection "lib/validation/validators/security/security-validator.sh"
    local sec_val="cd $D && source lib/core/colors.sh && source lib/validation/shared/file-operations.sh && source lib/validation/shared/reporters.sh && source lib/validation/shared/config.sh && source lib/validation/shared/patterns.sh && source lib/validation/validators/security/security-validator.sh"
    run_bench "security_validator_reset" "$sec_val && security_validator_reset" "validation/validators"
    run_bench "validate_sensitive_filename" "$sec_val && validate_sensitive_filename '$test_file'" "validation/validators"
    run_bench "validate_sensitive_filenames" "$sec_val && validate_sensitive_filenames '$test_file' 2>/dev/null || true" "validation/validators"
    run_bench "security_validator_has_violations" "$sec_val && security_validator_has_violations" "validation/validators"
    run_bench "is_sensitive_filename" "$sec_val && is_sensitive_filename '$test_file'" "validation/validators"

    log_subsection "lib/validation/validators/infra/workflow-validator.sh"
    local wf_val="cd $D && source lib/core/colors.sh && source lib/validation/shared/file-operations.sh && source lib/validation/shared/reporters.sh && source lib/validation/validators/infra/workflow-validator.sh"
    run_bench "workflow_validator_reset" "$wf_val && workflow_validator_reset" "validation/validators"
    run_bench "validate_workflow" "$wf_val && validate_workflow '$workflow_file' 2>/dev/null || true" "validation/validators"
    run_bench "workflow_validator_has_errors" "$wf_val && workflow_validator_has_errors" "validation/validators"

    log_subsection "lib/validation/validators/infra/infra-validator.sh"
    local infra_val="cd $D && source lib/core/colors.sh && source lib/validation/shared/file-operations.sh && source lib/validation/shared/reporters.sh && source lib/validation/validators/infra/infra-validator.sh"
    run_bench "infra_validator_reset" "$infra_val && infra_validator_reset" "validation/validators"
    run_bench "infra_validator_has_errors" "$infra_val && infra_validator_has_errors" "validation/validators"

    log_subsection "lib/validation/validators/gha/*.sh"
    run_bench "source actionlint-validator.sh" "source $D/lib/validation/validators/gha/actionlint-validator.sh 2>/dev/null || true" "validation/gha"
    run_bench "source zizmor-validator.sh" "source $D/lib/validation/validators/gha/zizmor-validator.sh 2>/dev/null || true" "validation/gha"
    run_bench "source poutine-validator.sh" "source $D/lib/validation/validators/gha/poutine-validator.sh 2>/dev/null || true" "validation/gha"
    run_bench "source octoscan-validator.sh" "source $D/lib/validation/validators/gha/octoscan-validator.sh 2>/dev/null || true" "validation/gha"
    run_bench "source pinact-validator.sh" "source $D/lib/validation/validators/gha/pinact-validator.sh 2>/dev/null || true" "validation/gha"

    # =========================================================================
    # lib/welcome/*.sh
    # =========================================================================
    log_section "lib/welcome/ - Welcome System"

    log_subsection "lib/welcome/main.sh"
    local welcome="cd $D && source lib/core/colors.sh && source lib/core/platform.sh && source lib/welcome/main.sh"
    run_bench "_welcome_terminal_supports_links" "$welcome && _welcome_terminal_supports_links || true" "welcome"
    run_bench "_welcome_get_datetime" "$welcome && _welcome_get_datetime || true" "welcome"
    run_bench "_welcome_print_link" "$welcome && _welcome_print_link '/path' 'text' || true" "welcome"
    run_bench "welcome_message" "$welcome && welcome_message >/dev/null 2>&1 || true" "welcome"

    log_subsection "lib/welcome/terminal-status.sh"
    local ts="cd $D && source lib/core/colors.sh && source lib/core/platform.sh && source lib/welcome/terminal-status.sh"
    run_bench "_ts_check_1password" "$ts && _ts_check_1password || true" "welcome/terminal-status"
    run_bench "_ts_check_ssh" "$ts && _ts_check_ssh || true" "welcome/terminal-status"
    run_bench "_ts_check_safe_rm" "$ts && _ts_check_safe_rm || true" "welcome/terminal-status"
    run_bench "_ts_check_git_wrapper" "$ts && _ts_check_git_wrapper || true" "welcome/terminal-status"
    run_bench "_ts_check_zsh_hardening" "$ts && _ts_check_zsh_hardening || true" "welcome/terminal-status"
    run_bench "_ts_check_ghls" "$ts && _ts_check_ghls || true" "welcome/terminal-status"
    run_bench "_ts_check_eza" "$ts && _ts_check_eza || true" "welcome/terminal-status"
    run_bench "_ts_check_fzf" "$ts && _ts_check_fzf || true" "welcome/terminal-status"
    run_bench "_ts_check_hyperfine" "$ts && _ts_check_hyperfine || true" "welcome/terminal-status"
    run_bench "_ts_check_autosuggestions" "$ts && _ts_check_autosuggestions || true" "welcome/terminal-status"
    run_bench "_ts_check_syntax_highlighting" "$ts && _ts_check_syntax_highlighting || true" "welcome/terminal-status"
    run_bench "_ts_count_aliases" "$ts && _ts_count_aliases || true" "welcome/terminal-status"
    run_bench "_ts_check_claude" "$ts && _ts_check_claude || true" "welcome/terminal-status"
    run_bench "_ts_check_ccat" "$ts && _ts_check_ccat || true" "welcome/terminal-status"
    run_bench "_ts_check_inshellisense" "$ts && _ts_check_inshellisense || true" "welcome/terminal-status"
    run_bench "_ts_icon (valid func)" "$ts && _ts_icon _ts_check_eza >/dev/null || true" "welcome/terminal-status"
    run_bench "_ts_div" "$ts && _ts_div '🔧' 'Tools' >/dev/null || true" "welcome/terminal-status"
    run_bench "_ts_get_safety_counts" "$ts && _ts_get_safety_counts || true" "welcome/terminal-status"
    run_bench "_ts_export_verification" "$ts && _ts_export_verification || true" "welcome/terminal-status"
    run_bench "_welcome_show_terminal_status" "$ts && _welcome_show_terminal_status >/dev/null 2>&1 || true" "welcome/terminal-status"

    log_subsection "lib/welcome/shortcuts.sh"
    local shortcuts="cd $D && source lib/core/colors.sh && source lib/core/platform.sh && source lib/welcome/shortcuts.sh"
    run_bench "_welcome_show_shortcuts" "$shortcuts && _welcome_show_shortcuts >/dev/null 2>&1 || true" "welcome"

    log_subsection "lib/welcome/main.sh (features loaded)"
    local features="cd $D && source lib/core/colors.sh && source lib/core/platform.sh && source lib/welcome/main.sh"
    run_bench "_welcome_show_features_loaded" "$features && _welcome_show_features_loaded >/dev/null 2>&1 || true" "welcome"

    log_subsection "lib/welcome/git-hooks-status.sh"
    local gh_status="cd $D && source lib/core/colors.sh && source lib/core/platform.sh && source lib/welcome/git-hooks-status.sh"
    run_bench "_welcome_show_git_hooks_status" "$gh_status && _welcome_show_git_hooks_status >/dev/null 2>&1 || true" "welcome"
    run_bench "_gh_check_hook (pre-commit)" "$gh_status && _gh_check_hook pre-commit || true" "welcome/git-hooks"
    run_bench "_gh_check_hook (pre-push)" "$gh_status && _gh_check_hook pre-push || true" "welcome/git-hooks"
    run_bench "_gh_check_hook (commit-msg)" "$gh_status && _gh_check_hook commit-msg || true" "welcome/git-hooks"
    run_bench "_gh_check_hook (post-commit)" "$gh_status && _gh_check_hook post-commit || true" "welcome/git-hooks"
    run_bench "_gh_check_hook (pre-merge-commit)" "$gh_status && _gh_check_hook pre-merge-commit || true" "welcome/git-hooks"
    run_bench "_gh_check_hook (post-merge)" "$gh_status && _gh_check_hook post-merge || true" "welcome/git-hooks"
    run_bench "_gh_check_hook (prepare-commit-msg)" "$gh_status && _gh_check_hook prepare-commit-msg || true" "welcome/git-hooks"

    log_subsection "lib/welcome/autocomplete-guide.sh"
    local ac_guide="cd $D && source lib/core/colors.sh && source lib/welcome/autocomplete-guide.sh"
    run_bench "_welcome_show_autocomplete_guide" "$ac_guide && _welcome_show_autocomplete_guide >/dev/null 2>&1 || true" "welcome"

    log_subsection "lib/welcome/shell-startup-time.sh"
    local startup_time="cd $D && source lib/core/colors.sh && source lib/welcome/shell-startup-time.sh"
    run_bench "_welcome_show_shell_startup_time" "$startup_time && _welcome_show_shell_startup_time >/dev/null 2>&1 || true" "welcome"

    # =========================================================================
    # Performance Micro-benchmarks
    # =========================================================================
    log_section "Performance Micro-benchmarks (100x iterations)"
    run_bench "command -v (100x)" "for i in {1..100}; do command -v bash >/dev/null; done" "performance"
    run_bench "type (100x)" "for i in {1..100}; do type bash >/dev/null; done" "performance"
    run_bench "((\$+commands[])) (100x)" "for i in {1..100}; do (( \$+commands[bash] )); done" "performance"

    log_section "Command Cache Benchmarks"
    local cache_src="source $D/lib/core/command-cache.sh"
    run_bench "command_exists (cache miss)" "$cache_src && command_cache_clear && command_exists bash" "performance/cache"
    run_bench "command_exists (cache hit)" "$cache_src && command_exists bash && command_exists bash" "performance/cache"
    run_bench "command_exists (100x cached)" "$cache_src && command_exists bash; for i in {1..100}; do command_exists bash; done" "performance/cache"

    log_section "Init Chain Module Source Cost"
    run_bench "source core/paths.sh" "source $D/lib/core/paths.sh 2>/dev/null || true" "init-chain"
    run_bench "source core/config.sh" "source $D/lib/core/config.sh 2>/dev/null || true" "init-chain"
    run_bench "source core/platform.sh" "source $D/lib/core/platform.sh 2>/dev/null || true" "init-chain"
    run_bench "source core/logging.sh" "source $D/lib/core/logging.sh 2>/dev/null || true" "init-chain"
    run_bench "source core/command-cache.sh" "source $D/lib/core/command-cache.sh 2>/dev/null || true" "init-chain"
    run_bench "source core/ensure-audit-symlink" "source $D/lib/core/ensure-audit-symlink.sh 2>/dev/null || true" "init-chain"
    run_bench "source core/traps.sh" "source $D/lib/core/traps.sh 2>/dev/null || true" "init-chain"
    run_bench "source aliases/init.sh" "source $D/lib/aliases/init.sh 2>/dev/null || true" "init-chain"
    run_bench "source command-safety/engine.sh" "source $D/lib/command-safety/engine.sh 2>/dev/null || true" "init-chain"
    run_bench "source git/wrapper.sh" "source $D/lib/git/wrapper.sh 2>/dev/null || true" "init-chain"
    run_bench "source integrations/eza.sh" "source $D/lib/integrations/eza.sh 2>/dev/null || true" "init-chain"
    run_bench "source integrations/ripgrep.sh" "source $D/lib/integrations/ripgrep.sh 2>/dev/null || true" "init-chain"
    run_bench "source integrations/fzf.sh" "source $D/lib/integrations/fzf.sh 2>/dev/null || true" "init-chain"
    run_bench "source integrations/cat.sh" "source $D/lib/integrations/cat.sh 2>/dev/null || true" "init-chain"
    run_bench "source security/init.sh" "source $D/lib/security/init.sh 2>/dev/null || true" "init-chain"
    run_bench "source welcome/main.sh" "cd $D && source lib/core/colors.sh && source lib/core/platform.sh && source lib/welcome/main.sh 2>/dev/null || true" "init-chain"
    run_bench "source terminal/autocomplete.sh" "source $D/lib/terminal/autocomplete.sh 2>/dev/null || true" "init-chain"
    run_bench "_shell_config_rotate_logs" "source $D/lib/core/logging.sh && _shell_config_rotate_logs 2>/dev/null || true" "init-chain"
}

# =============================================================================
# VALIDATION BENCHMARKS
# =============================================================================

benchmark_validation() {
    local D="$SHELL_CONFIG_DIR"

    log_section "External Validators"
    if command -v shellcheck &>/dev/null; then
        run_real "shellcheck (single file)" "shellcheck -f quiet $D/lib/core/colors.sh 2>/dev/null || true" "external"
        run_real "shellcheck (batch 3 files)" "shellcheck -f quiet $D/lib/core/colors.sh $D/lib/core/platform.sh $D/lib/core/config.sh 2>/dev/null || true" "external"
    fi

    if command -v actionlint &>/dev/null; then
        run_real "actionlint (workflow)" "actionlint -oneline $D/.github/workflows/ci.yml 2>/dev/null || true" "external"
    fi

    if command -v zizmor &>/dev/null; then
        run_real "zizmor (workflow)" "zizmor --format plain $D/.github/workflows/ci.yml 2>/dev/null || true" "external"
    fi

    if command -v gitleaks &>/dev/null; then
        run_real "gitleaks (pre-commit)" "gitleaks protect --staged --no-banner 2>/dev/null || true" "external"
    fi
}

# =============================================================================
# QUICK BENCHMARK
# =============================================================================

benchmark_quick() {
    RUNS=3
    WARMUP=1

    log_section "Quick Smoke Test"
    run_real "zsh (no config)" "zsh --no-rcs -c 'exit'" "startup"
    run_real "zsh -i (full)" "zsh -i -c 'exit' 2>/dev/null" "startup"
    run_bench "git status" "cd $SHELL_CONFIG_DIR && git status --porcelain" "git"

    local src="cd $SHELL_CONFIG_DIR && source lib/core/colors.sh && source lib/core/platform.sh && source lib/welcome/main.sh"
    run_real "welcome_message" "$src && welcome_message >/dev/null 2>&1" "welcome"
}

# =============================================================================
# REPORT GENERATION
# =============================================================================

generate_report() {
    log_header "BENCHMARK REPORT"

    local total great mid ok slow
    read -r total great mid ok slow < "$COUNTER_FILE"

    echo "${BOLD}Summary:${NC}"
    echo "  Total: $total | ${GREEN}GREAT: $great${NC} | ${YELLOW}MID: $mid${NC} | ${YELLOW}OK: $ok${NC} | ${RED}SLOW: $slow${NC}"

    log_header "SLOWEST OPERATIONS"
    printf "${BOLD}%-55s %12s %8s${NC}\n" "Operation" "Time (ms)" "Rating"
    echo "══════════════════════════════════════════════════════════════════════════════"

    tail -n +2 "$CSV_FILE" | grep -v "FAILED" | sort -t, -k2 -rn | head -15 | while IFS=, read -r name time rating category; do
        case "$rating" in
            GREAT) printf "%-55s ${GREEN}%12s${NC} ${GREEN}%8s${NC}\n" "$name" "$time" "$rating" ;;
            MID)   printf "%-55s ${YELLOW}%12s${NC} ${YELLOW}%8s${NC}\n" "$name" "$time" "$rating" ;;
            OK)    printf "%-55s ${YELLOW}%12s${NC} ${YELLOW}%8s${NC}\n" "$name" "$time" "$rating" ;;
            SLOW)  printf "%-55s ${RED}%12s${NC} ${RED}%8s${NC}\n" "$name" "$time" "$rating" ;;
        esac
    done

    log_header "CATEGORY SUMMARY"
    printf "${BOLD}%-30s %10s %15s${NC}\n" "Category" "Count" "Avg Time (ms)"
    echo "─────────────────────────────────────────────────────────────"

    for cat in $(tail -n +2 "$CSV_FILE" | grep -v "FAILED" | cut -d, -f4 | sort -u); do
        local count avg
        count=$(tail -n +2 "$CSV_FILE" | grep -v "FAILED" | grep -c ",$cat\$" || echo "0")
        avg=$(tail -n +2 "$CSV_FILE" | grep -v "FAILED" | grep ",$cat\$" | cut -d, -f2 | awk '{sum+=$1} END {if(NR>0) printf "%.2f", sum/NR; else print "0"}')
        printf "%-30s %10s %15s\n" "$cat" "$count" "$avg"
    done

    printf "\n%sResults saved to:%s %s\n" "${BOLD}" "${NC}" "$CSV_FILE"
    printf "%sTotal functions tested:%s %s\n" "${BOLD}" "${NC}" "$total"
}

# =============================================================================
# MAIN
# =============================================================================

show_help() {
    head -25 "$0" | tail -23
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            startup|functions|git|validation|all|quick)
                MODE="$1"; shift ;;
            -r|--runs)
                if [[ ! "$2" =~ ^[0-9]+$ ]] || [[ "$2" -lt 1 ]]; then
                    log_error "Invalid runs value: '$2'. Must be a positive integer."
                    exit 1
                fi
                RUNS="$2"; shift 2 ;;
            -w|--warmup)
                if [[ ! "$2" =~ ^[0-9]+$ ]] || [[ "$2" -lt 0 ]]; then
                    log_error "Invalid warmup value: '$2'. Must be a non-negative integer."
                    exit 1
                fi
                WARMUP="$2"; shift 2 ;;
            -o|--output)
                CSV_FILE="$2"; shift 2 ;;
            -q|--quiet)
                QUIET=true; shift ;;
            -v|--verbose)
                VERBOSE=true; shift ;;
            -h|--help)
                show_help ;;
            *)
                log_error "Unknown option: $1"; show_help ;;
        esac
    done
}

main() {
    parse_args "$@"

    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Verbose mode enabled"
    fi

    if ! command -v hyperfine &>/dev/null; then
        log_error "hyperfine not found. Install: brew install hyperfine"
        exit 1
    fi

    [[ "$QUIET" != "true" ]] && {
        printf "\n%s🚀 Shell-Config Benchmark%s\n" "${BOLD}" "${NC}"
        printf "%sMode: %s | Runs: %s | Warmup: %s | Shell: zsh %s%s\n\n" "${DIM}" "$MODE" "$RUNS" "$WARMUP" "$ZSH_VERSION" "${NC}"
    }

    init_csv
    cd "$SHELL_CONFIG_DIR" 2>/dev/null || { log_error "Failed to change to $SHELL_CONFIG_DIR"; exit 1; }

    case "$MODE" in
        startup)    benchmark_startup ;;
        functions)  benchmark_functions ;;
        git)        benchmark_git ;;
        validation) benchmark_validation ;;
        quick)      benchmark_quick ;;
        all)
            benchmark_startup
            benchmark_functions
            benchmark_git
            benchmark_validation
            ;;
    esac

    generate_report
}

main "$@"
