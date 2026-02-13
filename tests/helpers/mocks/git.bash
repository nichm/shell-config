#!/usr/bin/env bash
# =============================================================================
# 🧪 GIT MOCK FUNCTIONS
# =============================================================================
# Mock git commands for testing git-related functionality.
#
# Usage: source this file in your test setup
# =============================================================================

# Create a mock git command that records invocations
create_mock_git() {
    local mock_script="$MOCK_BIN_DIR/git"
    cat > "$mock_script" << 'MOCK_EOF'
#!/usr/bin/env bash
# Mock git command for testing

# Record invocation for testing
MOCK_GIT_CALLS_FILE="${TEST_TEMP_DIR}/mock-git-calls.txt"
mkdir -p "$(dirname "$MOCK_GIT_CALLS_FILE")"
echo "git $*" >> "$MOCK_GIT_CALLS_FILE"

# Handle special test commands
case "$1" in
    --mock-return-code)
        exit "${2:-0}"
        ;;
    --mock-output)
        shift
        echo "$@"
        exit 0
        ;;
esac

# Default: pass through to real git for setup
command git "$@"
MOCK_EOF

    chmod +x "$mock_script"
}

# Simple mock git for basic tests
mock_git() {
    case "$1" in
    init)
        mkdir -p .git
        return 0
        ;;
    config)
        return 0
        ;;
    diff)
        echo "test.txt"
        return 0
        ;;
    add)
        return 0
        ;;
    status)
        echo "On branch main"
        return 0
        ;;
    *)
        command git "$@"
        return $?
        ;;
    esac
}