# Bash for TypeScript/Node.js Developers

A comprehensive guide for developers coming from the TypeScript/React/Vite ecosystem.

---

## Tool Equivalents: What You Already Know

| TypeScript Ecosystem | Bash/Shell Equivalent | Install | Repo Status |
|---------------------|----------------------|---------|-------------|
| **Prettier** | *(none - not enforced)* | — | — |
| **ESLint** | **ShellCheck** | ✅ installed | ✅ v0.9.0 active |
| **TypeScript Language Server** | **bash-language-server** | `brew install bash-language-server` | ⚠️ Optional |
| **Vitest / Jest** | **bats-core** | `brew install bats-core` | ✅ Configured |
| **GitHub Actions Lint** | **actionlint** | `brew install actionlint` | ✅ Configured |
| **Prettier Eslint** | **shellharden** | `brew install shellharden` | ❌ Not configured |
| **Git Secrets** | **Gitleaks** | ✅ installed | ✅ Active in hooks |
| **tsx / ts-node** | Direct execution (`./script.sh`) | N/A | N/A |
| **package.json** | N/A (no package manager) | N/A | N/A |
| **node_modules** | Homebrew / apt | N/A | N/A |
| **npm scripts** | Makefile | N/A | ✅ Created |
| **tsconfig.json** | `.editorconfig` | N/A | ✅ Configured |

---

## Quick Start: Installation Checklist

Run these commands to set up your development environment:

```bash
# 1. Install core validators (required)
make install-deps
# Or manually:
brew install shellcheck bats-core actionlint

# 2. Optional: IDE language server for autocomplete
brew install bash-language-server

# 3. Verify installation
make check-deps
```

### VS Code Setup

The repository includes `.vscode/settings.json` and `.vscode/extensions.json` for automatic IDE configuration. When you open the project in VS Code, you'll be prompted to install recommended extensions:

- **ShellCheck** - Linting (like ESLint)
- **shell-format** - Formatting (like Prettier)
- **Bash IDE** - Autocomplete, hover docs, go-to-definition
- **BATS** - Test file syntax highlighting

**Important:** The VS Code settings include:
- ShellCheck on-type validation (as you type)
- bash-language-server integration
- File associations for executables without extension

---

## Your Toolchain

### 1. ShellCheck (ESLint equivalent)

**Install:** `brew install shellcheck`

```bash
# Check single file
shellcheck --severity=warning lib/git/wrapper.sh

# Check all shell scripts
find lib -name "*.sh" -exec shellcheck --severity=warning {} \;
```

