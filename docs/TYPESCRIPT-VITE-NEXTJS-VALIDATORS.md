# TypeScript/Vite/Next.js Validators

This document describes the TypeScript/Vite/Next.js specific validators added to the shell-config git hooks system.

## Overview

These validators provide additional quality checks specific to TypeScript, Vite, and Next.js projects. They run as part of the pre-commit hook and can be bypassed individually if needed.

## Validators

### 1. Environment Variable Security Validator

**Location:** `lib/validation/validators/typescript/env-security-validator.sh`

**Checks:**
- Detects `NEXT_PUBLIC_` prefixed variables with suspicious patterns (keys, secrets, passwords, tokens, etc.)
- Validates `.env` files are properly gitignored
- Ensures `.env.example` or `.env.sample` exists when `.env` files are present
- Checks for server/client boundary violations

**Severity:**
- Errors: Blocking (commit will fail)
- Warnings: Non-blocking (informational)

**Bypass:**
```bash
GIT_SKIP_ENV_SECURITY_CHECK=1 git commit -m "message"
```

### 2. Test Coverage Validator

**Location:** `lib/validation/validators/typescript/test-coverage-validator.sh`

**Checks:**
- Ensures test files exist for new source files
- Supports common test file patterns: `.test.ts`, `.spec.ts`, `__tests__/`, `tests/`
- Checks vitest/jest coverage configuration
- Validates coverage thresholds are configured

**File Types Checked:**
- JavaScript/TypeScript: `.js`, `.ts`, `.jsx`, `.tsx`
- Python: `.py`
- Go: `.go`
- Rust: `.rs`

**Excluded Patterns:**
- `node_modules/`, `dist/`, `build/`, `.next/`, `out/`, `coverage/`
- `*.config.js/ts`, `*.d.ts`
- Types/interfaces/constants directories

**Severity:**
- Errors: Warning only by default (non-blocking)
- Can be made blocking via: `GIT_BLOCK_MISSING_TESTS=1`

**Bypass:**
```bash
GIT_SKIP_TEST_COVERAGE_CHECK=1 git commit -m "message"
```

### 3. Framework Configuration Validator

**Location:** `lib/validation/validators/typescript/framework-config-validator.sh`

**Checks:**
- **TypeScript:** Verifies `strict: true` in `tsconfig.json`
- **Vite:** Validates `vite.config.ts/js` has plugins and build configuration
- **Next.js:** Checks `next.config.js/mjs/ts` for experimental features and image optimization
- **ESLint:** Ensures ESLint configuration exists (flat config or legacy)
- **Lint Tools:** Verifies oxlint or eslint is installed

**Severity:**
- Missing linter: Blocking error
- All other checks: Warnings (non-blocking)

**Bypass:**
```bash
GIT_SKIP_FRAMEWORK_CONFIG_CHECK=1 git commit -m "message"
```

## PR Merge Check Workflow

**Location:** `.github/workflows/pr-merge-check.yml`

**Triggers:**
- Pull requests (opened, synchronized, reopened)
- Push to `main` or `develop` branches

**Checks:**
1. **Build** - Runs `bun run build` (or npm/pnpm/yarn equivalent)
2. **Type Check** - Runs `tsc --noEmit`
3. **Lint** - Prefers oxlint, falls back to eslint
4. **Test** - Detects and runs appropriate test runner (vitest, jest, or bun test)

**Features:**
- Auto-detects package manager (bun, pnpm, yarn, npm)
- Auto-detects framework (Next.js, Vite, Remix, vanilla)
- Comments on PR with results
- Blocks merge if any check fails

**Required for Merge:**
All checks must pass before PR can be merged. This is enforced via GitHub branch protection rules.

## Bun Compliance

The shell-config codebase is fully Bun compliant:

1. **Pre-commit hooks:** Use `bun test` for running unit tests
2. **Aliases:** Provides `b*` aliases for common bun commands (`bi`, `ba`, `br`, `bdev`, etc.)
3. **Workflows:** GitHub Actions use `oven-sh/setup-bun@v2` for Bun projects
4. **No hard dependencies:** Shell scripts work regardless of whether project uses bun, npm, pnpm, or yarn

### Bun-Specific Features

```bash
# Bun aliases (from lib/aliases/package-managers.sh)
bi      # bun install
ba      # bun add
bad     # bun add -D
br      # bun remove
bdev    # bun run dev
bbuild  # bun run build
btest   # bun run test
blint   # bun run lint
btype   # bun run typecheck
```

## Integration with Pre-commit Hook

The new validators are integrated into the pre-commit hook in `lib/git/stages/commit/pre-commit.sh`:

```bash
# Run in parallel with other checks
run_env_security_check "$tmpdir" "${files[@]}" &
run_test_coverage_check "$tmpdir" "${files[@]}" &
run_framework_config_check "$tmpdir" &
```

Results are collected and reported along with other pre-commit validation results.

## Testing

Test files for these validators should be added to:
```
tests/validation/validators/typescript/
├── env-security-validator.bats
├── test-coverage-validator.bats
└── framework-config-validator.bats
```

## Configuration

### Environment Variables

- `GIT_SKIP_ENV_SECURITY_CHECK` - Skip environment variable security check
- `GIT_SKIP_TEST_COVERAGE_CHECK` - Skip test coverage check
- `GIT_SKIP_FRAMEWORK_CONFIG_CHECK` - Skip framework config check
- `GIT_BLOCK_MISSING_TESTS` - Make missing tests a blocking error
- `GIT_BLOCK_FORMAT` - Make format errors blocking

### Package.json Scripts

Recommended scripts for TypeScript projects:

```json
{
  "scripts": {
    "dev": "next dev || vite dev",
    "build": "next build || vite build",
    "test": "bun test || vitest run",
    "lint": "oxlint || eslint .",
    "typecheck": "tsc --noEmit"
  }
}
```

## Troubleshooting

### Validator Not Running

1. Ensure validators are sourced in pre-commit-checks.sh
2. Check SHELL_CONFIG_DIR is set correctly
3. Verify file permissions: `chmod +x lib/validation/validators/typescript/*.sh`

### False Positives

1. Use bypass flags for temporary exceptions
2. Update validator patterns to exclude specific cases
3. Add `.gitignore` entries for legitimate `.env` files

### Performance Issues

Validators run in parallel with other pre-commit checks. If performance is a concern:

1. Use `GIT_SKIP_HOOKS=1` to bypass all hooks temporarily
2. Adjust parallel execution in pre-commit.sh
3. Skip specific validators that aren't relevant

## Related Documentation

- [Main CLAUDE.md](../CLAUDE.md) - Shell-script development guidelines
- [SYNTAX-VALIDATOR.md](SYNTAX-VALIDATOR.md) - General syntax validation
- [decisions/BASH-5-UPGRADE.md](decisions/BASH-5-UPGRADE.md) - Bash 5.x features
- Issue #28 - Original TypeScript/Vite/Next.js validator issue

## Contributing

When adding new validators:

1. Follow existing patterns in `lib/validation/validators/`
2. Include WHAT/WHY/FIX error messages
3. Add tests in `tests/validation/validators/`
4. Update this documentation
5. Use command cache for performance

## License

Part of the shell-config project. See repository license for details.
