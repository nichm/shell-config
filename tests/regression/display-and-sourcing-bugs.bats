#!/usr/bin/env bats
# =============================================================================
# 🧪 DISPLAY & SOURCING BUG REGRESSION TESTS
# =============================================================================
# Prevents regressions of bugs found in the display/formatting layer and
# interactively-sourced files. Covers:
#
#   1. printf format strings with doubled backslashes (shfmt \\n bug)
#   2. Log functions outputting to stderr (not stdout)
#   3. OpenGrep display showing errors for 0 findings
#   4. Empty file display guards (syntax-errors, large-files, circular-deps)
#   5. set -euo pipefail in interactively-sourced files
#   6. Doctor/uninstall/install symlink coverage completeness
#   7. Missing >&2 redirects in display output
# =============================================================================

setup() {
    local repo_root
    repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export SHELL_CONFIG_DIR="$repo_root"
    export COLORS_LIB="$SHELL_CONFIG_DIR/lib/core/colors.sh"
}

# =============================================================================
# 🖨️ PRINTF FORMAT STRINGS - No doubled backslashes from shfmt
# shfmt doubles backslashes in printf single-quoted strings:
#   printf '\n' → printf '\\n' (literal \n instead of newline)
# =============================================================================

@test "printf-regression: colors.sh log functions produce real newlines (not literal \\n)" {
    # The most critical test: log_info must end with 0x0a (newline), not 0x5c 0x6e (\n)
    local output_hex
    output_hex=$(bash -c "source '$COLORS_LIB'; log_info 'test'" 2>&1 | xxd -p | tr -d '\n')

    # Must end with 0a (newline byte), NOT 5c6e (literal \n)
    [[ "$output_hex" == *"0a" ]]
    # Must NOT contain 5c6e (literal \n) anywhere
    [[ "$output_hex" != *"5c6e"* ]]
}

@test "printf-regression: colors.sh has no doubled backslash-n in printf format strings" {
    # Scan for the literal bytes 5c5c6e (\\n) in any printf line
    local line
    while IFS= read -r line; do
        # Get raw bytes of lines containing printf
        local hex
        hex=$(echo "$line" | xxd -p | tr -d '\n')
        # 5c5c6e = \\n (two backslashes + n) - this is the bug pattern
        if [[ "$hex" == *"5c5c6e"* ]]; then
            echo "FAIL: Doubled backslash found in: $line" >&2
            return 1
        fi
    done < <(grep "printf.*'" "$COLORS_LIB")
}

@test "printf-regression: reporters.sh has no doubled backslash-n in printf format strings" {
    local file="$SHELL_CONFIG_DIR/lib/validation/shared/reporters.sh"
    [ -f "$file" ] || skip "reporters.sh not found"

    while IFS= read -r line; do
        local hex
        hex=$(echo "$line" | xxd -p | tr -d '\n')
        if [[ "$hex" == *"5c5c6e"* ]]; then
            echo "FAIL: Doubled backslash found in: $line" >&2
            return 1
        fi
    done < <(grep "printf.*'" "$file")
}

@test "printf-regression: doctor.sh has no doubled backslash-n or backslash-033" {
    local file="$SHELL_CONFIG_DIR/lib/core/doctor.sh"
    [ -f "$file" ] || skip "doctor.sh not found"

    while IFS= read -r line; do
        local hex
        hex=$(echo "$line" | xxd -p | tr -d '\n')
        # Check for \\n (5c5c6e)
        if [[ "$hex" == *"5c5c6e"* ]]; then
            echo "FAIL: Doubled \\n found in: $line" >&2
            return 1
        fi
        # Check for \\033 (5c5c303333)
        if [[ "$hex" == *"5c5c303333"* ]]; then
            echo "FAIL: Doubled \\033 found in: $line" >&2
            return 1
        fi
    done < <(grep "printf.*'" "$file")
}

@test "printf-regression: hook-bootstrap.sh fallback log functions have correct format" {
    local file="$SHELL_CONFIG_DIR/lib/git/shared/hook-bootstrap.sh"
    [ -f "$file" ] || skip "hook-bootstrap.sh not found"

    while IFS= read -r line; do
        local hex
        hex=$(echo "$line" | xxd -p | tr -d '\n')
        if [[ "$hex" == *"5c5c6e"* ]]; then
            echo "FAIL: Doubled backslash found in: $line" >&2
            return 1
        fi
    done < <(grep "printf.*'" "$file")
}

