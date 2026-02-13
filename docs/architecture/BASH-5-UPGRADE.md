# Decision: Upgrade to Bash 5.x

**Date:** 2026-02-03  
**Status:** Approved  
**Author:** (maintainer)

---

## Summary

Upgrade shell-config from bash 3.x compatibility to **bash 5.x minimum requirement**.

---

## Context

### The Problem

macOS ships with bash 3.2.57 (released 2007, GPLv2) because Apple avoids GPLv3 software. This created a constraint where all shell-config scripts had to avoid bash 4+ features.

**Pain points:**

1. No associative arrays (`declare -A`)
2. No `readarray`/`mapfile`
3. No case conversion (`${var,,}`, `${var^^}`)
4. No stderr pipe shorthand (`|&`)
5. Constant workarounds and compatibility comments
6. Two files already violated the rule (were broken on macOS system bash)

### Environments We Support

| Environment | Default Bash | Action Required |
|-------------|--------------|-----------------|
| macOS | 3.2.57 | `brew install bash` |
| Ubuntu VPS | 5.1+ | None |
| GitHub Actions | 5.1+ | None |

### Why Not Zsh for Everything?

- zsh is not installed by default on Ubuntu/GitHub Actions
- Most shell scripting documentation assumes bash
- CI workflows default to bash
- Would require installing zsh in 2 places vs bash in 1

---

## Decision

**Require Bash 4.0+ (5.x recommended) for all shell-config scripts.**

### What This Means

1. **macOS users** must install Homebrew bash: `brew install bash`
2. **Scripts** use `#!/usr/bin/env bash` (finds first bash in PATH)
3. **Modern features** are now allowed:
   - `declare -A` (associative arrays)
   - `readarray` / `mapfile`
   - `${var,,}` / `${var^^}` (case conversion)
   - `|&` (stderr pipe shorthand)
4. **Interactive shell** remains zsh (unchanged)

### Why This Works

After `brew install bash`:
- `/opt/homebrew/bin/bash` (5.x) is in PATH before `/bin/bash` (3.2)
- `#!/usr/bin/env bash` finds the Homebrew bash
- No shebang changes needed in scripts

---

## Implementation

### 1. install.sh Changes

Added bash version check at startup:

```bash
check_bash_version() {
    local version
    version=$(bash -c 'echo ${BASH_VERSINFO[0]}')
    
    if [[ "$version" -lt 4 ]]; then
        echo "ERROR: Bash 4+ required, found bash $version" >&2
        echo "WHY: Modern shell features (associative arrays, etc.)" >&2
        if [[ "$(uname)" == "Darwin" ]]; then
            echo "FIX: brew install bash" >&2
        fi
        exit 1
    fi
}
```

### 2. Documentation Updates

Updated all references in:
- CLAUDE.md, AGENTS.md
- .windsurfrules, .gemini/styleguide.md
- All .claude/commands/*.md files
- docs/architecture/*.md
- lib/*/README.md files

### 3. Shebang Strategy

Keep using `#!/usr/bin/env bash` because:
- Finds bash in PATH (Homebrew first on macOS)
- Works on Linux without changes
- Portable across CI environments

---

## Alternatives Considered

### Stay with Bash 3.x Compatibility

**Rejected because:**
- Already had 2 files breaking the rule
- Constant workarounds reduce code quality
- Developers expect modern bash features

### Hardcode /opt/homebrew/bin/bash in Shebangs

**Rejected because:**
- Breaks Linux (different path)
- Breaks Intel Macs (`/usr/local/bin/bash`)
- `#!/usr/bin/env bash` handles all cases

### Switch to Pure Zsh

**Rejected because:**
- Would need to install zsh on Ubuntu VPS and GitHub Actions
- Less common for shell scripting
- Team members more familiar with bash

---

## Consequences

### Positive

- Cleaner, more readable code
- Associative arrays for data structures
- `readarray` for cleaner array population
- Case conversion without external commands
- No more "bash 3.x compatible" comments

### Negative

- macOS users must run `brew install bash` once
- Existing workaround code can be simplified (optional cleanup)

### Neutral

- Interactive shell (zsh) unchanged
- Shebang lines unchanged
- CI workflows unchanged

---

## Verification

After implementation:

```bash
# Verify bash version
bash --version  # Should show 5.x

# Verify PATH order (macOS)
which bash      # Should show /opt/homebrew/bin/bash

# Run tests
./tests/run_all.sh
```

---

## References

- [Why Apple ships old bash](https://apple.stackexchange.com/questions/208312/why-does-apple-ship-bash-3-2)
- [Bash changelog](https://tiswww.case.edu/php/chet/bash/CHANGES)
- [Homebrew bash formula](https://formulae.brew.sh/formula/bash)

---

*Approved: 2026-02-03*
