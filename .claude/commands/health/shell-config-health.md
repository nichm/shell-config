---
description: Shell-config specific health check - shellcheck, bash compatibility, tests, file sizes
argument-hint: [num-prs-to-review]
allowed-tools:
  Bash, Git, Read, Write, Edit, Glob, Grep, TodoWrite, AskUserQuestion
---

# Shell-Config Health Check

You are a senior engineer performing a comprehensive health check on the
shell-config repository. Your mission is to audit shell script quality, bash
compatibility, test coverage, and ensure the codebase meets shell-config
standards.

## Configuration

**PRs to Review:** $ARGUMENTS (default: 10 if not specified)

## Phase 1: Shell Script Quality

### 1.1 ShellCheck Compliance

```bash
# Run shellcheck on all shell scripts
echo "=== ShellCheck Scan ==="
find lib -name "*.sh" -exec shellcheck --severity=warning {} \; 2>&1 | head -50

# Count issues by severity
echo "=== Issue Summary ==="
find lib -name "*.sh" -exec shellcheck --format=gcc {} \; 2>&1 | grep -c "warning:" || echo "0 warnings"
find lib -name "*.sh" -exec shellcheck --format=gcc {} \; 2>&1 | grep -c "error:" || echo "0 errors"
```

### 1.2 Bash Version Requirement Check

```bash
echo "=== Bash Version Check ==="

# Verify bash version is 4.0+ (5.x recommended)
bash_version=$(bash -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null || echo "0")
if [[ "$bash_version" -ge 4 ]]; then
  echo "✅ Bash version: $bash_version (meets requirement)"
else
  echo "❌ Bash version: $bash_version (requires 4.0+, 5.x recommended)"
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "FIX: macOS users must run 'brew install bash'"
  fi
fi

# Check which bash is being used (macOS should use Homebrew bash)
which_bash=$(which bash 2>/dev/null || echo "not found")
echo "Bash location: $which_bash"
if [[ "$(uname)" == "Darwin" ]] && [[ ! "$which_bash" =~ ^/opt/homebrew/bin/bash ]] && [[ ! "$which_bash" =~ ^/usr/local/bin/bash ]]; then
  echo "⚠️  macOS detected but not using Homebrew bash"
  echo "FIX: Ensure Homebrew bash is installed and in PATH"
fi

# Reference to upgrade decision
echo ""
echo "See docs/architecture/BASH-5-UPGRADE.md for upgrade rationale"
```

### 1.3 File Size Compliance

```bash
# Target: 600 lines, Max: 800 lines
echo "=== File Size Check ==="

# Files over 800 lines (BLOCKED)
echo "--- Files over 800 lines (MUST SPLIT) ---"
wc -l lib/**/*.sh 2>/dev/null | awk '$1 > 800 && !/total/ { print "❌ BLOCKED:", $0 }'

# Files between 600-800 lines (WARNING)
echo "--- Files between 600-800 lines (consider splitting) ---"
wc -l lib/**/*.sh 2>/dev/null | awk '$1 > 600 && $1 <= 800 && !/total/ { print "⚠️ WARNING:", $0 }'

# Top 10 largest files
echo "--- Top 10 largest files ---"
wc -l lib/**/*.sh 2>/dev/null | sort -rn | head -11
```

## Phase 2: Testing & Coverage

### 2.1 Test Suite Health

```bash
# Run all tests
echo "=== Running Test Suite ==="
./tests/run_all.sh 2>&1 | tail -20

# Count test files
echo "=== Test Coverage ==="
echo "Test files: $(find tests -name "*.bats" | wc -l | tr -d ' ')"
echo "Source files: $(find lib -name "*.sh" | wc -l | tr -d ' ')"

# List test files
find tests -name "*.bats" -exec basename {} \; | sort
```

### 2.2 Test Helper Functions

```bash
# Check test infrastructure
test -f tests/test_helper.sh && echo "✅ test_helper.sh exists" || echo "❌ test_helper.sh missing"
test -f tests/run_all.sh && echo "✅ run_all.sh exists" || echo "❌ run_all.sh missing"
```

## Phase 3: Code Quality Patterns

### 3.1 Error Handling (WHAT/WHY/HOW format)

```bash
# Check for proper error message format
echo "=== Error Message Format Check ==="

# Look for echo "ERROR:" patterns
grep -rn 'echo.*ERROR:' lib/ | head -10

# Look for proper stderr usage
grep -rn '>&2' lib/ | wc -l | xargs echo "Lines using stderr:"

# Check for exit codes after errors
grep -rn 'exit 1' lib/ | wc -l | xargs echo "exit 1 statements:"
```

### 3.2 Trap Handlers for Temp Files