@test "printf-regression: git reporters.sh has no doubled backslash-n" {
    local file="$SHELL_CONFIG_DIR/lib/git/shared/reporters.sh"
    [ -f "$file" ] || skip "git reporters.sh not found"

    while IFS= read -r line; do
        local hex
        hex=$(echo "$line" | xxd -p | tr -d '\n')
        if [[ "$hex" == *"5c5c6e"* ]]; then
            echo "FAIL: Doubled backslash found in: $line" >&2
            return 1
        fi
    done < <(grep "printf.*'" "$file")
}

@test "printf-regression: file-validator.sh has no doubled backslash-n" {
    local file="$SHELL_CONFIG_DIR/lib/validation/validators/core/file-validator.sh"
    [ -f "$file" ] || skip "file-validator.sh not found"

    while IFS= read -r line; do
        local hex
        hex=$(echo "$line" | xxd -p | tr -d '\n')
        if [[ "$hex" == *"5c5c6e"* ]]; then
            echo "FAIL: Doubled backslash found in: $line" >&2
            return 1
        fi
    done < <(grep "printf.*'" "$file")
}

# =============================================================================
# 📤 LOG FUNCTIONS OUTPUT TO STDERR
# Log functions must write to stderr so git hooks work correctly
# =============================================================================

@test "log-stderr: log_info outputs to stderr, not stdout" {
    local stdout stderr
    stdout=$(bash -c "source '$COLORS_LIB'; log_info 'test'" 2>/dev/null)
    stderr=$(bash -c "source '$COLORS_LIB'; log_info 'test'" 2>&1 >/dev/null)

    # stdout should be empty
    [ -z "$stdout" ]
    # stderr should contain the message
    [[ "$stderr" == *"test"* ]]
}

@test "log-stderr: log_error outputs to stderr, not stdout" {
    local stdout stderr
    stdout=$(bash -c "source '$COLORS_LIB'; log_error 'fail'" 2>/dev/null)
    stderr=$(bash -c "source '$COLORS_LIB'; log_error 'fail'" 2>&1 >/dev/null)

    [ -z "$stdout" ]
    [[ "$stderr" == *"fail"* ]]
}

@test "log-stderr: log_success outputs to stderr, not stdout" {
    local stdout stderr
    stdout=$(bash -c "source '$COLORS_LIB'; log_success 'ok'" 2>/dev/null)
    stderr=$(bash -c "source '$COLORS_LIB'; log_success 'ok'" 2>&1 >/dev/null)

    [ -z "$stdout" ]
    [[ "$stderr" == *"ok"* ]]
}

@test "log-stderr: log_warning outputs to stderr, not stdout" {
    local stdout stderr
    stdout=$(bash -c "source '$COLORS_LIB'; log_warning 'warn'" 2>/dev/null)
    stderr=$(bash -c "source '$COLORS_LIB'; log_warning 'warn'" 2>&1 >/dev/null)

    [ -z "$stdout" ]
    [[ "$stderr" == *"warn"* ]]
}

@test "log-stderr: log_step outputs to stderr, not stdout" {
    local stdout stderr
    stdout=$(bash -c "source '$COLORS_LIB'; log_step 'step'" 2>/dev/null)
    stderr=$(bash -c "source '$COLORS_LIB'; log_step 'step'" 2>&1 >/dev/null)

    [ -z "$stdout" ]
    [[ "$stderr" == *"step"* ]]
}

# =============================================================================
# 🔎 OPENGREP DISPLAY - No false error for 0 findings
# display_validation_results must check exit code, not just output existence
# =============================================================================

@test "opengrep-display: no error shown when exit code is 0 (clean scan)" {
    local display_file="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-display.sh"
    [ -f "$display_file" ] || skip "pre-commit-display.sh not found"

    # The display logic MUST check opengrep-exit-code, not just opengrep-output
    run grep -A5 "Display OpenGrep findings" "$display_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"opengrep-exit-code"* ]]
}

@test "opengrep-display: error shown only when exit code equals 1" {
    local display_file="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-display.sh"
    [ -f "$display_file" ] || skip "pre-commit-display.sh not found"

    # Must check for exit_code -eq 1 (findings found), not just -ne 0
    run grep "exit_code -eq 1" "$display_file"
    [ "$status" -eq 0 ]
}

# =============================================================================
# 📂 EMPTY FILE DISPLAY GUARDS
# Display functions must check -s (non-empty) not just -f (exists)
# =============================================================================

@test "display-guard: syntax-errors uses -s check (non-empty)" {
    local file="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-display.sh"
    [ -f "$file" ] || skip "pre-commit-display.sh not found"

    run grep "syntax-errors" "$file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-s"* ]]
}

@test "display-guard: large-files uses -s check (non-empty)" {
    local file="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-display.sh"
    [ -f "$file" ] || skip "pre-commit-display.sh not found"

    run grep "large-files" "$file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"-s"* ]]
}

