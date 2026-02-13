#!/usr/bin/env bash
# =============================================================================
# run_module.sh - Run tests for specific modules
# =============================================================================
# Run tests by module instead of all tests.
#
# Usage:
# ./run_module.sh <module> [options]
#
# Modules: core, aliases, git, command-safety, validation, security, integrations, terminal, welcome, init, bin, benchmarking, compliance, regression
#
# Options:
# -v, --verbose    Verbose output
# -h, --help       Show this help
#
# Examples:
# ./run_module.sh core
# ./run_module.sh git --verbose
# ./run_module.sh validation/core
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
MODULE=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 <module> [options]"
            echo ""
            echo "Modules:"
            echo "  core            Core module tests (colors, logging, etc.)"
            echo "  aliases         Alias module tests"
            echo "  git             Git module tests"
            echo "  command-safety  Command safety engine & rules tests"
            echo "  validation      Validation module tests"
            echo "  security        Security module tests"
            echo "  integrations    Integration tests"
            echo "  terminal        Terminal module tests"
            echo "  welcome         Welcome module tests"
            echo "  init            Init/installation tests"
            echo "  bin             Binary/executable tests"
            echo "  benchmarking    Performance benchmark tests"
            echo "  compliance      Compliance/standards tests"
            echo "  regression      Regression tests"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Verbose output"
            echo "  -h, --help       Show this help"
            exit 0
            ;;
        *)
            if [[ -z "$MODULE" ]]; then
                MODULE="$1"
            else
                echo -e "${RED}Error: Multiple modules specified. Use: $0 <module>${NC}" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$MODULE" ]]; then
    echo -e "${RED}Error: No module specified. Use: $0 <module>${NC}" >&2
    echo "Run '$0 --help' for usage information." >&2
    exit 1
fi

# Map module names to test directories
declare -A MODULE_PATHS=(
    ["core"]="core/"
    ["aliases"]="aliases/"
    ["git"]="git/"
    ["command-safety"]="command-safety/"
    ["validation"]="validation/"
    ["security"]="security/"
    ["integrations"]="integrations/"
    ["terminal"]="terminal/"
    ["welcome"]="welcome/"
    ["init"]="init/"
    ["bin"]="bin/"
    ["benchmarking"]="benchmarking/"
    ["compliance"]="compliance/"
    ["regression"]="regression/"
)

# Check if module exists
if [[ ! -d "${MODULE_PATHS[$MODULE]}" ]]; then
    echo -e "${RED}Error: Module '$MODULE' not found or has no tests${NC}" >&2
    echo "Available modules: ${!MODULE_PATHS[*]}" >&2
    exit 1
fi

TEST_PATH="${MODULE_PATHS[$MODULE]}"

echo -e "${BLUE}Running tests for module: ${MODULE}${NC}"
echo -e "${BLUE}Test path: ${TEST_PATH}${NC}"

# Build bats command
BATS_CMD=("bats")
if [[ "$VERBOSE" == true ]]; then
    BATS_CMD+=("--verbose")
fi

# Add all .bats files in the module directory
BATS_FILES=()
while IFS= read -r -d '' file; do
    BATS_FILES+=("$file")
done < <(find "$TEST_PATH" -name "*.bats" -type f -print0 2>/dev/null || true)

if [[ ${#BATS_FILES[@]} -eq 0 ]]; then
    echo -e "${YELLOW}Warning: No .bats files found in ${TEST_PATH}${NC}" >&2
    exit 0
fi

echo -e "${BLUE}Found ${#BATS_FILES[@]} test files${NC}"

# Run the tests
START_TIME=$(date +%s)
"${BATS_CMD[@]}" "${BATS_FILES[@]}"
END_TIME=$(date +%s)

DURATION=$((END_TIME - START_TIME))
echo -e "${GREEN}Module '${MODULE}' tests completed in ${DURATION}s${NC}"
