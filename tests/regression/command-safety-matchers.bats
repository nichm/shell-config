#!/usr/bin/env bats
# =============================================================================
# Regression: Command Safety Matcher Tests (Generic Matcher Architecture)
# =============================================================================
# Tests for the unified generic matcher in lib/command-safety/engine/matcher.sh
# All matching is now data-driven from rule definitions — no separate matcher files.
#
# These tests verify that:
# 1. The generic matcher correctly blocks dangerous commands
# 2. Bypass flags work in all positions
# 3. Custom match functions (match_fn=) work correctly
# 4. Exempt flags prevent false positives
# 5. Context checks (git_repo) fire correctly
# 6. Edge cases don't create security holes
# =============================================================================

setup() {
    export SHELL_CONFIG_DIR
    SHELL_CONFIG_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

    # Source all engine dependencies
    export ENGINE_DIR="$SHELL_CONFIG_DIR/lib/command-safety/engine"
    export UTILS="$ENGINE_DIR/utils.sh"
    export MATCHER="$ENGINE_DIR/matcher.sh"
    export REGISTRY="$ENGINE_DIR/registry.sh"
    export RULE_HELPERS="$ENGINE_DIR/rule-helpers.sh"
}

# Helper to source the full engine with stubs for display/logging
_source_engine_with_rules() {
    local rule_file="$1"
    cat << 'SHELL'
        set -euo pipefail
        # Stub display/logging functions
        _show_rule_message() { :; }
        _log_violation() { :; }
SHELL
    echo "source '$REGISTRY'"
    echo "source '$UTILS'"
    echo "source '$RULE_HELPERS'"
    echo "source '$rule_file'"
    echo "source '$MATCHER'"
}

# Helper to source engine with just specific rules inline
_source_engine_inline() {
    cat << 'SHELL'
        set -euo pipefail
        _show_rule_message() { :; }
        _log_violation() { :; }
SHELL
    echo "source '$REGISTRY'"
    echo "source '$UTILS'"
    echo "source '$RULE_HELPERS'"
    echo "source '$MATCHER'"
}

# =============================================================================
# Utils: _has_bypass_flag
# =============================================================================

@test "utils: _has_bypass_flag finds flag at start" {
    run bash -c "
        source '$UTILS'
        _has_bypass_flag '--force-danger' --force-danger push --force
    "
    [ "$status" -eq 0 ]
}

@test "utils: _has_bypass_flag finds flag at end" {
    run bash -c "
        source '$UTILS'
        _has_bypass_flag '--force-danger' push --force --force-danger
    "
    [ "$status" -eq 0 ]
}

@test "utils: _has_bypass_flag returns 1 when flag missing" {
    run bash -c "
        source '$UTILS'
        _has_bypass_flag '--force-danger' push --force
    "
    [ "$status" -eq 1 ]
}

# =============================================================================
# Utils: _has_danger_flags
# =============================================================================

@test "utils: _has_danger_flags detects -rf combined" {
    run bash -c "source '$UTILS'; _has_danger_flags -rf /tmp/dir"
    [ "$status" -eq 0 ]
}

@test "utils: _has_danger_flags detects -fr combined" {
    run bash -c "source '$UTILS'; _has_danger_flags -fr /tmp/dir"
    [ "$status" -eq 0 ]
}

@test "utils: _has_danger_flags detects separate -r -f" {
    run bash -c "source '$UTILS'; _has_danger_flags -r -f /tmp/dir"
    [ "$status" -eq 0 ]
}

@test "utils: _has_danger_flags detects --recursive --force" {
    run bash -c "source '$UTILS'; _has_danger_flags --recursive --force /tmp/dir"
    [ "$status" -eq 0 ]
}

@test "utils: _has_danger_flags returns 1 for safe flags" {
    run bash -c "source '$UTILS'; _has_danger_flags -v /tmp/file.txt"
    [ "$status" -eq 1 ]
}

# =============================================================================
# Generic Matcher: _cs_match_pattern
# =============================================================================

