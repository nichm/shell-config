---
description: Audit and reduce code comments - remove fluff, consolidate TODOs, enforce best practices
argument-hint: [target-path-or-all]
allowed-tools:
  Bash, Git, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, TodoWrite,
  AskUserQuestion, LS
---

# Code Comment Cleanup & Optimization (Shell Scripts)

You are performing a periodic comment audit on shell-config to reduce code bloat
while preserving valuable documentation. Run this command every ~10 PRs or when
codebase feels cluttered.

## Project Context

**Repository:** shell-config  
**Type:** Shell configuration library  
**Comment Style:** `#` for single-line, no block comments in shell

**Target:** $ARGUMENTS (default: "." if not specified - entire repo)

---

## Shell Script Comment Best Practices

### Comments to KEEP

1. **Bug/Issue References**: `# Fixed: GH-123 race condition on concurrent writes`
2. **Non-obvious Logic**: `# Using trap to ensure cleanup on SIGINT/SIGTERM`
3. **Bash Version Notes**: `# Requires Bash 5.x (4.0+ minimum, macOS: brew install bash)`
4. **Security Notes**: `# SECURITY: Input sanitized before eval`
5. **ShellCheck Directives**: `# shellcheck disable=SC2086`
6. **Complex Regex Explanations**: Pattern matching explanations
7. **External API Quirks**: `# GitHub API returns 200 even on partial failure`

### Comments to REMOVE

1. **Obvious Code Narration**: `# increment counter` before `((counter++))`
2. **Change Logs in Code**: `# Updated 2024-01-15 by Nick` (use git history)
3. **Commented-out Code**: Dead code without clear "keep for reference" reason
4. **Redundant Function Docs**: `# Gets user by ID` above `get_user_by_id()`
5. **TODO/FIXME without Context**: `# TODO: fix this` (no actionable info)
6. **Copy-paste Artifacts**: Repeated boilerplate comments
7. **Excessive Dividers**: `###############################`

### Comment Quality Guidelines

- **Self-documenting code > comments**: Rename variables/functions first
- **Why > What**: Explain reasoning, not mechanics
- **Keep comments near code**: Avoid header blocks that drift from implementation
- **Update or delete**: Stale comments are worse than no comments

---

## Phase 1: Baseline Metrics

### 1.1 Count Total Comment Lines

```bash
echo "=== Comment Line Counts ==="
TARGET="${1:-.}"

echo ""
echo "🐚 Shell Scripts:"
sh_total=$(find "$TARGET" -type f -name "*.sh" \
  -not -path "*/.git/*" \
  -exec cat {} \; 2>/dev/null | grep -cE "^\s*#" || echo 0)
sh_code=$(find "$TARGET" -type f -name "*.sh" \
  -not -path "*/.git/*" \
  -exec cat {} \; 2>/dev/null | wc -l | tr -d ' ')
echo "  Comment lines: $sh_total"
echo "  Total lines: $sh_code"
echo "  Ratio: $(echo "scale=1; $sh_total * 100 / $sh_code" | bc 2>/dev/null || echo "N/A")%"

echo ""
echo "🧪 Bats Test Files:"
bats_total=$(find "$TARGET" -type f -name "*.bats" \
  -exec cat {} \; 2>/dev/null | grep -cE "^\s*#" || echo 0)
bats_code=$(find "$TARGET" -type f -name "*.bats" \
  -exec cat {} \; 2>/dev/null | wc -l | tr -d ' ')
echo "  Comment lines: $bats_total"
echo "  Total lines: $bats_code"
```

### 1.2 Identify Comment-Heavy Files

```bash
echo "=== Files with Highest Comment Density ==="
TARGET="${1:-.}"

for f in $(find "$TARGET" -type f -name "*.sh" -not -path "*/.git/*" 2>/dev/null); do
  total=$(wc -l < "$f" 2>/dev/null || echo 0)
  if [ "$total" -gt 50 ]; then
    comments=$(grep -cE "^\s*#" "$f" 2>/dev/null || echo 0)
    ratio=$(echo "scale=0; $comments * 100 / $total" | bc 2>/dev/null || echo 0)
    if [ "$ratio" -gt 25 ]; then
      echo "$ratio% ($comments/$total lines): $f"
    fi
  fi
done | sort -rn | head -20
```

