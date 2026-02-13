#!/usr/bin/env bash
# =============================================================================
# 🧪 VALIDATOR MOCK FUNCTIONS
# =============================================================================
# Mock validation tools for testing validator functionality.
#
# Usage: source this file in your test setup
# =============================================================================

# Create mock syntax validators
create_mock_oxlint() {
    local mock_script="$MOCK_BIN_DIR/oxlint"
    cat > "$mock_script" << 'MOCK_EOF'
#!/usr/bin/env bash
MOCK_OXLINT_CALLS_FILE="${TEST_TEMP_DIR}/mock-oxlint-calls.txt"
echo "oxlint $*" >> "$MOCK_OXLINT_CALLS_FILE"

if [[ "${MOCK_OXLINT_FAIL:-0}" == "1" ]]; then
    echo "error: Mock oxlint error" >&2
    exit 1
fi

exit 0
MOCK_EOF
    chmod +x "$mock_script"
}

mock_oxlint() {
    return 0
}

create_mock_ruff() {
    local mock_script="$MOCK_BIN_DIR/ruff"
    cat > "$mock_script" << 'MOCK_EOF'
#!/usr/bin/env bash
MOCK_RUFF_CALLS_FILE="${TEST_TEMP_DIR}/mock-ruff-calls.txt"
echo "ruff $*" >> "$MOCK_RUFF_CALLS_FILE"

if [[ "${MOCK_RUFF_FAIL:-0}" == "1" ]]; then
    echo "error: Mock ruff error" >&2
    exit 1
fi

exit 0
MOCK_EOF
    chmod +x "$mock_script"
}

create_mock_shellcheck() {
    local mock_script="$MOCK_BIN_DIR/shellcheck"
    cat > "$mock_script" << 'MOCK_EOF'
#!/usr/bin/env bash
MOCK_SHELLCHECK_CALLS_FILE="${TEST_TEMP_DIR}/mock-shellcheck-calls.txt"
echo "shellcheck $*" >> "$MOCK_SHELLCHECK_CALLS_FILE"

if [[ "${MOCK_SHELLCHECK_FAIL:-0}" == "1" ]]; then
    echo "error: Mock shellcheck error" >&2
    exit 1
fi

exit 0
MOCK_EOF
    chmod +x "$mock_script"
}

mock_shellcheck() {
    return 0
}

create_mock_yamllint() {
    local mock_script="$MOCK_BIN_DIR/yamllint"
    cat > "$mock_script" << 'MOCK_EOF'
#!/usr/bin/env bash
MOCK_YAMLLINT_CALLS_FILE="${TEST_TEMP_DIR}/mock-yamllint-calls.txt"
echo "yamllint $*" >> "$MOCK_YAMLLINT_CALLS_FILE"

if [[ "${MOCK_YAMLLINT_FAIL:-0}" == "1" ]]; then
    echo "error: Mock yamllint error" >&2
    exit 1
fi

exit 0
MOCK_EOF
    chmod +x "$mock_script"
}

create_mock_gitleaks() {
    local mock_script="$MOCK_BIN_DIR/gitleaks"
    cat > "$mock_script" << 'MOCK_EOF'
#!/usr/bin/env bash
MOCK_GITLEAKS_CALLS_FILE="${TEST_TEMP_DIR}/mock-gitleaks-calls.txt"
echo "gitleaks $*" >> "$MOCK_GITLEAKS_CALLS_FILE"

case "$1" in
    protect)
        if [[ "${MOCK_GITLEAKS_DETECT:-0}" == "1" ]]; then
            exit 1
        fi
        exit 0
        ;;
esac

exit 0
MOCK_EOF
    chmod +x "$mock_script"
}

# Create all mock commands at once
create_all_mocks() {
    create_mock_git
    create_mock_op
    create_mock_oxlint
    create_mock_ruff
    create_mock_shellcheck
    create_mock_yamllint
    create_mock_gitleaks
}