@test "display-guard: circular-deps uses -s check (non-empty)" {
    local file="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-display.sh"
    [ -f "$file" ] || skip "pre-commit-display.sh not found"

    # The circular-deps line that checks the file should use -s
    run grep 'circular-deps.*-s\|circular-deps.*\[\[ -s' "$file"
    [ "$status" -eq 0 ]
}

# =============================================================================
# 🛡️ SET -EUO PIPEFAIL IN INTERACTIVELY-SOURCED FILES
# Files sourced by init.sh into interactive shells must NOT have set -euo
# =============================================================================

@test "strict-mode: git/wrapper.sh has no active set -euo pipefail" {
    run grep -E "^set -euo pipefail" "$SHELL_CONFIG_DIR/lib/git/wrapper.sh"
    [ "$status" -ne 0 ]
}

@test "strict-mode: 1password/secrets.sh has no active set -euo pipefail" {
    run grep -E "^set -euo pipefail" "$SHELL_CONFIG_DIR/lib/integrations/1password/secrets.sh"
    [ "$status" -ne 0 ]
}

@test "strict-mode: security/init.sh has no active set -euo pipefail" {
    run grep -E "^set -euo pipefail" "$SHELL_CONFIG_DIR/lib/security/init.sh"
    [ "$status" -ne 0 ]
}

@test "strict-mode: security/hardening.sh has no active set -euo pipefail" {
    run grep -E "^set -euo pipefail" "$SHELL_CONFIG_DIR/lib/security/hardening.sh"
    [ "$status" -ne 0 ]
}

@test "strict-mode: security/audit.sh has no active set -euo pipefail" {
    run grep -E "^set -euo pipefail" "$SHELL_CONFIG_DIR/lib/security/audit.sh"
    [ "$status" -ne 0 ]
}

# =============================================================================
# 🔗 SYMLINK COVERAGE - doctor, install, uninstall must cover all config files
# =============================================================================

@test "symlink-coverage: doctor.sh checks all 8 expected symlinks" {
    local file="$SHELL_CONFIG_DIR/lib/core/doctor.sh"
    [ -f "$file" ] || skip "doctor.sh not found"

    # All 8 symlinks that install.sh creates
    local expected=(
        ".shell-config"
        ".zshrc"
        ".zshenv"
        ".zprofile"
        ".bashrc"
        ".gitconfig"
        ".ssh/config"
        ".ripgreprc"
    )

    for symlink in "${expected[@]}"; do
        run grep "$symlink" "$file"
        if [ "$status" -ne 0 ]; then
            echo "FAIL: doctor.sh missing check for ~/$symlink" >&2
            return 1
        fi
    done
}

@test "symlink-coverage: uninstall.sh removes all 8 expected symlinks" {
    local file="$SHELL_CONFIG_DIR/uninstall.sh"
    local manager="$SHELL_CONFIG_DIR/lib/setup/symlink-manager.sh"
    [ -f "$file" ] || skip "uninstall.sh not found"

    local expected=(
        ".shell-config"
        ".zshrc"
        ".zshenv"
        ".zprofile"
        ".bashrc"
        ".gitconfig"
        ".ssh/config"
        ".ripgreprc"
    )

    # Paths may be in uninstall.sh directly or in the shared symlink-manager.sh
    for symlink in "${expected[@]}"; do
        run grep "$symlink" "$file" "$manager"
        if [ "$status" -ne 0 ]; then
            echo "FAIL: uninstall.sh/symlink-manager.sh missing removal for ~/$symlink" >&2
            return 1
        fi
    done
}

@test "symlink-coverage: install.sh creates all 8 expected symlinks" {
    local file="$SHELL_CONFIG_DIR/install.sh"
    local manager="$SHELL_CONFIG_DIR/lib/setup/symlink-manager.sh"
    [ -f "$file" ] || skip "install.sh not found"

    local expected=(
        ".shell-config"
        ".zshrc"
        ".zshenv"
        ".zprofile"
        ".bashrc"
        ".gitconfig"
        ".ssh/config"
        ".ripgreprc"
    )

    # Paths may be in install.sh directly or in the shared symlink-manager.sh
    for symlink in "${expected[@]}"; do
        run grep "$symlink" "$file" "$manager"
        if [ "$status" -ne 0 ]; then
            echo "FAIL: install.sh/symlink-manager.sh missing symlink for ~/$symlink" >&2
            return 1
        fi
    done
}

# =============================================================================
# 📤 DISPLAY STDERR REDIRECT
# All display output in pre-commit must go to stderr
# =============================================================================

