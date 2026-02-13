# Syntax Validator for Git Safety Wrapper

**Updated:** 2026-01-29  
**Location:** `lib/validation/validators/core/syntax-validator.sh`

---

## Overview

The Syntax Validator provides fast syntax checking for staged files during git commits. It uses Rust-based tools for maximum performance while gracefully degrading when tools aren't installed.

## Supported File Types

| Extension | Primary Tool | Fallback | Performance |
|-----------|-------------|----------|-------------|
| `js`, `ts`, `jsx`, `tsx`, `mjs`, `cjs` | **oxlint** | biome, eslint | 50-100x faster than ESLint |
| `py` | **ruff** | flake8 | 10-50x faster than Flake8 |
| `sql` | **sqruff** | sqlfluff | 100-1000x faster than SQLFluff |
| `sh`, `bash`, `zsh` | **shellcheck** | - | Fast |
| `yml`, `yaml` | **yamllint** | - | Fast |
| `json` | **biome** | oxlint | Very fast |
| `.github/workflows/*.yml` | **actionlint** | yamllint | GitHub Actions specific |

## Installation

### Quick Start (macOS)

```bash
# Install recommended tools
brew install oxlint ruff shellcheck yamllint actionlint

# Optional: SQL validation
brew install sqruff
```

### Tool-Specific Installation

```bash
# JavaScript/TypeScript
brew install oxlint       # Recommended: 50-100x faster than ESLint

# Python
brew install ruff         # Recommended: 10-50x faster than Flake8

# Shell scripts
brew install shellcheck   # Standard shell linter

# YAML
brew install yamllint     # Standard YAML linter

# GitHub Actions
brew install actionlint   # Workflow-specific validation
```

## Usage

### Automatic (Default)

Validation runs automatically on `git commit`:

```bash
git add file.js
git commit -m "Add feature"
# Output:
# ✅ All files passed syntax validation
```

### Bypass Validation

```bash
git commit -m "message" --skip-syntax-check
```

### Verbose Mode

```bash
VERBOSE_MODE=1 git commit -m "message"
```

## How It Works

### 1. File Detection

The validator examines staged files and selects appropriate validators:

```bash
# From syntax.sh
_get_validator_for_file() {
    case "$ext" in
        js|ts|jsx|tsx) echo "oxlint:biome:eslint" ;;
        py) echo "ruff:flake8" ;;
        sh|bash|zsh) echo "shellcheck" ;;
        yml|yaml) echo "yamllint" ;;
        # ...
    esac
}
```

### 2. Batch Processing

Files are grouped by type and validated in batches for performance:

```bash
# JS/TS files → oxlint
# Python files → ruff  
# Shell files → shellcheck
# YAML files → yamllint
```

### 3. Error Reporting

On failure, shows up to 5 files with error details:

```
❌ Syntax errors in 2 file(s):

  • src/utils.js
    src/utils.js:15:8: Unexpected token
  • lib/helper.py
    lib/helper.py:23:1: E999 SyntaxError

Fix errors or use --skip-syntax-check to bypass
```

## Performance

### Typical Commit Times

| Files | Batch Validation | Per-File |
|-------|-----------------|----------|
| 5 files | ~50ms | ~10ms |
| 10 files | ~80ms | ~8ms |
| 20 files | ~120ms | ~6ms |

Batch processing provides significant speedup over per-file validation.

### Tool Comparison

| Tool | Language | Speed (1000 lines) |
|------|----------|-------------------|
| **oxlint** | Rust | ~40ms |
| **ruff** | Rust | ~25ms |
| **shellcheck** | Haskell | ~30ms |
| **yamllint** | Python | ~50ms |
| ESLint | JavaScript | ~450ms |
| Flake8 | Python | ~250ms |

## Configuration

### Shellcheck Severity

Only errors and warnings are reported (info/style ignored):

```bash
shellcheck --severity=warning "$file"
```

### Actionlint Configuration

Place `.github/actionlint.yaml` in repo root for custom rules:

```yaml
self-hosted-runner:
  labels:
    - ubuntu-latest
    - macos-latest
```

## Integration

### Pre-commit Hook

The validator is called from `lib/git/hooks/pre-commit`:

```bash
# Syntax validation
if [[ "$skip_syntax" -eq 0 ]]; then
    _validate_staged_files || exit 1
fi
```

### Git Wrapper

Also available via `lib/git/wrapper.sh` for direct git commands.

## Troubleshooting

### "No validator found"

Install the recommended tools:

```bash
brew install oxlint ruff shellcheck yamllint
```

### Validation feels slow

1. Ensure Rust-based tools are installed (oxlint, ruff)
2. Check if fallback tools (ESLint, Flake8) are being used
3. Large files (>10k lines) may take longer

### False positives

Use `--skip-syntax-check` to bypass, or configure tool-specific ignore rules in:

- `.oxlintrc.json` - oxlint rules
- `pyproject.toml` - ruff rules  
- `.shellcheckrc` - shellcheck rules
- `.yamllint.yml` - yamllint rules

## Related Documentation

- [SHELL-CONFIG-BENCHMARK-REPORT.md](SHELL-CONFIG-BENCHMARK-REPORT.md) - Performance analysis
- [lib/git/wrapper.sh](../lib/git/wrapper.sh) - Git safety wrapper
- [lib/git/hooks/pre-commit](../lib/git/hooks/pre-commit) - Pre-commit hook
