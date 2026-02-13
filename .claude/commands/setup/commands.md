---
description: Shows how to create custom slash commands with examples
argument-hint: [command-name]
allowed-tools: Bash(mkdir:*), Bash(echo:*), Write
---

# How to Create Custom Slash Commands

This command demonstrates the structure and features of custom slash commands in
Claude Code.

## Basic Command Structure

Custom slash commands are Markdown files stored in:

- **Project commands**: `.claude/commands/` (shared with team)
- **Personal commands**: `~/.claude/commands/` (available across all projects)

## Frontmatter Options

```yaml
---
description: Brief description shown in /help
argument-hint: [optional] [arguments] pattern
allowed-tools: Bash(*), Write, Read  # Tools this command can use
disable-model-invocation: true       # Prevent SlashCommand tool from calling
---
```

## Argument Handling

### All arguments with `$ARGUMENTS`

```markdown
Create a git commit with message: $ARGUMENTS
```

### Positional arguments with `$1`, `$2`, etc.

```markdown
Review PR #$1 with priority $2 and assign to $3
```

## Advanced Features

### Bash command execution

Use `!` prefix to execute bash commands:

```markdown
Current git status: !`git status` Current branch: !`git branch --show-current`
```

### File references

Use `@` prefix to include file contents:

```markdown
Review the implementation in @lib/git/core.sh
```

### Namespacing

Organize commands in subdirectories:

- `.claude/commands/dev/fix-build.md` → `/fix-build` (shows "(project:dev)")
- `.claude/commands/git/commit.md` → `/commit` (shows "(project:git)")

## Example Commands for Shell-Config

### Simple shellcheck command

```markdown
---
description: Run shellcheck on specified file
argument-hint: [path/to/file.sh]
allowed-tools: Bash(shellcheck:*)
---

Run shellcheck on: $ARGUMENTS

```bash
shellcheck --severity=warning $ARGUMENTS
```
```

### Bats test command

```markdown
---
description: Run specific bats test file
argument-hint: [test-name]
---

Run bats test: tests/$ARGUMENTS.bats

```bash
bats tests/$ARGUMENTS.bats
```
```

### Context-aware command

```markdown
---
description: Analyze current git status and create commit
allowed-tools: Bash(git:*)
---

## Context

- Current git status: !`git status`
- Current git diff: !`git diff HEAD --stat`

## Your task

Based on the above changes, create an appropriate git commit.
```

## Shell-Config Specific Patterns

### Common scopes for commits

```markdown
# Scope identification for shell-config

- `git` - lib/git/ - wrapper, hooks, secrets
- `command-safety` - lib/command-safety/ - rules, engine
- `validation` - lib/validation/ - validators
- `validation/gha` - lib/validation/validators/gha/ - GHA scanners
- `1password` - lib/integrations/1password/ - op integration
- `ghls` - lib/integrations/ghls/ - github list
- `terminal` - lib/terminal/ - setup, autocomplete
- `welcome` - lib/welcome/ - welcome messages
- `core` - lib/core/ - colors, logging, config, platform
- `tests` - tests/ - bats test files
```

### Quality check pattern

```markdown
---
description: Run all quality checks
allowed-tools: Bash(shellcheck:*), Bash(bats:*), Bash(find:*), Bash(wc:*)
---

## Quality Checks

### Shellcheck
```bash
find lib -name "*.sh" -exec shellcheck --severity=warning {} \;
```

### Bats Tests
```bash
./tests/run_all.sh
```

### File Size Check
```bash
find lib -name "*.sh" -exec wc -l {} \; | awk '$1 > 600 {print "❌ " $0}'
```
```

## Usage

Once created, commands are available via:

- `/command-name` (if no conflicts)
- `/plugin-name:command-name` (if conflicts exist)
- With arguments: `/command-name arg1 arg2`

## Management

- List all commands: `/help`
- View available tools: `/permissions`
- Check context usage: `/context`

## Skills vs Slash Commands

Use **slash commands** for:

- Simple, frequently-used prompts
- Quick reminders or templates
- Explicit control over execution

Use **Skills** for:

- Complex workflows with multiple steps
- Capabilities requiring scripts or utilities
- Knowledge organized across multiple files
- Team standardization

Both can coexist and serve different purposes in your workflow.

Continuously improve this documentation and add it to all relevant repositories
for consistency.
