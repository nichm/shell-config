# Environment Variable Namespace Migration Guide

**Migration Date:** 2026-01-29
**Issue:** #112
**Status:** ✅ Complete

---

## Summary

All shell-config environment variables have been properly namespaced to prevent conflicts with user scripts and other tools. This migration follows shell scripting best practices and ensures better isolation of shell-config variables.

## What Changed

### Local Script Variables (Internal Use)

These variables are **internal to shell-config scripts** and are not intended for user configuration:

| Old Name | New Name | Location |
|----------|----------|----------|
| `GH_AVAILABLE` | `SC_GH_AVAILABLE` | `lib/ghls/ghls` |
| `_SL_GH_AVAILABLE` | `SC_GH_AVAILABLE` | `lib/ghls/statusline.sh` |
| `FAST_MODE` | `SC_FAST_MODE` | `lib/ghls/ghls` |
| `SKIP_DEPS` | `SC_SKIP_DEPS` | `install.sh` |
| `SKIP_UV` | `SC_SKIP_UV` | `install.sh` |

**Note:** The `_SL_*` prefix variables in `statusline.sh` (e.g., `_SL_BOLD`, `_SL_RESET`) are **readonly color constants** and remain unchanged. Only mutable state variables were migrated to `SC_*`.

### User-Configurable Environment Variables (No Changes)

These variables were **already properly namespaced** and remain unchanged:

- `SHELL_CONFIG_*` - Feature flags (git wrapper, command safety, etc.)
- `WELCOME_*` - Welcome message configuration
- `RM_AUDIT_*`, `RM_PROTECT_ENABLED`, `RM_FORCE_CONFIRM` - RM wrapper settings
- `COMMAND_SAFETY_*` - Command safety engine settings

## Why This Matters

### Before (Problem)

```bash
# User script:
export FAST_MODE=true

# Shell-config's ghls script:
FAST_MODE=false  # ❌ Conflicts with user variable!
```

### After (Solution)

```bash
# User script:
export FAST_MODE=true  # ✅ No conflict

# Shell-config's ghls script:
SC_FAST_MODE=false  # ✅ Properly namespaced
```

## Naming Convention

Shell-config now follows a clear naming convention:

| Prefix | Usage | Example |
|--------|-------|---------|
| `SHELL_CONFIG_*` | Exported feature flags | `SHELL_CONFIG_GIT_WRAPPER=false` |
| `WELCOME_*` | Welcome message settings | `WELCOME_MESSAGE_ENABLED=true` |
| `RM_*` | RM wrapper configuration | `RM_AUDIT_ENABLED=1` |
| `SC_*` | Internal script variables | `SC_GH_AVAILABLE=true` |
| `_*` | Private function-scoped vars | `_WM_COLOR_RESET='\033[0m'` |

## Migration Impact

### For Users

**No action required.** All user-facing environment variables remain unchanged. This migration only affects internal script variables.

### For Developers

If you have scripts that reference internal shell-config variables:

1. **Stop using internal variables** - They are implementation details
2. **Use public feature flags** - See `FEATURES.md` for configuration options
3. **Use `SC_*` prefix** - If you must namespace your own variables

## Testing

All shell-config features have been tested and verified working:

- ✅ `ghls` command (with `SC_GH_AVAILABLE` and `SC_FAST_MODE`)
- ✅ Git statusline (with `SC_GH_AVAILABLE`)
- ✅ Installation script (with `SC_SKIP_DEPS` and `SC_SKIP_UV`)
- ✅ Welcome message (with `WELCOME_*` vars - unchanged)
- ✅ Command safety (with `SHELL_CONFIG_COMMAND_SAFETY` - unchanged)
- ✅ All other features (unchanged)

## Verification

To verify the migration is complete:

```bash
# Check for any remaining non-namespaced variables
cd ~/.shell-config
grep -r "^\s*[A-Z_][A-Z0-9_]*=" lib/ | grep -v "SC_\|SHELL_CONFIG_\|WELCOME_\|RM_\|COMMAND_SAFETY_\|HOMEBREW_\|BUN_\|PATH\|MANPATH\|INFOPATH"

# Should return empty (all variables properly namespaced)
```

## Future Best Practices

When adding new variables to shell-config:

1. **User-configurable settings:** Use `SHELL_CONFIG_*` or feature-specific prefix
2. **Internal script variables:** Use `SC_*` prefix
3. **Private function variables:** Use `_*` prefix
4. **Exported variables:** Always namespace with clear prefix
5. **Local variables:** Use `local` keyword and descriptive names

## References

- Issue: #112
- Analysis Report: `SHELL-CONFIG-ANALYSIS-REPORT.md` (Q21)
- Features: `FEATURES.md`
- Best Practices: [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

---

**Migration completed successfully on 2026-01-29**

All shell-config variables are now properly namespaced following industry best practices.
