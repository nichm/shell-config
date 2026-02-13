#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# 🔍 TOOLCHAIN SCANNER - Analyze Project Dependencies & Tools
# =============================================================================
# Scans repositories and system for packages, tools, and configurations.
# Identifies opportunities for automated validation and safety rules.
#
# Two modes:
#   DEFAULT MODE: Find tools with config validators (nginx -t, terraform
#                 validate, docker-compose config, etc.) - for git hook setup
#   DANGEROUS MODE: Focus on CLI tools with destructive actions - for adding
#                   to command-safety rules
#
# Usage:
#   ./toolchain-scanner.sh [OPTIONS]
#
# Options:
#   --dangerous-only        Focus on dangerous CLI tools for safety rules
#   --format=json|md|txt    Output format (default: md)
#   --output=<file>         Output file (default: stdout)
#   --repos-dir=<path>      Directory containing repos (default: parent dirs)
#   --include-system        Include system-installed packages (brew, global)
#   --verbose               Show detailed scanning progress
#   --help                  Show this help message
#
# Examples:
#   # Find all tools needing config validation (for git hooks)
#   ./toolchain-scanner.sh
#
#   # Focus on dangerous CLI tools (for command-safety rules)
#   ./toolchain-scanner.sh --dangerous-only
#
#   # Include system packages
#   ./toolchain-scanner.sh --include-system
#
# =============================================================================

# SCRIPT_DIR and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
COMMAND_SAFETY_RULES_DIR="$SHELL_CONFIG_DIR/lib/command-safety/rules"
DEFAULT_REPOS_DIR="$(dirname "$(dirname "$SHELL_CONFIG_DIR")")"

# Output settings
OUTPUT_FORMAT="md"
OUTPUT_FILE=""
REPOS_DIR="$DEFAULT_REPOS_DIR"
INCLUDE_SYSTEM=false
VERBOSE=false
DANGEROUS_ONLY=false

# Data structures (temp files for cross-process storage)
TEMP_DIR=""
PACKAGES_FILE=""
VALIDATORS_FILE=""
DANGEROUS_TOOLS_FILE=""
EXISTING_RULES_FILE=""

# HELPER FUNCTIONS

log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[INFO] $*" >&2
    fi
}

error() {
    echo "[ERROR] $*" >&2
}

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

show_help() {
    head -35 "$0" | tail -32
    exit 0
}

# ARGUMENT PARSING

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dangerous-only)
                DANGEROUS_ONLY=true
                ;;
            --format=*)
                OUTPUT_FORMAT="${1#*=}"
                if [[ ! "$OUTPUT_FORMAT" =~ ^(json|md|txt)$ ]]; then
                    error "Invalid format: $OUTPUT_FORMAT. Must be json, md, or txt"
                    exit 1
                fi
                ;;
            --output=*)
                OUTPUT_FILE="${1#*=}"
                ;;
            --repos-dir=*)
                REPOS_DIR="${1#*=}"
                if [[ ! -d "$REPOS_DIR" ]]; then
                    error "Directory not found: $REPOS_DIR"
                    exit 1
                fi
                ;;
            --include-system)
                INCLUDE_SYSTEM=true
                ;;
            --verbose)
                VERBOSE=true
                ;;
            --help|-h)
                show_help
                ;;
            *)
                error "Unknown option: $1"
                show_help
                ;;
        esac
        shift
    done
}

# MAIN EXECUTION

main() {
    parse_args "$@"

    # Load data definitions
    local data_file
    for data_file in precommit-tools prepush-tools dangerous-tools; do
        data_file="$SCRIPT_DIR/toolchain-scanner/data/$data_file.sh"
        if [[ ! -f "$data_file" ]]; then
            error "Required data file not found: $data_file"
            exit 1
        fi
        source "$data_file"
    done

    # Load core scanning logic
    local core_file="$SCRIPT_DIR/toolchain-scanner/scanner-core.sh"
    if [[ ! -f "$core_file" ]]; then
        error "Required core file not found: $core_file"
        exit 1
    fi
    source "$core_file"

    # Load output reporters
    local reporters_file="$SCRIPT_DIR/toolchain-scanner/reporters.sh"
    if [[ ! -f "$reporters_file" ]]; then
        error "Required reporters file not found: $reporters_file"
        exit 1
    fi
    source "$reporters_file"

    # Setup temp directory
    TEMP_DIR=$(mktemp -d)
    PACKAGES_FILE="$TEMP_DIR/packages.txt"
    VALIDATORS_FILE="$TEMP_DIR/validators.txt"
    DANGEROUS_TOOLS_FILE="$TEMP_DIR/dangerous.txt"
    EXISTING_RULES_FILE="$TEMP_DIR/rules.txt"
    : > "$PACKAGES_FILE"
    : > "$VALIDATORS_FILE"
    : > "$DANGEROUS_TOOLS_FILE"
    : > "$EXISTING_RULES_FILE"

    log "Starting validator discovery..."
    log "Repos directory: $REPOS_DIR"
    log "Mode: $(if [[ "$DANGEROUS_ONLY" == true ]]; then echo "Dangerous Only"; else echo "Full Validators"; fi)"

    # Extract existing rules (for dangerous mode comparison)
    extract_existing_rules

    # Scan repositories
    for repo in "$REPOS_DIR"/*/; do
        [[ -d "$repo" ]] && scan_repository "$repo"
    done

    # Scan system packages if requested
    if [[ "$INCLUDE_SYSTEM" == true ]]; then
        log "Scanning system tools..."
        scan_system_tools
    fi

    # Analyze
    local validator_analysis dangerous_analysis
    validator_analysis=$(analyze_validators)
    dangerous_analysis=$(analyze_dangerous)

    # Generate output
    local output
    case "$OUTPUT_FORMAT" in
        json)
            output=$(format_json "$validator_analysis" "$dangerous_analysis")
            ;;
        md)
            if [[ "$DANGEROUS_ONLY" == true ]]; then
                output=$(format_markdown_dangerous "$dangerous_analysis")
            else
                output=$(format_markdown_validators "$validator_analysis")
            fi
            ;;
        txt)
            output=$(format_txt "$validator_analysis" "$dangerous_analysis")
            ;;
    esac

    # Write output
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$output" > "$OUTPUT_FILE"
        log "Report written to: $OUTPUT_FILE"
    else
        echo "$output"
    fi
}

main "$@"
