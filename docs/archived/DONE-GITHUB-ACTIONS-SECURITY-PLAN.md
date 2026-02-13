# GitHub Actions Security Scanning Plan

**Report Date:** 2025-01-28
**Status:** Implementation Complete

## Executive Summary

This document outlines the implementation plan for multi-engine GitHub Actions security scanning. After testing 6+ security scanning tools, we have integrated 4 complementary scanners that provide comprehensive coverage of workflow vulnerabilities.

## Tools Tested & Analysis

### Tested Tools

| Tool | Version | Status | Purpose | Installation |
|------|---------|--------|---------|--------------|
| **actionlint** | 1.7.10 | ✅ Integrated | Syntax, shellcheck, permissions | `brew install actionlint` |
| **zizmor** | 1.22.0 | ✅ Integrated | Security: injection, unpinned actions, credentials | `brew install zizmor` |
| **poutine** | 1.0.6 | ✅ Integrated | Supply chain: verified creators, injections | Binary download |
| **pinact** | 3.8.0 | ✅ Integrated | Version pinning enforcement | `brew install pinact` |
| **octoscan** | latest | ✅ Integrated | Expression injection, dangerous checkout, credentials | Build from source |
| **ades** | - | ❌ Skipped | Package name collision (encryption tool) | N/A |

### Tool Comparison Matrix

| Check Type | actionlint | zizmor | poutine | octoscan |
|------------|:----------:|:------:|:-------:|:--------:|
| Syntax validation | ✅ | - | - | - |
| ShellCheck integration | ✅ | - | - | ✅ |
| Permissions validation | ✅ | ✅ | - | - |
| Expression validation | ✅ | - | - | - |
| Template injection | ✅ | ✅ | ✅ | ✅ |
| Dangerous checkout | - | - | - | ✅ |
| Unpinned actions | - | ✅ | - | - |
| Credential persistence | - | ✅ | - | ✅ |
| Unverified creators | - | - | ✅ | ✅ |
| Self-hosted runner risks | - | - | ✅ | ✅ |
| Known vulnerabilities | - | - | - | ✅ |
| SARIF output | ✅ | ✅ | ✅ | ✅ |

## Current Findings Summary

### Repository Scan Results (2025-01-28)

| Category | Count | Severity | Action Required |
|----------|-------|----------|-----------------|
| Syntax/ShellCheck (info) | 60+ | Info | Optional |
| Unknown permission scope | 1 | Error | Fix Required |
| If-condition always true | 2 | Error | Fix Required |
| Template injection (high) | 15+ | High | Review Required |
| Template injection (low) | 40+ | Info | Optional |
| Unpinned actions | 80+ | High | Review (policy decision) |
| Unverified creators | 7 | Note | Acknowledged |
| Self-hosted runner (FP) | 10 | Note | False Positive (configured) |
| Excessive permissions | 7 | Medium | Review Required |

### False Positives Identified

1. **Self-hosted runner warnings (poutine)**
   - We use Ubicloud and BuildJet runners intentionally
   - Suppressed via `.poutine.yml` configuration

2. **Unpinned actions (zizmor)**
   - Policy decision: We use semver tags for trusted actions
   - Can be changed to SHA pinning via `pinact run`

3. **Template injection (low confidence)**
   - Many are from step outputs, not user input
   - Suppressed low-confidence findings via `.zizmor.yml`

## Implementation

### Files Created

1. **`.poutine.yml`** - Poutine configuration
   - Skips `pr_runs_on_self_hosted` rule (false positive)

2. **`.zizmor.yml`** - Zizmor configuration
   - Sets severity levels for different rule types
   - Reduces noise from low-confidence findings

3. **`.github/actionlint.yaml`** - Actionlint configuration
   - Already existed with custom runner labels

4. **`shell-config/lib/gha-security/scanner.sh`** - Multi-engine scanner
   - Main scanner logic with actionlint, zizmor, poutine, octoscan integration
   - `config/.zizmor.yml` - Zizmor configuration
   - `config/.poutine.yml` - Poutine configuration

5. **`shell-config/lib/bin/gha-scan`** - CLI wrapper for PATH

6. **`.github/workflows/gha-security-scan.yml`** - CI workflow
   - Runs on workflow file changes
   - Uploads SARIF to GitHub Code Scanning
   - Comments on PRs with findings

7. **Updated `shell-config/lib/git/hooks/pre-commit`**
   - Added actionlint validation for workflow files

### Pre-commit Integration