**VS Code Extension:** [ShellCheck](https://marketplace.visualstudio.com/items?itemName=timonwong.shellcheck)

**Common warnings you'll see:**

| Code | What | Fix |
|------|------|-----|
| SC2086 | Unquoted variable | Use `"$var"` not `$var` |
| SC2046 | Unquoted command substitution | Use `"$(cmd)"` not `$(cmd)` |
| SC2034 | Unused variable | Remove or use the variable |
| SC2155 | Declare and assign separately | `local var; var=$(cmd)` |

### 2. bats-core (Vitest/Jest equivalent)

**Install:** `brew install bats-core`

```bash
# Run all tests
./tests/run_all.sh

# Run single test file
bats tests/command-safety/rules.bats
```

**Writing tests:**

```bash
#!/usr/bin/env bats

@test "addition works" {
    result="$(echo $((2 + 2)))"
    [ "$result" -eq 4 ]
}

@test "file exists" {
    [ -f "lib/init.sh" ]
}

@test "command succeeds" {
    run ./my-script.sh
    [ "$status" -eq 0 ]
}
```

### 4. Makefile (Unified Task Runner)

Instead of remembering individual commands, use the Makefile:

```bash
# Show all available commands
make help

# Run all validation checks
make validate

# Individual commands
make lint           # Run ShellCheck
make format         # Format all scripts
make format-check   # Check formatting without modifying
make test           # Run BATS tests

# Utilities
make install-deps   # Install all development tools
make check-deps     # Verify tools are installed
make install-hooks  # Install git hooks for pre-commit validation
make verify-hooks   # Verify git hooks are properly installed
make stats          # Show project statistics
```

**TypeScript equivalent:**
- `make validate` → `npm run lint && npm test`
- `make format` → `npm run format`
- `make test` → `npm test`

### 5. bash-language-server (TypeScript Language Server equivalent)

**Install:** `brew install bash-language-server`

Provides TypeScript-like IDE features:
- **Autocomplete** - Variables, functions, commands
- **Hover documentation** - Function signatures, command help
- **Go-to-definition** - Jump to function definitions
- **Find references** - See where functions are used

**VS Code extension:** [Bash IDE](https://marketplace.visualstudio.com/items?itemName=mads-hartmann.bash-ide-vscode)

Already configured in `.vscode/settings.json` - just install the extension and language server.

### 6. actionlint (GitHub Actions Linter)

**Install:** `brew install actionlint`

Validates GitHub Actions workflow files:

```bash
# Check all workflows
actionlint .github/workflows/*.yml

# With config file
actionlint -config-file .github/actionlint.yaml .github/workflows/*.yml
```

**Features:**
- Syntax validation
- ShellCheck integration for workflow scripts
- Expression validation
- Job dependency checking

### 7. EditorConfig

Already configured in `.editorconfig` - your editor should pick this up automatically.

---

## Syntax Comparison: TypeScript vs Bash

### Variables

```typescript
// TypeScript
const name = "nick";
let count = 5;
const arr = [1, 2, 3];
const obj = { key: "value" };
```

```bash
# Bash
name="nick"          # No spaces around =
count=5              # Still no spaces!
arr=(1 2 3)          # Arrays use parentheses
declare -A obj       # Associative arrays require declaration
obj[key]="value"     # Then assign
```

**Critical:** No spaces around `=` in assignments. `name = "nick"` is a syntax error.

### Functions

```typescript
// TypeScript
function greet(name: string): void {
    console.log(`Hello, ${name}`);
}

const add = (a: number, b: number): number => a + b;
```

```bash
# Bash
greet() {
    local name="$1"  # Parameters are positional: $1, $2, etc.
    echo "Hello, ${name}"
}

add() {
    local a="$1"
    local b="$2"
    echo $((a + b))  # Return via echo (stdout)
}

# Call functions
greet "nick"
result=$(add 2 3)  # Capture output
```

### Conditionals

```typescript
// TypeScript
if (name === "nick" && count > 0) {
    console.log("match");
} else if (count === 0) {
    console.log("zero");
}
```

```bash
# Bash - use [[ ]] for conditionals
if [[ "$name" == "nick" && "$count" -gt 0 ]]; then
    echo "match"
elif [[ "$count" -eq 0 ]]; then
    echo "zero"
fi
```

**Comparison operators:**

| TypeScript | Bash (strings) | Bash (numbers) |
|------------|----------------|----------------|
| `===` | `==` | `-eq` |
| `!==` | `!=` | `-ne` |
| `<` | `<` (alphabetic) | `-lt` |
| `>` | `>` (alphabetic) | `-gt` |
| `<=` | N/A | `-le` |
| `>=` | N/A | `-ge` |

### Loops

```typescript
// TypeScript
for (const item of items) {
    console.log(item);
}

for (let i = 0; i < 10; i++) {
    console.log(i);
}
```

```bash
# Bash
for item in "${items[@]}"; do
    echo "$item"
done

for ((i = 0; i < 10; i++)); do
    echo "$i"
done

# Or sequence
for i in {0..9}; do
    echo "$i"
done
```

### String Interpolation

```typescript
// TypeScript
const message = `Hello ${name}, you have ${count} items`;
```

```bash
# Bash - double quotes, NOT backticks
message="Hello ${name}, you have ${count} items"
```

**Critical:** Backticks in bash mean command substitution (old syntax): `` `date` `` runs the `date` command.

### Arrays

```typescript
// TypeScript
const arr = ["a", "b", "c"];
arr.push("d");
console.log(arr[0]);
console.log(arr.length);
arr.forEach(item => console.log(item));
```

```bash
# Bash
arr=("a" "b" "c")
arr+=("d")              # Append
echo "${arr[0]}"        # First element
echo "${#arr[@]}"       # Length
for item in "${arr[@]}"; do
    echo "$item"
done
```

### Objects / Maps

```typescript
// TypeScript
const config = { host: "localhost", port: 3000 };
console.log(config.host);
```

```bash
# Bash (requires bash 4+)
declare -A config
config[host]="localhost"
config[port]=3000
echo "${config[host]}"

# Or inline (bash 4+)
declare -A config=(["host"]="localhost" ["port"]=3000)
```

### Async/Await → Command Execution

```typescript
// TypeScript
const result = await fetch(url);
const data = await result.json();
```

```bash
# Bash - everything is synchronous by default
result=$(curl -s "$url")

# Run in background with &
curl -s "$url" &
pid=$!
wait $pid  # Wait for completion
```

### Error Handling

```typescript
// TypeScript
try {
    riskyOperation();
} catch (error) {
    console.error("Failed:", error);
    process.exit(1);
}
```

```bash
# Bash - check exit codes
if ! risky_operation; then
    echo "ERROR: risky_operation failed" >&2
    exit 1
fi

# Or with set -e (exit on first error)
set -e
risky_operation  # Script exits if this fails
```

---

## Major Gotchas Coming from TypeScript

### 1. Whitespace is Significant (Sometimes)

```bash
# WRONG - spaces around = cause errors
name = "nick"   # Tries to run "name" as command with args "=" and "nick"

# CORRECT
name="nick"
```

### 2. Quoting is Critical

```bash
# WRONG - word splitting breaks this
file="my file.txt"
rm $file          # Runs: rm my file.txt (two files!)

# CORRECT
rm "$file"        # Runs: rm "my file.txt" (one file)
```

**Rule:** Always quote variables: `"$var"`, `"${arr[@]}"`, `"$(command)"`.

### 3. No Return Values (Only Exit Codes + stdout)

```bash
# WRONG - can't return strings
get_name() {
    return "nick"  # Error! return only accepts integers 0-255
}

# CORRECT - echo to stdout, capture with $()
get_name() {
    echo "nick"
}
name=$(get_name)
```

### 4. Exit Codes are Inverted from Booleans

| | Success | Failure |
|-|---------|---------|
| TypeScript | `true` | `false` |
| Bash exit code | `0` | `1-255` |

```bash
# This is CORRECT (0 = success = truthy in conditionals)
if command; then
    echo "command succeeded"
fi

# Check explicitly
if [[ $? -eq 0 ]]; then
    echo "last command succeeded"
fi
```

### 5. Subshells Lose Variables

```bash
# WRONG - variables set in pipe subshells are lost
cat file.txt | while read line; do
    count=$((count + 1))
done
echo "$count"  # Still 0!

# CORRECT - use process substitution
while read line; do
    count=$((count + 1))
done < <(cat file.txt)
echo "$count"  # Correct value
```

### 6. stderr vs stdout

```bash
# stdout - normal output (goes to terminal or pipe)
echo "This is output"

# stderr - errors/diagnostics (still shows even when piped)
echo "ERROR: something failed" >&2
```

### 7. Single vs Double Quotes

```bash
name="nick"

# Double quotes: variables ARE expanded
echo "Hello $name"   # Hello nick

# Single quotes: variables are NOT expanded
echo 'Hello $name'   # Hello $name (literal)
```

### 8. [[ ]] vs [ ] vs test

```bash
# PREFER [[ ]] - bash-specific, safer, more features
if [[ "$name" == "nick" ]]; then

# AVOID [ ] - POSIX, weird edge cases
if [ "$name" = "nick" ]; then  # Note: single = for equality

# AVOID test - same as [ ]
if test "$name" = "nick"; then
```

---

## Bash Shortcomings vs TypeScript

| Issue | TypeScript | Bash |
|-------|------------|------|
| **Type safety** | Full static typing | None - everything is strings |
| **Error handling** | try/catch/finally | Exit codes + `set -e` |
| **Package manager** | npm/pnpm/yarn | None (use brew/apt) |
| **Debugging** | DevTools, source maps | `set -x`, echo statements |
| **IDE support** | Excellent | Basic (ShellCheck helps) |
| **Refactoring** | Type-safe renaming | Text search/replace |
| **Dependencies** | Semantic versioning | Hope the tool is installed |
| **Portability** | node runs everywhere | bash 3 vs 4 vs 5 differences |

---

## Best Practices for This Project

### File Header Template

```bash
#!/usr/bin/env bash
# =============================================================================
# script-name.sh - Brief description
# =============================================================================
# Longer description explaining purpose, dependencies, and usage.
#
# Usage:
#   ./script-name.sh [options] <argument>
#
# Options:
#   -h, --help    Show this help message
#   -v, --verbose Enable verbose output
# =============================================================================

set -euo pipefail  # Exit on error, unset var, pipe fail
```

### Error Message Format (Required)

```bash
echo "ERROR: gitleaks not installed" >&2
echo "WHY: Required for secrets scanning in pre-commit hooks" >&2
echo "FIX: brew install gitleaks" >&2
exit 1
```

### Temp File Cleanup

```bash
temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT INT TERM
# Use temp_file...
```

### Check Dependencies

```bash
if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq not installed" >&2
    echo "WHY: Required for JSON parsing" >&2
    echo "FIX: brew install jq" >&2
    exit 1
fi
```

---

## Debugging Tips

### See What's Happening

```bash
# Print each command before running (like --verbose)
set -x

# Turn off
set +x
```

### Print Variables

```bash
# Debug print
echo "DEBUG: name=$name, count=$count" >&2
```

### Check Exit Codes

```bash
some_command
echo "Exit code: $?"
```

### Run with Debug Output

```bash
bash -x ./script.sh
```

---

## Quick Reference Card

```bash
# Variables
name="value"              # Set (no spaces!)
echo "$name"              # Use (always quote!)
echo "${name:-default}"   # Default if unset

# Arrays
arr=(a b c)              # Create
arr+=("d")               # Append
"${arr[@]}"              # All elements
"${#arr[@]}"             # Length
"${arr[0]}"              # First element

# Conditionals
[[ -f file ]]            # File exists
[[ -d dir ]]             # Directory exists
[[ -n "$var" ]]          # Variable not empty
[[ -z "$var" ]]          # Variable empty
[[ "$a" == "$b" ]]       # String equality
[[ "$n" -eq 5 ]]         # Numeric equality

# Functions
func() { echo "hi"; }    # Define
result=$(func)           # Call and capture

# Exit codes
exit 0                   # Success
exit 1                   # Failure
$?                       # Last exit code

# I/O
>&2                      # Redirect to stderr
>/dev/null               # Discard output
2>&1                     # Merge stderr to stdout
```

---

## Resources

### Core Documentation
- [ShellCheck Wiki](https://github.com/koalaman/shellcheck/wiki) - Explains every warning
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Pitfalls](https://mywiki.wooledge.org/BashPitfalls) - Common mistakes
- [Advanced Bash Scripting Guide](https://tldp.org/LDP/abs/html/)
- [explainshell.com](https://explainshell.com) - Paste command, get explanation

### Project-Specific
- [CLAUDE.md](/CLAUDE.md) - Project quality standards and conventions
- [docs/architecture/BASH-5-UPGRADE.md](/docs/architecture/BASH-5-UPGRADE.md) - Why bash 5 is required
- [Makefile](/Makefile) - Unified task runner commands
- [.vscode/settings.json](/.vscode/settings.json) - IDE configuration

### Tools
- [bats-core documentation](https://bats-core.readthedocs.io/) - Testing framework
- [bash-language-server](https://github.com/bash-lsp/bash-language-server) - Language server
- [actionlint](https://github.com/rhysd/actionlint) - GitHub Actions linter

---

## Pre-Commit Workflow

When you commit changes, these checks run automatically:

1. ✅ **File length validation** - Blocks files over 800 lines
2. ✅ **Sensitive filename detection** - Blocks `.env`, `.pem`, credentials
3. ✅ **Syntax validation** - Checks shell, YAML, JS/TS, Python
4. ✅ **Code formatting** - Prettier checks (JS/TS/JSON/YAML)
5. ✅ **Gitleaks secrets scan** - Blocks leaked secrets
6. ✅ **OpenGrep security scan** - Additional security checks
7. ⚠️ **Large file detection** - Warns about files >5MB
8. ⚠️ **Commit size analysis** - Warns about large commits

**Note:** Pre-commit hooks must be installed for automatic validation. Use `make install-hooks` to set them up.

**Bypass hooks (emergency only):**
```bash
GIT_SKIP_HOOKS=1 git commit -m "message"
# Or:
git commit --no-verify -m "message"
```

**Format and fix before committing:**
```bash
# Auto-fix formatting
GIT_AUTO_FIX_FORMAT=1 git commit -m "message"
```

---

## CI/CD Integration

The repository has CI workflows configured. To enable them:

### Re-enabling CI Workflows

Due to security permissions, the CI workflow files are currently disabled. To enable them:

```bash
# Re-enable CI workflow
mv .github/workflows/ci.yml.disabled .github/workflows/ci.yml
git add .github/workflows/ci.yml
git commit -m "feat: enable CI workflow with shellcheck and bats"

# Optionally re-enable security scan
mv .github/workflows/gha-security-scan.yml.disabled .github/workflows/gha-security-scan.yml
```

### What CI Does

Once enabled, CI will run:
- **ShellCheck** - Lint all shell scripts
- **BATS tests** - Run test suite on macOS runner
- **actionlint** - Validate GitHub Actions workflows
- **Security scans** - Multi-engine scanning (actionlint, zizmor, poutine)

---

## Common Development Tasks

### Before Committing

```bash
# 1. Format your code
make format

# 2. Check formatting
make format-check

# 3. Run linter
make lint

# 4. Run tests
make test

# 5. Run all checks
make validate
```

### Creating New Scripts

1. **Use the template header** from `Best Practices` above
2. **Source shared libraries:**
   ```bash
   source "$SHELL_CONFIG_DIR/lib/core/colors.sh"
   source "$SHELL_CONFIG_DIR/lib/core/logging.sh"
   ```
3. **Add temp file cleanup:**
   ```bash
   temp_file=$(mktemp)
   trap 'rm -f "$temp_file"' EXIT INT TERM
   ```
4. **Check dependencies:**
   ```bash
   if ! command -v tool >/dev/null 2>&1; then
       echo "ERROR: tool not installed" >&2
       echo "WHY: Required for X" >&2
       echo "FIX: brew install tool" >&2
       exit 1
   fi
   ```
5. **Use proper error messages** (WHAT, WHY, HOW format)

### Writing Tests

Create test file in `tests/` directory:

```bash
#!/usr/bin/env bats

@test "function does X" {
    # Arrange
    source lib/path/to/script.sh

    # Act
    result=$(your_function "input")

    # Assert
    [ "$result" == "expected" ]
}

@test "command succeeds" {
    run your_command
    [ "$status" -eq 0 ]
}

@test "file exists after operation" {
    run your_command
    [ -f "expected_file.txt" ]
}
```

Run tests: `make test` or `make test-single TEST=tests/your-test.bats`

---

*Last updated: 2026-02-04*
