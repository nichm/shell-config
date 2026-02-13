---
description: Audit and align Claude commands with the actual repository structure and purpose
argument-hint: [command-name-or-all]
allowed-tools:
  Bash, Git, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, TodoWrite,
  AskUserQuestion, LS
---

# Command Alignment Audit

You are auditing Claude Code commands to ensure they accurately reflect and are
tailored to THIS repository - whatever it may be. Do not assume anything about
the project. Discover what it is first, then audit commands against that reality.

## Related Audit: Prompt Quality

**After completing this alignment audit**, run the prompt quality audit to
optimize commands for Claude 4.x best practices:

```bash
/setup:setup-prompt-quality [command-name-or-all]
```

The prompt quality audit focuses on **how** prompts are written (explicitness,
context, tool direction, format control) while this audit focuses on **what**
they reference (paths, tools, tech stack). Run both for comprehensive command
optimization.

## Audit Scope

**Target:** $ARGUMENTS (default: "all" if not specified)

If "all" or no argument, audit ALL commands in `.claude/commands/`. Otherwise,
audit only the specified command file.

---

## Phase 1: Discover Repository Identity

Before auditing any commands, you MUST understand what this repository actually
is. Gather comprehensive context.

### 1.1 Core Identity

```bash
# Repository name and remote
echo "=== Repository Identity ==="
basename "$(git rev-parse --show-toplevel)"
git remote get-url origin 2>/dev/null || echo "(no remote)"

# Recent commit activity (what's being worked on)
echo ""
echo "=== Recent Commits (last 10) ==="
git log --oneline -10
```

### 1.2 Read Primary Documentation

**CRITICAL:** Read these files to understand the project's stated purpose:

- `README.md` - Primary project description
- `CLAUDE.md` or `AGENTS.md` - AI agent instructions (if exists)
- `CONTRIBUTING.md` - Development guidelines (if exists)
- `package.json` - Project metadata and scripts (if exists)
- `pyproject.toml` or `setup.py` - Python project info (if exists)
- `Cargo.toml` - Rust project info (if exists)
- `go.mod` - Go project info (if exists)

```bash
# Check which documentation exists
echo "=== Documentation Files ==="
for f in README.md CLAUDE.md AGENTS.md CONTRIBUTING.md; do
  test -f "$f" && echo "✅ $f exists" || echo "❌ $f missing"
done
```

### 1.3 Understand Project Structure

```bash
# Top-level directory structure
echo "=== Top-Level Structure ==="
ls -la

echo ""
echo "=== Directory Tree (depth 2) ==="
find . -maxdepth 2 -type d -not -path '*/\.*' -not -path '*/node_modules/*' | sort

echo ""
echo "=== Key Config Files ==="
ls -la *.json *.yaml *.yml *.toml *.lock* 2>/dev/null | head -20
```

### 1.4 Identify Tech Stack

```bash
# Package manager and dependencies
echo "=== Package Manager Detection ==="
test -f "bun.lockb" && echo "📦 Bun detected"
test -f "pnpm-lock.yaml" && echo "📦 pnpm detected"
test -f "yarn.lock" && echo "📦 Yarn detected"
test -f "package-lock.json" && echo "📦 npm detected"
test -f "Pipfile.lock" && echo "🐍 Pipenv detected"
test -f "poetry.lock" && echo "🐍 Poetry detected"
test -f "requirements.txt" && echo "🐍 pip detected"
test -f "Cargo.lock" && echo "🦀 Cargo detected"
test -f "go.sum" && echo "🐹 Go modules detected"

echo ""
echo "=== Language Breakdown (by file count) ==="
echo "TypeScript: $(find . -name '*.ts' -o -name '*.tsx' 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')"
echo "JavaScript: $(find . -name '*.js' -o -name '*.jsx' 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')"
echo "Python: $(find . -name '*.py' 2>/dev/null | grep -v __pycache__ | wc -l | tr -d ' ')"
echo "Shell: $(find . -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
echo "Rust: $(find . -name '*.rs' 2>/dev/null | wc -l | tr -d ' ')"
echo "Go: $(find . -name '*.go' 2>/dev/null | wc -l | tr -d ' ')"

echo ""
echo "=== Framework Detection ==="
grep -l "next\|Next" package.json 2>/dev/null && echo "⚡ Next.js detected"
grep -l "vite\|Vite" package.json 2>/dev/null && echo "⚡ Vite detected"
grep -l "react\|React" package.json 2>/dev/null && echo "⚛️ React detected"
grep -l "vue\|Vue" package.json 2>/dev/null && echo "💚 Vue detected"
grep -l "svelte\|Svelte" package.json 2>/dev/null && echo "🔥 Svelte detected"
grep -l "hono\|Hono" package.json 2>/dev/null && echo "🔥 Hono detected"
grep -l "express\|Express" package.json 2>/dev/null && echo "🚂 Express detected"
grep -l "fastapi\|FastAPI" pyproject.toml requirements.txt 2>/dev/null && echo "⚡ FastAPI detected"
grep -l "django\|Django" pyproject.toml requirements.txt 2>/dev/null && echo "🎸 Django detected"
grep -l "flask\|Flask" pyproject.toml requirements.txt 2>/dev/null && echo "🍶 Flask detected"
```

