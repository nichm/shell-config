# GitHub Repository Setup

This directory contains scripts to configure GitHub repository settings.

## Branch Protection & Auto-Delete Setup

### Quick Start

Run the branch protection configuration script:

```bash
./.github/setup/configure-branch-protection.sh
```

### What It Does

1. **Branch Protection for `main` branch:**
   - Requires pull request reviews (1 approval minimum)
   - Requires status checks to pass before merging
   - Requires branches to be up to date before merging
   - Includes administrators (admins must follow same rules)
   - Requires conversation resolution before merging
   - Prevents force pushes
   - Prevents branch deletion

2. **Auto-Delete Branches on Merge:**
   - Automatically deletes merged branches
   - Keeps repository clean
   - Reduces branch clutter

### Requirements

- GitHub CLI (`gh`) installed and authenticated
- Repository owner/admin permissions
- Run from repository root directory

### Manual Verification

After running the script, verify settings at:
- Branch protection: `https://github.com/<owner>/<repo>/settings/branches`
- Repository settings: `https://github.com/<owner>/<repo>/settings`

## Code Formatting Setup

### Configuration Files

- **`.prettierrc.js`** - JavaScript/TypeScript/JSON/YAML formatting (Prettier)

### Pre-Commit Hook Integration

The pre-commit hook automatically checks formatting for:
- JavaScript/TypeScript (`.js`, `.jsx`, `.ts`, `.tsx`) - uses `prettier`
- JSON files (`.json`) - uses `prettier`
- YAML files (`.yml`, `.yaml`) - uses `prettier`

### Usage

**Check formatting (non-blocking by default):**
```bash
git commit -m "your message"
# Shows warnings if files need formatting
```

**Auto-fix formatting:**
```bash
GIT_AUTO_FIX_FORMAT=1 git commit -m "your message"
# Automatically formats files and re-stages them
```

**Block commits on formatting errors:**
```bash
GIT_BLOCK_FORMAT=1 git commit -m "your message"
# Fails commit if files need formatting
```

**Manual formatting:**
```bash
# Format JS/TS/JSON/YAML
prettier --write "**/*.{js,jsx,ts,tsx,json,yml,yaml}"
```

### Formatting Settings

**JavaScript/TypeScript/JSON/YAML (Prettier):**
- 100 character line width (wider for readability)
- 2-space indentation
- Single quotes (matches shell script style)
- Trailing commas (easier diffs)
- Unix line endings (LF)

## Troubleshooting

### Branch Protection Script Fails

**Error: "GitHub CLI not authenticated"**
```bash
gh auth login
```

**Error: "Could not determine repository"**
- Ensure you're in the repository root directory
- Check that `.git` directory exists

**Error: "Failed to configure branch protection"**
- Verify you have admin/owner permissions
- Check GitHub API rate limits
- Ensure `main` branch exists

### Formatting Checks Fail

**Error: "prettier not found"**
```bash
npm install -g prettier
# or
pnpm add -g prettier
```

**Formatting check is too slow:**
- Formatting checks run in parallel with other checks
- Use `GIT_SKIP_HOOKS=1` to bypass (not recommended)
- Consider running formatting manually before committing
