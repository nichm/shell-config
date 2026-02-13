#!/usr/bin/env bash
# =============================================================================
# Validator API Test Suite
# =============================================================================
# Tests the Validator API in various modes and configurations.
#
# Usage: ./test-api.sh
# =============================================================================

# Note: Not using set -euo pipefail because validator functions may return
# non-zero exit codes during normal operation, which would cause the script
# to exit prematurely.

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helpers
test_start() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${BLUE}Test $TESTS_RUN:${NC} $1"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓ PASS${NC}"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗ FAIL${NC} $1"
}

test_skip() {
    echo -e "  ${YELLOW}⊘ SKIP${NC} $1"
}

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

export SHELL_CONFIG_DIR

# Source API
source "$SHELL_CONFIG_DIR/lib/validation/api.sh"

# Create test files
TEST_DIR="${TMPDIR:-/tmp}/validator-api-test-$$"
mkdir -p "$TEST_DIR"

cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo "════════════════════════════════════════════════════════════════"
echo "  Validator API Test Suite"
echo "════════════════════════════════════════════════════════════════"
echo ""

# =============================================================================
# Test 1: Console Output Mode
# =============================================================================
test_start "Console output mode"

cat > "$TEST_DIR/test.py" << 'EOF'
def hello():
    print("Hello, World!")
EOF

if VALIDATOR_OUTPUT=console validator_api_run "$TEST_DIR/test.py" >/dev/null 2>&1; then
    test_pass
else
    test_fail "Console output failed"
fi

# =============================================================================
# Test 2: JSON Output Mode
# =============================================================================
test_start "JSON output mode"

OUTPUT=$(VALIDATOR_OUTPUT=json validator_api_run "$TEST_DIR/test.py" 2>/dev/null)

if grep -q '"version":"1.0"' <<< "$OUTPUT" && \
   grep -q '"summary":' <<< "$OUTPUT" && \
   grep -q '"results":' <<< "$OUTPUT"; then
    test_pass
else
    test_fail "Invalid JSON output"
fi

# =============================================================================
# Test 3: Multiple Files
# =============================================================================
test_start "Multiple file validation"

cat > "$TEST_DIR/test2.sh" << 'EOF'
#!/bin/bash
echo "test"
EOF

cat > "$TEST_DIR/test3.yml" << 'EOF'
test: value
EOF

if VALIDATOR_OUTPUT=json validator_api_run \
    "$TEST_DIR/test.py" "$TEST_DIR/test2.sh" "$TEST_DIR/test3.yml" >/dev/null 2>&1; then
    test_pass
else
    test_fail "Multiple file validation failed"
fi

# =============================================================================
# Test 4: Parallel Execution
# =============================================================================
test_start "Parallel execution"

if VALIDATOR_OUTPUT=json VALIDATOR_PARALLEL=2 validator_api_run \
    "$TEST_DIR/test.py" "$TEST_DIR/test2.sh" "$TEST_DIR/test3.yml" >/dev/null 2>&1; then
    test_pass
else
    test_fail "Parallel execution failed"
fi

# =============================================================================
# Test 5: Directory Validation
# =============================================================================
test_start "Directory validation"

if VALIDATOR_OUTPUT=console validator_api_validate_dir "$TEST_DIR" "*.py" >/dev/null 2>&1; then
    test_pass
else
    test_fail "Directory validation failed"
fi

# =============================================================================
# Test 6: Error Detection (Syntax Error)
# =============================================================================
test_start "Syntax error detection"

