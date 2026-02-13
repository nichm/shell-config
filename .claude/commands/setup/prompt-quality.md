---
description: Audit slash commands for prompt quality and effectiveness
argument-hint: [command-name-or-all]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, TodoWrite, LS
---

# Slash Command Prompt Quality Audit

You are auditing Claude Code slash commands for **prompt quality** and
effectiveness. This focuses on how to write commands that produce consistent,
high-quality results.

**Target:** $ARGUMENTS (default: "all" if not specified)

If "all" or no argument, audit ALL commands in `.claude/commands/`. Otherwise,
audit only the specified command file.

---

## Phase 1: Command Structure Best Practices

### 1.1 Frontmatter Configuration

Evaluate frontmatter completeness and correctness:

| Field | Purpose | Best Practice |
|-------|---------|---------------|
| `description` | Shows in `/help` and helps Claude decide when to use | Clear, action-oriented (e.g., "Fix linting errors" not "Linting") |
| `argument-hint` | Shows expected arguments during autocomplete | Use brackets: `[required]` or `[optional]` |
| `allowed-tools` | Tools permitted without asking | Only include tools the command actually needs |
| `disable-model-invocation` | Prevents automatic triggering | Use `true` for commands with side effects (deploy, commit) |

**Good frontmatter example:**

```yaml
---
description: Create a conventional commit from staged changes
argument-hint: [type] [scope]
allowed-tools: Bash(git *)
disable-model-invocation: true
---
```

**Anti-patterns:**

