# Shell-Config Validator API - Examples

**Version:** 1.0.0
**Last Updated:** 2026-02-04

---

## Table of Contents

1. [Example 1: Line Limit Validator](#example-1-line-limit-validator)
2. [Example 2: No-TODO Validator](#example-2-no-todo-validator)
3. [Example 3: Dependency License Validator](#example-3-dependency-license-validator)
4. [Example 4: TypeScript Path Alias Validator](#example-4-typescript-path-alias-validator)
5. [Example 5: Shell Script Portability Validator](#example-5-shell-script-portability-validator)
6. [Testing Validators](#testing-validators)

---

## Example 1: Line Limit Validator

```bash
#!/usr/bin/env bash
# =============================================================================
# line-limit-validator.sh - Enforce line count limits
# =============================================================================

validate_line_limits() {
  local file="$1"
  local max_lines="${VALIDATOR_MAX_LINES:-600}"

  # Check if file exists
  if [[ ! -f "$file" ]]; then
    return 0
  fi

  # Count lines
  local line_count
  line_count=$(wc -l < "$file")

  # Check limit
  if (( line_count > max_lines )); then
    echo "ERROR: $file has $line_count lines (exceeds $max_lines limit)" >&2
    echo "WHY: Large files are difficult to maintain and review" >&2
    echo "FIX: Split into smaller modules (target: <600 lines)" >&2
    return 1
  fi

  return 0
}

# Register
validator_register "line-limits" "file" 10 validate_line_limits
```

**Usage:**
```bash
# Source the validator
source ~/.shell-config/lib/validation/validators/line-limit-validator.sh

# Run manually
validator_run "file" "/path/to/large-file.sh"

# Use in pre-commit hook
validator_run "pre-commit" "$(git diff --cached --name-only)"
```

---

## Example 2: No-TODO Validator

```bash
#!/usr/bin/env bash
# =============================================================================
# no-todo-validator.sh - Block commits with TODO comments
# =============================================================================

validate_no_todo() {
  local files="$1"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    # Check for TODO/FIXME
    if grep -nE "TODO|FIXME" "$file" | head -5; then
      echo "ERROR: TODO/FIXME found in $file" >&2
      echo "WHY: Unfinished work should not be committed to the codebase" >&2
      echo "FIX: Complete the work or create a tracking issue" >&2
      return 1
    fi
  done <<< "$files"

  return 0
}

# Register
validator_register "no-todo" "pre-commit" 20 validate_no_todo
```

**Usage:**
```bash
# Source the validator
source ~/.shell-config/lib/validation/validators/no-todo-validator.sh

# Run in pre-commit
validator_run "pre-commit" "$(git diff --cached --name-only)"
```

---

## Example 3: Dependency License Validator

```bash
#!/usr/bin/env bash
# =============================================================================
# license-validator.sh - Check package.json for restrictive licenses
# =============================================================================

validate_licenses() {
  local package_file="$1"

  # Only check package.json files
  [[ "$(basename "$package_file")" != "package.json" ]] && return 0

  # Check if license-checker is available
  if ! command -v license-checker >/dev/null 2>&1; then
    echo "WARNING: license-checker not installed, skipping license check" >&2
    return 0
  fi

  # Check for GPL/AGPL licenses
  local output
  output=$(license-checker --production --json --failOn "GPL;AGPL" 2>&1)

  if [[ $? -ne 0 ]]; then
    echo "ERROR: Restrictive licenses found in $package_file" >&2
    echo "WHY: GPL/AGPL licenses may not be compatible with project license" >&2
    echo "FIX: Review and replace restrictive dependencies" >&2
    echo "$output" >&2
    return 1
  fi

  return 0
}

# Register
validator_register "license-check" "dependency" 30 validate_licenses
```

**Usage:**
```bash
# Install license-checker
npm install -g license-checker

# Source the validator
source ~/.shell-config/lib/validation/validators/license-validator.sh

# Run on package.json
validator_run "dependency" "package.json"
```

---

## Example 4: TypeScript Path Alias Validator

```bash
#!/usr/bin/env bash
# =============================================================================
# ts-path-validator.sh - Validate TypeScript path aliases
# =============================================================================

validate_ts_paths() {
  local file="$1"

  # Only check .ts/.tsx files
  [[ ! "$file" =~ \.(ts|tsx)$ ]] && return 0

  # Check for path aliases (e.g., @/components/Button)
  local imports
  imports=$(grep -oE "from ['\"]@/[^'\"]+['\"]" "$file" || true)

  if [[ -n "$imports" ]]; then
    # Check if tsconfig.json exists
    local tsconfig
    tsconfig="$(dirname "$file")/tsconfig.json"

    if [[ ! -f "$tsconfig" ]]; then
      echo "WARNING: Path aliases found but no tsconfig.json" >&2
      return 0
    fi

    # Validate paths against tsconfig
    # (simplified example)
    echo "$imports" | while read -r import; do
      [[ -z "$import" ]] && continue
      local path
      path=$(echo "$import" | sed 's/from.*@\///' | sed "s/[\"']//g")
      if ! grep -q "\"$path\"" "$tsconfig"; then
        echo "ERROR: Path alias @$path not defined in tsconfig.json" >&2
        echo "WHY: Undefined path aliases will cause TypeScript compilation errors" >&2
        echo "FIX: Add the path to tsconfig.json paths section" >&2
        return 1
      fi
    done
  fi

  return 0
}

# Register
validator_register "ts-paths" "file" 15 validate_ts_paths
```

**Usage:**
```bash
# Source the validator
source ~/.shell-config/lib/validation/validators/ts-path-validator.sh

# Run on TypeScript files
validator_run "file" "src/components/Button.tsx"
```

---

## Example 5: Shell Script Version Validator

```bash
#!/usr/bin/env bash
# =============================================================================
# bash-version-validator.sh - Ensure scripts use bash 5.x shebang
# =============================================================================

validate_bash_version() {
  local file="$1"

  # Only check .sh files
  [[ ! "$file" =~ \.sh$ ]] && return 0

  local errors=0

  # Check shebang uses env bash (portable)
  local shebang
  shebang=$(head -1 "$file")
  
  if [[ "$shebang" == "#!/bin/bash" ]]; then
    echo "ERROR: Hardcoded /bin/bash shebang found" >&2
    echo "FILE: $file" >&2
    echo "WHY: /bin/bash on macOS is 3.2.57; we require bash 5.x" >&2
    echo "FIX: Use #!/usr/bin/env bash for PATH-based resolution" >&2
    ((errors++))
  fi

  # Check for deprecated bash 3.x workaround patterns
  if grep -qE "# Bash 3.x|# bash 3|# macOS system bash" "$file"; then
    echo "WARNING: Outdated bash 3.x compatibility comment found" >&2
    echo "FILE: $file" >&2
    echo "INFO: Bash 5.x is now required - these comments can be removed" >&2
  fi

  if ((errors > 0)); then
    return 1
  fi

  return 0
}

# Register
validator_register "bash-version" "syntax" 25 validate_bash_version
```

**Usage:**
```bash
# Source the validator
source ~/.shell-config/lib/validation/validators/bash-version-validator.sh

# Run on shell scripts
validator_run "syntax" "/path/to/script.sh"
```

**Note:** As of the Bash 5.x upgrade (see [BASH-5-UPGRADE.md](../decisions/BASH-5-UPGRADE.md)),
modern bash features like `declare -A`, `readarray`, `${var,,}`, and `|&` are now allowed.

---

## Testing Validators

### Unit Testing

```bash
#!/usr/bin/env bash
# Test validator

test_validator() {
  local test_name="$1"
  local input="$2"
  local expected_result="$3"

  # Run validator
  your_validator "$input"
  local actual_result=$?

  # Check result
  if [[ $actual_result -eq $expected_result ]]; then
    echo "✓ $test_name"
    return 0
  else
    echo "✗ $test_name (expected $expected_result, got $actual_result)"
    return 1
  fi
}

# Run tests
test_validator "Valid file" "/path/to/valid/file.sh" 0
test_validator "Invalid file" "/path/to/invalid/file.sh" 1
```

---

### Integration Testing

```bash
#!/usr/bin/env bash
# Test validator in context

# Register validator
validator_register "test-validator" "pre-commit" 10 test_callback

# Run validator
test_callback() {
  local files="$1"
  # ... validation logic
}

# Test with real files
validator_run "pre-commit" "file1.ts
file2.ts
file3.ts"
```

---

## Validator Template

```bash
#!/usr/bin/env bash
# =============================================================================
# my-validator.sh - Brief description
# =============================================================================
# Longer description of what this validator does.
#
# Usage:
#   validator_register "my-validator" "pre-commit" 50 my_validator_callback
#
# Dependencies:
#   - tool1 (required)
#   - tool2 (optional)
# =============================================================================

my_validator_callback() {
  local context="$1"

  # Parse context
  # Perform validation
  # Return 0 on success, 1 on failure

  if [[ some_condition ]]; then
    echo "ERROR: What failed" >&2
    echo "WHY: Why it matters" >&2
    echo "FIX: How to fix it" >&2
    return 1
  fi

  return 0
}

# Optional: Auto-register if sourced directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This file should be sourced, not executed"
  exit 1
fi
```

---

## Best Practices Checklist

- [x] Clear error messages (WHAT/WHY/FIX)
- [x] Non-interactive (no prompts)
- [x] Handle edge cases (empty input, missing files)
- [x] Use appropriate exit codes
- [x] Log to stderr (not stdout)
- [x] Graceful degradation (skip if tool missing)
- [x] Safe file handling (handle spaces in filenames)

---

*For more information, see:*
- [Quick Start](API-QUICKSTART.md) - Getting started guide
- [API Reference](API-REFERENCE.md) - Complete API documentation
- [ARCHITECTURE](../ARCHITECTURE.md) - System architecture
