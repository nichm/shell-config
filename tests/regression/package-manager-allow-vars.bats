#!/usr/bin/env bats
# =============================================================================
# Regression: Per-manager COMMAND_SAFETY_ALLOW_* env var tests
# =============================================================================
# Verifies that each ALLOW_ flag unblocks only its own manager and leaves
# all others blocked. Return codes from _check_command_rules:
#   0 = checked + allowed   1 = blocked   2 = no rule registered (also = allow)
# Tests use [ "$status" -ne 1 ] to mean "not blocked" (covers both 0 and 2).
# =============================================================================

setup() {
    export SHELL_CONFIG_DIR
    SHELL_CONFIG_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

    export ENGINE_DIR="$SHELL_CONFIG_DIR/lib/command-safety/engine"
    export REGISTRY="$ENGINE_DIR/registry.sh"
    export UTILS="$ENGINE_DIR/utils.sh"
    export RULE_HELPERS="$ENGINE_DIR/rule-helpers.sh"
    export MATCHER="$ENGINE_DIR/matcher.sh"
    export PKG_RULES="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
}

# Emit code to source the engine + rule file in a fresh bash -c subshell
_engine_with_rules() {
    cat << 'SHELL'
        set -euo pipefail
        _show_rule_message() { :; }
        _log_violation() { :; }
SHELL
    echo "source '$REGISTRY'"
    echo "source '$UTILS'"
    echo "source '$RULE_HELPERS'"
    echo "source '$PKG_RULES'"
    echo "source '$MATCHER'"
}

# =============================================================================
# Node managers
# =============================================================================

@test "ALLOW_NPM: npm not blocked when COMMAND_SAFETY_ALLOW_NPM=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_NPM=true
        $(_engine_with_rules)
        _check_command_rules npm install lodash
    "
    [ "$status" -ne 1 ]
}

@test "ALLOW_NPM: yarn still blocked when only COMMAND_SAFETY_ALLOW_NPM=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_NPM=true
        $(_engine_with_rules)
        _check_command_rules yarn add lodash
    "
    [ "$status" -eq 1 ]
}

@test "ALLOW_NPM: pnpm still blocked when only COMMAND_SAFETY_ALLOW_NPM=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_NPM=true
        $(_engine_with_rules)
        _check_command_rules pnpm install lodash
    "
    [ "$status" -eq 1 ]
}

@test "ALLOW_NPX: npx not blocked when COMMAND_SAFETY_ALLOW_NPX=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_NPX=true
        $(_engine_with_rules)
        _check_command_rules npx create-react-app my-app
    "
    [ "$status" -ne 1 ]
}

@test "ALLOW_NPX: npm still blocked when only COMMAND_SAFETY_ALLOW_NPX=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_NPX=true
        $(_engine_with_rules)
        _check_command_rules npm install lodash
    "
    [ "$status" -eq 1 ]
}

@test "ALLOW_YARN: yarn not blocked when COMMAND_SAFETY_ALLOW_YARN=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_YARN=true
        $(_engine_with_rules)
        _check_command_rules yarn add lodash
    "
    [ "$status" -ne 1 ]
}

@test "ALLOW_YARN: npm still blocked when only COMMAND_SAFETY_ALLOW_YARN=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_YARN=true
        $(_engine_with_rules)
        _check_command_rules npm install lodash
    "
    [ "$status" -eq 1 ]
}

@test "ALLOW_PNPM: pnpm not blocked when COMMAND_SAFETY_ALLOW_PNPM=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_PNPM=true
        $(_engine_with_rules)
        _check_command_rules pnpm install lodash
    "
    [ "$status" -ne 1 ]
}

@test "ALLOW_PNPM: yarn still blocked when only COMMAND_SAFETY_ALLOW_PNPM=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_PNPM=true
        $(_engine_with_rules)
        _check_command_rules yarn add lodash
    "
    [ "$status" -eq 1 ]
}

# =============================================================================
# Python tools
# =============================================================================

@test "ALLOW_PIP: pip not blocked when COMMAND_SAFETY_ALLOW_PIP=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_PIP=true
        $(_engine_with_rules)
        _check_command_rules pip install requests
    "
    [ "$status" -ne 1 ]
}

@test "ALLOW_PIP: pip3 not blocked when COMMAND_SAFETY_ALLOW_PIP=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_PIP=true
        $(_engine_with_rules)
        _check_command_rules pip3 install requests
    "
    [ "$status" -ne 1 ]
}

@test "ALLOW_PIP: python still blocked when only COMMAND_SAFETY_ALLOW_PIP=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_PIP=true
        $(_engine_with_rules)
        _check_command_rules python script.py
    "
    [ "$status" -eq 1 ]
}

@test "ALLOW_PIP: python3 still blocked when only COMMAND_SAFETY_ALLOW_PIP=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_PIP=true
        $(_engine_with_rules)
        _check_command_rules python3 script.py
    "
    [ "$status" -eq 1 ]
}

@test "ALLOW_PYTHON: python not blocked when COMMAND_SAFETY_ALLOW_PYTHON=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_PYTHON=true
        $(_engine_with_rules)
        _check_command_rules python script.py
    "
    [ "$status" -ne 1 ]
}

@test "ALLOW_PYTHON: python3 not blocked when COMMAND_SAFETY_ALLOW_PYTHON=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_PYTHON=true
        $(_engine_with_rules)
        _check_command_rules python3 script.py
    "
    [ "$status" -ne 1 ]
}

@test "ALLOW_PYTHON: pip still blocked when only COMMAND_SAFETY_ALLOW_PYTHON=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_PYTHON=true
        $(_engine_with_rules)
        _check_command_rules pip install requests
    "
    [ "$status" -eq 1 ]
}

@test "ALLOW_PYTHON: pip3 still blocked when only COMMAND_SAFETY_ALLOW_PYTHON=true" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_PYTHON=true
        $(_engine_with_rules)
        _check_command_rules pip3 install requests
    "
    [ "$status" -eq 1 ]
}

# =============================================================================
# Independence: node allows don't affect python and vice versa
# =============================================================================

@test "independence: all node ALLOW vars set, python still blocked" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_NPM=true COMMAND_SAFETY_ALLOW_NPX=true
        export COMMAND_SAFETY_ALLOW_YARN=true COMMAND_SAFETY_ALLOW_PNPM=true
        $(_engine_with_rules)
        _check_command_rules python script.py
    "
    [ "$status" -eq 1 ]
}

@test "independence: all node ALLOW vars set, pip still blocked" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_NPM=true COMMAND_SAFETY_ALLOW_YARN=true COMMAND_SAFETY_ALLOW_PNPM=true
        $(_engine_with_rules)
        _check_command_rules pip install requests
    "
    [ "$status" -eq 1 ]
}

@test "independence: ALLOW_PIP + ALLOW_PYTHON set, npm still blocked" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_PIP=true COMMAND_SAFETY_ALLOW_PYTHON=true
        $(_engine_with_rules)
        _check_command_rules npm install lodash
    "
    [ "$status" -eq 1 ]
}

@test "independence: ALLOW_PIP + ALLOW_PYTHON set, yarn still blocked" {
    run bash -c "
        export COMMAND_SAFETY_ALLOW_PIP=true COMMAND_SAFETY_ALLOW_PYTHON=true
        $(_engine_with_rules)
        _check_command_rules yarn add lodash
    "
    [ "$status" -eq 1 ]
}