cat > "$TEST_DIR/broken.py" << 'EOF'
def broken(
    # Missing closing parenthesis
EOF

OUTPUT=$(VALIDATOR_OUTPUT=json validator_api_run "$TEST_DIR/broken.py" 2>&1 || true)

if grep -q '"status":"fail"' <<< "$OUTPUT"; then
    test_pass
else
    test_fail "Failed to detect syntax error"
fi

# =============================================================================
# Test 7: Sensitive Filename Detection
# =============================================================================
test_start "Sensitive filename detection"

touch "$TEST_DIR/.env"

OUTPUT=$(VALIDATOR_OUTPUT=json validator_api_run "$TEST_DIR/.env" 2>&1 || true)

if grep -q '"status":"fail"' <<< "$OUTPUT"; then
    test_pass
else
    test_fail "Failed to detect sensitive filename"
fi

# =============================================================================
# Test 8: File Output
# =============================================================================
test_start "JSON file output"

OUTPUT_FILE="$TEST_DIR/results.json"

if VALIDATOR_OUTPUT=json VALIDATOR_OUTPUT_FILE="$OUTPUT_FILE" \
    validator_api_run "$TEST_DIR/test.py" >/dev/null 2>&1; then

    if [[ -f "$OUTPUT_FILE" ]] && grep -q '"version"' "$OUTPUT_FILE"; then
        test_pass
    else
        test_fail "JSON file not created or invalid"
    fi
else
    test_fail "JSON file output failed"
fi

# =============================================================================
# Test 9: Non-existent File
# =============================================================================
test_start "Non-existent file handling"

OUTPUT=$(VALIDATOR_OUTPUT=json validator_api_run "$TEST_DIR/doesnotexist.py" 2>&1 || true)

if grep -q '"status":"skipped"' <<< "$OUTPUT"; then
    test_pass
else
    test_fail "Didn't skip non-existent file"
fi

# =============================================================================
# Test 10: API Version
# =============================================================================
test_start "API version"

VERSION=$(validator_api_version)

if [[ "$VERSION" == "Validator API v1.0.0" ]]; then
    test_pass
else
    test_fail "Unexpected version: $VERSION"
fi

# =============================================================================
# Test 11: Help Text
# =============================================================================
test_start "Help text"

HELP=$(validator_api_help)

if grep -q "Validator API" <<< "$HELP" && \
   grep -q "USAGE:" <<< "$HELP"; then
    test_pass
else
    test_fail "Help text missing or invalid"
fi

# =============================================================================
# Test 12: Empty Directory
# =============================================================================
test_start "Empty directory handling"

EMPTY_DIR="$TEST_DIR/empty"
mkdir -p "$EMPTY_DIR"

if validator_api_validate_dir "$EMPTY_DIR" >/dev/null 2>&1; then
    test_pass
else
    test_fail "Empty directory handling failed"
fi

# =============================================================================
# Test 13: Performance Benchmark
# =============================================================================
test_start "Performance benchmark (reasonable overhead)"

# Create 30 test files (more files = better parallel performance)
for i in {1..30}; do
    cat > "$TEST_DIR/perf-$i.py" << EOF
def test_$i():
    # Add some content to make validation non-trivial
    return $i
EOF
done

# Measure sequential time
START=$(date +%s.%N 2>/dev/null || date +%s)
VALIDATOR_OUTPUT=console VALIDATOR_PARALLEL=0 \
    validator_api_run "$TEST_DIR"/perf-*.py >/dev/null 2>&1
END=$(date +%s.%N 2>/dev/null || date +%s)

if command -v bc >/dev/null 2>&1; then
    SEQUENTIAL_TIME=$(echo "$END - $START" | bc)

    # Measure parallel time with 4 jobs
    START=$(date +%s.%N 2>/dev/null || date +%s)
    VALIDATOR_OUTPUT=console VALIDATOR_PARALLEL=4 \
        validator_api_run "$TEST_DIR"/perf-*.py >/dev/null 2>&1
    END=$(date +%s.%N 2>/dev/null || date +%s)
    PARALLEL_TIME=$(echo "$END - $START" | bc)

    # For small file counts, parallel can be up to 2x slower due to overhead
    # This is acceptable as parallel benefits increase with file count/size
    if [[ $(echo "$PARALLEL_TIME <= $SEQUENTIAL_TIME * 2.0" | bc) -eq 1 ]]; then
        test_pass "Sequential: ${SEQUENTIAL_TIME}s, Parallel: ${PARALLEL_TIME}s"
    else
        test_fail "Excessive overhead: ${SEQUENTIAL_TIME}s → ${PARALLEL_TIME}s"
    fi
else
    test_skip "bc not available for timing"
fi

# =============================================================================
# Test 14: Parallel Correctness
# =============================================================================
test_start "Parallel execution correctness"

cat > "$TEST_DIR/correctness-a.py" << 'EOF'
def test_a():
    return 1
EOF

cat > "$TEST_DIR/correctness-b.sh" << 'EOF'
#!/bin/bash
echo "test"
EOF

# Run sequential and parallel, compare results
SEQUENTIAL=$(VALIDATOR_OUTPUT=json VALIDATOR_PARALLEL=0 validator_api_run \
    "$TEST_DIR/correctness-a.py" "$TEST_DIR/correctness-b.sh" 2>/dev/null)

PARALLEL=$(VALIDATOR_OUTPUT=json VALIDATOR_PARALLEL=2 validator_api_run \
    "$TEST_DIR/correctness-a.py" "$TEST_DIR/correctness-b.sh" 2>/dev/null)

# Extract status from JSON (both should have same results)
SEQ_STATUS=$(grep -o '"status":"[^"]*"' <<< "$SEQUENTIAL" | head -1)
PAR_STATUS=$(grep -o '"status":"[^"]*"' <<< "$PARALLEL" | head -1)

if [[ "$SEQ_STATUS" == "$PAR_STATUS" ]]; then
    test_pass
else
    test_fail "Parallel and sequential results differ"
fi

# =============================================================================
# Test 15: Special Characters in Filenames
# =============================================================================
test_start "Special characters in filenames"

# Create file with special characters in name
cat > "$TEST_DIR/file with spaces.py" << 'EOF'
def test():
    pass
EOF

cat > "$TEST_DIR/file'with'quotes.sh" << 'EOF'
#!/bin/bash
echo "test"
EOF

OUTPUT=$(VALIDATOR_OUTPUT=json validator_api_run \
    "$TEST_DIR/file with spaces.py" "$TEST_DIR/file'with'quotes.sh" 2>/dev/null || true)

if echo "$OUTPUT" | grep -q '"status":"pass"'; then
    test_pass
else
    test_fail "Failed to handle special characters in filenames"
fi

# =============================================================================
# Test 16: Invalid Environment Variables
# =============================================================================
test_start "Invalid environment variable handling"

# Test invalid VALIDATOR_OUTPUT
OUTPUT=$(VALIDATOR_OUTPUT=invalid validator_api_run "$TEST_DIR/test.py" 2>&1 || true)

if echo "$OUTPUT" | grep -q "Error: VALIDATOR_OUTPUT must be"; then
    test_pass
else
    test_fail "Failed to validate invalid VALIDATOR_OUTPUT"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Test Summary"
echo "════════════════════════════════════════════════════════════════"
echo "  Total:   $TESTS_RUN"
echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
else
    echo -e "  ${GREEN}Failed:${NC}  $TESTS_FAILED"
fi
echo "════════════════════════════════════════════════════════════════"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
