# RM Security Guide

**Version:** 2.0
**Updated:** 2026-01-31
**Related Issue:** #156 (internal tracking)

---

## Executive Summary

This shell config implements a **multi-layer protection approach** for `rm` operations, balancing safety with usability. The system uses four independent layers of protection, from convenient warnings to kernel-level immutable file protection.

**Key Design Philosophy:**

- Provide **mechanism**, not policy (Unix tradition)
- Allow expert users to bypass when needed
- Real security = **kernel-level (chflags)**, not shell wrappers
- AI-safe non-interactive design

---

## Protection Architecture

### Layer 1: Command-Safety System

**Location:** `lib/command-safety/`
**Scope:** Pattern-based warnings
**Audit Log:** `~/.command-safety.log`

**What it does:**

- Warns on dangerous patterns (e.g., `rm -rf` requires `--force-danger`)
- Non-interactive design (AI-safe)
- Logs all violations to audit log
- Provides alternative command suggestions

**Example:**

```bash
$ rm -rf /tmp/test
⚠️  DANGER: rm -rf PERMANENTLY deletes without confirmation.
   Rule: Recursive force delete - PERMANENT data loss risk
   Alternatives:
     • rm -ri <path>   # Interactive confirmation
     • trash <path>    # Move to trash (recoverable)
     • git rm -r       # If tracked files
   Bypass: rm -rf /tmp/test --force-danger

$ rm -rf /tmp/test --force-danger
# Executes with bypass flag
```

**View logs:**

```bash
command_safety_log    # View command-safety violations
```

---

### Layer 2: PATH Wrapper

**Location:** `lib/bin/rm`
**Scope:** Protected path blocking
**Audit Log:** `~/.rm_audit.log`

**What it does:**

- Intercepts ALL `rm` calls (including `command rm`) by being first in PATH
- Blocks deletion of protected paths
- Zero overhead (<1ms on M1 Mac)
- Async audit logging (non-blocking)

**Protected Paths:**

- **Home config:** `~/.ssh`, `~/.gnupg`, `~/.shell-config`, `~/.config`
- **Dotfiles:** `~/.zshrc`, `~/.zshenv`, `~/.bashrc`, `~/.gitconfig`
- **System:** `/`, `/etc`, `/usr`, `/var`, `/bin`, `/sbin`
- **macOS:** `/System`, `/Library`, `/Applications`

**Example:**

```bash
$ rm -rf ~/.ssh
🔴 BLOCKED: Protected path(s):
   • /Users/you/.ssh
Bypass: /bin/rm -rf /Users/you/.ssh

$ /bin/rm -rf ~/.ssh
# Executes (bypasses PATH wrapper, but blocked by Layer 3 function override)
```

**View logs:**

```bash
rm-audit              # View rm audit log (last 50 lines)
rm-audit 100          # View last 100 lines
rm-audit-bypass       # Analyze bypass attempts
rm-audit-clear        # Clear audit log
```

---

### Layer 3: Function Override

**Location:** `lib/security/rm/wrapper.sh` (function: `rm()`)
**Scope:** Blocks `/bin/rm` on protected paths (interactive shells only)
**Delegates:** To PATH wrapper (Layer 2)

**What it does:**