@test "display-stderr: all display echo statements go to stderr" {
    local file="$SHELL_CONFIG_DIR/lib/git/stages/commit/pre-commit-display.sh"
    [ -f "$file" ] || skip "pre-commit-display.sh not found"

    # Check echo statements that are display output (start with spaces + echo)
    # Exclude: command substitutions like $(... || echo "0"), and lines inside $()
    local missing
    missing=$(grep -n '^ *echo ' "$file" | grep -v '>&2' | grep -v '\$(' || true)

    if [ -n "$missing" ]; then
        echo "FAIL: echo statements missing >&2 redirect:" >&2
        echo "$missing" >&2
        return 1
    fi
}

# =============================================================================
# 8. export -f in zsh leaks function definitions to stdout
# =============================================================================
# In zsh, `export -f func` is interpreted as `typeset -gx -f func` which PRINTS
# the function definition to stdout instead of exporting it. All export -f calls
# MUST be inside a BASH_VERSION guard.

@test "export-f-guard: cat.sh wraps export -f in BASH_VERSION guard" {
    local file="$SHELL_CONFIG_DIR/lib/integrations/cat.sh"
    [ -f "$file" ] || skip "cat.sh not found"

    # Must NOT have bare export -f (outside of BASH_VERSION block)
    # Check that every export -f CODE line is preceded (within 10 lines) by BASH_VERSION
    local bare_exports
    bare_exports=$(awk '
        /BASH_VERSION/ { guard=NR }
        /^[[:space:]]*#/ { next }
        /export -f/ { if (NR - guard > 10 || guard == 0) print NR": "$0 }
    ' "$file")

    if [[ -n "$bare_exports" ]]; then
        echo "FAIL: cat.sh has unguarded export -f:" >&2
        echo "$bare_exports" >&2
        return 1
    fi
}

@test "export-f-guard: no unguarded export -f in startup-sourced files" {
    # Files sourced during interactive shell startup via init.sh
    local startup_files=(
        "$SHELL_CONFIG_DIR/lib/core/colors.sh"
        "$SHELL_CONFIG_DIR/lib/core/command-cache.sh"
        "$SHELL_CONFIG_DIR/lib/core/platform.sh"
        "$SHELL_CONFIG_DIR/lib/core/logging.sh"
        "$SHELL_CONFIG_DIR/lib/core/traps.sh"
        "$SHELL_CONFIG_DIR/lib/integrations/cat.sh"
    )
    local failures=""
    for file in "${startup_files[@]}"; do
        [ -f "$file" ] || continue
        local bare
        bare=$(awk '
            /BASH_VERSION/ { guard=NR }
            /^[[:space:]]*#/ { next }
            /export -f/ { if (NR - guard > 10 || guard == 0) print FILENAME":"NR": "$0 }
        ' "$file")
        [[ -n "$bare" ]] && failures+="$bare"$'\n'
    done

    if [[ -n "$failures" ]]; then
        echo "FAIL: Unguarded export -f in startup files:" >&2
        echo "$failures" >&2
        return 1
    fi
}

@test "export-f-guard: cat.sh sourcing produces no stdout output" {
    # The most critical test: sourcing cat.sh must NOT print the function definition
    local output
    output=$(bash -c "
        export SHELL_CONFIG_DIR='$SHELL_CONFIG_DIR'
        source '$SHELL_CONFIG_DIR/lib/integrations/cat.sh'
    " 2>/dev/null)

    if [[ -n "$output" ]]; then
        echo "FAIL: cat.sh produced stdout output (likely unguarded export -f):" >&2
        echo "$output" | head -5 >&2
        return 1
    fi
}

# =============================================================================
# 9. Colors passed through printf %s are printed literally
# =============================================================================
# Colors defined as '\033[0;36m' (literal backslash) work when expanded in printf
# format strings, but NOT when passed through %s. Colors must always be in the
# format string, never in %s arguments.

@test "shortcuts-colors: no color variables passed as printf %s arguments" {
    local file="$SHELL_CONFIG_DIR/lib/welcome/shortcuts.sh"
    [ -f "$file" ] || skip "shortcuts.sh not found"

    # Look for patterns like: printf '...%s...' "...COLOR..."
    # where color vars are in the argument list with a single-quoted format string
    # This pattern causes literal \033 to be printed
    local bad_patterns
    bad_patterns=$(grep -n "printf '[^']*%s" "$file" | while IFS= read -r line; do
        local linenum="${line%%:*}"
        local content="${line#*:}"
        # Check if the same line or next line has _WM_COLOR as argument
        if echo "$content" | grep -q '_WM_COLOR.*%s\|%s.*_WM_COLOR'; then
            echo "$line"
        fi
    done)

    if [[ -n "$bad_patterns" ]]; then
        echo "FAIL: shortcuts.sh passes color variables through %s:" >&2
        echo "$bad_patterns" >&2
        return 1
    fi
}
