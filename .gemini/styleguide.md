# Shell-Config Review Guide

## Platform
- macOS (bash 5.x via Homebrew, zsh 5.9) primary
- Linux (bash 5.x) secondary
- Never Windows

## Critical Checks (BLOCK if violated)

### Bash 5.x Required
macOS users must run: `brew install bash`
Modern features allowed: `declare -A`, `${var,,}`, `readarray`, `|&`

### Non-Interactive Commands
- Must run without user input
- Must fail loudly (non-zero exit)
- Must include WHAT/WHY/HOW in errors

### Security
- All variables quoted: `"$var"`
- Trap handlers for temp files
- ShellCheck passes

### File Size
- Target: 600 lines
- Block: 800+ lines

### Testing
- New functions need tests
- Bug fixes need regression tests

## Error Message Format (Required)
```bash
echo "ERROR: What failed" >&2
echo "WHY: Why it matters" >&2
echo "FIX: How to fix" >&2
exit 1
```

## High-Risk Files
- `lib/bin/rm` - CRITICAL
- `lib/git/core.sh` - HIGH
- `lib/validation/api.sh` - HIGH (721 lines, needs split)

## Good Review Comments
- "Missing trap handler for temp file"
- "Error doesn't explain how to fix"
- "File is 500+ lines, consider splitting"
- "Requires bash 5.x - ensure install.sh checks version"

## Don't Review
- Formatting (not enforced)
- Files in hooks.disabled/
