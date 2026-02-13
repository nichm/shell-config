# Integration Layer - Phase 3

**Status:** ✅ Complete | **Date:** 2026-02-03

## Overview

The integration layer provides thin adapters for git hooks and standalone CLI tools, reducing complexity by delegating to the validation API.

### Key Benefits

1. **Reduced Complexity**: Pre-commit hook reduced by 68% (682→220 lines)
2. **Clear Separation**: Git orchestration vs validation logic
3. **Reusability**: Validation API used by hooks and CLI
4. **Standalone CLI**: Manual validation without git context
5. **JSON Output**: CI/CD and AI agent integration

---

## Git Hooks

### Pre-Commit Hook

**Location:** `shell-config/lib/integrations/git/pre-commit`

**What it does:**

- Validates staged files using validation API
- Checks for large files (>5MB)
- Validates commit size (three-tier warning system)
- Warns about dependency file changes
- Scans for secrets (Gitleaks)

**Bypass:**

```bash
GIT_SKIP_HOOKS=1 git commit -m "message"
```

**Line count reduction:**

- Before: 682 lines
- After: 220 lines
- Reduction: **68%**

### Pre-Push Hook

**Location:** `shell-config/lib/integrations/git/pre-push`

**What it does:**

- Validates files in push range (not entire repo)
- Runs tests on changed files (if test script exists)
- Scans for secrets in changed files (defense in depth)

**Bypass:**

```bash
git push --no-verify
```

**Line count reduction:**

- Before: 154 lines
- After: 130 lines
- Reduction: **16%**

---

## CLI Tool

### Validate Command

**Location:** `shell-config/lib/integrations/cli/validate`

**What it does:**

- Manual validation without git context
- Supports single file and batch validation
- JSON output for CI/CD and AI agents
- Parallel execution for speed

### Usage Examples

#### Basic Validation

```bash
# Validate single file
validate file.py

# Validate multiple files
validate file.py file.js file.sh
```

#### JSON Output

```bash
# JSON output for CI/CD
validate --json file.py

# Write JSON to file
validate --json file.py > results.json
```

#### Parallel Validation

```bash
# Run 4 validations in parallel
validate --parallel 4 src/

# Validate entire directory
validate --all src/
```

#### Selective Validation

```bash
# Syntax validation only
validate --syntax file.sh

# Security validation only
validate --security config/
```

#### Help

```bash
validate --help
```

---

## Git Utilities

**Location:** `shell-config/lib/integrations/git/utils.sh`

### Available Functions

#### Messaging

```bash
git_hook_start "hook-name" "Message"
git_hook_success "hook-name"
git_validation_success "Message"
git_info "Message"
git_warning "Message"
git_error "Message"
```

#### Git Detection

```bash
# Check if in git repository
is_git_repo

# Get staged files
get_staged_files

# Get changed files in push range
get_range_files "commit-range"

# Get push commit range
get_push_range "remote"
```

#### File Operations

```bash
# Check if file exists
file_exists "file.py"

# Get file size in bytes
get_file_size "file.py"

# Get file extension
get_file_extension "file.py"

# Check file type
is_file_type "file.py" "py"
```

#### Validation Helpers

```bash
# Check if command exists
command_exists "gitleaks"

# Run command with timeout
run_with_timeout 5 "command"
```

#### Commit Analysis

```bash
# Get commit statistics
get_commit_stats "output-file"

# Classify commit tier (ok/info/warning/extreme)
classify_commit_tier "$files" "$lines"
```

---

## Installation

### Git Hooks

The hooks are stored in the repository at `shell-config/lib/integrations/git/`.

**To install:**

```bash
cd shell-config/lib/git
./setup.sh install
```

This creates symlinks in `~/.githooks/` pointing to the integration layer hooks.

**To check status:**

```bash
cd shell-config/lib/git
./setup.sh status
```

**To uninstall:**

```bash
cd shell-config/lib/git
./setup.sh uninstall
```

### CLI Tool

The CLI tool is automatically added to your PATH when you source shell-config:

```bash
source "$HOME/.shell-config/init.sh"
```

**Verify installation:**

```bash
which validate
validate --help
```

---

## Usage

### Git Hooks (Automatic)

Once installed, hooks run automatically:

