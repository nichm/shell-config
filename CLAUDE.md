# Shell-Config AI Development Guidelines

**Scope:** ~21,600 lines bash/zsh, 154 source files, 102 test files
**Platform:** macOS (Apple Silicon) primary, Linux secondary, **never Windows**
**Tools:** shellcheck, bats

> **Note:** `AGENTS.md` and `.cursorrules` are **symlinks** to `CLAUDE.md` — only edit `CLAUDE.md`. Changes propagate automatically.

---

## Platform Requirements

```
┌─────────────┬───────────────────┬─────────┬──────────────────────┐
│ Component   │ macOS             │ Linux   │ Notes                │
├─────────────┼───────────────────┼─────────┼──────────────────────┤
│ Bash        │ 5.x (Homebrew)    │ 5.x     │ Bash 4+ required     │
│ Zsh         │ 5.9               │ 5.4+    │ Default interactive  │
│             │                   │         │   shell              │
│ macOS Setup │ brew install bash │ N/A     │ Required on macOS    │
└─────────────┴───────────────────┴─────────┴──────────────────────┘
```

### Bash 5.x Requirement

**Minimum:** Bash 4.0+ | **Recommended:** Bash 5.x

macOS ships with bash 3.2.57 (GPLv2). You **must** install Homebrew bash:

```bash
brew install bash
# Verify: bash --version shows 5.x
# Verify: which bash shows /opt/homebrew/bin/bash
```

### Modern Bash Features (Now Allowed)

```bash
# ✅ Associative arrays
declare -A config=(["key"]="value" ["other"]="data")

# ✅ readarray / mapfile
readarray -t lines < <(git diff --cached --name-only)

# ✅ Case conversion
lower="${var,,}"
upper="${var^^}"

# ✅ Stderr pipe shorthand
command |& grep "error"
```

See [docs/architecture/BASH-5-UPGRADE.md](docs/architecture/BASH-5-UPGRADE.md) for full rationale.

### Platform Detection (REQUIRED)

**All platform-specific code MUST use centralized platform detection:**

```bash
source "$(dirname "${BASH_SOURCE[0]}")/core/platform.sh"

if is_macos; then
    size=$(stat -f%z "$file")    # macOS stat syntax
elif is_linux; then
    size=$(stat -c%s "$file")    # Linux stat syntax
fi
```

**Available Functions:** `is_macos()`, `is_linux()`, `is_wsl()`, `is_bsd()`

**Global Variables:** `$SC_OS`, `$SC_ARCH`, `$SC_LINUX_DISTRO`, `$SC_PKG_MANAGER`, `$SC_HOMEBREW_PREFIX`

**Also available:** `pkg_install "name"`, `platform_log_info "msg"`, `platform_log_warning`, `platform_log_error`

**❌ DO NOT:** Use `[[ "$OSTYPE" == darwin* ]]` directly, check `uname -s` inline, or define platform detection in individual scripts.

### Command Cache (Performance Optimization)

Use the command cache for all command existence checks to avoid repeated subshell spawns:

```bash
source "$SHELL_CONFIG_DIR/lib/core/command-cache.sh"

if command_exists "git"; then echo "git exists"; fi
if ! command_exists "node"; then
    echo "❌ ERROR: Node.js not found" >&2
    echo "ℹ️  WHY: Required for running certain tools like Inshellisense" >&2
    echo "💡 FIX: Install Node.js (e.g., 'brew install node') and retry" >&2
    exit 1
fi
```

**Available functions:** `command_exists <cmd>` (cached), `command_cache_clear`, `command_cache_stats`

---

## Quality Standards (Enforced)

### Script Header Standard

```bash
#!/usr/bin/env bash
# =============================================================================
# script-name.sh - Brief description of what this script does
# =============================================================================
# Longer description if needed, explaining dependencies and context.
#
# Usage:
#   ./script-name.sh [options] <argument>
# =============================================================================
```

### Strict Mode (REQUIRED for Critical Scripts)

**All critical scripts MUST use strict mode:**