@test "matcher: _cs_match_pattern matches single token" {
    run bash -c "
        source '$MATCHER'
        _cs_match_pattern 'delete' delete my-resource
    "
    [ "$status" -eq 0 ]
}

@test "matcher: _cs_match_pattern matches multi-token" {
    run bash -c "
        source '$MATCHER'
        _cs_match_pattern 'push --force' push --force origin
    "
    [ "$status" -eq 0 ]
}

@test "matcher: _cs_match_pattern fails when token missing" {
    run bash -c "
        source '$MATCHER'
        _cs_match_pattern 'push --force' push origin
    "
    [ "$status" -eq 1 ]
}

@test "matcher: _cs_match_pattern handles pipe alternatives" {
    run bash -c "
        source '$MATCHER'
        _cs_match_pattern 'uninstall|remove|rm' rm lodash
    "
    [ "$status" -eq 0 ]
}

# =============================================================================
# Generic Matcher: npm/yarn/pnpm blocking
# =============================================================================

@test "generic-matcher: blocks npm without bypass" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules npm install lodash
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: allows npm with --force-npm bypass" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules npm install lodash --force-npm
    "
    [ "$status" -eq 0 ]
}

@test "generic-matcher: blocks yarn without bypass" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules yarn add lodash
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: blocks pnpm without bypass" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules pnpm install lodash
    "
    [ "$status" -eq 1 ]
}

# =============================================================================
# Generic Matcher: rm -rf blocking (custom match_fn)
# =============================================================================

@test "generic-matcher: blocks rm -rf without bypass" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules rm -rf /tmp/dir
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: allows rm -rf with --force-danger bypass" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules rm -rf /tmp/dir --force-danger
    "
    [ "$status" -eq 0 ]
}

@test "generic-matcher: allows rm without dangerous flags" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        # Mock _in_git_repo to return false
        _in_git_repo() { return 1; }
        _check_command_rules rm /tmp/file.txt
    "
    [ "$status" -eq 0 ]
}

# =============================================================================
# Generic Matcher: chmod 777 blocking
# =============================================================================

@test "generic-matcher: blocks chmod 777" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules chmod 777 /tmp/dir
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: allows chmod 755" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules chmod 755 /tmp/dir
    "
    [ "$status" -eq 0 ]
}

# =============================================================================
# Generic Matcher: sudo rm blocking
# =============================================================================

@test "generic-matcher: blocks sudo rm" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules sudo rm -rf /
    "
    [ "$status" -eq 1 ]
}

# =============================================================================
# Generic Matcher: gh repo operations
# =============================================================================

@test "generic-matcher: blocks gh repo create" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/git.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules gh repo create my-repo
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: blocks gh repo delete" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/git.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules gh repo delete my-repo
    "
    [ "$status" -eq 1 ]
}

# =============================================================================
# Generic Matcher: git dangerous subcommands
# =============================================================================

@test "generic-matcher: blocks git reset --hard" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/git.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules git reset --hard HEAD~1
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: allows git reset --hard with --force-danger" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/git.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules git reset --hard HEAD~1 --force-danger
    "
    [ "$status" -eq 0 ]
}

@test "generic-matcher: blocks git push --force" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/git.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules git push --force origin main
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: allows git push --force-with-lease (exempt)" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/git.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules git push --force-with-lease origin main
    "
    [ "$status" -eq 0 ]
}

@test "generic-matcher: blocks git push -f (short flag)" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/git.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules git push -f origin main
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: blocks git clean -fd" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/git.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules git clean -fd
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: blocks git branch -D" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/git.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules git branch -D feature-branch
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: blocks git branch --delete --force" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/git.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules git branch --delete --force feature-branch
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: blocks git checkout -f" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/git.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules git checkout -f main
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: returns 2 for non-registered commands" {
    run bash -c "
        $(_source_engine_inline)
        _check_command_rules unknown_tool arg1
    "
    [ "$status" -eq 2 ]
}

