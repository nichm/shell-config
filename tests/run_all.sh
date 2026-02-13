#!/usr/bin/env bash
# =============================================================================
# 🧪 SHELL-CONFIG TEST RUNNER
# =============================================================================
# Runs all test suites for shell-config with timeouts, parallel execution,
# and verbose logging
#
# Usage:
#   ./run_all.sh              # Run all tests (parallel)
#   ./run_all.sh quick        # Run quick tests only (bats)
#   ./run_all.sh bats         # Run bats tests only
#   ./run_all.sh legacy       # Run legacy bash tests only
#   ./run_all.sh serial       # Run tests sequentially (no parallel)
#   ./run_all.sh <file.bats>  # Run single test file
#
# Environment:
#   TEST_TIMEOUT=60           # Timeout per test file (default: 60s)
#   TEST_PARALLEL=4           # Number of parallel jobs (default: 4, 0=auto)
#   TEST_VERBOSE=1            # Extra verbose output
#   TEST_SERIAL=1             # Force sequential execution
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly CYAN='\033[0;36m'
readonly DIM='\033[2m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
TEST_TIMEOUT="${TEST_TIMEOUT:-60}"    # seconds per test file
TEST_PARALLEL="${TEST_PARALLEL:-4}"   # parallel jobs (0 = auto-detect CPU count)
TEST_VERBOSE="${TEST_VERBOSE:-0}"
TEST_SERIAL="${TEST_SERIAL:-0}"       # force sequential execution

