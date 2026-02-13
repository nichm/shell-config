#!/usr/bin/env bash
# =============================================================================
# pre-commit-checks-extended.sh - Additional pre-commit checks
# =============================================================================
# Extended checks for tests and type checking.
# Usage:
#   source "${BASH_SOURCE[0]}"
# =============================================================================
set -euo pipefail

# Ensure command_exists is available
declare -f command_exists &>/dev/null || command_exists() { command -v "$1" >/dev/null 2>&1; }

# Unit tests
run_unit_tests() {
    local tmpdir="$1"

    if [[ -f "package.json" ]]; then
        if grep -q '"test":' package.json 2>/dev/null; then
            if command_exists "bun"; then
                # Use arrays for command handling to prevent word splitting issues
                local portable_timeout=()
                if command_exists "timeout"; then
                    portable_timeout=(timeout "${SC_HOOK_TIMEOUT_LONG:-60}")
                elif command_exists "gtimeout"; then
                    portable_timeout=(gtimeout "${SC_HOOK_TIMEOUT_LONG:-60}")
                fi

                if [[ ${#portable_timeout[@]} -gt 0 ]]; then
                    if ! "${portable_timeout[@]}" bun test >"$tmpdir/test-output" 2>&1; then
                        echo "error" >"$tmpdir/test-errors"
                    fi
                else
                    # No timeout command available, run without timeout
                    if ! bun test >"$tmpdir/test-output" 2>&1; then
                        echo "error" >"$tmpdir/test-errors"
                    fi
                fi
            fi
        fi
    fi
    echo -e "${GREEN}✓${NC} 🧪 Unit tests complete" >&2
}

# TypeScript type checking
run_typescript_check() {
    local tmpdir="$1"
    shift
    local files=("$@")

    if [[ "${GIT_SKIP_TSC_CHECK:-}" != "1" ]]; then
        local staged_ts_files=()
        for file in "${files[@]}"; do
            [[ ! -f "$file" ]] && continue
            local ext
            ext="${file##*.}"
            case "$ext" in
                ts | tsx | mts | cts)
                    staged_ts_files+=("$file")
                    ;;
            esac
        done

        if [[ ${#staged_ts_files[@]} -gt 0 ]] && [[ -f "tsconfig.json" ]] && command_exists "tsc"; then
            local tsc_output tsc_exit=0
            tsc_output=$(timeout "${SC_HOOK_TIMEOUT:-30}" tsc --noEmit 2>&1) || tsc_exit=$?

            echo "$tsc_output" >"$tmpdir/tsc-output"

            if [[ $tsc_exit -ne 0 ]]; then
                echo "error" >"$tmpdir/tsc-errors"
            fi
            echo -e "${GREEN}✓${NC} 📘 TypeScript check complete (${#staged_ts_files[@]} TS files staged)" >&2
        else
            if [[ ${#staged_ts_files[@]} -eq 0 ]]; then
                echo -e "${BLUE}ℹ${NC}  📘 TypeScript check skipped (no TS files staged)" >&2
            elif [[ ! -f "tsconfig.json" ]]; then
                echo -e "${BLUE}ℹ${NC}  📘 TypeScript check skipped (no tsconfig.json)" >&2
            else
                echo -e "${BLUE}ℹ${NC}  📘 TypeScript check skipped (tsc not installed)" >&2
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  TypeScript check skipped (GIT_SKIP_TSC_CHECK=1)${NC}" >&2
    fi
}

# Circular dependency detection
run_circular_dependency_check() {
    local tmpdir="$1"
    shift
    local files=("$@")

    if [[ "${GIT_SKIP_CIRCULAR_DEPS:-}" != "1" ]]; then
        local js_ts_files=()
        for file in "${files[@]}"; do
            [[ ! -f "$file" ]] && continue
            local ext
            ext="${file##*.}"
            case "$ext" in
                js | ts | jsx | tsx | mjs | cjs | mts | cts)
                    js_ts_files+=("$file")
                    ;;
            esac
        done

        if [[ ${#js_ts_files[@]} -gt 0 ]]; then
            local dpdm_cmd=()
            if command_exists "dpdm"; then
                dpdm_cmd=(dpdm)
            elif command_exists "bunx" && bunx dpdm --version >/dev/null 2>&1; then
                dpdm_cmd=(bunx dpdm)
            else
                echo -e "${GREEN}✓${NC} 🔄 Circular dependency check skipped (dpdm not installed)" >&2
                return
            fi

            local dpdm_exit_code=0
            circular_output=$(timeout "${SC_HOOK_TIMEOUT:-30}" "${dpdm_cmd[@]}" --circular --no-warning --no-tree --exit-code circular:1 "${js_ts_files[@]}" 2>&1) || dpdm_exit_code=$?
            if [[ $dpdm_exit_code -ne 0 ]]; then
                if [[ $dpdm_exit_code -eq 1 ]]; then
                    echo "$circular_output" >"$tmpdir/circular-deps"
                elif [[ $dpdm_exit_code -eq 124 ]]; then
                    echo "warning" >"$tmpdir/circular-timeout"
                fi
            fi
            echo -e "${GREEN}✓${NC} 🔄 Circular dependency check complete" >&2
        else
            echo -e "${BLUE}ℹ${NC}  🔄 Circular dependency check skipped (no JS/TS files staged)" >&2
        fi
    else
        echo -e "${YELLOW}⚠️  Circular dependency check skipped (GIT_SKIP_CIRCULAR_DEPS=1)${NC}" >&2
    fi
}

# Python type checking
run_python_type_check() {
    local tmpdir="$1"
    shift
    local files=("$@")

    if [[ "${GIT_SKIP_MYPY_CHECK:-}" != "1" ]]; then
        if [[ -f "pyproject.toml" ]] || [[ -f "mypy.ini" ]] || [[ -f ".mypy.ini" ]]; then
            # Filter Python files from already-fetched staged files (no redundant git call)
            local staged_py=()
            for file in "${files[@]}"; do
                [[ ! -f "$file" ]] && continue
                [[ "$file" == *.py ]] && staged_py+=("$file")
            done

            if [[ ${#staged_py[@]} -gt 0 ]]; then
                local mypy_cmd=()
                if command_exists "uv"; then
                    mypy_cmd=(uv run --no-sync mypy)
                elif command_exists "mypy"; then
                    mypy_cmd=(mypy)
                else
                    echo -e "${GREEN}✓${NC} 🐍 Python type check skipped (no mypy/uv)" >&2
                    return
                fi

                local mypy_output mypy_exit=0
                mypy_output=$(timeout "${SC_HOOK_TIMEOUT_LONG:-60}" "${mypy_cmd[@]}" "${staged_py[@]}" 2>&1) || mypy_exit=$?

                if [[ -n "$mypy_output" ]]; then
                    echo "$mypy_output" >"$tmpdir/mypy-output"
                fi

                if [[ $mypy_exit -eq 124 ]]; then
                    echo "error" >"$tmpdir/mypy-errors"
                    echo "timeout" >"$tmpdir/mypy-timeout"
                elif [[ $mypy_exit -ne 0 ]]; then
                    echo "error" >"$tmpdir/mypy-errors"
                fi
                echo -e "${GREEN}✓${NC} 🐍 Python type check complete" >&2
            else
                echo -e "${BLUE}ℹ${NC}  🐍 Python type check skipped (no Python files staged)" >&2
            fi
        else
            echo -e "${BLUE}ℹ${NC}  🐍 Python type check skipped (no mypy config)" >&2
        fi
    else
        echo -e "${YELLOW}⚠️  Python type check skipped (GIT_SKIP_MYPY_CHECK=1)${NC}" >&2
    fi
}