@test "generic-matcher: allows plain git with no args" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/git.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules git
    "
    # With the generic matcher, 'git' with no args won't match any rule
    # that requires specific tokens, so it should return 0 (no match for any rule)
    [ "$status" -eq 0 ]
}

# =============================================================================
# Generic Matcher: File Ops (sed/find/truncate)
# =============================================================================

@test "generic-matcher: blocks sed -i" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules sed -i 's/foo/bar/' file.txt
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: allows sed without -i" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules sed 's/foo/bar/' file.txt
    "
    [ "$status" -eq 0 ]
}

@test "generic-matcher: blocks find -delete" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules find /tmp -name '*.tmp' -delete
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: allows find without -delete" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules find /tmp -name '*.tmp'
    "
    [ "$status" -eq 0 ]
}

@test "generic-matcher: blocks truncate -s0 (custom match_fn)" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules truncate -s0 file.txt
    "
    [ "$status" -eq 1 ]
}

# =============================================================================
# Generic Matcher: Package Managers (brew/pip/cargo/bun)
# =============================================================================

@test "generic-matcher: blocks brew uninstall --zap" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules brew uninstall --zap firefox
    "
    [ "$status" -eq 1 ]
}

# =============================================================================
# UV Enforcement: pip/pip3 → uv pip
# =============================================================================

@test "uv-enforce: blocks pip install" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules pip install requests
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: blocks pip3 install" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules pip3 install flask
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: blocks pip freeze" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules pip freeze
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: blocks pip list" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules pip list
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: blocks pip uninstall" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules pip uninstall requests
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: allows pip with --force-pip bypass" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules pip install requests --force-pip
    "
    [ "$status" -eq 0 ]
}

@test "uv-enforce: allows pip3 with --force-pip3 bypass" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules pip3 install flask --force-pip3
    "
    [ "$status" -eq 0 ]
}

# =============================================================================
# UV Enforcement: python -m pip / python3 -m pip → uv pip
# =============================================================================

@test "uv-enforce: blocks python -m pip install" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python -m pip install requests
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: blocks python3 -m pip install" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python3 -m pip install requests
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: allows python -m pip with --force-python bypass" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python -m pip install requests --force-python
    "
    [ "$status" -eq 0 ]
}

@test "uv-enforce: allows python3 -m pip with --force-python3 bypass" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python3 -m pip install requests --force-python3
    "
    [ "$status" -eq 0 ]
}

# =============================================================================
# UV Enforcement: python/python3 direct usage → uv run
# =============================================================================

@test "uv-enforce: blocks python script.py" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python script.py
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: blocks python3 script.py" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python3 script.py
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: blocks python -c inline code" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python -c 'print(1)'
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: blocks python3 -c inline code" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python3 -c 'import json; print(json.dumps({}))'
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: blocks python3 -m module (non-pip)" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python3 -m http.server 8080
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: blocks python3 -m venv" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python3 -m venv .venv
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: blocks bare python (no args)" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: blocks bare python3 (no args)" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python3
    "
    [ "$status" -eq 1 ]
}

@test "uv-enforce: allows python with --force-python bypass" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python script.py --force-python
    "
    [ "$status" -eq 0 ]
}

@test "uv-enforce: allows python3 with --force-python3 bypass" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python3 script.py --force-python3
    "
    [ "$status" -eq 0 ]
}

@test "uv-enforce: allows python3 -c with --force-python3 bypass" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules python3 -c 'import sys; print(sys.version)' --force-python3
    "
    [ "$status" -eq 0 ]
}

@test "generic-matcher: blocks cargo uninstall" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules cargo uninstall ripgrep
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: blocks bun remove" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules bun remove lodash
    "
    [ "$status" -eq 1 ]
}

@test "generic-matcher: returns 2 for unknown commands" {
    run bash -c "
        $(_source_engine_inline)
        _check_command_rules unknown_cmd arg1
    "
    [ "$status" -eq 2 ]
}

# =============================================================================
# Exempt flag tests
# =============================================================================