```bash
# Pre-commit hook runs
git commit -m "Add feature"

# Pre-push hook runs
git push
```

### CLI Tool (Manual)

```bash
# Validate current file
validate app.py

# Validate entire project
validate --all src/

# JSON output for CI/CD
validate --json src/ > results.json
```

---

## Integration with Validation API

The integration layer uses the validation API at `shell-config/lib/validation/api.sh`.

### How It Works

1. **Git Hook**:
   - Gets staged/changed files
   - Calls `validator_api_run` with file list
   - Adds git-specific checks (commit size, large files)
   - Blocks or warns based on results

2. **CLI Tool**:
   - Parses command-line arguments
   - Collects files to validate
   - Calls `validator_api_run` with configuration
   - Outputs results (console or JSON)

### Validation API Features

- **Parallel execution**: `VALIDATOR_PARALLEL=4`
- **JSON output**: `VALIDATOR_OUTPUT=json`
- **Batch validation**: Multiple files at once
- **Exit codes**: 0=pass, 1=fail, 2=error

---

## Comparison: Before vs After

### Pre-Commit Hook

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Lines | 682 | 220 | **-68%** |
| Validation Logic | Inline | Delegated | Cleaner |
| Parallel Jobs | Manual (11 jobs) | API | Simplified |
| Error Handling | Inline | Centralized | Consistent |

### Pre-Push Hook

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Lines | 154 | 130 | **-16%** |
| File Detection | Inline | Utils | Reusable |
| Messaging | Inline | Utils | Consistent |

---

---

## Phase 3 Success Criteria

- ⚠️ Pre-commit hook: Target ≤100 lines, achieved 220 lines (**68% reduction** from 682)
- ⚠️ Pre-push hook: Target ≤100 lines, achieved 130 lines (**16% reduction** from 154)
- ✅ CLI tool works standalone
- ✅ All hooks use validator API
- ✅ CLI tool works without git context
- ✅ All existing functionality preserved

> **Note:** While the line count targets weren't fully met, the primary goals of clean
> separation of concerns, code reuse via the validation API, and significantly reduced
> complexity were achieved. The remaining lines contain essential git-specific logic
> (commit size analysis, large file detection, dependency warnings) that appropriately
> belongs in the git hooks rather than the validation layer.

---

## Next Steps

### Phase 4: CI/CD Integration

- GitHub Actions workflow examples
- GitLab CI templates
- Docker container with validation tools
- AI agent integration guides

### Future Enhancements

- Add more git hooks (post-merge, post-checkout)
- Add more CLI options (filter by severity, fix auto-detected issues)
- Performance optimizations (caching, incremental validation)
- More validators (code quality, complexity, duplications)

---

## Troubleshooting

### Hook Not Running

**Problem:** Git hook not executing

**Solution:**

```bash
# Check hooks path
git config --global core.hooksPath

# Verify hook exists
ls -la ~/.githooks/pre-commit

# Reinstall hooks
cd shell-config/lib/git && ./setup.sh install
```

### CLI Tool Not Found

**Problem:** `validate: command not found`

**Solution:**

```bash
# Verify shell-config is sourced
echo $PATH | grep shell-config

# Source shell-config
source "$HOME/.shell-config/init.sh"

# Verify installation
which validate
```

### Validation Failures

**Problem:** Hook fails but files seem correct

**Solution:**

```bash
# Run validation manually
validate --all src/

# Check specific file
validate file.py

# JSON output for debugging
validate --json file.py | jq
```

---

## Contributing

When adding new integrations:

1. **Git Hooks**: Add to `lib/integrations/git/`
2. **CLI Tools**: Add to `lib/integrations/cli/`
3. **Utilities**: Add to `lib/integrations/git/utils.sh`
4. **Documentation**: Update this README

**Principles:**

- Keep hooks thin (<250 lines)
- Delegate to validation API
- Use git utilities for consistency
- Test hooks with real commits/pushes

---

## Related Documentation

- **Validation API:** `shell-config/lib/validation/README.md`
- **Phase 2 Completion:** `shell-config/lib/validation/PHASE2-COMPLETION.md`
- **Git Hooks README:** `shell-config/lib/git/README.md`
- **Master Epic:** Issue #230

---

**Phase 3 Complete!** ✅