log_header() { echo -e "\n${BOLD}${CYAN}═══ $1 ═══${NC}\n"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_info() { echo -e "${DIM}ℹ️  $1${NC}"; }
log_timestamp() { echo -e "${DIM}[$(date '+%H:%M:%S')]${NC} $1"; }

MODE="${1:-all}"
ERRORS=0
TIMEOUTS=0
PASSED=0
SKIPPED=0
START_TIME=$(date +%s)

# Portable timeout function
run_with_timeout() {
    local timeout_secs="$1"
    shift
    local cmd=("$@")
    
    if command -v timeout &>/dev/null; then
        # GNU timeout (Linux)
        timeout --kill-after=5 "$timeout_secs" "${cmd[@]}"
    elif command -v gtimeout &>/dev/null; then
        # GNU timeout via Homebrew (macOS)
        gtimeout --kill-after=5 "$timeout_secs" "${cmd[@]}"
    else
        # Fallback: use background job with wait
        local pid
        "${cmd[@]}" &
        pid=$!
        
        local count=0
        while kill -0 "$pid" 2>/dev/null; do
            if [[ $count -ge $timeout_secs ]]; then
                kill -9 "$pid" 2>/dev/null || true
                wait "$pid" 2>/dev/null || true
                return 124  # timeout exit code
            fi
            sleep 1
            count=$((count + 1))
        done
        wait "$pid"
        return $?
    fi
}

# Run a single bats file and record results (used by parallel runner)
# Writes result to a temp file for aggregation
run_single_bats_file() {
    local bats_file="$1"
    local result_dir="$2"
    local test_name
    test_name="${bats_file#"$SCRIPT_DIR/"}"
    test_name="${test_name%.bats}"
    
    local output_file result_file
    output_file=$(mktemp)
    result_file="$result_dir/$(echo "$test_name" | tr '/' '_').result"
    
    local start exit_code=0
    start=$(date +%s)
    
    if run_with_timeout "$TEST_TIMEOUT" bats "$bats_file" > "$output_file" 2>&1; then
        local elapsed=$(($(date +%s) - start))
        local summary
        summary=$(tail -1 "$output_file" 2>/dev/null || echo "")
        echo "PASS|$test_name|$elapsed|$summary" > "$result_file"
    else
        exit_code=$?
        local elapsed=$(($(date +%s) - start))
        if [[ $exit_code -eq 124 ]]; then
            echo "TIMEOUT|$test_name|$elapsed|" > "$result_file"
            tail -20 "$output_file" >> "$result_file" 2>/dev/null || true
        else
            echo "FAIL|$test_name|$elapsed|$exit_code" > "$result_file"
            cat "$output_file" >> "$result_file" 2>/dev/null || true
        fi
    fi
    
    rm -f "$output_file"
}

# Export function for xargs/parallel
export -f run_with_timeout run_single_bats_file
export SCRIPT_DIR TEST_TIMEOUT

# Run bats tests in parallel
run_bats_tests_parallel() {
    log_header "Running Bats Tests (Parallel)"
    
    if ! command -v bats &>/dev/null; then
        log_error "bats not installed"
        log_info "Install with: brew install bats-core"
        ERRORS=$((ERRORS + 1))
        return
    fi
    
    # Find all .bats files recursively
    local bats_files=()
    while IFS= read -r -d '' file; do
        bats_files+=("$file")
    done < <(find "$SCRIPT_DIR" -name "*.bats" -type f -print0 | sort -z)
    
    if [[ ${#bats_files[@]} -eq 0 ]]; then
        log_warn "No .bats files found in $SCRIPT_DIR"
        return
    fi
    
    local total=${#bats_files[@]}
    local jobs="$TEST_PARALLEL"
    
    # Auto-detect CPU count if jobs=0
    if [[ "$jobs" -eq 0 ]]; then
        if command -v nproc &>/dev/null; then
            jobs=$(nproc)
        elif command -v sysctl &>/dev/null; then
            jobs=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
        else
            jobs=4
        fi
    fi
    
    echo -e "${BOLD}Found $total bats test files${NC}"
    log_info "Running with $jobs parallel jobs"
    log_info "Timeout per file: ${TEST_TIMEOUT}s"
    echo ""
    
    # Create temp directory for results
    local result_dir
    result_dir=$(mktemp -d)
    trap 'rm -rf "$result_dir"' RETURN INT TERM
    
    # Ensure bats can load shared helpers from tests/
    export BATS_LIB_PATH="${SCRIPT_DIR}${BATS_LIB_PATH:+:$BATS_LIB_PATH}"
    export SHELL_CONFIG_DIR
    
    log_timestamp "Starting parallel test execution..."
    
    # Run tests in parallel using xargs
    printf '%s\n' "${bats_files[@]}" | \
        xargs -P "$jobs" -I {} bash -c 'run_single_bats_file "$@"' _ {} "$result_dir"
    
    log_timestamp "All tests completed, processing results..."
    echo ""
    
    # Process results
    local pass_count=0 fail_count=0 timeout_count=0
    
    for result_file in "$result_dir"/*.result; do
        [[ -f "$result_file" ]] || continue
        
        local first_line status test_name elapsed extra
        first_line=$(head -1 "$result_file")
        IFS='|' read -r status test_name elapsed extra <<< "$first_line"
        
        case "$status" in
            PASS)
                log_success "$test_name passed (${elapsed}s) $extra"
                pass_count=$((pass_count + 1))
                ;;
            TIMEOUT)
                log_error "$test_name TIMEOUT after ${TEST_TIMEOUT}s"
                if [[ "$TEST_VERBOSE" == "1" ]]; then
                    tail -n +2 "$result_file" 2>/dev/null || true
                fi
                timeout_count=$((timeout_count + 1))
                fail_count=$((fail_count + 1))
                ;;
            FAIL)
                log_error "$test_name failed (${elapsed}s, exit: $extra)"
                # Show failure output
                tail -n +2 "$result_file" 2>/dev/null || true
                fail_count=$((fail_count + 1))
                ;;
        esac
    done
    
    PASSED=$((PASSED + pass_count))
    ERRORS=$((ERRORS + fail_count))
    TIMEOUTS=$((TIMEOUTS + timeout_count))
    
    rm -rf "$result_dir"
    trap - RETURN
}

# Run bats tests sequentially (original method)
run_bats_tests_serial() {
    log_header "Running Bats Tests (Sequential)"
    
    if ! command -v bats &>/dev/null; then
        log_error "bats not installed"
        log_info "Install with: brew install bats-core"
        ERRORS=$((ERRORS + 1))
        return
    fi
    
    # Find all .bats files recursively
    local bats_files=()
    while IFS= read -r -d '' file; do
        bats_files+=("$file")
    done < <(find "$SCRIPT_DIR" -name "*.bats" -type f -print0 | sort -z)
    
    if [[ ${#bats_files[@]} -eq 0 ]]; then
        log_warn "No .bats files found in $SCRIPT_DIR"
        return
    fi
    
    local total=${#bats_files[@]}
    echo -e "${BOLD}Found $total bats test files${NC}"
    log_info "Timeout per file: ${TEST_TIMEOUT}s"
    echo ""
    
    # Ensure bats can load shared helpers from tests/
    export BATS_LIB_PATH="${SCRIPT_DIR}${BATS_LIB_PATH:+:$BATS_LIB_PATH}"

    local current=0
    for bats_file in "${bats_files[@]}"; do
        current=$((current + 1))
        if [[ -f "$bats_file" ]]; then
            local test_name
            # Show relative path from SCRIPT_DIR for clarity
            test_name="${bats_file#"$SCRIPT_DIR/"}"
            test_name="${test_name%.bats}"
            
            log_timestamp "[$current/$total] Testing: ${BOLD}$test_name${NC}"
            
            local start exit_code=0
            start=$(date +%s)
            
            # Run with timeout and capture output
            local output_file
            output_file=$(mktemp)
            trap 'rm -f "$output_file"' RETURN
            
            if run_with_timeout "$TEST_TIMEOUT" bats "$bats_file" > "$output_file" 2>&1; then
                local elapsed=$(($(date +%s) - start))
                # Show summary line from bats output
                local summary
                summary=$(tail -1 "$output_file" 2>/dev/null || echo "")
                log_success "$test_name passed (${elapsed}s) $summary"
                PASSED=$((PASSED + 1))
                
                # Show full output in verbose mode
                if [[ "$TEST_VERBOSE" == "1" ]]; then
                    cat "$output_file"
                fi
            else
                exit_code=$?
                local elapsed=$(($(date +%s) - start))
                
                if [[ $exit_code -eq 124 ]]; then
                    log_error "$test_name TIMEOUT after ${TEST_TIMEOUT}s"
                    log_info "Partial output:"
                    tail -20 "$output_file" 2>/dev/null || true
                    TIMEOUTS=$((TIMEOUTS + 1))
                else
                    log_error "$test_name failed (${elapsed}s, exit: $exit_code)"
                    # Always show output on failure
                    cat "$output_file"
                fi
                ERRORS=$((ERRORS + 1))
            fi
            
            rm -f "$output_file"
            trap - RETURN
            echo ""
        fi
    done
}

# Main bats test entry point - choose parallel or serial
run_bats_tests() {
    if [[ "$TEST_SERIAL" == "1" ]]; then
        run_bats_tests_serial
    else
        run_bats_tests_parallel
    fi
}

# Run a single test file
run_single_test() {
    local test_file="$1"
    
    # Handle relative or absolute paths
    if [[ ! -f "$test_file" ]]; then
        if [[ -f "$SCRIPT_DIR/$test_file" ]]; then
            test_file="$SCRIPT_DIR/$test_file"
        else
            log_error "Test file not found: $test_file"
            exit 1
        fi
    fi
    
    log_header "Running Single Test: $(basename "$test_file")"
    log_timestamp "File: $test_file"
    log_info "Timeout: ${TEST_TIMEOUT}s"
    echo ""
    
    export BATS_LIB_PATH="${SCRIPT_DIR}${BATS_LIB_PATH:+:$BATS_LIB_PATH}"
    
    local start exit_code=0
    start=$(date +%s)
    
    if run_with_timeout "$TEST_TIMEOUT" bats "$test_file"; then
        local elapsed=$(($(date +%s) - start))
        log_success "Test passed (${elapsed}s)"
        PASSED=1
    else
        exit_code=$?
        local elapsed=$(($(date +%s) - start))
        if [[ $exit_code -eq 124 ]]; then
            log_error "Test TIMEOUT after ${TEST_TIMEOUT}s"
            TIMEOUTS=1
        else
            log_error "Test failed (${elapsed}s, exit: $exit_code)"
        fi
        ERRORS=1
    fi
}

# Main
case "$MODE" in
    all)
        run_bats_tests
        ;;
    quick|bats)
        run_bats_tests
        ;;
    serial)
        TEST_SERIAL=1
        run_bats_tests_serial
        ;;
    *.bats)
        run_single_test "$MODE"
        ;;
    *)
        if [[ -f "$MODE" ]] || [[ -f "$SCRIPT_DIR/$MODE" ]]; then
            run_single_test "$MODE"
        else
            echo "Usage: $0 [all|quick|bats|serial|<file.bats>]"
            echo ""
            echo "Modes:"
            echo "  all      Run all tests in parallel (default)"
            echo "  quick    Run bats tests only (parallel)"
            echo "  bats     Same as quick"
            echo "  serial   Run all tests sequentially"
            echo "  legacy   Run legacy command-safety tests only"
            echo ""
            echo "Environment variables:"
            echo "  TEST_TIMEOUT=60    # Timeout per test file in seconds"
            echo "  TEST_PARALLEL=4    # Number of parallel jobs (0=auto)"
            echo "  TEST_VERBOSE=1     # Show full output even on success"
            echo "  TEST_SERIAL=1      # Force sequential execution"
            echo ""
            echo "Examples:"
            echo "  ./run_all.sh                        # Run all tests (4 parallel)"
            echo "  TEST_PARALLEL=8 ./run_all.sh        # Run with 8 parallel jobs"
            echo "  TEST_TIMEOUT=120 ./run_all.sh       # 2 minute timeout per test"
            echo "  ./run_all.sh serial                 # Run sequentially"
            echo "  ./run_all.sh git/wrapper.bats       # Run single test file"
            exit 1
        fi
        ;;
esac

# Summary
TOTAL_TIME=$(($(date +%s) - START_TIME))
log_header "Test Summary"

echo -e "  ${GREEN}Passed:${NC}   $PASSED"
echo -e "  ${RED}Failed:${NC}   $ERRORS"
if [[ $TIMEOUTS -gt 0 ]]; then
    echo -e "  ${YELLOW}Timeouts:${NC} $TIMEOUTS"
fi
if [[ $SKIPPED -gt 0 ]]; then
    echo -e "  ${DIM}Skipped:${NC}  $SKIPPED"
fi
echo -e "  ${DIM}Duration:${NC} ${TOTAL_TIME}s"
if [[ "$TEST_SERIAL" != "1" ]]; then
    echo -e "  ${DIM}Mode:${NC}     parallel (${TEST_PARALLEL} jobs)"
else
    echo -e "  ${DIM}Mode:${NC}     sequential"
fi
echo ""

if [[ $ERRORS -eq 0 ]]; then
    log_success "All tests passed!"
    exit 0
else
    if [[ $TIMEOUTS -gt 0 ]]; then
        log_error "$ERRORS test suite(s) failed ($TIMEOUTS timed out)"
        log_info "Try increasing timeout: TEST_TIMEOUT=120 ./run_all.sh"
    else
        log_error "$ERRORS test suite(s) failed"
    fi
    exit 1
fi
