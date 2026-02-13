# Shell-Config Architecture - Integrations

**Last Updated:** 2026-02-13

---

## Table of Contents

1. [Integration Layer](#integration-layer)
2. [Git Hooks Integration](#git-hooks-integration)
3. [CLI Integration](#cli-integration)
4. [Validation Integration](#validation-integration)
5. [Writing Integrations](#writing-integrations)

---

## Integration Layer

The integration layer provides external tool integration points for Shell-Config.

---

## Git Hooks Integration

### Location

**Path:** `lib/integrations/git/`

**Installation:** Automatically installed by `lib/git/setup.sh`

**Hook Location:** `.git/hooks/<hook-name>`

**Symlink Target:** `~/.shell-config/lib/integrations/git/<hook-name>`

---

### Pre-Commit Hook

**Purpose:** Validate changes before commit

**Validations:**
- Syntax validation (oxlint, ruff, shellcheck, etc.)
- Dependency validation
- Large file detection
- Large commit detection
- Secret scanning
- Bypass flag support

**Installation:**
```bash
# Automatically installed by git/setup.sh
cd ~/.shell-config
source lib/git/setup.sh
```

**Verification:**
```bash
# Check if hook is installed
ls -la .git/hooks/pre-commit

# Should show symlink
# pre-commit -> ~/.shell-config/lib/integrations/git/pre-commit
```

**Usage:**
```bash
# Normal commit (runs all validators)
git commit -m "Add feature"

# Bypass validators (emergency only)
git commit --no-verify -m "WIP"
git commit --skip-secrets -m "Temp commit"
```

**Bypass Flags:**
| Flag | Purpose | Logged |
|------|---------|--------|
| `--no-verify` | Skip all hooks | Yes |
| `--skip-secrets` | Skip secret scan only | Yes |
| `--allow-large-files` | Skip file size check | Yes |

---

### Pre-Push Hook

**Purpose:** Validate before pushing to remote

**Validations:**
- Target branch validation
- Protected branch checks

**Installation:**
```bash
# Automatically installed with git setup
source ~/.shell-config/lib/git/setup.sh
```

**Configuration:**
```bash
# Disable pre-push hook if needed
export SHELL_CONFIG_PRE_PUSH_HOOK=false
```

**Usage:**
```bash
# Normal push (runs validators)
git push origin feature-branch

# Bypass validators
git push --no-verify origin feature-branch
```

---

## CLI Integration

### Validate Command

**Location:** `lib/integrations/cli/validate`

**Purpose:** Run all validators manually

**Usage:**
```bash
# Run all validators
shell-config-validate

# Run specific validator type
shell-config-validate --type pre-commit

# Run with custom context
shell-config-validate --type file --context /path/to/file.sh

# JSON output
shell-config-validate --json
```

**Exit Codes:**
- `0`: All validators passed
- `1`: One or more validators failed
- `2`: System error (missing dependency, etc.)

**Output Format:**
```
✓ line-limits validator passed
✓ syntax-check validator passed
✗ secret-scan validator failed

ERROR: API key found in src/api.ts
WHY: API keys committed to git can be leaked
FIX: Remove the API key and use environment variables

Validation failed: 1/3 validators passed
```

---

## Validation Integration

### Git Hook Integration

The validation framework integrates with git hooks through `lib/integrations/git/pre-commit`:

```bash
#!/usr/bin/env bash
# lib/integrations/git/pre-commit

# Get staged files
files=$(git diff --cached --name-only)

# Run all pre-commit validators
validator_run "pre-commit" "$files"

# Exit with validator status
exit $?
```

---

### Custom Git Hooks

To add a custom git hook using the validator API:

```bash
#!/usr/bin/env bash
# .git/hooks/post-commit

# Source the validator API
source ~/.shell-config/lib/validation/api.sh

# Register custom validator
validator_register "my-post-commit" "post-commit" 10 my_callback

# Define callback
my_callback() {
  local context="$1"
  # Your validation logic
}

# Run validator
validator_run "post-commit" "$context"
```

---

## Writing Integrations

For integration templates and examples, see the `examples/` directory and existing integrations in `lib/integrations/`.

**Key pattern:** Source core dependencies, define a main function, handle errors with WHAT/WHY/FIX format.

---

## Best Practices

### 1. Error Handling

```bash
# ✅ Good - Follows WHAT/WHY/FIX format
echo "ERROR: Integration failed to initialize" >&2
echo "WHY: Required dependencies are missing" >&2
echo "FIX: Install dependencies using 'brew install tool'" >&2
return 1

# ❌ Bad - Not descriptive
echo "Failed"
```

### 2. Non-Interactive

```bash
# ✅ Good - Fails loudly
if ! command -v tool >/dev/null 2>&1; then
  echo "ERROR: tool not installed" >&2
  echo "FIX: brew install tool" >&2
  return 1
fi

# ❌ Bad - Interactive prompt
read -p "Install tool? (y/n) " answer
```

### 3. Safe File Handling

```bash
# ✅ Good - Handles spaces in filenames
while IFS= read -r file; do
  process "$file"
done < <(git diff --cached --name-only)

# ❌ Bad - Breaks on spaces
for file in $(git diff --cached --name-only); do
  process "$file"
done
```

---

## Related Docs

- **[OVERVIEW.md](OVERVIEW.md)** — High-level architecture
- **[GIT-HOOKS-PIPELINE.md](GIT-HOOKS-PIPELINE.md)** — All 7 hooks in detail
- **[API Quickstart](api/API-QUICKSTART.md)** — Validator API
