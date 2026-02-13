#!/usr/bin/env bash
# =============================================================================
# 🧪 Git Hooks Verification Script
# =============================================================================
# Comprehensive test to validate all git hooks work correctly
# Tests each hook stage, bypass flags, and error detection
# =============================================================================

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../lib/git/hooks"
# Shared utilities are in lib/git/shared (not hooks/shared)
GIT_SHARED_DIR="$SCRIPT_DIR/../lib/git/shared"
VALIDATION_DIR="$SCRIPT_DIR/../lib/validation/shared"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((TESTS_FAILED++)); }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; ((TESTS_SKIPPED++)); }

# =============================================================================
# PHASE 1: File Existence Verification
# =============================================================================
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PHASE 1: File Existence Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

verify_file_exists() {
    local file="$1"
    local desc="$2"
    log_test "Checking $desc exists..."
    if [[ -f "$file" ]]; then
        log_pass "$desc exists: $file"
    else
        log_fail "$desc missing: $file"
    fi
}

# Main hooks
verify_file_exists "$HOOKS_DIR/pre-commit" "pre-commit hook"
verify_file_exists "$HOOKS_DIR/pre-merge-commit" "pre-merge-commit hook"
verify_file_exists "$HOOKS_DIR/pre-push" "pre-push hook"
verify_file_exists "$HOOKS_DIR/commit-msg" "commit-msg hook"
verify_file_exists "$HOOKS_DIR/post-commit" "post-commit hook"
verify_file_exists "$HOOKS_DIR/post-merge" "post-merge hook"
verify_file_exists "$HOOKS_DIR/prepare-commit-msg" "prepare-commit-msg hook"

# Shared utilities (in lib/git/shared, not hooks/shared)
verify_file_exists "$GIT_SHARED_DIR/reporters.sh" "git/shared/reporters.sh"
verify_file_exists "$GIT_SHARED_DIR/validation-loop.sh" "git/shared/validation-loop.sh"
verify_file_exists "$GIT_SHARED_DIR/file-scanner.sh" "git/shared/file-scanner.sh"
verify_file_exists "$GIT_SHARED_DIR/timeout-wrapper.sh" "git/shared/timeout-wrapper.sh"

# Validation modules
verify_file_exists "$VALIDATION_DIR/file-operations.sh" "validation/shared/file-operations.sh"
verify_file_exists "$VALIDATION_DIR/reporters.sh" "validation/shared/reporters.sh"

# Helper scripts
verify_file_exists "$HOOKS_DIR/check-file-length.sh" "check-file-length.sh"
verify_file_exists "$HOOKS_DIR/check-sensitive-filenames.sh" "check-sensitive-filenames.sh"
verify_file_exists "$HOOKS_DIR/opengrep-hook.sh" "opengrep-hook.sh"

# =============================================================================
# PHASE 2: Bash Syntax Verification
# =============================================================================
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PHASE 2: Bash Syntax Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

verify_syntax() {
    local file="$1"
    local name
    name="$(basename "$file")"
    log_test "Checking bash syntax: $name"
    if bash -n "$file" 2>/dev/null; then
        log_pass "$name syntax OK"
    else
        log_fail "$name has syntax errors"
    fi
}

verify_syntax "$HOOKS_DIR/pre-commit"
verify_syntax "$HOOKS_DIR/pre-merge-commit"
verify_syntax "$HOOKS_DIR/pre-push"
verify_syntax "$HOOKS_DIR/commit-msg"
verify_syntax "$HOOKS_DIR/post-commit"
verify_syntax "$HOOKS_DIR/post-merge"
verify_syntax "$HOOKS_DIR/prepare-commit-msg"
verify_syntax "$GIT_SHARED_DIR/validation-loop.sh"
verify_syntax "$GIT_SHARED_DIR/reporters.sh"
verify_syntax "$VALIDATION_DIR/file-operations.sh"
verify_syntax "$VALIDATION_DIR/reporters.sh"