---

## Phase 2: Identify Comment Anti-Patterns

### 2.1 Find Obvious/Redundant Comments

```bash
echo "=== Obvious/Redundant Comments ==="
TARGET="${1:-.}"

# Comments that just restate the code
echo ""
echo "🔍 Code Narration (# increment, # return, # set variable):"
grep -rn --include="*.sh" \
  -E "#\s*(increment|decrement|return|set|get|add|remove|update|delete|create|check|loop|iterate)" \
  "$TARGET" 2>/dev/null | head -15

echo ""
echo "🔍 Function name restatement:"
grep -rn --include="*.sh" -B1 "^function\|^[a-z_]*\s*()" "$TARGET" 2>/dev/null | \
  grep -E "#.*function|#.*does" | head -10
```

### 2.2 Find Stale/Changelog Comments

```bash
echo "=== Changelog-Style Comments (use git history instead) ==="
TARGET="${1:-.}"

echo ""
echo "🔍 Date-based Comments:"
grep -rn --include="*.sh" --include="*.bats" \
  -E "#.*20[0-9]{2}" \
  "$TARGET" 2>/dev/null | head -15

echo ""
echo "🔍 Author Attribution in Comments:"
grep -rn --include="*.sh" --include="*.bats" \
  -iE "#.*(author|created by|updated by|modified by)" \
  "$TARGET" 2>/dev/null | head -10
```

### 2.3 Find Commented-Out Code

```bash
echo "=== Commented-Out Code (dead code) ==="
TARGET="${1:-.}"

echo ""
echo "🔍 Commented function/variable definitions:"
grep -rn --include="*.sh" \
  -E "^\s*#\s*(function|local|readonly|export|if|for|while|case)" \
  "$TARGET" 2>/dev/null | head -20

echo ""
echo "🔍 Commented command invocations:"
grep -rn --include="*.sh" \
  -E "^\s*#\s*(echo|printf|return|exit|source|cd|mkdir|rm|cp|mv)" \
  "$TARGET" 2>/dev/null | head -15
```

### 2.4 Find Excessive Dividers

```bash
echo "=== Decorative/Excessive Comments ==="
TARGET="${1:-.}"

echo ""
echo "🔍 Divider Lines (###, ===):"
grep -rn --include="*.sh" \
  -E "^[[:space:]]*#[#=-]{10,}" \
  "$TARGET" 2>/dev/null | head -15

echo ""
echo "🔍 Empty Comments:"
grep -rn --include="*.sh" \
  -E "^\s*#\s*$" \
  "$TARGET" 2>/dev/null | head -10
```

---

## Phase 3: Collect All TODOs/FIXMEs

### 3.1 Extract All Task Comments

```bash
echo "=== All TODO/FIXME/HACK/XXX Comments ==="
TARGET="${1:-.}"

echo ""
echo "📋 TODOs:"
grep -rn --include="*.sh" --include="*.bats" \
  -E "#\s*TODO" \
  "$TARGET" 2>/dev/null

echo ""
echo "🔧 FIXMEs:"
grep -rn --include="*.sh" --include="*.bats" \
  -E "#\s*FIXME" \
  "$TARGET" 2>/dev/null

echo ""
echo "⚠️ HACKs:"
grep -rn --include="*.sh" --include="*.bats" \
  -E "#\s*HACK" \
  "$TARGET" 2>/dev/null

echo ""
echo "❓ XXXs:"
grep -rn --include="*.sh" --include="*.bats" \
  -E "#\s*XXX" \
  "$TARGET" 2>/dev/null
```

### 3.2 Categorize TODOs by Quality

| Quality | Description | Action |
|---------|-------------|--------|
| ✅ Good | Has context, actionable, includes reference | Keep as-is |
| ⚠️ Vague | Missing context or action | Improve or remove |
| ❌ Stale | Outdated, already done, or irrelevant | Remove |

---

## Phase 4: Identify Valuable Comments

### 4.1 Find Critical Documentation