- Blocks direct calls to `/bin/rm` in interactive shells
- **Scripts bypass this automatically** (functions don't execute in non-interactive shells)
- Checks arguments against protected paths
- Logs blocked attempts to audit log
- Delegates to PATH wrapper for non-protected paths

**Example:**

```bash
# Interactive shell (user types command)
$ /bin/rm -rf ~/.ssh
🔴 BLOCKED: Protected path: /Users/you/.ssh
   Use unprotect-file first or trash-rm instead
   Bypass: command /bin/rm -rf '/Users/you/.ssh'

# Script (non-interactive shell)
#!/bin/bash
/bin/rm -rf ~/.ssh
# Executes (function override doesn't run in scripts)
```

**Why scripts bypass:**

- Scripts are assumed to be tested/intentional
- Functions don't execute in non-interactive shells
- Prevents breaking automation
- Allows expert users to use `/bin/rm` in scripts

---

### Layer 4: Kernel Protection

**Location:** `lib/security/filesystem/protect.sh` (functions: `protect-file`, `unprotect-file`)
**Scope:** Filesystem level
**Mechanism:** `chflags schg` (immutable flag)

**What it does:**

- Makes files **immutable** at kernel level
- Blocks **all** deletion attempts (even by root)
- Provides ultimate safety for critical files
- Intentional bypass requires `sudo chflags noschg`

**Example:**

```bash
$ protect-file ~/.ssh/config
🔒 Protected: /Users/you/.ssh/config

$ rm ~/.ssh/config
rm: ~/.ssh/config: Operation not permitted

$ sudo rm ~/.ssh/config
rm: ~/.ssh/config: Operation not permitted

$ /bin/rm ~/.ssh/config
# Still blocked - kernel protection

$ unprotect-file ~/.ssh/config
🔓 Unprotected: /Users/you/.ssh/config

$ rm ~/.ssh/config
# Now works (protection removed)
```

**Commands:**

```bash
protect-file <path>       # Make file immutable
unprotect-file <path>     # Remove kernel protection
protect-dir <dir>         # Recursive directory protection
unprotect-dir <dir>       # Recursive directory unprotection
list-protected [dir]      # List protected files
```

**Use cases:**

- Critical SSH keys: `protect-file ~/.ssh/id_ed25519`
- Important configs: `protect-file ~/.gitconfig`
- Development directories: `protect-dir ~/projects/critical`

---

## The /bin/rm Bypass

### Why It Exists

The `/bin/rm` bypass is **intentional** design:

- Provides escape hatch for legitimate needs
- Allows expert users to override protections
- Unix philosophy: mechanism, not policy
- Real security comes from **chflags** (Layer 4), not shell wrappers

### How It Works

**Bypass chain:**

```
User types: /bin/rm file.txt
  ↓
Shell lookup:
  1. Command-safety wrapper rm() → NOT invoked (called /bin/rm directly)
  2. Function override rm() → NOT invoked (called /bin/rm directly)
  3. PATH wrapper lib/bin/rm → BYPASSED (absolute path)
  4. Kernel chflags protection → Still blocks immutable files
```

**Result:**

- ❌ Bypasses command-safety pattern detection
- ❌ Bypasses PATH wrapper protected path checks
- ❌ Bypasses rm() function (absolute path bypasses function)
- ✅ **Still blocked** by chflags for protected files

### Detection & Monitoring

All `/bin/rm` usage is logged to audit logs:

```bash
# View bypass attempts
rm-audit-bypass

# View recent activity
tail -20 ~/.rm_audit.log

# Check for patterns (scripts vs AI agents)
rm-audit-bypass | grep -E "(script|agent|claude)"
```

---

## AI Agent Guidelines

### Safety Rules

**For AI Agents (Claude, ChatGPT, etc.):**

1. **Always use `trash-rm` instead of `rm`**

   ```bash
   # GOOD
   trash-rm file.txt

   # BAD
   rm file.txt
   ```

2. **Use `--force-danger` bypass only when user explicitly confirms**

   ```bash
   # Ask user first
   "Are you sure you want to delete these files? [y/N] "

   # Only then use bypass
   rm -rf /tmp/test --force-danger
   ```

3. **Never use `/bin/rm` unless explicitly required**

   ```bash
   # BAD
   /bin/rm file.txt

   # GOOD (use normal rm - protections apply)
   rm file.txt

   # GOOD (use trash - recoverable)
   trash file.txt
   ```

4. **Check audit logs after operations**

   ```bash
   rm-audit-bypass    # Review bypass attempts
   command_safety_log # Review command-safety violations
   ```

### Decision Tree

```
Need to delete files?
│
├─ Is it a critical file (SSH keys, configs)?
│  └─ YES → Use protect-file (kernel protection is already there)
│           If need to delete: unprotect-file first, then trash-rm
│
├─ Is it an AI operation?
│  └─ YES → Always use trash-rm (recoverable)
│           Never use rm unless user confirms
│
├─ Is it an emergency?
│  └─ YES → Use /bin/rm + document reason in commit
│           Check: rm-audit-bypass after
│
└─ Normal operation?
   └─ Use rm (protection layers apply)
      or trash-rm (recoverable, recommended)
```

---

## Command Reference

### RM Operations

```bash
# Safe deletion (recoverable)
trash-rm <path>          # Move to trash
alias: trm

# Normal rm (with protection layers)
rm <path>                # Protected by Layers 1-3

# Force bypass (not recommended)
rm -rf <path> --force-danger    # Bypass command-safety warning
/bin/rm <path>                   # Bypass PATH wrapper
command /bin/rm <path>           # Bypass function override

# Emergency (document reason)
/bin/rm <path>    # Log reason in commit message
```

### Audit & Analysis

```bash
rm-audit               # View rm audit log (last 50 lines)
rm-audit <n>           # View last n lines
rm-audit-bypass        # Analyze bypass attempts
rm-audit-clear         # Clear audit log
command_safety_log     # View command-safety violations
```

### Kernel Protection

```bash
protect-file <path>    # Make file immutable
unprotect-file <path>  # Remove kernel protection
protect-dir <dir>      # Recursive directory protection
unprotect-dir <dir>    # Recursive directory unprotection
list-protected [dir]   # List protected files
```

### Help & Documentation

```bash
rm-safety              # Show inline help (this guide)
man rm                 # Official rm documentation
```

---

## Configuration

### Environment Variables

```bash
# Enable/disable rm protection (Layer 2)
export RM_PROTECT_ENABLED=1    # 1 = enabled, 0 = disabled

# Enable/disable audit logging
export RM_AUDIT_ENABLED=1      # 1 = enabled, 0 = disabled

# Force confirmation for dangerous operations
export RM_FORCE_CONFIRM=0      # 1 = enabled, 0 = disabled

# Enable/disable bypass warnings (Layer 1)
export RM_BYPASS_WARNING=1     # 1 = enabled, 0 = disabled

# Audit log location
export RM_AUDIT_LOG="$HOME/.rm_audit.log"
```

### Disable Protection (Not Recommended)

```bash
# Disable all protection layers
export RM_PROTECT_ENABLED=0
export RM_BYPASS_WARNING=0

# Use system rm directly
export PATH="/usr/bin:$PATH"   # Put system bin first
```

---

## Troubleshooting

### "Operation not permitted" Error

**Cause:** File has kernel protection (chflags)

**Solution:**

```bash
# Check if file is protected
list-protected

# Remove protection
unprotect-file <path>

# Then delete
rm <path>
```

### "BLOCKED: Protected path" Error

**Cause:** Protected path blocked by PATH wrapper or function override

**Solutions:**

```bash
# Option 1: Use trash (recommended)
trash-rm <path>

# Option 2: Unprotect first (if kernel-protected)
unprotect-file <path>
rm <path>

# Option 3: Bypass (not recommended, document reason)
/bin/rm <path>
```

### Audit Log Missing

**Cause:** Audit logging disabled or log deleted

**Solution:**

```bash
# Check if enabled
echo $RM_AUDIT_ENABLED

# Enable if needed
export RM_AUDIT_ENABLED=1

# View log location
echo $RM_AUDIT_LOG
```

### Script Can't Delete Protected Paths

**Cause:** Script uses `rm` (blocked by PATH wrapper)

**Solution:**

```bash
# Option 1: Use /bin/rm in script (scripts bypass function override)
/bin/rm <path>

# Option 2: Disable protection in script
export RM_PROTECT_ENABLED=0
rm <path>

# Option 3: Use trash (safer)
trash <path>
```

---

## Best Practices

### For Daily Use

1. **Use `trash-rm` for most deletions**
   - Recoverable if you make a mistake
   - No risk of permanent data loss
   - Works with all protections

2. **Use `protect-file` for critical files**
   - SSH keys: `protect-file ~/.ssh/id_*`
   - Important configs: `protect-file ~/.gitconfig`
   - Project directories: `protect-dir ~/projects/important`

3. **Check audit logs periodically**
   - `rm-audit-bypass` to review bypass attempts
   - Look for patterns (scripts, AI agents, mistakes)
   - Adjust protections based on usage

### For Development

1. **Use `git rm` for tracked files**
   - Safer than `rm` for version-controlled files
   - Properly stages deletion in git

2. **Protect build directories**
   - `protect-dir node_modules/.cache`
   - Prevents accidental cache deletion

3. **Audit script behavior**
   - Check if scripts use `/bin/rm`
   - Review bypass patterns: `rm-audit-bypass | grep script`

### For AI Agents

1. **Always use `trash-rm`**
   - Never use `rm` unless user confirms
   - Never use `/bin/rm` unless explicitly required

2. **Check before deleting**
   - Run `ls -la <path>` to see what will be deleted
   - Run `git status` to check for uncommitted changes
   - Ask user for confirmation on dangerous operations

3. **Log and review**
   - Check `rm-audit-bypass` after operations
   - Document bypass reasons in commit messages

---

## Security Model

### Threat Levels

**Level 1: Annoyance** (Command-safety warnings)

- Protects against: Mistakes, typos, misunderstandings
- Mechanism: Pattern matching, require bypass flag
- Bypass: `--force-danger` flag

**Level 2: Data Loss** (PATH wrapper)

- Protects against: Accidental deletion of protected paths
- Mechanism: PATH interception, protected path blocking
- Bypass: `/bin/rm` absolute path

**Level 3: Script Safety** (Function override)

- Protects against: Interactive shell mistakes
- Mechanism: Function override in interactive shells
- Bypass: Scripts (functions don't execute in non-interactive)

**Level 4: Critical Protection** (Kernel chflags)

- Protects against: ALL deletion attempts (even root)
- Mechanism: Immutable flag at filesystem level
- Bypass: `sudo chflags noschg` (intentional)

### What Each Layer Protects Against

| Threat | Layer 1 | Layer 2 | Layer 3 | Layer 4 |
|--------|---------|---------|---------|---------|
| Typos (`rm -fr` instead of `rm -rf`) | ✅ | ✅ | ✅ | ✅ |
| Accidental protected path deletion | ❌ | ✅ | ✅ | ✅ |
| Script errors | ❌ | ❌ | ❌ | ✅ |
| Malicious scripts | ❌ | ❌ | ❌ | ✅ |
| Root compromise | ❌ | ❌ | ❌ | ✅ |
| User bypass (intentional) | ✅ | ✅ | ⚠️ | ❌ |

**Legend:** ✅ Protected | ❌ Not protected | ⚠️ Partial (scripts bypass)

### Realistic Expectations

**What this system DOES:**

- ✅ Prevent accidental deletion of important files
- ✅ Provide friction for dangerous operations
- ✅ Log all deletion attempts for forensic analysis
- ✅ Allow expert users to bypass when needed
- ✅ Provide kernel-level protection for critical files

**What this system does NOT do:**

- ❌ Prevent malicious intentional actions
- ❌ Protect against compromised root access
- ❌ Prevent all data loss (user can bypass)
- ❌ Replace proper backups (you still need backups!)

**Conclusion:** This is a **safety system**, not a **security system**. Real security requires:

1. Proper backups (3-2-1 rule)
2. Kernel protection (chflags) for critical files
3. User education and awareness
4. Version control (git) for important work

---

## Advanced Topics

### Adding Protected Paths

Edit `lib/bin/rm` and `lib/security/rm/wrapper.sh` to add new protected paths:

```bash
# In lib/bin/rm is_protected() function
case "$path" in
    "/new/protected/path"|"/new/protected/path"/*) return 0 ;;
esac

# In lib/security/rm/wrapper.sh rm() function
case "$arg" in
    "$HOME"/new/path|"$HOME"/new/path/*)
        # Block and log
        ;;
esac
```

### Custom Audit Log Analysis

```bash
# Find bypasses in last hour
grep "/bin/rm" ~/.rm_audit.log | tail -50

# Or filter by specific date pattern (adjust timestamp format as needed)
grep "2026-01-31" ~/.rm_audit.log | grep "/bin/rm"

# Count bypasses by directory
grep "/bin/rm" ~/.rm_audit.log | awk '{print $NF}' | sort | uniq -c

# Find dangerous operations
grep -E "rm.*-rf" ~/.rm_audit.log

# Export to CSV for analysis
grep "BLOCKED:" ~/.rm_audit.log | sed 's/|/,/g' > bypasses.csv
```

### Integration with Other Tools

**Integration with `trash`:**

```bash
# Install trash
brew install trash

# Use trash-rm alias
alias trm='trash-rm'
```

**Integration with `git`:**

```bash
# Use git rm for tracked files
git-rm() {
    if git ls-files --error-unmatch "$1" &>/dev/null; then
        git rm "$1"
    else
        rm "$1"
    fi
}
```

**Integration with monitoring:**

```bash
# Alert on frequent bypasses
bypass-alert() {
    local count
    count=$(grep -c "/bin/rm" ~/.rm_audit.log 2>/dev/null || echo 0)
    if [[ $count -gt 10 ]]; then
        printf '⚠️  High bypass count: %d\n' "$count" >&2
        printf '   Review: rm-audit-bypass\n' >&2
    fi
}

# Run in cron or periodically
bypass-alert
```

---

## FAQ

### Q: Why not block `/bin/rm` entirely?

**A:** Because scripts need it. Functions don't execute in non-interactive shells, so blocking `/bin/rm` would break countless scripts and tools. The bypass is intentional design.

### Q: Can I make protections stricter?

**A:** Yes. Use `protect-file` (kernel protection) for critical files. This blocks even root and cannot be bypassed by shell wrappers.

### Q: Why use `trash-rm` instead of `rm`?

**A:** `trash-rm` moves files to trash, making deletion recoverable. `rm` permanently deletes. For most operations, recoverable deletion is safer.

### Q: Do these protections slow down my system?

**A:** No. PATH wrapper overhead is <1ms on M1 Mac. Audit logging is async (non-blocking). Function override executes on every `/bin/rm` invocation in interactive shells, with negligible performance impact.

### Q: What if I need to delete a protected path?

**A:** Use `unprotect-file` first (if kernel-protected), then `/bin/rm` (bypass). Or use `trash-rm` for recoverable deletion.

### Q: Are bypasses logged?

**A:** Yes. All `/bin/rm` usage is logged to `~/.rm_audit.log`. Use `rm-audit-bypass` to analyze.

### Q: Can AI agents bypass protections?

**A:** Yes, if they use `/bin/rm`. That's why AI agents should always use `trash-rm` and check with users before using `--force-danger`.

### Q: What's the difference between command-safety and rm wrapper?

**A:** Command-safety checks patterns (e.g., `rm -rf`). RM wrapper checks paths (e.g., `~/.ssh`). They work together independently.

---

## Related Documentation

- `shell-config/lib/command-safety/README.md` - Command-safety system documentation
- `shell-config/docs/SYNTAX-VALIDATOR.md` - Shell configuration validation
- Issue #156 (internal) - RM bypass protection proposals
- Issue #148 (internal) - Original bypass documentation

---

## Version History

- **v2.0** (2026-01-31): Added `rm-audit-bypass` analysis and comprehensive `RM-SECURITY-GUIDE.md` documentation (Path B implementation)
- **v1.5** (2025-XX-XX): Added function override for `/bin/rm` (Layer 1.5)
- **v1.0** (2025-XX-XX): Initial multi-layer protection system

---

**Summary:** This guide documents a 4-layer protection system for `rm` operations, from convenient warnings to kernel-level immutable file protection. The system balances safety with usability, following Unix philosophy of providing mechanism without enforcing policy.

**Remember:** Real security = backups + kernel protection (chflags) + user awareness. Shell wrappers are convenience, not security.