# =============================================================================
# PHASE 3: ShellCheck Verification
# =============================================================================
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PHASE 3: ShellCheck Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

verify_shellcheck() {
    local file="$1"
    local name
    name="$(basename "$file")"
    log_test "Running shellcheck: $name"
    if command -v shellcheck >/dev/null 2>&1; then
        if shellcheck --severity=error "$file" 2>/dev/null; then
            log_pass "$name passes shellcheck"
        else
            log_fail "$name has shellcheck errors"
        fi
    else
        log_skip "shellcheck not installed"
    fi
}

verify_shellcheck "$HOOKS_DIR/pre-commit"
verify_shellcheck "$HOOKS_DIR/pre-merge-commit"
verify_shellcheck "$HOOKS_DIR/pre-push"
verify_shellcheck "$HOOKS_DIR/commit-msg"
verify_shellcheck "$GIT_SHARED_DIR/validation-loop.sh"
verify_shellcheck "$VALIDATION_DIR/file-operations.sh"

# =============================================================================
# PHASE 4: Function Availability Verification
# =============================================================================
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PHASE 4: Function Availability Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

verify_function_in_file() {
    local file="$1"
    local func="$2"
    log_test "Checking function '$func' in $(basename $file)"
    if grep -q "^${func}()" "$file" 2>/dev/null; then
        log_pass "Function $func found"
    elif grep -q "^function ${func}" "$file" 2>/dev/null; then
        log_pass "Function $func found"
    else
        log_fail "Function $func NOT found in $file"
    fi
}

# Critical functions needed by pre-merge-commit
verify_function_in_file "$VALIDATION_DIR/file-operations.sh" "file_contains_string"
verify_function_in_file "$VALIDATION_DIR/file-operations.sh" "get_staged_files"
verify_function_in_file "$VALIDATION_DIR/file-operations.sh" "should_validate_file"

# Functions in git/shared/reporters.sh
verify_function_in_file "$GIT_SHARED_DIR/reporters.sh" "report_hook_start"
verify_function_in_file "$GIT_SHARED_DIR/reporters.sh" "report_validation_error"
verify_function_in_file "$GIT_SHARED_DIR/reporters.sh" "hook_fail"

# Functions in validation-loop.sh
verify_function_in_file "$GIT_SHARED_DIR/validation-loop.sh" "run_validation_on_staged"

