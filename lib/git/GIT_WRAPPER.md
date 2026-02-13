# Git Wrapper Module

Modular git wrapper that provides comprehensive safety protections and automation for git operations.

## 🎯 Purpose

The git wrapper provides:

1. **Dangerous Command Warnings** - Blocks destructive operations with helpful alternatives
2. **Secrets Scanning** - Automatic secrets detection via Gitleaks (5x faster than git-secrets)
3. **Dependency Validation** - Slopsquatting attack warnings for dependency changes
4. **Large File Detection** - Warns about files >5MB
5. **Large Commit Detection** - Blocks oversized commits based on research
6. **Success Feedback** - Visual confirmation for operations
7. **Syntax Validation** - Fast syntax checking via syntax.sh

## 🚀 Usage

The wrapper is automatically loaded when you source the git module. All git commands go through the wrapper.

### Bypass Flags

```bash
# Skip secrets scanning
git commit --skip-secrets -m "message"

# Skip syntax validation
git commit --skip-syntax-check -m "message"

# Skip dependency validation
git commit --skip-deps-check -m "message"

# Allow large files
git commit --allow-large-files -m "message"

# Allow large commit
git commit --allow-large-commit -m "message"

# Bypass dangerous command warnings
git reset --hard --force-danger
git push --force --force-allow
git rebase --force-danger

# Allow duplicate clone
git clone <repo> --force-allow
```

## 🔒 Security Features

### 1. Dangerous Command Protection

**Protected Commands:**

- `git reset --hard` - Warns about permanent data loss
- `git push --force` - Warns about overwriting collaborators' work
- `git rebase` - Warns about history rewriting

**Alternatives Provided:**

- Suggests safer alternatives (e.g., `--force-with-lease`)
- Provides recovery options (e.g., `git stash`)
- Shows help commands for decision-making

### 2. Secrets Detection

**Gitleaks Integration:**

- 600+ built-in secret patterns
- Entropy detection for high-entropy strings
- Custom config support: `secrets/gitleaks.toml`
- ~20ms per file (5x faster than git-secrets)

**Installation:**

```bash
brew install gitleaks
```

### 3. Dependency Change Warnings

**Protected Files:**

- `package.json`, `package-lock.json`
- `Cargo.toml`
- Other dependency manifests

**Rationale:**

- 440,000+ AI-hallucinated packages exist
- Slopsquatting attacks are common
- Warns to run security audits before committing

### 4. Large File Detection

**Threshold:** 5MB per file

**Rationale:**

- Large files bloat repository size
- Slow down clone operations
- Suggests Git LFS for binaries

### 5. Large Commit Detection

**Three-Tier Blocking System:**

| Tier | Files | Lines | Action |
|------|-------|-------|--------|
| Info | 15+ | 1000+ | Block with info |
| Warning | 25+ | 3000+ | Block with warning |
| Extreme | 40+ | 6000+ | Block with strong warning |

**Rationale:**

- Research shows defect detection drops to 28% at extreme size
- Each +100 lines adds ~25 min review time
- Historically produces 3-5x more post-review defects

## 📊 Performance

**Fast Path Optimization:**

- Safe read-only commands bypass all wrapper logic
- Prevents recursive slowdowns (e.g., git config calls)
- Zero overhead for: `status`, `diff`, `log`, `show`, `branch`, etc.

**Typical Performance:**

- Dangerous commands: ~1-2ms (warning display)
- Secrets check: ~20ms per file
- Validation checks: ~5-10ms total

## 🔧 Adding New Features

### Adding a New Safety Check

1. Create function in appropriate safety module:

   ```bash
   # safety/new-check.sh
   _run_new_check() {
       local cmd="$1"
       # Check logic
       # Return 0 to allow, 1 to block
   }
   ```

2. Add to `wrapper.sh` main function:

   ```bash
   if ! _run_new_check "$cmd" "${new_args[@]}"; then
       return 1
   fi
   ```

### Adding a New Validation

1. Add function to `utils/validation-checks.sh`:

   ```bash
   _check_new_validation() {
       # Validation logic
       # Return 0 to pass, 1 to fail
   }
   ```

