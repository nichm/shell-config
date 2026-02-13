# Gitleaks Migration

**Status:** ✅ Complete (2026-01-30)

Migrated from `git-secrets` to **Gitleaks** for secret detection.

## Benefits

- **5x faster** scanning (102ms → ~20ms per file)
- **600+ built-in patterns** (vs custom patterns)
- **Better accuracy** with entropy detection
- **Single binary** (no git config dependency)

## Installation

```bash
# macOS
brew install gitleaks

# Verify
~/.shell-config/lib/git/setup.sh status
```

## Usage

**Automatic:** Runs on every commit via pre-commit hook.

**Manual:**

```bash
gitleaks detect --source . --config ~/.shell-config/lib/git/secrets/gitleaks.toml
```

**Bypass (not recommended):**

```bash
git commit --skip-secrets -m "message"
```

## Configuration

Custom config: `~/.shell-config/lib/git/secrets/gitleaks.toml`

**Add custom patterns:**

```toml
[[rules]]
id = "my-custom-key"
description = "My Custom API Key"
regex = '''myapi_[a-zA-Z0-9]{32}'''
keywords = ["myapi_"]
```

**Add allowlist:**

```toml
[allowlist]
regexes = ['''my_allowed_pattern''']
```

## References

- [Gitleaks GitHub](https://github.com/zricethezav/gitleaks)
- [Built-in Rules](https://github.com/zricethezav/gitleaks/blob/master/config/gitleaks.toml)
