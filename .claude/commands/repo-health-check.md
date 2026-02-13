---
description: Comprehensive repository health check - validates PRs, standards, structure, and tooling
argument-hint: [num-prs-to-review]
allowed-tools:
  Bash, Git, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, TodoWrite,
  AskUserQuestion
---

# Repository Health Check (Shell-Config)

You are a senior engineer performing a comprehensive health check on shell-config.
Your mission is to audit recent changes, validate standards compliance, and
ensure the codebase remains maintainable and well-organized.

## Project Context

**Repository:** shell-config
**Type:** Shell configuration library (~10,000 lines bash/zsh)
**Primary Files:** `lib/**/*.sh` (117 source files)
**Testing:** `tests/**/*.bats` (28 test files)
**Linting:** shellcheck (severity: warning)

## Configuration

**PRs to Review:** $ARGUMENTS (default: 10 if not specified)

## Phase 1: Foundation Checks

### 1.1 Git Configuration Audit

```bash
# Check .gitignore exists and is comprehensive
test -f .gitignore && echo "✅ .gitignore exists" || echo "❌ .gitignore missing"
wc -l .gitignore

# Check for common patterns that should be ignored
grep -E "(\.env|\.DS_Store|logs)" .gitignore || echo "⚠️ May be missing common ignore patterns"

# Check git hooks
ls -la .git/hooks/ 2>/dev/null | grep -v "\.sample" || echo "No custom git hooks in .git/hooks"

# Check for secrets in tracked files
git ls-files | xargs grep -l "API_KEY\|SECRET\|PASSWORD\|TOKEN" 2>/dev/null | head -5 || echo "✅ No obvious secrets in tracked files"
```

### 1.2 Repository Configuration Files

```bash
# Check essential config files for shell-config
for file in .gitignore .editorconfig README.md CLAUDE.md VERSION; do
  test -f "$file" && echo "✅ $file exists" || echo "❌ $file missing"
done

# shell-config specific files
test -f init.sh && echo "✅ init.sh exists (main loader)" || echo "❌ init.sh missing"
test -f install.sh && echo "✅ install.sh exists (installer)" || echo "❌ install.sh missing"
test -d lib && echo "✅ lib/ directory exists" || echo "❌ lib/ missing"
test -d tests && echo "✅ tests/ directory exists" || echo "❌ tests/ missing"
```

## Phase 2: PR Analysis (Review Last N PRs)

### 2.1 Gather PR Context

```bash
# Get list of recent merged PRs
gh pr list --state merged --limit ${1:-10} --json number,title,author,mergedAt,headRefName,body,additions,deletions,changedFiles

# Get detailed PR info for analysis
gh pr list --state merged --limit ${1:-10} --json number,title,headRefName --jq '.[] | "PR #\(.number): \(.title) (\(.headRefName))"'
```

### 2.2 PR Health Analysis Criteria

For each PR, analyze and document:

**Refactoring Completeness:**
- Did the PR refactor one area but leave related areas inconsistent?
- Are there orphaned functions, dead code, or incomplete migrations?
- Were all references to renamed/moved items updated?

**Atomic Migration Quality:**
- Is this a complete port with no backwards compatibility shims?
- Are there any "temporary" workarounds that became permanent?

**PR Cohesion:**
- Do all the recent PRs work together coherently?
- Are there conflicting patterns introduced across PRs?

**File Structure Impact:**
- Are new files placed in appropriate lib/ subdirectories?
- Is the project tree still navigable and logical?

## Phase 3: Documentation & Standards Compliance

### 3.1 Documentation Currency

```bash
# Check README freshness
git log -1 --format="%ar" -- README.md 2>/dev/null || echo "README.md not found"

# Check CLAUDE.md freshness
git log -1 --format="%ar" -- CLAUDE.md 2>/dev/null || echo "CLAUDE.md not found"

# Check if documentation matches lib/ structure
echo "=== lib/ directories ==="
find lib -type d -maxdepth 1 | sort
```

## Phase 4: Quality Tooling Validation

### 4.1 ShellCheck Validation

```bash
# Check shellcheck is available
command -v shellcheck >/dev/null && echo "✅ shellcheck available: $(shellcheck --version | grep version:)" || echo "❌ shellcheck not installed"

# Run shellcheck on all shell scripts
echo "=== ShellCheck Results ==="
find lib -name "*.sh" -exec shellcheck --severity=warning {} \; 2>&1 | head -30
shellcheck_errors=$(find lib -name "*.sh" -exec shellcheck --severity=warning {} \; 2>&1 | grep -c "error\|warning" || echo 0)
echo "Total shellcheck issues: $shellcheck_errors"
```

### 4.2 Bats Testing

```bash
# Check bats is available
command -v bats >/dev/null && echo "✅ bats available: $(bats --version)" || echo "❌ bats not installed"

# Count test files
test_count=$(find tests -name "*.bats" 2>/dev/null | wc -l | tr -d ' ')
echo "Bats test files: $test_count"
```

## Phase 5: Code Quality & Maintainability

### 5.1 File Size Analysis