### 1.5 Identify Build/Dev Commands

```bash
# Check package.json scripts
echo "=== Available Scripts (package.json) ==="
if test -f package.json; then
  cat package.json | grep -A100 '"scripts"' | grep -B1 -A100 '{' | head -50
else
  echo "(no package.json)"
fi

# Check for Makefile
echo ""
echo "=== Makefile Targets ==="
if test -f Makefile; then
  grep -E "^[a-zA-Z_-]+:" Makefile | head -20
else
  echo "(no Makefile)"
fi
```

### 1.6 Document Repository Profile

After gathering all context, create a mental profile:

```markdown
## Repository Profile (fill in after discovery)

**Name:** [repo name]
**Type:** [monorepo | single-app | library | CLI tool | documentation | etc.]
**Primary Purpose:** [one sentence]
**Main Languages:** [list]
**Package Manager:** [bun | pnpm | npm | yarn | pip | poetry | cargo | etc.]
**Frameworks:** [list or "none"]
**Key Directories:** [list important dirs]
**Build Command:** [if applicable]
**Test Command:** [if applicable]
**Dev Command:** [if applicable]
```

---

## Phase 2: Inventory Current Commands

```bash
# List all command files with their descriptions
echo "=== Claude Commands Inventory ==="
find .claude/commands -name "*.md" -type f 2>/dev/null | while read -r file; do
  desc=$(grep -m1 "^description:" "$file" 2>/dev/null | sed 's/description: *//')
  echo ""
  echo "📄 $file"
  echo "   Description: ${desc:-'(none)'}"
done

echo ""
echo "Total commands: $(find .claude/commands -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')"
```

---

## Phase 3: Deep Analysis Protocol

For EACH command file, perform this comprehensive analysis:

### 3.1 Read and Extract Key Elements

For each command, identify:

1. **Frontmatter configuration**
   - description
   - argument-hint
   - allowed-tools
2. **Stated purpose** - What does it claim to do?
3. **Referenced technologies** - What tools/frameworks does it mention?
4. **Hardcoded values** - Project names, paths, URLs
5. **Assumed commands** - What scripts/binaries does it expect to exist?
6. **Workflow structure** - Phases, steps, validation criteria

### 3.2 Compare Against Repository Reality

For each element, categorize as:

| Symbol | Category             | Action Required                |
| ------ | -------------------- | ------------------------------ |
| ❌     | **Wrong**            | References non-existent things |
| ⚠️     | **Misaligned**       | Generic but doesn't fit well   |
| 🔄     | **Needs Adaptation** | Could work with modifications  |
| ✅     | **Correct**          | Matches repo reality           |

**Check for these common issues:**

1. **Project name mismatches** - Does it reference a different project name?
2. **Tech stack mismatches** - Does it assume React when this is Python?
3. **Path mismatches** - Does it reference `src/` when this repo uses `lib/`?
4. **Script mismatches** - Does it run `bun run dev` when no such script exists?
5. **Framework mismatches** - Does it assume Vite when this uses Next.js?
6. **Tool mismatches** - Does it use ESLint when this repo uses Biome?

### 3.3 Assessment Template

For each command, document:

```markdown
## Command: [filename]

### Current State

- **Stated Purpose:** [what it claims to do]
- **Technologies Referenced:** [list all mentioned tech]
- **Assumptions:** [what it assumes about the project]

### Alignment Analysis

| Element            | Status | Finding                        |
| ------------------ | ------ | ------------------------------ |
| Project context    | [❌⚠️✅] | [description]                 |
| Tech stack refs    | [❌⚠️✅] | [description]                 |
| File paths         | [❌⚠️✅] | [description]                 |
| Build commands     | [❌⚠️✅] | [description]                 |
| Test commands      | [❌⚠️✅] | [description]                 |
| Workflow structure | [❌⚠️✅] | [description]                 |

### Required Changes

1. [specific change with before/after]
2. [specific change with before/after]

### Elements to Preserve

- [valuable pattern to keep]
- [useful workflow to keep]
```

---

## Phase 4: Update Strategy

When updating commands, follow these principles:

### 4.1 Preserve What Works

**ALWAYS keep:**

- Well-structured workflow phases
- Comprehensive quality checks
- Git best practices
- Error handling patterns
- Documentation patterns
- Universal shell commands

### 4.2 Replace What's Wrong

**ALWAYS fix:**

- Incorrect project names → Use actual repo name
- Wrong tech stack → Use discovered tech stack
- Non-existent scripts → Use actual available scripts
- Wrong paths → Use actual directory structure
- Incorrect package manager → Use detected package manager

### 4.3 Context Block Template

Replace any hardcoded project context with a dynamic discovery approach or
accurate context for THIS repo:

```markdown
## Project Context

This command operates on the current repository. Key characteristics:

- **Repository:** [discovered name]
- **Type:** [discovered type]
- **Package Manager:** [discovered PM]
- **Key Commands:**
  - Build: `[actual build command]`
  - Test: `[actual test command]`
  - Lint: `[actual lint command]`
```