```bash
# Check for temp file usage and trap handlers
echo "=== Temp File Safety ==="

# Find mktemp usage
echo "Files using mktemp:"
grep -rln "mktemp" lib/

# Check for trap handlers in those files
for file in $(grep -rln "mktemp" lib/ 2>/dev/null); do
  if grep -q "trap.*EXIT\|trap.*INT" "$file"; then
    echo "✅ $file has trap handler"
  else
    echo "❌ $file MISSING trap handler"
  fi
done
```

### 3.3 Variable Quoting

```bash
# Check for common quoting issues
echo "=== Variable Quoting Check ==="

# Unquoted variables in conditionals (common issue)
grep -rn '\[ \$[^"]*\]' lib/ | head -10 && echo "⚠️ Unquoted variables in conditionals found" || echo "✅ No obvious quoting issues"
```

## Phase 4: Module Structure

### 4.1 Directory Organization

```bash
# Check directory structure
echo "=== Directory Structure ==="
ls -la lib/

# Key modules
for dir in lib/core lib/git lib/command-safety lib/validation lib/integrations lib/terminal lib/welcome; do
  test -d "$dir" && echo "✅ $dir exists" || echo "❌ $dir missing"
done
```

### 4.2 Core Module Health

```bash
# Check core modules
echo "=== Core Modules ==="

# colors.sh - shared colors
test -f lib/core/colors.sh && echo "✅ colors.sh exists" || echo "❌ colors.sh missing"

# logging.sh - shared logging
test -f lib/core/logging.sh && echo "✅ logging.sh exists" || echo "❌ logging.sh missing"

# git wrapper
test -f lib/git/core.sh && echo "✅ git/core.sh exists" || echo "❌ git/core.sh missing"

# command safety
test -f lib/command-safety/init.sh && echo "✅ command-safety/init.sh exists" || echo "❌ command-safety/init.sh missing"
```

## Phase 5: Configuration Files

### 5.1 Essential Files

```bash
# Check essential config files
echo "=== Configuration Files ==="
for file in .gitignore .editorconfig README.md CLAUDE.md AGENTS.md; do
  test -f "$file" && echo "✅ $file exists" || echo "⚠️ $file missing"
done

# Formatting config
test -f .editorconfig && echo "✅ .editorconfig" || echo "❌ .editorconfig missing"
```

### 5.2 Git Hooks

```bash
# Check git hooks
echo "=== Git Hooks ==="
ls -la lib/git/hooks/ 2>/dev/null | grep -v "\.sample\|disabled"

# Check for hook installation
test -f lib/git/setup.sh && echo "✅ Hook setup script exists" || echo "❌ Hook setup script missing"
```

## Phase 6: PR Analysis (Last N PRs)

### 6.1 Gather PR Context

```bash
# Get list of recent merged PRs
gh pr list --state merged --limit ${1:-10} --json number,title,author,mergedAt,headRefName --jq '.[] | "PR #\(.number): \(.title)"'
```

### 6.2 Shell-Config Specific PR Checks

For each PR, analyze:

**Shell Script Quality:**
- Did the PR introduce any shellcheck violations?
- Are new functions properly tested with bats?
- Does the PR document bash 5.x requirement where needed?

**File Size Impact:**
- Did the PR push any files over 600 lines?
- Should any modified files be split?

**Error Handling:**
- Do new error messages follow WHAT/WHY/HOW format?
- Are temp files properly cleaned up with trap handlers?

**Module Cohesion:**
- Are new functions placed in appropriate modules?
- Is there code duplication that should be refactored?

## Phase 7: Health Summary

### Generate Report

After all checks, create a summary:

```markdown
## Shell-Config Health Report - [DATE]

### Critical Issues (MUST FIX)
- [ ] Bash version < 4.0: [version found]
- [ ] Files over 600 lines: [list files]
- [ ] Missing trap handlers: [list files]

### Warnings (SHOULD FIX)
- [ ] ShellCheck warnings: [count]
- [ ] Files 600-800 lines: [list files]
- [ ] Tests without coverage: [list modules]

### Recommendations
- [ ] [Specific actionable items]

### Metrics
- Total shell scripts: X
- Total test files: X
- ShellCheck pass rate: X%
- Bash 5.x required: YES (4.0+ minimum, macOS: brew install bash)
```

## High-Risk Files to Always Check

| File | Risk | Reason |
|------|------|--------|
| `lib/bin/rm` | CRITICAL | Protected path deletion |
| `lib/git/core.sh` | HIGH | Security bypass flags |
| `lib/command-safety/engine/matcher.sh` | HIGH | Core matching logic |
| `lib/validation/api.sh` | HIGH | 721 lines - needs split |

## Success Criteria

- [ ] Bash version 4.0+ (5.x recommended)
- [ ] Zero files over 600 lines
- [ ] All tests passing
- [ ] ShellCheck clean at warning level
- [ ] Trap handlers for all temp files
- [ ] Error messages include WHAT/WHY/HOW

**Workflow Evolution:** After using this command, document any new patterns or
issues discovered for future health checks.
