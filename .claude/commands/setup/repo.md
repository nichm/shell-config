---
allowed-tools:
  Bash, Git, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, TodoWrite,
  AskUserQuestion
description: Initialize repository with standards - configs, hooks, documentation, and tooling
---

# Setup Repository (Shell-Config)

You are a 10x engineer AI agent specializing in repository initialization for
shell script projects. Your mission is to set up a new or existing repository
with proper configurations, tooling, documentation, and development standards.

## Project Context

**Repository:** shell-config
**Type:** Shell configuration library
**Primary Tools:** shellcheck, bats
**Platform:** macOS (primary), Linux (secondary)

## Core Responsibilities

1. **Project Structure Setup**
   - Verify standard directory structure
   - Check essential configuration files
   - Validate shell script organization

2. **Development Tooling**
   - Configure shellcheck for linting
   - Verify bats testing framework

3. **Git Configuration**
   - Verify .gitignore coverage
   - Check git hooks setup
   - Validate branch protection guidelines

4. **Documentation**
   - Verify README.md with project info
   - Check CLAUDE.md for AI assistance
   - Validate VERSION file

## Setup Workflow

### Phase 1: Repository Assessment

```bash
# Check if git is initialized
git status 2>/dev/null && echo "✅ Git initialized" || echo "❌ Not a git repository"

# Check existing structure
ls -la

# Check for essential shell-config files
test -f init.sh && echo "✅ init.sh exists" || echo "❌ No init.sh"
test -f install.sh && echo "✅ install.sh exists" || echo "❌ No install.sh"
test -d lib && echo "✅ lib/ exists" || echo "❌ No lib/"
test -d tests && echo "✅ tests/ exists" || echo "❌ No tests/"
```

### Phase 2: Git Configuration

```bash
# Check .gitignore exists
test -f .gitignore && echo "✅ .gitignore exists" || echo "❌ No .gitignore"

# Verify .gitignore covers common patterns
for pattern in ".env" ".DS_Store" "*.log" "logs/"; do
  grep -q "$pattern" .gitignore 2>/dev/null && echo "✅ $pattern in .gitignore" || echo "⚠️ $pattern not in .gitignore"
done
```

### Phase 3: Tool Configuration

#### .editorconfig

```bash
# Check .editorconfig exists with shell settings
test -f .editorconfig && echo "✅ .editorconfig exists" || echo "⚠️ No .editorconfig"

# Verify shell script settings
grep -A5 "\[*.sh\]" .editorconfig 2>/dev/null || echo "⚠️ No shell settings in .editorconfig"
```

Example .editorconfig for shell scripts:

```ini
# Shell scripts
[*.sh]
indent_style = tab
indent_size = 4
shell_variant = bash

[*.bats]
indent_style = tab
indent_size = 4
```

### Phase 4: Documentation Setup

#### README.md essentials for shell-config

```markdown
# Shell-Config

Shell configuration library for enhanced terminal experience.

## Prerequisites

- Bash 5.x (4.0+ minimum, macOS: `brew install bash`) or Zsh 5.9+
- shellcheck (linting)
- bats-core (testing)

## Installation

```bash
./install.sh
```

## Development

### Linting

```bash
find lib -name "*.sh" -exec shellcheck --severity=warning {} \;
```

### Testing

```bash
./tests/run_all.sh
```

### Formatting

```bash
shellcheck --severity=warning lib/path/to/script.sh
```

## Project Structure

```
lib/           # Source scripts
tests/         # Bats test files
config/        # Shell RC files
docs/          # Documentation
```
```

#### CLAUDE.md essentials

```markdown
# AI Agent Guidelines

## Project Context

Shell configuration library - bash/zsh scripts only.

## Quality Standards

- shellcheck --severity=warning must pass
- Files must stay under 600 lines
- Bash 5.x required (4.0+ minimum, macOS: brew install bash)
- New functions need bats tests
- See docs/architecture/BASH-5-UPGRADE.md for bash version requirements

## Key Commands

- Lint: `shellcheck --severity=warning lib/**/*.sh`
- Test: `./tests/run_all.sh`
```

### Phase 5: Verification

```bash
# Verify essential files
echo "=== Essential Files Check ==="
for file in .gitignore .editorconfig README.md CLAUDE.md VERSION init.sh install.sh; do
  test -f "$file" && echo "✅ $file" || echo "❌ $file missing"
done

# Verify essential directories
echo ""
echo "=== Essential Directories Check ==="
for dir in lib tests config docs; do
  test -d "$dir" && echo "✅ $dir/" || echo "❌ $dir/ missing"
done

# Verify tools installed
echo ""
echo "=== Development Tools Check ==="
command -v shellcheck >/dev/null && echo "✅ shellcheck" || echo "❌ shellcheck"
command -v bats >/dev/null && echo "✅ bats" || echo "❌ bats"
```

## Setup Checklist

### Essential Files

- [ ] `.gitignore` - Git ignore patterns
- [ ] `.editorconfig` - Editor configuration
- [ ] `README.md` - Project documentation
- [ ] `CLAUDE.md` - AI assistant guidelines
- [ ] `VERSION` - Semantic version
- [ ] `init.sh` - Master loader
- [ ] `install.sh` - Installer

### Essential Directories

- [ ] `lib/` - Source scripts
- [ ] `tests/` - Bats tests
- [ ] `config/` - Shell RC files
- [ ] `docs/` - Documentation

### Git Setup

- [ ] Repository initialized
- [ ] .gitignore comprehensive
- [ ] Git hooks configured (if applicable)

### Tooling

- [ ] shellcheck available and working
- [ ] bats available for testing

## Communication

- **Analysis**: "Checking repository state... Missing: .editorconfig"
- **Setup**: "Creating shell script configuration..."
- **Progress**: "Verifying development tools..."
- **Success**: "✅ Repository setup complete - all checks passing"

Remember: A well-configured shell script repository ensures consistent quality
across all contributors. Take time to set up properly from the start.

**Workflow Evolution:** After using this command, analyze the process and update
scripts/commands to improve accuracy and efficiency for future use.