### 4.4 Command Adaptation Patterns

**Build commands:**

```bash
# WRONG: Hardcoded assumption
bun run build

# RIGHT: Check what exists first
if grep -q '"build"' package.json 2>/dev/null; then
  bun run build  # or npm/pnpm based on lockfile
elif test -f Makefile; then
  make build
elif test -f Cargo.toml; then
  cargo build
fi
```

**Lint commands:**

```bash
# Detect and run appropriate linter
# Shell scripts (check for .sh files in lib/ or similar)
find lib -name "*.sh" -type f | head -1 && find lib -name "*.sh" -exec shellcheck --severity=warning {} \;
# JavaScript/TypeScript
test -f biome.json && bunx biome check .
test -f eslint.config.js && bun run lint
test -f .eslintrc* && bun run lint
# Python
test -f pyproject.toml && ruff check .
```

---

## Phase 5: Execute Updates

For each command needing changes:

1. **Read the full command content**
2. **Identify ALL misaligned elements**
3. **Draft updated version** preserving structure and valuable patterns
4. **Apply changes** using Edit tool
5. **Verify changes** are syntactically correct

### Update Checklist Per Command

- [ ] Project name/context updated
- [ ] Tech stack references match reality
- [ ] File paths exist in this repo
- [ ] Scripts/commands are available
- [ ] Package manager is correct
- [ ] Frameworks match what's installed
- [ ] Tools referenced are available
- [ ] Frontmatter description is accurate

---

## Phase 6: Validation

After all updates, verify:

```bash
echo "=== Post-Audit Validation ==="

# Check for common issues
echo ""
echo "Checking for placeholder text..."
grep -r "TODO\|FIXME\|XXX\|CHANGEME" .claude/commands/ | grep -v "audit-commands.md" || echo "✅ No placeholders found"

echo ""
echo "Checking frontmatter consistency..."
for f in $(find .claude/commands -name "*.md" -type f); do
  if ! head -1 "$f" | grep -q "^---$"; then
    echo "❌ Missing frontmatter: $f"
  else
    echo "✅ Valid frontmatter: $f"
  fi
done

echo ""
echo "Checking for orphaned references..."
# Look for references to common wrong patterns
grep -rE "your-project|my-app|example-repo|TODO-project" .claude/commands/ || echo "✅ No generic placeholders"
```

---

## Phase 7: Summary Report

Generate a comprehensive audit report:

```markdown
# Command Alignment Audit Report

**Date:** [timestamp]
**Repository:** [discovered name]
**Repository Type:** [discovered type]
**Commands Audited:** [count]

## Repository Profile

[Include the profile from Phase 1]

## Audit Summary

| Status       | Count | Commands           |
| ------------ | ----- | ------------------ |
| ✅ Aligned   | [n]   | [list]             |
| 🔧 Fixed     | [n]   | [list with changes]|
| ⚠️ Review    | [n]   | [needs manual work]|
| ❌ Cannot Fix| [n]   | [explain why]      |

## Changes Made

### [command-name.md]

**Before:** [brief description of issue]
**After:** [brief description of fix]
**Changes:**

- [change 1]
- [change 2]

## Recommendations

1. [suggestion for improvement]
2. [missing command that would be useful]

## Commands That May Need Manual Review

[List any commands that couldn't be fully automated]
```

---

## Command Priority Order

Audit in this order (foundational first):

1. **README.md** (in commands/) - Sets context for all others
2. **Core workflows** - build, lint, test, fix commands
3. **Git workflows** - commit, push, PR commands
4. **Utility commands** - cleanup, health checks
5. **Specialized commands** - project-specific tooling

---

## Quality Gates

Before completing the audit:

- [ ] Repository profile accurately captured
- [ ] All commands read and analyzed
- [ ] All misaligned references identified
- [ ] Fixes preserve valuable workflow patterns
- [ ] Updated commands reference real paths/scripts
- [ ] Frontmatter descriptions are accurate
- [ ] No placeholder text remains
- [ ] Summary report generated

---

## Completion Protocol

1. **Present repository profile** - Show what you discovered
2. **Report findings** - List all issues found per command
3. **Apply fixes** - Update commands with accurate context
4. **Verify changes** - Run validation checks
5. **Generate report** - Create summary of all changes
6. **Suggest improvements** - Recommend missing or enhanced commands

---

## Next Step: Prompt Quality Audit

After completing this alignment audit, run the prompt quality audit to optimize
commands for Claude 4.x best practices:

```bash
/setup:setup-prompt-quality all
```

This ensures commands not only reference the correct tools and paths, but also
follow modern prompt engineering patterns for:

- Explicit instructions with quality modifiers
- Context and motivation for key behaviors
- Clear tool action expectations (act vs suggest)
- Format control with XML blocks
- Parallel execution guidance
- Code exploration requirements
- Scope boundaries for implementations

---

**Mission:** Ensure every Claude command accurately reflects and is optimized
for THIS specific repository, whatever it may be.

**Discover first, audit second, preserve what works, fix what's wrong.**