2. Call in `wrapper.sh` commit section:

   ```bash
   if [[ "$cmd" == "commit" ]]; then
       _check_new_validation || return 1
   fi
   ```

### Adding a New Security Rule

1. Add to `utils/security-rules.sh`:

   ```bash
   new_rule:emoji) echo "⚠️ WARNING";;
   new_rule:desc) echo "Description here";;
   new_rule:msg1) echo "Message 1";;
   new_rule:bypass) echo "--bypass-flag";;
   ```

2. Use in safety module:

   ```bash
   _show_warning "new_rule"
   ```

## 🔍 Audit Logging

**Location:** `~/.shell-config-audit.log`
**Symlink:** `shell-config/logs/audit.log`

**Logged Events:**

- All bypass flag usage
- Timestamp and command
- Current working directory
- Specific bypass flag used

**View Audit Log:**

```bash
# Via repository symlink (recommended)
tail -20 shell-config/logs/audit.log

# Or directly from home directory
tail -20 ~/.shell-config-audit.log
```

## 🧪 Testing

### Manual Testing

```bash
# Test dangerous command warnings
git reset --hard  # Should show warning
git reset --hard --force-danger  # Should bypass

# Test large commit detection
# Create many files and commit - should block

# Test secrets detection
echo "AWS_ACCESS_KEY=AKIA..." > test.txt
git add test.txt
git commit -m "test"  # Should detect secret

# Test bypass flags
git commit --skip-secrets -m "test"  # Should bypass
```

### Automated Testing

```bash
# Load wrapper and test functions
source shell-config/lib/git/wrapper.sh

# Test individual functions
_get_real_git_command "commit"  # Should output: commit
_get_real_git_command "--skip-secrets" "commit"  # Should output: commit

# Test security rules
_get_rule_value "reset_hard" "emoji"  # Should output: 🔴 DANGER
```

## 🐛 Troubleshooting

### Wrapper Not Loading

Check git module loading:

```bash
# Check if wrapper is sourced
type git
# Should show git() function from wrapper

# Check if wrapper.sh exists
ls -la shell-config/lib/git/wrapper.sh
```

### Bypass Flags Not Working

Check for typos:

```bash
# Correct
git commit --skip-secrets -m "test"

# Incorrect (missing hyphens)
git commit --skip secrets -m "test"
```

### Gitleaks Not Found

Install Gitleaks:

```bash
# macOS
brew install gitleaks

# Verify
gitleaks version
```

### Performance Issues

Check if fast path is working:

```bash
# These should be instant (no wrapper overhead)
git status
git log
git diff

# If slow, check for recursive calls
grep -r "command git" shell-config/lib/git/
```

## 📚 References

### Related Files

- `../wrapper.sh` - Original monolithic wrapper (now compatibility layer)
- `../syntax.sh` - Syntax validation integration
- `../secrets/gitleaks.toml` - Custom Gitleaks rules
- `../../docs/git-secrets-complete-guide.md` - Comprehensive git-secrets guide

### Related Issues

- Issue #85 - Wrapper flag bypass security fix
- Issue #149 - Bypass audit logging
- Issue #191 - Modular refactoring

## 📝 Migration Notes

### From Monolithic Wrapper

The old monolithic wrapper (589 lines) was refactored into:

- **wrapper.sh** (198 lines) - Main wrapper logic (renamed from core.sh)
- **shared/** (12 files) - Reusable utilities, safety checks, parsers
- **stages/** (7 files) - Hook implementations by git lifecycle stage

**Atomic Migration (February 2026):**
The compatibility layer has been removed and all modules now reside directly in `lib/git/`:

- Entry point: `lib/git/wrapper.sh` (sourced by shell-config)
- Shared utilities: `lib/git/shared/`
- Stage implementations: `lib/git/stages/{commit,push,merge}/`
- Documentation: `lib/git/GIT_WRAPPER.md`

**Benefits:**

- Easier to navigate (find code in seconds)
- Easier to extend (add new checks without touching core)
- Easier to test (test modules independently)
- Easier to maintain (clear separation of concerns)

## 📄 License

MIT License - See repository root for details.