@test "exempt: brew uninstall skipped when --zap present" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    # BREW_UNINSTALL has exempt="--zap", so when --zap is present,
    # it should be skipped. BREW_UNINSTALL_ZAP should fire instead.
    run bash -c "
        $(_source_engine_with_rules "$rules")
        # Both rules exist for brew. With --zap:
        # - BREW_UNINSTALL: exempt='--zap' → skipped
        # - BREW_UNINSTALL_ZAP: match='uninstall --zap' → matches → blocked
        _check_command_rules brew uninstall --zap firefox
    "
    [ "$status" -eq 1 ]
}

@test "exempt: brew uninstall fires without --zap" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/package-managers.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules brew uninstall firefox
    "
    [ "$status" -eq 1 ]
}

# =============================================================================
# Custom match function tests
# =============================================================================

@test "match_fn: _cs_match_rm_rf detects -rf" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules rm -rf /tmp/dir
    "
    [ "$status" -eq 1 ]
}

@test "match_fn: _cs_match_rm_rf detects separate -r -f" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules rm -r -f /tmp/dir
    "
    [ "$status" -eq 1 ]
}

@test "match_fn: _cs_match_truncate detects -s 0" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules truncate -s 0 file.txt
    "
    [ "$status" -eq 1 ]
}

@test "match_fn: prettier --write with glob blocked" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/prettier.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules prettier --write '**/*.js'
    "
    [ "$status" -eq 1 ]
}

@test "match_fn: prettier --write . blocked" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/prettier.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules prettier --write .
    "
    [ "$status" -eq 1 ]
}

@test "match_fn: prettier --check is allowed" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/prettier.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules prettier --check .
    "
    [ "$status" -eq 0 ]
}

@test "match_fn: _cs_match_sudo_chown_homebrew blocks chown -R on /opt/homebrew" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules sudo chown -R testuser /opt/homebrew
    "
    [ "$status" -eq 1 ]
}

@test "match_fn: _cs_match_sudo_chown_homebrew allows chown without homebrew path" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/dangerous-commands.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        # sudo chown without homebrew path — only SUDO_RM could fire,
        # but 'chown' != 'rm', so no match
        _check_command_rules sudo chown -R testuser /home/testuser
    "
    [ "$status" -eq 0 ]
}

@test "match_fn: _cs_match_wrangler_deploy_prod blocks --env prod" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/cloudflare.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules wrangler deploy --env prod
    "
    [ "$status" -eq 1 ]
}

@test "match_fn: _cs_match_wrangler_deploy_prod blocks --env=prod" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/cloudflare.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules wrangler deploy --env=prod
    "
    [ "$status" -eq 1 ]
}

@test "match_fn: _cs_match_wrangler_deploy_prod allows --env staging" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/cloudflare.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules wrangler deploy --env staging
    "
    # deploy without prod env shouldn't trigger DEPLOY_PROD rule,
    # but generic 'delete'/'publish' rules don't apply to 'deploy' either
    [ "$status" -eq 0 ]
}

@test "match_fn: _cs_match_ansible_dangerous blocks --tags dangerous" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/ansible.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules ansible-playbook playbook.yml --tags dangerous
    "
    [ "$status" -eq 1 ]
}

@test "match_fn: _cs_match_ansible_dangerous allows safe tags" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/ansible.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules ansible-playbook playbook.yml --tags deploy
    "
    [ "$status" -eq 0 ]
}

@test "match_fn: _cs_match_pg_dump_gzip blocks pipe in args" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/supabase.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules pg_dump mydb '|' gzip
    "
    [ "$status" -eq 1 ]
}

@test "match_fn: pg_dump without pipe is allowed" {
    local rules="$SHELL_CONFIG_DIR/lib/command-safety/rules/supabase.sh"
    run bash -c "
        $(_source_engine_with_rules "$rules")
        _check_command_rules pg_dump -Fc mydb -f backup.dump
    "
    [ "$status" -eq 0 ]
}
