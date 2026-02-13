# Shell-Config Validator API - Reference

**Version:** 1.0.0
**Last Updated:** 2026-02-04

---

## Table of Contents

1. [Core Functions](#core-functions)
2. [Validator Types](#validator-types)
3. [Error Handling](#error-handling)
4. [Context Handling](#context-handling)
5. [Debugging](#debugging)

---

## Core Functions

### `validator_register`

Register a new validator.

**Signature:**
```bash
validator_register <name> <type> <priority> <callback>
```

**Parameters:**
- `name` (string): Unique identifier for the validator
- `type` (string): Validator type (see [Validator Types](#validator-types))
- `priority` (integer): Execution order (lower = earlier, default: 50)
- `callback` (function): Bash function to execute

**Returns:**
- `0` on success
- `1` if validator already exists
- `2` if invalid parameters

**Example:**
```bash
validate_no_console_log() {
  local file="$1"
  if grep -q "console.log" "$file"; then
    echo "ERROR: console.log found in $file" >&2
    echo "WHY: console.log statements should not be committed" >&2
    echo "FIX: Remove the console.log statement" >&2
    return 1
  fi
  return 0
}

validator_register "no-console-log" "file" 10 validate_no_console_log
```

---

### `validator_run`

Run all validators of a specific type.

**Signature:**
```bash
validator_run <type> [context]
```

**Parameters:**
- `type` (string): Validator type to run
- `context` (string, optional): Context data (e.g., file paths, git diff)

**Returns:**
- `0` if all validators pass
- `1` if any validator fails
- `2` if no validators found for type

**Exit Behavior:**
- Continues executing all validators even if one fails
- Collects all failures and reports at the end

**Example:**
```bash
# Run all pre-commit validators
validator_run "pre-commit" "$(git diff --cached --name-only)"

# Run all file validators
validator_run "file" "/path/to/file.sh"
```

---

### `validator_exists`

Check if a validator is registered.

**Signature:**
```bash
validator_exists <name>
```

**Parameters:**
- `name` (string): Validator name to check

**Returns:**
- `0` if validator exists
- `1` if validator doesn't exist

**Example:**
```bash
if validator_exists "line-limits"; then
  echo "Line limits validator is registered"
fi
```

---

### `validator_list`

List all registered validators, optionally filtered by type.

**Signature:**
```bash
validator_list [type]
```

**Parameters:**
- `type` (string, optional): Filter by type

**Output Format:**
```
Name                    Type         Priority  Callback
----------------------  -----------  --------  -------------------
line-limits             file         10        validate_line_limits
syntax-check            pre-commit   20        validate_syntax
secret-scan             pre-commit   30        validate_secrets
```

**Example:**
```bash
# List all validators
validator_list

# List only pre-commit validators
validator_list "pre-commit"
```

---

### `validator_unregister`

Unregister a validator.

**Signature:**
```bash
validator_unregister <name>
```

**Parameters:**
- `name` (string): Validator name to unregister

**Returns:**
- `0` on success
- `1` if validator doesn't exist

**Example:**
```bash
validator_unregister "old-validator"
```

---

## Validator Types

### `pre-commit`

**Context:** Git pre-commit hook
**Purpose:** Validate changes before commit
**Context Data:** Staged file paths (newline-separated)

**Example:**
```bash
validator_register "my-pre-commit" "pre-commit" 10 my_validator

my_validator() {
  local files="$1"
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Validate each file
    validate_file "$file" || return 1
  done <<< "$files"
  return 0
}
```

---

### `pre-push`

**Context:** Git pre-push hook
**Purpose:** Validate before pushing to remote
**Context Data:** Target branch name

**Example:**
```bash
validator_register "branch-name-check" "pre-push" 10 check_branch_name

check_branch_name() {
  local target_branch="$1"
  if [[ "$target_branch" =~ ^main$|^master$ ]]; then
    echo "ERROR: Cannot push directly to $target_branch" >&2
    echo "WHY: Direct pushes to main/master break the PR workflow" >&2
    echo "FIX: Create a pull request instead" >&2
    return 1
  fi
  return 0
}
```

---

### `file`

**Context:** File operations
**Purpose:** Validate individual files
**Context Data:** Single file path

**Example:**
```bash
validator_register "file-size" "file" 10 check_file_size

check_file_size() {
  local file="$1"
  local size
  size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)

  if (( size > 1048576 )); then  # 1MB
    echo "ERROR: $file is too large ($((size / 1024))KB)" >&2
    echo "WHY: Large files slow down git operations and downloads" >&2
    echo "FIX: Use git-lfs for large files or reduce file size" >&2
    return 1
  fi
  return 0
}
```

---

### `syntax`

**Context:** Syntax checking
**Purpose:** Validate file syntax
**Context Data:** File content or path

**Example:**
```bash
validator_register "bash-syntax" "syntax" 10 check_bash_syntax

check_bash_syntax() {
  local file="$1"
  if ! shellcheck --severity=warning "$file" 2>/dev/null; then
    echo "ERROR: ShellCheck failed for $file" >&2
    echo "WHY: Bash syntax errors can break scripts and cause unexpected behavior" >&2
    echo "FIX: Run 'shellcheck $file' and fix reported issues" >&2
    return 1
  fi
  return 0
}
```

---

### `secret`

**Context:** Secret scanning
**Purpose:** Detect secrets/sensitive data
**Context Data:** File content or path

**Example:**
```bash
validator_register "api-key-scan" "secret" 10 scan_api_keys

scan_api_keys() {
  local file="$1"
  if grep -iE "API[_-]?KEY\s*=\s*['\"][^'\"]+['\"]" "$file"; then
    echo "WARNING: Possible API key found in $file" >&2
    echo "WHY: API keys committed to git can be leaked and abused" >&2
    echo "FIX: Remove the API key and use environment variables instead" >&2
    return 1
  fi
  return 0
}
```

---

### `dependency`

**Context:** Dependency validation
**Purpose:** Check dependencies for issues
**Context Data:** Package file path or dependency list

**Example:**
```bash
validator_register "npm-audit" "dependency" 10 run_npm_audit

run_npm_audit() {
  local package_file="$1"
  [[ "$(basename "$package_file")" != "package.json" ]] && return 0

  if ! npm audit --audit-level=high >/dev/null 2>&1; then
    echo "ERROR: npm audit found high-severity vulnerabilities" >&2
    echo "WHY: Security vulnerabilities can expose your application to attacks" >&2
    echo "FIX: Run 'npm audit fix' to automatically fix vulnerabilities" >&2
    return 1
  fi
  return 0
}
```

---

## Error Handling

### Standard Error Format

All validators should follow the error message format:

```bash
echo "ERROR: <what failed>" >&2
echo "WHY: <why it matters>" >&2
echo "FIX: <how to fix it>" >&2
```

**Example:**
```bash
if (( line_count > 600 )); then
  echo "ERROR: $file has $line_count lines" >&2
  echo "WHY: Files over 600 lines violate project standards" >&2
  echo "FIX: Split into smaller modules (target: <600 lines)" >&2
  return 1
fi
```

---

### Exit Codes

| Code | Meaning | Usage |
|------|---------|-------|
| 0 | Success | Validation passed |
| 1 | Validation Failed | Validation logic failed |
| 2 | System Error | Missing dependency, invalid input, etc. |

---

### Graceful Degradation

Validators should fail gracefully:

```bash
my_validator() {
  local file="$1"

  # Check if file exists
  if [[ ! -f "$file" ]]; then
    echo "WARNING: File not found: $file" >&2
    return 0  # Don't fail the entire validation
  fi

  # Check if required tool is available
  if ! command -v tool >/dev/null 2>&1; then
    echo "WARNING: tool not available, skipping validation" >&2
    return 0  # Don't fail if tool is missing
  fi

  # Perform validation
  ...
}
```

---

## Context Handling

### Pre-Commit Context

**Format:** Newline-separated file paths

**Example:**
```bash
file1.ts
file2.ts
src/utils/file3.js
```

**Parsing:**
```bash
my_validator() {
  local context="$1"
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    validate_file "$file" || return 1
  done <<< "$context"
  return 0
}
```

---

### File Context

**Format:** Single file path

**Example:**
```bash
/path/to/file.sh
```

**Parsing:**
```bash
my_validator() {
  local file="$1"
  # Directly use $file
  check_file "$file"
}
```

---

### Secret Context

**Format:** File path or content

**Example:**
```bash
# Path mode
/path/to/file.ts

# Content mode (if passed via stdin)
export API_KEY=sk-1234567890
```

**Parsing:**
```bash
my_validator() {
  local input="$1"
  if [[ -f "$input" ]]; then
    # File path mode
    scan_file "$input"
  else
    # Content mode
    scan_content "$input"
  fi
}
```

---

## Debugging

### Enable Debug Mode

```bash
export VALIDATOR_DEBUG=1
```

### Trace Validator Execution

```bash
# List all validators
validator_list

# Check if validator exists
validator_exists "my-validator"

# Run validator with context
validator_run "pre-commit" "$(git diff --cached --name-only)"
```

### Common Issues

1. **Validator not running**
   - Check if registered: `validator_exists "my-validator"`
   - Check type matches: `validator_list "pre-commit"`

2. **Context not received**
   - Ensure context is passed: `validator_run "type" "$context"`
   - Check parsing logic

3. **Exit codes ignored**
   - Ensure return codes are used (not exit)
   - Check for subshells that lose exit codes

---

*For more information, see:*
- [Quick Start](API-QUICKSTART.md) - Getting started guide
- [Examples](API-EXAMPLES.md) - Working examples
- [ARCHITECTURE](../ARCHITECTURE.md) - System architecture