```bash
echo "=== Valuable Comments to PRESERVE ==="
TARGET="${1:-.}"

echo ""
echo "🐛 Bug/Issue References:"
grep -rn --include="*.sh" --include="*.bats" \
  -iE "#.*(GH-|#[0-9]+|bug|issue|fix|workaround|regression)" \
  "$TARGET" 2>/dev/null | head -20

echo ""
echo "🔒 Security Notes:"
grep -rn --include="*.sh" --include="*.bats" \
  -iE "#.*(security|sanitize|escape|validate|auth|permission|injection)" \
  "$TARGET" 2>/dev/null | head -15

echo ""
echo "🔧 ShellCheck Directives:"
grep -rn --include="*.sh" \
  -E "#\s*shellcheck" \
  "$TARGET" 2>/dev/null | head -15

echo ""
echo "⚠️ Bash Version Notes:"
grep -rn --include="*.sh" \
  -iE "#.*(bash [45]|bash[45]|brew install bash|bash version)" \
  "$TARGET" 2>/dev/null | head -10
```

---

## Phase 5: Execute Cleanup

### 5.1 Automated Safe Removals

For these categories, propose batch removal:

1. **Empty comments** (`# ` with no content)
2. **Divider lines** (`#####`, `#====`)
3. **Obvious narration** (when code is self-explanatory)

### 5.2 Manual Review Required

Flag these for human decision:

1. **Commented-out code** - May have historical value
2. **Vague TODOs** - Owner may have context
3. **Date-based comments** - May reference important events

### 5.3 Comment Improvements

Instead of removing, improve these:

**Before:**
```bash
# TODO: fix this
```

**After:**
```bash
# TODO(GH-456): Handle edge case when user has no permissions
```

---

## Phase 6: Create GitHub Issue for TODOs

After collecting all TODOs, create a consolidated tracking issue:

```bash
gh issue create --title "📋 Code TODOs Consolidated - $(date +%Y-%m-%d)" --body "$(cat <<'EOF'
## Codebase TODO Audit

**Audit Date:** YYYY-MM-DD
**Total TODOs Found:** X
**Total FIXMEs Found:** X

## High Priority (FIXMEs/HACKs)

### FIXME-001: [Brief description]
- **File:** `lib/path/to/file.sh:123`
- **Comment:** `# FIXME: actual comment text`
- **Assessment:** [Actionable/Vague/Stale]

## Medium Priority (TODOs)

### TODO-001: [Brief description]
- **File:** `lib/path/to/file.sh:456`
- **Comment:** `# TODO: actual comment text`

## Summary

| Type | Count | Actionable | Vague | Stale |
|------|-------|------------|-------|-------|
| TODO | X | X | X | X |
| FIXME | X | X | X | X |
| HACK | X | X | X | X |

## Recommended Actions

1. [ ] Triage high-priority FIXMEs
2. [ ] Remove stale/vague TODOs identified above
3. [ ] Convert actionable TODOs to GitHub issues
4. [ ] Update remaining TODOs with context

---
*Generated by comment-cleanup command*
EOF
)" --label "tech-debt,documentation"
```

---

## Phase 7: Generate Cleanup Report

```markdown
# Comment Cleanup Report

**Date:** [timestamp]
**Target:** [path audited]

## Before/After Metrics

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Total comment lines | X | X | -X (Y%) |
| Shell script comments | X | X | -X |
| Comment/Code ratio | X% | X% | -X% |

## Changes Made

### Removed
- Redundant comments: X
- Stale comments: X
- Dead code: X
- Decorative dividers: X

### Improved
- TODOs with added context: X

### Preserved
- Security notes: X
- Bug fix references: X
- ShellCheck directives: X
```

---

## Quality Gates

Before completing the audit:

- [ ] Baseline metrics captured
- [ ] All anti-patterns identified
- [ ] Valuable comments preserved
- [ ] TODOs collected and categorized
- [ ] GitHub issue created for TODOs
- [ ] No critical documentation removed
- [ ] Shellcheck still passes after changes

---

**Mission:** Reduce comment bloat while preserving critical documentation.
Self-documenting code is the goal; comments explain the "why," not the "what."