# =============================================================================
# PHASE 5: Source Path Verification (Critical Issue #251 Fix)
# =============================================================================
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PHASE 5: Source Path Verification (Issue #251 Fix)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

log_test "Verifying pre-merge-commit sources file-operations.sh from validation module..."
# Check for either literal path or variable-based path (VALIDATION_SHARED)
if grep -q 'validation/shared/file-operations.sh' "$HOOKS_DIR/pre-merge-commit" || \
   grep -q 'VALIDATION_SHARED.*file-operations.sh' "$HOOKS_DIR/pre-merge-commit"; then
    log_pass "pre-merge-commit correctly sources validation/shared/file-operations.sh"
else
    log_fail "pre-merge-commit does NOT source validation/shared/file-operations.sh"
fi

log_test "Verifying pre-merge-commit does NOT source old file-scanner.sh for file_contains_string..."
if grep -q 'source.*shared/file-scanner.sh' "$HOOKS_DIR/pre-merge-commit"; then
    log_fail "pre-merge-commit still sources hooks/shared/file-scanner.sh (old path)"
else
    log_pass "pre-merge-commit no longer sources hooks/shared/file-scanner.sh"
fi

# =============================================================================
# PHASE 6: TESTS_PID Wait Verification (Critical Issue #253 Fix)
# =============================================================================
# NOTE: The pre-commit hook is now a thin wrapper that delegates to the stage module.
# Check the stage module (lib/git/stages/commit/pre-commit.sh) for implementation details.
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PHASE 6: Stage Module Architecture Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

STAGES_DIR="$SCRIPT_DIR/../lib/git/stages/commit"

log_test "Verifying pre-commit sources stage module..."
if grep -q 'run_pre_commit_checks' "$HOOKS_DIR/pre-commit"; then
    log_pass "pre-commit delegates to run_pre_commit_checks()"
else
    log_fail "pre-commit does NOT delegate to stage module"
fi

log_test "Verifying tests_pid is defined in stage module..."
if grep -q 'tests_pid=' "$STAGES_DIR/pre-commit.sh"; then
    log_pass "tests_pid is defined in stage module"
else
    log_fail "tests_pid is NOT defined in stage module"
fi

log_test "Verifying 'wait \$tests_pid' exists in stage module..."
if grep -qE 'wait \$tests_pid' "$STAGES_DIR/pre-commit.sh"; then
    log_pass "'wait \$tests_pid' found in stage module"
else
    log_fail "'wait \$tests_pid' NOT found in stage module"
fi

# =============================================================================
# PHASE 7: Bypass Flags Verification
# =============================================================================
# NOTE: Bypass flags are in the hook (for GIT_SKIP_HOOKS) and stage modules
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PHASE 7: Bypass Flags Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

verify_bypass_flag() {
    local flag="$1"
    local file="$2"
    log_test "Checking bypass flag: $flag"
    if grep -q "$flag" "$file" 2>/dev/null; then
        log_pass "Bypass flag $flag found in $(basename $file)"
    else
        log_fail "Bypass flag $flag NOT found in $(basename $file)"
    fi
}

# Hook-level bypasses (in the thin wrapper)
verify_bypass_flag "GIT_SKIP_HOOKS" "$HOOKS_DIR/pre-commit"
verify_bypass_flag "GIT_SKIP_FILE_LENGTH_CHECK" "$HOOKS_DIR/pre-commit"

# Stage module bypasses (in the checks file)
CHECKS_FILE="$STAGES_DIR/pre-commit-checks-extended.sh"
verify_bypass_flag "GIT_SKIP_TSC_CHECK" "$CHECKS_FILE"
verify_bypass_flag "GIT_SKIP_MYPY_CHECK" "$CHECKS_FILE"
verify_bypass_flag "GIT_SKIP_CIRCULAR_DEPS" "$CHECKS_FILE"
verify_bypass_flag "GIT_SKIP_INFRA_CHECK" "$STAGES_DIR/pre-commit.sh"

# =============================================================================
# PHASE 8: Parallel Job Structure Verification (in stage module)
# =============================================================================
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PHASE 8: Parallel Job Structure Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

verify_job_pid() {
    local pid_var="$1"
    log_test "Verifying $pid_var job pattern..."
    
    # Check PID is assigned in stage module (lowercase variable names)
    if grep -q "${pid_var}=\$!" "$STAGES_DIR/pre-commit.sh"; then
        # Check PID is waited
        if grep -qE "wait \\\$${pid_var}" "$STAGES_DIR/pre-commit.sh"; then
            log_pass "$pid_var: assigned and waited"
        else
            log_fail "$pid_var: assigned but NOT waited"
        fi
    else
        log_skip "$pid_var not found (may be optional)"
    fi
}

# Stage module uses lowercase variable names
verify_job_pid "sensitive_pid"
verify_job_pid "syntax_pid"
verify_job_pid "dependency_pid"
verify_job_pid "largefiles_pid"
verify_job_pid "stats_pid"
verify_job_pid "opengrep_pid"
verify_job_pid "gitleaks_pid"
verify_job_pid "tests_pid"
verify_job_pid "tsc_pid"
verify_job_pid "circular_pid"
verify_job_pid "mypy_pid"

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  TEST SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}PASSED:${NC}  $TESTS_PASSED"
echo -e "  ${RED}FAILED:${NC}  $TESTS_FAILED"
echo -e "  ${YELLOW}SKIPPED:${NC} $TESTS_SKIPPED"
echo ""

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}❌ Some tests failed. Please review the failures above.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
fi