```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Required for:** high-risk files (`lib/bin/rm`, `lib/git/wrapper.sh`, `lib/command-safety/engine/*.sh`), install/setup scripts, anything that modifies system state. **To disable for specific commands:** `command || true` or temporarily `set +e` / `set -e`.

### File Size Limits

```
┌───────────┬───────┬─────────────────┐
│ Threshold │ Lines │ Action          │
├───────────┼───────┼─────────────────┤
│ Target    │   600 │ Ideal           │
│ Warning   │   700 │ Consider split  │
│ BLOCKED   │  800+ │ Must split      │
└───────────┴───────┴─────────────────┘
```

### Testing (REQUIRED)

- Every new function MUST have tests
- **Every bug fix MUST have a regression test** in `tests/regression/` to prevent recurrence
- Run `./tests/run_all.sh` before commit

**Regression test convention** — add a test to the appropriate file in `tests/regression/`:
- `cross-shell-compat.bats` — Bash/Zsh compatibility issues
- `command-prefix-recursion.bats` — `command cat/mv/rm` wrapper recursion prevention
- `git-safety-integration.bats` — Git wrapper, safety checks, fast-path bypasses
- `command-safety-matchers.bats` — Rule matching engine
- `command-parser-security.bats` — Git command parser
- `protected-paths-regression.bats` — Protected path validation
- `config-loading.bats` — Config file parsing
- `display-and-sourcing-bugs.bats` — Display/sourcing issues
- `file-scanner-regression.bats` — File scanner edge cases
- `git-utils-regression.bats` — Git utility functions
- Create a new regression file for a new category of bug

### Non-Interactive Commands & Error Format (CRITICAL)

**All scripts MUST:** run without user input, fail loudly with clear errors, exit non-zero on failure, never hang.

Every error MUST include **WHAT** failed, **WHY** it matters, **HOW** to fix:

```bash
if ! command_exists "gitleaks"; then
    echo "❌ ERROR: gitleaks not installed" >&2
    echo "ℹ️  WHY: Required for secrets scanning in pre-commit hooks" >&2
    echo "💡 FIX: brew install gitleaks" >&2
    exit 1
fi
```

### Error Handling Patterns (Standardized)

#### Pattern 1: WHAT/WHY/FIX (Required for Critical Dependencies)

Use when a tool is **essential** for the script to function (see format above).

#### Pattern 2: Silent Return (Internal Helpers & Optional Features)

Use for **internal helpers** (caller provides error handling) or **optional features** (fallback behavior):

```bash
# Internal helper — caller provides WHAT/WHY/FIX
_op_check_auth() {
    command_exists "op" || return 1
    # ...
}

# Optional feature — graceful degradation
_load_config_yaml() {
    local config_file="$1"
    [[ -f "$config_file" ]] || return 0
    command_exists "yq" || return 0  # Falls back to .conf files
    # ...
}
```

#### Pattern 3: Log Warning (Optional Tools)

Use when an **optional tool** is missing but you want to inform the user:

```bash
if ! _wf_check_tool "actionlint"; then
    _gha_log_warning "actionlint not installed (brew install actionlint)"
    return 2
fi
```

#### Decision Tree

```
Is the tool critical for the script's core functionality?
├─ YES → Pattern 1 (WHAT/WHY/FIX)
└─ NO
    ├─ Is this an internal helper, or is there fallback behavior?
    │   └─ YES → Pattern 2 (Silent return, with comment)
    └─ Should user be informed?
        ├─ YES → Pattern 3 (Log warning)
        └─ NO → Pattern 2 (Silent return)
```

---

## Mandatory Patterns

### 0. Use Shared Colors Library (REQUIRED)

```bash
source "$(dirname "${BASH_SOURCE[0]}")/core/colors.sh"
# Use $COLOR_RED, $COLOR_GREEN, $COLOR_RESET, etc.
# Or aliases: $RED, $GREEN, $NC

# ❌ WRONG - Never define inline colors
local RED='\033[0;31m'
```

**Available variables:**
- Basic: `COLOR_RED`, `COLOR_GREEN`, `COLOR_YELLOW`, `COLOR_BLUE`, `COLOR_CYAN`
- Formatting: `COLOR_BOLD`, `COLOR_DIM`, `COLOR_RESET`
- Aliases: `RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `BOLD`, `DIM`, `NC`

**With Fallback:** source `colors.sh` with `[[ -f ... ]]` guard, else define `readonly RED/GREEN/NC` as fallback.

### 1. Trap Handlers for Temp Files

```bash
temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT INT TERM
```

<details>
<summary><b>Multiple temp files pattern</b></summary>

```bash
TEMP_FILES=()
cleanup() {
    for f in "${TEMP_FILES[@]}"; do
        rm -f "$f" 2>/dev/null || true
    done
}
trap cleanup EXIT INT TERM

temp1=$(mktemp); TEMP_FILES+=("$temp1")
temp2=$(mktemp); TEMP_FILES+=("$temp2")
```

</details>

### 2. Handle Filenames with Spaces

```bash
while IFS= read -r file; do
    process "$file"
done < <(git diff --cached --name-only)
```

### 3. Don't Pipe curl to sh

```bash
# ❌ BAD - Security risk
curl -fsSL https://example.com/install.sh | sh

# ✅ GOOD - Download, verify, then execute
curl -fsSL https://example.com/install.sh -o /tmp/install.sh
cat /tmp/install.sh  # Review the script
sh /tmp/install.sh && rm /tmp/install.sh
```

### 4. Cross-Shell Compatibility (REQUIRED for Sourced Files)

**CRITICAL:** Files sourced into interactive shells (init.sh, command-safety engine, welcome modules) **MUST** be compatible with both Bash 5.x and Zsh 5.9+.

#### No `set -euo pipefail` in Sourced Files

```bash
# ❌ WRONG — kills the interactive shell on any command failure
set -euo pipefail

# ✅ CORRECT — comment explaining why
# NOTE: No set -euo pipefail here — this file is sourced into interactive shells
# where set -e would cause the shell to exit on any command failure.
```

#### Cross-Shell Patterns

```
┌──────────────┬────────────────────────┬───────────────────────────────────────────┐
│ Pattern      │ Bash-only              │ Cross-shell                               │
├──────────────┼────────────────────────┼───────────────────────────────────────────┤
│ Uppercase    │ ${var^^}               │ if ZSH_VERSION: ${(U)var} else ${var^^}   │
│ Lowercase    │ ${var,,}               │ if ZSH_VERSION: ${(L)var} else ${var,,}   │
│ Array read   │ read -ra               │ if ZSH_VERSION: read -rA else read -ra    │
│ Indirect     │ ${!var}                │ if ZSH_VERSION: ${(P)var} else ${!var}    │
│ Nameref      │ local -n ref="$name"   │ if ZSH_VERSION: ref=("${(@P)name}") else  │
│              │                        │   local -n                                │
│ Array keys   │ ARRAY["$key"]=val      │ ARRAY[$key]=val (no quotes in subscript)  │
│ Dynamic arr  │ declare -ga "NAME=()"  │ eval "typeset -ga NAME=()"                │
└──────────────┴────────────────────────┴───────────────────────────────────────────┘
```

**Regression tests:** `tests/regression/cross-shell-compat.bats` (31 tests)

### 5. Use `command` Prefix for cat/mv/rm in Sourced Files (REQUIRED)

**CRITICAL:** All code sourced into interactive shells MUST use `command cat`, `command mv`, `command rm` instead of bare `cat`, `mv`, `rm`. These commands are wrapped by the command-safety engine, and calling them bare from core code causes **infinite recursion**:

```
mv → MV_GIT info rule → _log_violation → atomic_append → mv → MV_GIT → ...
```

```bash
# ❌ WRONG — triggers command-safety wrappers, causes infinite recursion
cat "$log_file" > "$temp_file"
mv "$temp_file" "$log_file"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

# ✅ CORRECT — bypasses wrappers
command cat "$log_file" > "$temp_file"
command mv "$temp_file" "$log_file"
trap 'command rm -rf "$tmpdir"' EXIT INT TERM
```

**Affected areas (all fixed, tested):**
- `lib/core/logging.sh` — atomic_write, atomic_append, _rotate_log
- `lib/core/traps.sh` — _trap_cleanup_handler
- `lib/core/ensure-audit-symlink.sh` — symlink removal
- `lib/core/loaders/completions.sh` — uv completion cleanup
- `lib/security/audit.sh` — security-audit, clear-violations
- `lib/security/rm/audit.sh` — rm-audit-clear
- `lib/git/stages/` — pre-commit, commit-msg, prepare-commit-msg, pre-push traps
- `lib/git/shared/metrics.sh` — metrics log rotation
- `lib/validation/api-internal.sh` — temp dir cleanup
- `lib/validation/validators/typescript/env-security-validator.sh` — gitignore read

**Regression tests:** `tests/regression/command-prefix-recursion.bats` (17 tests)

### 6. Declare `local` Variables Outside Loops (Zsh Compatibility)

In Zsh, declaring `local` inside a loop body **re-declares** the variable on each iteration, printing its value to stdout. Always declare loop variables **before** the loop:

```bash
# ❌ WRONG — Zsh prints "msg=..." on each iteration
while true; do
    local msg="$(_get_value "$i")"
done

# ✅ CORRECT — declare once before loop
local msg=""
while true; do
    msg="$(_get_value "$i")"
done
```

**Regression tests:** `tests/regression/git-safety-integration.bats` (27 tests)

---

## Protected Paths Module

The `lib/core/protected-paths.sh` module provides centralized protected path validation. Security-critical — must be used by all code that performs destructive operations.

```bash
source "${SHELL_CONFIG_DIR}/lib/core/protected-paths.sh"

# Check if a path is protected and get message type
if message_type=$(get_protected_path_type "$path"); then
    echo "Path is protected: $message_type"
    # Message types: protected-path, config-file, system-path, macos-system-path
fi

# Convenience wrapper — only returns exit code
is_protected "$path" && echo "Protected"
```

**Constants:** `PROTECTED_SSH_DIR`, `PROTECTED_GNUPG_DIR`, `PROTECTED_SHELL_CONFIG_DIR`, `PROTECTED_CONFIG_DIR`

**Security:** Symlink resolution via `readlink -f`, blocks `..` traversal, O(1) case-statement matching.

**Consumers:** `lib/bin/rm`, `lib/security/rm/wrapper.sh`, `lib/integrations/1password/ssh-sync.sh`, `lib/welcome/shortcuts.sh`

**IMPORTANT**: When modifying protected path logic, update both the function and `tests/core/protected-paths.bats`.

---

## Welcome/MOTD

The welcome script (`lib/welcome/main.sh`) displays a greeting followed by live status grids that verify each feature at render time. The Terminal Status grid (`terminal-status.sh`) and Git Hooks grid (`git-hooks-status.sh`) replace the old "Features Loaded" list — they show the same information with real-time check/cross indicators.

**Required MOTD sections (in order):**

1. Greeting: `👋 Hey username • date`
2. Terminal Status grid (security, tools, zsh plugins, safety/alias counts)
3. Git Hooks & Validators grid (commit pipeline, push/merge pipeline)
4. Autocomplete Guide (keybindings for fzf, inshellisense, autosuggestions)
5. Shortcuts (top aliases)
6. Shell startup time (color-coded: green <200ms, yellow <400ms, red >=400ms)

---

## High-Risk Files

```
┌──────────────────────────────────────────┬──────────┬────────────────────────────────────────────────┐
│ File                                     │ Risk     │ Reason                                         │
├──────────────────────────────────────────┼──────────┼────────────────────────────────────────────────┤
│ lib/bin/rm                               │ CRITICAL │ Protected path deletion                        │
│ lib/core/protected-paths.sh              │ HIGH     │ Centralized path validation — symlink          │
│                                          │          │   resolution, bypass prevention                │
│ lib/git/wrapper.sh                       │ HIGH     │ Security bypass flags                          │
│ lib/command-safety/engine/matcher.sh     │ HIGH     │ Core matching engine                           │
│ lib/command-safety/engine/registry.sh    │ HIGH     │ Rule metadata storage                          │
│ install.sh                               │ HIGH     │ Symlinks, idempotent                           │
└──────────────────────────────────────────┴──────────┴────────────────────────────────────────────────┘
```

---

## Git Commit Requirements

1. All validations pass (shellcheck, tests, file length)
2. No secrets (gitleaks scan)
3. Tests included for new code
4. Non-interactive, fails loudly

### Bypass Flags (Logged to ~/.shell-config-audit.log)

```
┌────────────────────┬─────────────────────────────────────────────┐
│ Flag               │ Purpose                                     │
├────────────────────┼─────────────────────────────────────────────┤
│ --no-verify        │ Skip all hooks (emergency)                  │
│ --skip-secrets     │ Skip secrets scan (false positives)         │
│ --allow-large-files│ Skip size check                             │
└────────────────────┴─────────────────────────────────────────────┘
```

---

## AI Agent Rules

### DO

- Run shellcheck on every change
- Run tests for modified modules
- **Write regression tests** for every bug fix (in `tests/regression/`)
- Use `command cat/mv/rm` in sourced files (Mandatory Pattern 5)
- Use parameter expansion (`${var%/*}`) instead of `dirname`/`basename` subshells

### DON'T

- Assume macOS system bash (require Homebrew bash)
- Skip validations or commit without tests
- Create files >600 lines
- Use interactive prompts or fail silently

---

## Emoji Vocabulary (Standardized)

Emojis are **high-density semantic markers** (1-2 tokens each) for instant visual categorization. All emoji below are **safe for terminal use** — single codepoint, Emoji_Presentation=Yes, consistent 2-cell width.

### Severity / Status

```
┌────┬─────────────────────────────────┬──────────────────────────────────────────────┐
│ 🔴 │ DANGER                          │ Blocked, destructive operations              │
│ 🟡 │ WARNING                         │ Caution advised (rebase, force operations)   │
│ 🛑 │ BLOCKED                         │ Commit/action blocked by validation          │
│ 🟠 │ Warning (non-blocking)          │ Formatting, timeouts, dependency changes     │
│ ✅ │ Success / Pass                  │ Status checks, log_success                   │
│ ❌ │ Error / Fail                    │ Status checks, log_error                     │
│ ⏳ │ Pending / Lazy-loaded           │ Zsh plugins not yet active                   │
│ 🔵 │ Info / In Progress              │ AI warnings, skipped checks                  │
└────┴─────────────────────────────────┴──────────────────────────────────────────────┘
```

**Note:** Replaced `⚠️` (VS16-dependent) with `🟠` (orange circle), `ℹ️` with `🔵` (blue circle). Text checkmark `✓` can be used inline when emoji would misalign.

### Domain-Specific

```
┌────┬─────────────────────────────────┬──────────────────────────────────────────────┐
│ 🔐 │ Secrets / 1Password / Auth      │ 1Password module, sensitive files check      │
│ 🔑 │ SSH keys                        │ Terminal status, key management              │
│ 🔒 │ Security validators             │ Validator module headers                     │
│ 🛡️ │ Security / Protection           │ Security sections, gha-scan                  │
│ 🕵️ │ Secrets scanning (Gitleaks)     │ Pre-commit secrets detection                 │
│ 🔎 │ Deep security scan (OpenGrep)   │ Pre-commit checks, git status                │
│ 🔍 │ Search / Syntax validation      │ Validators, fzf, code search                 │
└────┴─────────────────────────────────┴──────────────────────────────────────────────┘
```

**Note:** `🛡️` and `🕵️` use VS16 but render consistently on macOS terminals. If alignment issues occur, replace `🛡️` with `🔒` (lock).

### Tools / Features

```
┌────┬─────────────────────────────────┬──────────────────────────────────────────────┐
│ 🪝 │ Git hooks                       │ Git hooks status display                     │
│ 🗑️ │ rm / Delete protection          │ Terminal status, rm wrapper                  │
│ 📐 │ File length check               │ Pre-commit validation                        │
│ 📦 │ Large files / Dependencies      │ Large file check, package deps               │
│ 🧪 │ Tests                           │ Test coverage check, pre-push                │
│ 🎨 │ Formatting / Syntax highlighting│ Code formatting check, zsh themes            │
│ ⚙️ │ Framework / Config              │ Framework config check                       │
│ 🔗 │ Symlinks / Circular deps        │ Symlink creation, circular deps              │
│ 📋 │ Config files / Dependency check │ 1Password config, yamllint                   │
│ 📚 │ Documentation links             │ Command safety docs                          │
└────┴─────────────────────────────────┴──────────────────────────────────────────────┘
```

**Note:** `🗑️` uses VS16 but is consistently 2-wide. `⚙️` (gear) is safe single-codepoint.

### Vibes / Communication

```
┌────┬─────────────────────────────────┬──────────────────────────────────────────────┐
│ 👋 │ Welcome / Goodbye               │ Welcome message, uninstall                   │
│ 🚀 │ Ship it! / Performance          │ Pre-commit success, startup time             │
│ ⚡ │ Fast / Features / Performance   │ Features loaded, startup time, setup         │
│ 💪 │ All healthy                     │ Doctor all-pass summary                      │
│ 🩺 │ Diagnostics                     │ Doctor tool header                           │
│ 💡 │ Tips / Hints                    │ Autosuggestions, verify steps                │
│ 🔧 │ Setup / Step progress           │ log_step prefix, install steps               │
│ 👉 │ Call to action                  │ Next steps, important notices                │
│ 🎬 │ actionlint                      │ GitHub Actions linter                        │
│ 🐚 │ Shell / shellcheck              │ Zsh, shellcheck tool icon                    │
│ 🐍 │ Python / ruff                   │ Python linter tool icon                      │
│ 🤖 │ Claude CLI                      │ AI tool icon                                 │
│ 🔮 │ Inshellisense                   │ Autocomplete prediction                      │
└────┴─────────────────────────────────┴──────────────────────────────────────────────┘
```

**Note:** All single-codepoint, safe for terminal tables. When adding new emojis, check this vocabulary first to avoid duplicates.

---

## Quick Reference

```bash
# Lint all scripts
find lib -name "*.sh" -exec shellcheck --severity=warning {} \;

# Run all tests
./tests/run_all.sh

# Check file sizes
wc -l lib/**/*.sh | sort -rn | head -20
```

---

*Last updated: 2026-02-10 | Enforced via code review and git hooks*