```bash
# Shell scripts: 600 lines target, 800 lines max per CLAUDE.md
echo "=== Shell Scripts Exceeding Limits ==="
echo "Files >800 lines (MUST SPLIT):"
find lib -type f -name "*.sh" -exec wc -l {} \; 2>/dev/null | awk '$1 > 800 {print "  ❌ " $0}' | sort -rn

echo ""
echo "Files >600 lines (should consider splitting):"
find lib -type f -name "*.sh" -exec wc -l {} \; 2>/dev/null | awk '$1 > 600 && $1 <= 800 {print "  ⚠️ " $0}' | sort -rn

# Count total
total_oversized=$(find lib -type f -name "*.sh" -exec wc -l {} \; 2>/dev/null | awk '$1 > 600 {count++} END {print count+0}')
echo ""
echo "Files exceeding 600 line limit: $total_oversized"
```

### 5.2 Bash Version Requirement Check

```bash
echo "=== Bash Version Check ==="

# Verify bash version is 4.0+ (5.x recommended)
bash_version=$(bash -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null || echo "0")
if [[ "$bash_version" -ge 4 ]]; then
  echo "  ✅ Bash version: $bash_version (meets requirement)"
else
  echo "  ❌ Bash version: $bash_version (requires 4.0+, 5.x recommended)"
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "  FIX: macOS users must run 'brew install bash'"
  fi
fi

# Check which bash is being used (macOS should use Homebrew bash)
which_bash=$(which bash 2>/dev/null || echo "not found")
echo "  Bash location: $which_bash"
if [[ "$(uname)" == "Darwin" ]] && [[ ! "$which_bash" =~ ^/opt/homebrew/bin/bash ]] && [[ ! "$which_bash" =~ ^/usr/local/bin/bash ]]; then
  echo "  ⚠️  macOS detected but not using Homebrew bash"
  echo "  FIX: Ensure Homebrew bash is installed and in PATH"
fi

# Reference to upgrade decision
echo ""
echo "  See docs/architecture/BASH-5-UPGRADE.md for upgrade rationale"
```

### 5.3 Trap Handler Verification

```bash
echo "=== Temp File Safety ==="

# Files using mktemp
echo "Files using mktemp:"
grep -rln 'mktemp' lib/ 2>/dev/null | head -10

# Check if they have trap handlers
echo ""
echo "Checking for trap handlers in files using mktemp..."
for file in $(grep -rln 'mktemp' lib/ 2>/dev/null); do
  if grep -q 'trap.*EXIT\|trap.*cleanup' "$file" 2>/dev/null; then
    echo "  ✅ $file has trap handler"
  else
    echo "  ⚠️ $file may be missing trap handler"
  fi
done
```

### 5.4 Shared Colors Library Usage

```bash
echo "=== Color Definition Check ==="

# Check for inline color definitions (should use lib/core/colors.sh)
echo "Files with inline color definitions (should use colors.sh):"
grep -rln "RED=.*033\|GREEN=.*033" lib/ 2>/dev/null | grep -v "colors.sh" | head -10 || echo "  ✅ None found (good!)"
```

### 5.5 Dead Code Detection

```bash
echo "=== TODO/FIXME/HACK Comments ==="
grep -rn "TODO\|FIXME\|HACK\|XXX" lib/ --include="*.sh" 2>/dev/null | head -20
todo_count=$(grep -rn "TODO\|FIXME\|HACK\|XXX" lib/ --include="*.sh" 2>/dev/null | wc -l | tr -d ' ')
echo "Total TODO/FIXME/HACK/XXX: $todo_count"
```

## Phase 6: Test Coverage Analysis

### 6.1 Test Coverage Gaps

```bash
echo "=== Test Coverage Analysis ==="

# Count source files vs test files
src_count=$(find lib -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
test_count=$(find tests -name "*.bats" 2>/dev/null | wc -l | tr -d ' ')
echo "Source files: $src_count"
echo "Test files: $test_count"
echo "Ratio: $(echo "scale=1; $test_count * 100 / $src_count" | bc 2>/dev/null || echo "N/A")%"

# Key modules that should have tests
echo ""
echo "Key modules test coverage:"
for module in git command-safety validation gha-security 1password ghls; do
  src=$(find lib/$module -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
  tests=$(find tests -name "*${module}*.bats" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$src" -gt 0 ]; then
    echo "  $module: $src source files, $tests test files"
  fi
done
```

## Phase 7: Health Report Generation

After gathering all data, create a comprehensive health report.

## Quality Gates

Before completing the health check, verify:

- [ ] All critical issues documented
- [ ] Warnings categorized and prioritized
- [ ] Standards compliance assessed
- [ ] File size analysis complete
- [ ] Bash 5.x requirement documented (4.0+ minimum)
- [ ] Test coverage assessed
- [ ] Action items are specific and actionable

## Completion Protocol

1. **Generate full report** as `docs/health-check-[date].md`
2. **Summarize findings** for immediate review
3. **Propose fixes** for automated remediation
4. **Track progress** on action items

Remember: A healthy shell-config repository ensures reliable shell configuration
for all users. Identify friction points and provide clear paths to resolution.

**Workflow Evolution:** After using this command, analyze the process and update
the checks based on issues discovered for continuous improvement.
