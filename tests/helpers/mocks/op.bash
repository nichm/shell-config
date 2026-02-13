#!/usr/bin/env bash
# =============================================================================
# 🧪 1PASSWORD (OP) MOCK FUNCTIONS
# =============================================================================
# Mock 1Password CLI commands for testing secrets functionality.
#
# Usage: source this file in your test setup
# =============================================================================

# Create a mock op (1Password CLI) command
create_mock_op() {
    local mock_script="$MOCK_BIN_DIR/op"
    cat > "$mock_script" << 'MOCK_EOF'
#!/usr/bin/env bash
# Mock op command for testing

MOCK_OP_CALLS_FILE="${TEST_TEMP_DIR}/mock-op-calls.txt"
echo "op $*" >> "$MOCK_OP_CALLS_FILE"

case "$1" in
    whoami)
        if [[ "${MOCK_OP_AUTHENTICATED:-1}" == "1" ]]; then
            echo "test@example.com"
            exit 0
        else
            exit 1
        fi
        ;;
    read)
        if [[ "${MOCK_OP_READ_FAIL:-0}" == "1" ]]; then
            exit 1
        fi
        if [[ -n "${MOCK_OP_SECRET_VALUE:-}" ]]; then
            echo "$MOCK_OP_SECRET_VALUE"
            exit 0
        else
            echo "mock-secret-value-12345"
            exit 0
        fi
        ;;
    --mock-fail)
        exit 1
        ;;
esac

exit 0
MOCK_EOF

    chmod +x "$mock_script"
}

# Simple mock op for basic tests
mock_op() {
    case "$1" in
    whoami)
        echo "test@example.com"
        return 0
        ;;
    read)
        echo "mock-secret-value"
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}