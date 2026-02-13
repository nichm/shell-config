---
allowed-tools: Read, Write, Edit
description: Documentation for Claude Code commands and usage guidelines
---

# Claude Commands - Shell-Config Repository

High-efficiency AI commands organized by workflow category for the shell-config
repository. Commands are namespaced by folder and accessible via
`/command-name (project:folder)`.

## Project Context

**Repository:** shell-config
**Type:** Shell configuration library (~10,000 lines bash/zsh)
**Primary Files:** `lib/**/*.sh`, `tests/**/*.bats`
**Linting:** shellcheck (severity: warning)
**Testing:** bats (Bash Automated Testing System)
**Formatting:** Not enforced (consistent 4-space indentation by convention)

## Commands by Category

### 💻 Dev Commands (dev/)

| Command | Description |
|---------|-------------|
| `/dev:fix-build` | Fix shellcheck errors and bash compatibility |
| `/dev:fix-lint-types-tests` | Fix shellcheck, formatting, and bats tests |

### 🌿 Git Commands (git/)

| Command | Description |
|---------|-------------|
| `/git:commit` | Smart commit with conventional format |
| `/git:pr-list-all` | List all open PRs with status |
| `/git:pr-merge-all` | Review and merge all open PRs |
| `/git:push-to-main` | Direct push to main with safety checks |
| `/git:push-to-pr` | Create pull request with quality verification |
| `/git:repo-clean` | Branch cleanup and stale branch removal |
| `/git:switch-main` | Stash work, switch to clean main |
| `/git:sync` | Sync branch with main/upstream |

### 🏥 Health Commands (health/)

| Command | Description |
|---------|-------------|
| `/health:repo-health` | Comprehensive health check with shell-config analysis |
| `/health:repo-resolve-conflicts` | Resolve merge conflicts on all PRs |
| `/health:repo-security` | Security audit for shell scripts |
| `/health:shell-config-health` | Shell-config specific health check |

### ⚙️ Setup Commands (setup/)

| Command | Description |
|---------|-------------|
| `/setup:audit-commands` | Audit commands for repo alignment |
| `/setup:commands` | Guide for creating commands |
| `/setup:comment-cleanup` | Audit and clean shell script comments |
| `/setup:prompt-quality` | Audit prompts for Claude 4.x best practices |
| `/setup:repo` | Initialize shell script repository standards |

### ⭐ Super Commands (super/)

| Command | Description |
|---------|-------------|
| `/super:fix` | Comprehensive shell script debugging |
| `/super:research` | Deep research & analysis |
| `/super:sure` | Double-check all work is complete |

## Quick Reference

### Daily Development

```bash
/dev:start                    # Validate dev environment
/git:sync                     # Sync with latest main
/dev:fix-lint-types-tests     # Fix shellcheck/test issues
/git:commit                   # Smart commit
/git:push-to-pr               # Create PR
```

### Code Quality

```bash
/dev:fix-build                # Fix shellcheck errors
/dev:fix-lint-types-tests     # Fix lint/test issues
/super:sure                   # Verify everything is correct
```

### Repository Maintenance

```bash
/health:repo-health           # Health check + tracking issue
/health:repo-security         # Security audit + tracking issue
/git:repo-clean               # Clean up branches
```

### Command Audit Workflow

```bash
# Full audit: run both in sequence
/setup:audit-commands all     # 1. Fix paths, tech stack, scripts
/setup:prompt-quality all     # 2. Optimize prompt engineering

# Or audit a single command
/setup:audit-commands dev/fix-build
/setup:prompt-quality dev/fix-build
```

### PR Workflow

```bash
/git:pr-list-all              # List all open PRs
/health:repo-resolve-conflicts # Fix merge conflicts
/git:pr-merge-all             # Review and merge all PRs
```

### Git Operations

```bash
/git:switch-main              # Stash and switch to main
/git:sync                     # Sync with upstream
/git:commit                   # Conventional commit
/git:push-to-main             # Direct to main
/git:push-to-pr               # Create PR
```

## Shell-Config Quality Commands

Standard shell-config validation commands:

```bash
# Linting - shellcheck
find lib -name "*.sh" -exec shellcheck --severity=warning {} \;

# Testing - bats
./tests/run_all.sh
bats tests/specific.bats

# Lint
shellcheck --severity=warning lib/path/to/file.sh

# File size check (800 max, 600 target)
wc -l lib/**/*.sh | sort -rn | head -20
```

## Creating New Commands

See `/setup:commands` for the complete guide. Basic structure:

```markdown
---
description: Brief description shown in /help
allowed-tools: Bash, Git, Read, Write, Edit
---

# Command Name

Instructions for the AI agent...
```

## Naming Conventions

| Folder | Invocation | Example File |
|--------|------------|--------------|
| `dev/` | `/dev:name` | `fix-build.md` |
| `git/` | `/git:name` | `commit.md` |
| `health/` | `/health:name` | `repo-health.md` |
| `setup/` | `/setup:name` | `repo.md` |
| `super/` | `/super:name` | `fix.md` |

## Shell-Config Specific Context

These commands are tailored for shell-config's unique characteristics:

- **No Node.js/npm** - Pure shell scripts, no package.json
- **shellcheck linting** - Not ESLint/TypeScript
- **bats testing** - Not Jest/Vitest
- **File size limits** - 800 lines max, 600 target
- **Bash 5.x required** - 4.0+ minimum, macOS: brew install bash (see docs/architecture/BASH-5-UPGRADE.md)
- **Squash-only merges** - Merge commits disabled

---

**Workflow Evolution:** After using any command, analyze the process and update
scripts/commands to improve accuracy and efficiency for future use.
