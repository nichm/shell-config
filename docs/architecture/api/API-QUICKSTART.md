# Shell-Config Validator API - Quick Start

**Version:** 1.0.0
**Last Updated:** 2026-02-04

---

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Basic Usage](#basic-usage)
4. [Your First Validator](#your-first-validator)
5. [Common Patterns](#common-patterns)
6. [Next Steps](#next-steps)

---

## Overview

The Shell-Config Validator API provides a pluggable framework for implementing validation checks at various points in the development workflow.

### Design Principles

- **Pluggable:** Easy to add new validators
- **Context-Aware:** Validators receive relevant context
- **Prioritized:** Control execution order
- **Non-Breaking:** Failed validators don't crash the system

---

## Installation

The Validator API is included with Shell-Config:

```bash
# The API is automatically loaded with init.sh
source ~/.shell-config/init.sh

# Or load it directly
source ~/.shell-config/lib/validation/api.sh
```

---

## Basic Usage

### Register a Validator

```bash
validator_register <name> <type> <priority> <callback>
```

**Parameters:**
- `name` (string): Unique identifier for the validator
- `type` (string): Validator type (`pre-commit`, `pre-push`, `file`, `syntax`, `secret`, `dependency`)
- `priority` (integer): Execution order (lower = earlier, default: 50)
- `callback` (function): Bash function to execute

### Run Validators

```bash
validator_run <type> [context]
```

**Parameters:**
- `type` (string): Validator type to run
- `context` (string, optional): Context data (e.g., file paths, git diff)

**Example:**

```bash
# Run all pre-commit validators
validator_run "pre-commit" "$(git diff --cached --name-only)"

# Run all file validators
validator_run "file" "/path/to/file.sh"
```

---

## Your First Validator

### Example: No Console Log Validator

```bash
#!/usr/bin/env bash
# =============================================================================
# no-console-log-validator.sh - Block console.log in production code
# =============================================================================

validate_no_console_log() {
  local file="$1"

  if grep -q "console.log" "$file"; then
    echo "ERROR: console.log found in $file" >&2
    echo "WHY: console.log statements should not be committed to production code" >&2
    echo "FIX: Remove the console.log statement or replace with proper logging" >&2
    return 1
  fi

  return 0
}

# Register the validator
validator_register "no-console-log" "file" 10 validate_no_console_log
```

### Using Your Validator

```bash
# Source the validator file
source ~/.shell-config/lib/validation/validators/no-console-log-validator.sh

# Run it manually
validator_run "file" "/path/to/file.js"

# Or use it in a pre-commit hook
validator_run "pre-commit" "$(git diff --cached --name-only)"
```

---

## Common Patterns

### 1. File Validation

```bash
validate_file_size() {
  local file="$1"
  local max_size="${VALIDATOR_MAX_SIZE:-1048576}"  # 1MB default

  if [[ ! -f "$file" ]]; then
    return 0  # Skip non-files
  fi

  local size
  size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)

  if (( size > max_size )); then
    echo "ERROR: $file is too large ($((size / 1024))KB)" >&2
    echo "WHY: Large files slow down git operations and downloads" >&2
    echo "FIX: Use git-lfs for large files or reduce file size" >&2
    return 1
  fi

  return 0
}
```

### 2. Syntax Checking

```bash
validate_bash_syntax() {
  local file="$1"

  # Only check .sh files
  [[ ! "$file" =~ \.sh$ ]] && return 0

  if ! shellcheck --severity=warning "$file" 2>/dev/null; then
    echo "ERROR: ShellCheck failed for $file" >&2
    echo "WHY: Bash syntax errors can break scripts and cause unexpected behavior" >&2
    echo "FIX: Run 'shellcheck $file' and fix reported issues" >&2
    return 1
  fi

  return 0
}
```

### 3. Pre-Commit Hooks

```bash
my_pre_commit_hook() {
  local files="$1"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    # Validate each file
    if ! validate_bash_syntax "$file"; then
      return 1
    fi
  done <<< "$files"

  return 0
}

# Register as pre-commit validator
validator_register "my-syntax-check" "pre-commit" 10 my_pre_commit_hook
```

### 4. Dependency Validation

```bash
validate_npm_audit() {
  local package_file="$1"

  # Only check package.json files
  [[ "$(basename "$package_file")" != "package.json" ]] && return 0

  # Check if npm is available
  if ! command -v npm >/dev/null 2>&1; then
    echo "WARNING: npm not available, skipping security audit" >&2
    return 0
  fi

  # Run npm audit
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

## Best Practices

### 1. Clear Error Messages

```bash
# ✅ Good - Follows WHAT/WHY/FIX format
echo "ERROR: File exceeds 600 line limit" >&2
echo "WHY: Large files are hard to maintain and review" >&2
echo "FIX: Split into smaller modules (target: <600 lines)" >&2

# ❌ Bad - Not descriptive enough
echo "File too big"
```

### 2. Non-Interactive

```bash
# ✅ Good - Fails loudly with clear error message
if ! command -v tool >/dev/null 2>&1; then
  echo "ERROR: tool not installed" >&2
  echo "WHY: This validator requires tool to function" >&2
  echo "FIX: Install tool using 'brew install tool'" >&2
  return 1
fi

# ❌ Bad - Interactive prompt (violates non-interactive requirement)
read -p "Install tool? (y/n) " answer
```

### 3. Handle Edge Cases

```bash
# ✅ Good - Handles empty input
if [[ -z "$context" ]]; then
  return 0  # Nothing to validate
fi

# ❌ Bad - Assumes input exists
for file in $context; do  # Breaks if context is empty
  ...
done
```

### 4. Use Appropriate Exit Codes

```bash
return 0  # Success
return 1  # Validation failure
return 2  # System error (missing dependency, etc.)
```

### 5. Log to stderr

```bash
# ✅ Good
echo "ERROR: Something went wrong" >&2

# ❌ Bad - Pollutes stdout
echo "ERROR: Something went wrong"
```

---

## Validator Types

| Type | Purpose | Context |
|------|---------|---------|
| `pre-commit` | Git pre-commit hooks | Git diff files (newline-separated) |
| `pre-push` | Git pre-push hooks | Target branch name |
| `file` | File validation | Single file path |
| `syntax` | Syntax checking | File content or path |
| `secret` | Secret scanning | File content or path |
| `dependency` | Dependency validation | Package file path |

---

## Next Steps

- **[API Reference](API-REFERENCE.md)** - Complete API documentation
- **[Examples](API-EXAMPLES.md)** - Working examples for common use cases
- **[ARCHITECTURE](../ARCHITECTURE.md)** - System architecture overview
- **[CLAUDE.md](../CLAUDE.md)** - Development guidelines

---

*For more information, see:*
- [README.md](../README.md) - User documentation
- [ARCHITECTURE.md](../ARCHITECTURE.md) - System architecture
- [CLAUDE.md](../CLAUDE.md) - Development guidelines