The pre-commit hook now validates GitHub Actions workflows:

```bash
# Automatic on commit (if actionlint installed)
git commit -m "update workflow"

# Skip if needed
GIT_SKIP_HOOKS=1 git commit -m "update workflow"
```

### Local Usage (Universal CLI)

The scanner is integrated into shell-config and available as `gha-scan` command:

```bash
# Default scan (actionlint + zizmor - recommended balance)
gha-scan

# Quick scan (actionlint only - fastest)
gha-scan -q

# Full scan (adds poutine + octoscan for deeper analysis)
gha-scan -a

# Modified files only (for pre-commit)
gha-scan -m

# Scan specific repo
gha-scan /path/to/repo
```

### Recommended Configuration

**What's enabled by default:**

- **actionlint**: Syntax, permissions, expression validation, shellcheck (errors only)
- **zizmor**: Template injection, unsound conditions, dangerous triggers

**What's filtered out (noise reduction):**

- SHA pinning warnings (we use semver tags like `v4` for trusted actions)
- Shellcheck info/style suggestions (not real bugs)
- Template injection from workflow_dispatch inputs (admin-controlled)
- Template injection from step outputs (internal, not user-controlled)

**Remaining issues are real bugs:**

- Actual expression injection from untrusted user input
- Logic bugs in `if:` conditions
- Invalid permissions that will cause failures
- Dangerous triggers (pull_request_target)

## Required Fixes

### Priority 1: Errors (Must Fix)

1. **Unknown permission scope `workflows`** - `auto-fix.yml:82`

   ```yaml
   # Remove or replace with valid scope
   # workflows: write  # Invalid
   contents: write    # Valid alternative
   ```

2. **If-condition always true** - `auto-fix.yml:73`, `claude.yml:318`

   ```yaml
   # Wrong (outer ${{ }} with inner expression)
   if: always() && ${{ steps.context.outputs.issue_number != '' }}
   
   # Correct
   if: always() && steps.context.outputs.issue_number != ''
   ```

### Priority 2: High Severity (Should Fix)

1. **Template injection with user input** - Multiple files
   - Pass untrusted input via environment variables
   - Example fix:

   ```yaml
   # Before (vulnerable)
   run: echo "Title: ${{ github.event.issue.title }}"
   
   # After (safe)
   env:
     ISSUE_TITLE: ${{ github.event.issue.title }}
   run: echo "Title: $ISSUE_TITLE"
   ```

2. **Excessive permissions** - `package-checker.yml:39-40`
   - Move permissions to job level instead of workflow level
   - Use minimal required permissions per job

### Priority 3: Warnings (Consider Fixing)

1. **Unpinned actions** - All workflows
   - Decision: Pin to SHA for supply chain security
   - Run `pinact run` to auto-pin all actions

2. **persist-credentials: false** - Multiple checkouts
   - Add to all `actions/checkout` steps

## CI/CD Integration

### GitHub Code Scanning

The workflow uploads SARIF files to GitHub Code Scanning:

- Results appear in Security → Code scanning alerts
- Can set as required status check

### Branch Protection

Recommended settings:

1. Add `GHA Security Scan` as required status check
2. Require code scanning alerts to be addressed
3. Enable Dependabot alerts for actions

## Maintenance

### Tool Updates

```bash
# Update tools via Homebrew
brew upgrade actionlint zizmor pinact

# Update poutine (manual)
curl -sSL https://github.com/boostsecurityio/poutine/releases/latest/download/poutine_darwin_arm64.tar.gz | tar -xz -C /tmp
```

### Adding New Rules

1. **Suppress false positives** - Add to `.poutine.yml` or `.zizmor.yml`
2. **Custom actionlint rules** - Update `.github/actionlint.yaml`
3. **New runner labels** - Add to actionlint config

## References

- [Awesome GitHub Actions Security](https://github.com/johnbillion/awesome-github-actions-security)
- [Actionlint Documentation](https://github.com/rhysd/actionlint)
- [Zizmor Documentation](https://docs.zizmor.sh/)
- [Poutine Documentation](https://boostsecurityio.github.io/poutine/)
- [GitHub Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

## Conclusion

The multi-engine approach provides comprehensive security coverage:

- **actionlint**: Catches syntax and logic errors before CI runs
- **zizmor**: Focuses on security-specific issues
- **poutine**: Supply chain and injection vulnerabilities
- **pinact**: Enforces version pinning policy

Using multiple scanners is recommended as each catches different issues. The configuration files suppress known false positives while maintaining security coverage.