- Missing `description` (command won't appear helpful in `/help`)
- Overly broad `allowed-tools: Bash(*)` when specific patterns work
- No `argument-hint` when arguments are expected

### 1.2 Argument Handling

Commands should handle arguments predictably:

| Syntax | Use Case | Example |
|--------|----------|---------|
| `$ARGUMENTS` | All arguments as single string | "Fix issue: $ARGUMENTS" |
| `$0`, `$1`, `$2` | Positional arguments | "Review PR #$0 assigned to $1" |
| `$ARGUMENTS[0]` | Same as `$0` (longer form) | "Component: $ARGUMENTS[0]" |

**Best practices:**

- Document expected arguments in the command body if complex
- Provide defaults or fallback behavior when arguments are optional
- Use positional args when order matters, `$ARGUMENTS` for free-form input

**Example with fallback:**

```markdown
## Target

$ARGUMENTS

If no argument provided, audit all commands in `.claude/commands/`.
```

### 1.3 Dynamic Context Injection

Use `!`command`` to inject live data before Claude sees the prompt:

```markdown
## Current State

- Git status: !`git status --short`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -5`

## Task

Based on the above context, [do something specific]...
```

**Best practices:**

- Keep injected commands fast (avoid long-running operations)
- Use `--short` or similar flags to reduce output size
- Only inject context that's actually needed for the task

**Anti-patterns:**

- Injecting entire file contents when a summary would suffice
- Running commands that might fail or hang
- Injecting sensitive data (secrets, tokens)

---

## Phase 2: Instruction Quality

### 2.1 Clarity and Specificity

Commands should tell Claude exactly what to do:

| Quality | Poor | Better |
|---------|------|--------|
| Vague | "Review the code" | "Review for security issues, performance problems, and style violations" |
| Incomplete | "Fix the errors" | "Fix all linting errors. Run the linter again to verify fixes." |
| Ambiguous | "Update the file" | "Update the README to reflect the new API endpoints" |

**Effective instruction patterns:**

```markdown
## Task

1. Read the specified files to understand current implementation
2. Identify [specific issues to look for]
3. Make changes that [specific outcome]
4. Verify changes by [specific verification step]
```

### 2.2 Action vs Research Commands

Be explicit about whether the command should take action or just analyze:

**Action command:**

```markdown
## Task

Fix all TypeScript errors in the specified files. Make the minimal changes
needed to resolve each error while preserving existing behavior.
```

**Research command:**

```markdown
## Task

Analyze the codebase architecture and report findings. Do not make any changes.
Present your analysis with specific file references.
```

### 2.3 Output Expectations

When specific output format matters, specify it:

```markdown
## Output Format

Present findings as a table with columns:
- File path
- Issue type
- Severity (high/medium/low)
- Recommended fix

End with a summary of total issues by severity.
```

### 2.4 Scope Boundaries

Prevent scope creep with explicit boundaries:

```markdown
## Scope

- Only modify files in `src/components/`
- Do not refactor unrelated code
- Do not add new dependencies
- Keep changes minimal and focused on the stated task
```

---

## Phase 3: Common Patterns

### 3.1 Git Operations

```markdown
---
description: Create commit from staged changes
allowed-tools: Bash(git *)
disable-model-invocation: true
---

## Context

- Staged changes: !`git diff --cached --stat`
- Recent commits: !`git log --oneline -3`

## Task

Create a conventional commit for the staged changes. Use the commit type that
best matches the changes (feat, fix, docs, refactor, test, chore).
```

### 3.2 Code Review (Shell Script Example)

```markdown
---
description: Review shell scripts for issues
argument-hint: [file-or-directory]
---

## Target

$ARGUMENTS

## Review Checklist

1. Shellcheck compliance (--severity=warning)
2. Bash 5.x features (macOS: brew install bash)
3. Variable quoting (prevent word splitting)
4. Error handling (set -euo pipefail, trap handlers)
5. File size limits (600 lines max)

Present findings with severity ratings and specific line references.
```

### 3.3 Debugging

```markdown
---
description: Debug an issue with systematic investigation
argument-hint: [error-or-symptom]
---

## Problem

$ARGUMENTS

## Investigation Protocol

1. Reproduce the issue - understand exact conditions
2. Locate the source - trace from symptom to cause
3. Identify the fix - determine minimal change needed
4. Verify the solution - confirm fix doesn't introduce new issues

Document your reasoning at each step.
```

### 3.4 Documentation

```markdown
---
description: Generate documentation for shell function
argument-hint: [file-or-function]
---

## Target

$ARGUMENTS

## Documentation Requirements

- Purpose and use cases
- Parameters/arguments
- Exit codes
- Example usage
- Dependencies (required tools)

Match the documentation style already used in this codebase.
```

---

## Phase 4: Quality Scoring

Rate each command on these dimensions (1-5):

| Dimension | 1 (Poor) | 3 (Adequate) | 5 (Excellent) |
|-----------|----------|--------------|---------------|
| Frontmatter | Missing/wrong fields | Basic fields present | Complete with appropriate tools |
| Clarity | Vague instructions | Understandable intent | Crystal clear steps |
| Context | No relevant context | Some context | Dynamic context injection |
| Scope | Unlimited/unclear | Some boundaries | Explicit limits |
| Verification | No verification | Manual check mentioned | Automated verification step |

### Assessment Template

```markdown
## Command: [filename]

### Scores

| Dimension | Score | Notes |
|-----------|-------|-------|
| Frontmatter | [n]/5 | [observation] |
| Clarity | [n]/5 | [observation] |
| Context | [n]/5 | [observation] |
| Scope | [n]/5 | [observation] |
| Verification | [n]/5 | [observation] |

**Overall:** [avg]/5

### Improvements Needed

1. [specific improvement]
2. [specific improvement]
```

---

## Phase 5: Execute Audit

For each command:

1. **Read the command file**
2. **Score against dimensions** using the assessment template
3. **Identify specific improvements** with examples
4. **Apply changes** that improve quality without changing intent
5. **Verify** the command still works as expected

### Improvement Checklist

- [ ] Frontmatter has appropriate `description` and `allowed-tools`
- [ ] Arguments are documented and handled with fallbacks
- [ ] Instructions are specific and actionable
- [ ] Scope boundaries are defined for action commands
- [ ] Dynamic context is used where it adds value
- [ ] Output format is specified when relevant
- [ ] Verification step included for modification commands

---

## Phase 6: Summary Report

```markdown
# Slash Command Quality Report

**Date:** [timestamp]
**Commands Audited:** [count]
**Average Score:** [n]/5

## Commands by Score

### High Quality (4-5)
- [command]: [score] - [brief note]

### Needs Improvement (2-3)
- [command]: [score] - [key issue]

### Requires Rewrite (1)
- [command]: [score] - [major problems]

## Common Issues Found

1. [pattern seen across multiple commands]
2. [pattern seen across multiple commands]

## Recommendations

1. [actionable recommendation]
2. [actionable recommendation]
```

---

## Quality Gates

Before completing:

- [ ] All commands scored
- [ ] Low-scoring commands improved or flagged
- [ ] Improvements preserve original intent
- [ ] Summary report generated

---

**Mission:** Ensure every slash command produces consistent, high-quality results
through clear instructions, appropriate context, and explicit expectations.
