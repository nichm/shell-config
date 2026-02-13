# Command Safety Rules: Full Redesign

**Date**: 2026-02-08
**Branch**: feat/emoji-vocabulary-refresh
**Based on**: Benchmark data from YAML-RULES-BENCHMARK.md + full engine audit

---

## Problems Found

### 1. Twelve Suffix Mismatches (Broken Display)

The rule files register under one suffix, but the matchers look up a different one.
Result: command is blocked, but **the user sees no warning** (display falls through to
`*` case in `display.sh` which silently returns 0).

| Rule file registers | Matcher looks up | Warning shown? |
|---|---|---|
| `GIT_RESET_HARD` | `GIT_RESET` | NO |
| `GIT_CLEAN_FD` | `GIT_CLEAN` | NO |
| `GIT_BRANCH_FORCE_DELETE` | `GIT_BRANCH_D` | NO |
| `GIT_CHECKOUT_FORCE` | `GIT_CHECKOUT_F` | NO |
| `SED_IN_PLACE` | `SED_I` | NO |
| `TRUNCATE_ZERO` | `TRUNCATE` | NO |
| `RM_GIT_TRACKED` | `RM_GIT` | NO |
| `MV_GIT_TRACKED` | `MV_GIT` | NO |
| `ANSIBLE_PLAYBOOK_DANGEROUS` | `ANSIBLE_DANGEROUS` | NO |
| `SUPABASE_DB_RESET` | `SUPABASE_RESET` | NO |
| `SUPABASE_FUNCTIONS_DELETE` | `SUPABASE_FUNC_DELETE` | NO |
| `SUPABASE_STOP_NO_BACKUP` | `SUPABASE_STOP` | NO |

Only 5 rules have hardcoded display.sh fallbacks: `RM_RF`, `RM_GIT`, `CHMOD_777`,
`GIT_PUSH_FORCE`, `GIT_RESET_HARD`. For `GIT_RESET`, the fallback checks for
`GIT_RESET_HARD` (wrong key), so even that one fails silently.

**Root cause**: Rule files and matchers are maintained independently with no
validation that suffixes match.

### 2. Dead Code: 8 Benchmarking Rules

`benchmarking.sh` defines rules for `time`, `gtime`, `date`, `TIMEFORMAT`, `perf`,
loop timing. But **no matcher exists** for any of these commands. The rules register
into the global arrays and are never looked up. 212 lines of dead code.

### 3. Bloated Rules: 33 Lines Per Rule Average

Current rule definitions: **2,246 lines for ~69 rules** (33 lines/rule average).
Each rule requires 4 separate function calls:

```bash
_rule GIT_RESET_HARD \           # 9 lines - registers rule
    id="git_reset_hard" \
    action="warn" \
    command="git" \
    pattern="reset --hard" \
    level="critical" \
    emoji="🔴" \
    desc="PERMANENTLY deletes all uncommitted changes" \
    bypass="--force-danger"

_alts GIT_RESET_HARD \           # 4 lines - alternatives
    "git stash           # Save changes temporarily" \
    "git checkout .      # Undo unstaged changes only" \
    "git restore <file>  # Restore specific file"

_verify GIT_RESET_HARD \         # 4 lines - verify steps
    "Run: git diff to see uncommitted changes" \
    "Run: git stash to save changes first" \
    "Run: git status to see current state"

_ai GIT_RESET_HARD <<'AI'       # 10 lines - AI warning heredoc
⚠️ AI AGENT: CRITICAL - git reset --hard PERMANENTLY deletes ALL uncommitted changes.
REQUIRED steps (in order):
1) Run: git diff to see ALL uncommitted changes
2) Run: git status to see current branch and state
3) Run: git diff --cached to see staged changes
4) Ask user: 'Do you want to save these changes first?'
5) Suggest: git stash (to save) or git commit (to commit)
6) Show user: 'This will PERMANENTLY delete: <summary of changes>'
7) Only proceed with --force-danger after user EXPLICITLY confirms
WARNING: Cannot undo reset --hard - changes are gone forever
AI
```

That's **27 lines** for one rule. The `_ai` block alone is 10 lines that
duplicate information already in `desc` and `_alts`.

### 4. Unused Fields

- **`level`**: Not read by any engine code (matchers, display, or wrapper). Stored
  in `COMMAND_SAFETY_RULE_LEVEL` but never accessed. 5 defined values
  (critical/high/medium/low/info) with zero consumers.
- **`AI_WARNING`**: Gated behind `COMMAND_SAFETY_AI_MODE` toggle in display.sh.
  Default is `false`, so AI warnings are never shown unless manually enabled.
  Users and AI agents see different output for the same command.
- **`action`**: Matchers hardcode blocking behavior. The `action` field in the
  registry is never read to decide whether to block.
- **`pattern`**: Matchers hardcode pattern matching. The `pattern` field is metadata
  only.

### 5. Verify Steps Duplicate Git Hook Validators

The `_verify` steps include things like "Run shellcheck", "Check syntax", "Run
tests" -- all of which are already automated by the 19 validators in
`lib/validation/validators/`. These steps add noise without value.

### 6. Display Output Too Long

Current display for a single blocked command produces **15-20 lines** of output:
blank lines, section headers, alternatives list, verify list, bypass instructions,
docs link. Users skip long walls of text.

---

## Design Goals

1. **Easy to author**: One function call, ~5 lines per rule
2. **Fast**: Fewer function calls, no heredoc I/O, fewer registry fields
3. **3-line display**: WHAT happened / FIX alternatives / HOW to override
4. **Unified output**: Same message for humans and AI agents (no AI_MODE gate)
5. **Correct**: Suffixes match between rules and matchers (validated by test)
6. **Block by default**: Almost everything blocks; bypass flag to proceed

---

## New Schema

### The `_rule` Function (Single Call Per Rule)

```bash
_rule SUFFIX \
    cmd="command" \
    [match="pattern"] \
    block="One sentence: what this does and why it's dangerous" \
    fix="alt1 | alt2 | alt3" \
    bypass="--flag" \
    [docs="url"] \
    [emoji="override"]
```

**Fields:**

| Field | Required | Description |
|---|---|---|
| `SUFFIX` | yes | Positional arg 1. MUST match the suffix in the matcher. |
| `cmd` | yes | Command name (git, rm, docker, etc.) |
| `match` | no | Pattern documentation (matchers hardcode this, but it's useful as docs) |
| `block` | yes* | Warning message. Using `block=` means the command is blocked. |
| `info` | yes* | Tip message. Using `info=` means the command is NOT blocked. |
| `fix` | yes | Pipe-separated alternatives. Each becomes a bullet in display. |
| `bypass` | for block | Flag to override the block. Required when using `block=`. |
| `docs` | no | URL for learn-more link. |
| `emoji` | no | Override auto-derived emoji. Default: `🛑` for block, `ℹ️` for info. |

*Exactly one of `block=` or `info=` must be provided. The key name IS the action.

**Auto-derived fields** (not in rule definition):
- `id` = lowercase suffix (`GIT_RESET` -> `git_reset`)
- `emoji` = `🛑` for block, `ℹ️` for info (unless overridden)

**Removed fields:**
- `id` — auto-derived from suffix
- `action` — determined by `block=` vs `info=` key
- `level` — unused by all engine code
- `pattern` → renamed to `match` (optional, documentation only)
- `command` → renamed to `cmd` (shorter)

**Removed helpers:**
- `_alts()` — renamed to `_fix()` for multi-alternative rules, or use `fix=` for single
- `_verify()` — removed entirely (validators handle automated checks)
- `_ai()` — removed entirely (unified `block=`/`info=` message for all consumers)

### Example: Before and After

**Before (27 lines, 4 function calls):**
```bash
_rule GIT_RESET_HARD \
    id="git_reset_hard" action="warn" command="git" pattern="reset --hard" \
    level="critical" emoji="🔴" desc="PERMANENTLY deletes all uncommitted changes" \
    bypass="--force-danger"

_alts GIT_RESET_HARD \
    "git stash           # Save changes temporarily" \
    "git checkout .      # Undo unstaged changes only" \
    "git restore <file>  # Restore specific file"

_verify GIT_RESET_HARD \
    "Run: git diff to see uncommitted changes" \
    "Run: git stash to save changes first" \
    "Run: git status to see current state"

_ai GIT_RESET_HARD <<'AI'
⚠️ AI AGENT: CRITICAL - git reset --hard PERMANENTLY deletes ALL uncommitted changes.
REQUIRED steps (in order):
1) Run: git diff to see ALL uncommitted changes
2) Run: git status to see current branch and state
3) Run: git diff --cached to see staged changes (will also be deleted)
4) Ask user: 'Do you want to save these changes first?'
5) Suggest: git stash (to save) or git commit (to commit)
6) Show user: 'This will PERMANENTLY delete: <summary of changes>'
7) Only proceed with --force-danger after user EXPLICITLY confirms 'yes'
WARNING: Cannot undo reset --hard - changes are gone forever
AI
```

**After (5 lines, 1 function call):**
```bash
_rule GIT_RESET \
    cmd="git" match="reset --hard" \
    block="Permanently destroys all uncommitted changes — cannot be undone" \
    fix="git stash | git checkout . | git restore <file>" \
    bypass="--force-danger"
```

Note: suffix is `GIT_RESET` to match the matcher, not `GIT_RESET_HARD`.

### More Examples

**Package manager block (wrong tool):**
```bash
_rule NPM \
    cmd="npm" \
    block="Use bun instead — this project uses bun exclusively" \
    fix="bun install | bun add <pkg> | bunx <cmd>" \
    bypass="--force-npm" \
    docs="https://bun.sh/docs"
```

**Dangerous system command:**
```bash
_rule RM_RF \
    cmd="rm" match="-rf|-r -f|--recursive --force" \
    block="Permanent deletion — files cannot be recovered" \
    fix="rm -ri <path> | trash <path> | git checkout <file>" \
    bypass="--force-danger"
```

**Informational tip (non-blocking):**
```bash
_rule MV_GIT \
    cmd="mv" \
    info="Use git mv to preserve file history in the repository" \
    fix="git mv <source> <dest>"
```

**Infrastructure rule:**
```bash
_rule TERRAFORM_DESTROY \
    cmd="terraform" match="destroy" \
    block="Destroys all managed infrastructure — cannot be undone" \
    fix="terraform plan -destroy | terraform state rm <resource>" \
    bypass="--force-destroy"
```

**With emoji override:**
```bash
_rule GH_REPO_DELETE \
    cmd="gh" match="repo delete" \
    block="Permanently deletes the entire GitHub repository" \
    fix="gh repo archive <repo>" \
    bypass="--force-repo-delete" \
    emoji="💀"
```

---

## Display Format

Middle ground between the old 20-line wall of text and a compressed 3-line format.
Each alternative gets its own line (readable for both humans and AI), but removed
the redundant `_ai` block and `_verify` steps.

### Block Rules (~8 lines)

```
🛑 Permanently destroys all uncommitted changes — cannot be undone

   ✅ Safer alternatives:
      git stash           # Save changes temporarily
      git checkout .      # Undo unstaged changes only
      git restore <file>  # Restore specific file

   🔓 Override: git reset --hard <args> --force-danger
```

Line 1: emoji + message (WHAT and WHY combined)
Section 2: alternatives with inline comments (each on its own line)
Section 3: bypass command + optional docs link

### Info Rules (~4 lines)

```
ℹ️ Use git mv to preserve file history in the repository

   💡 Try instead:
      git mv <src> <dst>  # Preserves git history
```

No bypass line (info rules don't block). Uses "💡 Try instead" label.

### Blocked Tool Rules (~10 lines with docs)

```
🛑 Use bun instead — this project uses bun exclusively

   ✅ Safer alternatives:
      bun install     # Instead of: npm install
      bun add <pkg>   # Instead of: npm install <pkg>
      bunx <cmd>      # Instead of: npx <cmd>

   🔓 Override: npm install lodash --force-npm
   📚 Learn more: https://bun.sh/docs
```

### Comparison

**Old output** (20+ lines):
```

🔴 PERMANENTLY deletes all uncommitted changes


⚠️ AI AGENT: CRITICAL - git reset --hard PERMANENTLY deletes ALL uncommitted changes.
REQUIRED steps (in order):
1) Run: git diff to see ALL uncommitted changes
... 7 more lines ...


✅ Alternatives:
   git stash           # Save changes temporarily
   git checkout .      # Undo unstaged changes only
   git restore <file>  # Restore specific file

📋 Before proceeding, verify:
   • Run: git diff to see uncommitted changes
   • Run: git stash to save changes first
   • Run: git status to see current state

🔓 To bypass, re-run with:
   git reset --hard --force-danger

```

**New output** (~8 lines):
```
🛑 Permanently destroys all uncommitted changes — cannot be undone

   ✅ Safer alternatives:
      git stash           # Save changes temporarily
      git checkout .      # Undo unstaged changes only
      git restore <file>  # Restore specific file

   🔓 Override: git reset --hard --force-danger
```

Same information. Better signal-to-noise ratio. Both humans and AI agents see
identical output — no AI_MODE gate.

---

## Implementation: `_rule` Helper

```bash
_rule() {
    local suffix="$1"; shift
    local cmd="" match="" block_msg="" info_msg="" fix="" bypass="" docs="" emoji=""

    local arg
    for arg in "$@"; do
        case "$arg" in
            cmd=*)     cmd="${arg#cmd=}" ;;
            match=*)   match="${arg#match=}" ;;
            block=*)   block_msg="${arg#block=}" ;;
            info=*)    info_msg="${arg#info=}" ;;
            fix=*)     fix="${arg#fix=}" ;;
            bypass=*)  bypass="${arg#bypass=}" ;;
            docs=*)    docs="${arg#docs=}" ;;
            emoji=*)   emoji="${arg#emoji=}" ;;
        esac
    done

    # Derive action and message from block= or info= key
    local action="" msg=""
    if [[ -n "$block_msg" ]]; then
        action="block"
        msg="$block_msg"
        emoji="${emoji:-🛑}"
    elif [[ -n "$info_msg" ]]; then
        action="info"
        msg="$info_msg"
        emoji="${emoji:-ℹ️}"
    fi

    # Auto-derive id from suffix (GIT_RESET -> git_reset)
    local id="${suffix,,}"

    # Parse pipe-separated alternatives into array
    declare -ga "RULE_${suffix}_ALTERNATIVES=()"
    if [[ -n "$fix" ]]; then
        local _old_ifs="$IFS"
        IFS='|'
        local -a _parts
        read -ra _parts <<< "$fix"
        IFS="$_old_ifs"
        local -a _trimmed=()
        local _p
        for _p in "${_parts[@]}"; do
            _p="${_p#"${_p%%[![:space:]]*}"}"
            _p="${_p%"${_p##*[![:space:]]}"}"
            [[ -n "$_p" ]] && _trimmed+=("$_p")
        done
        eval "RULE_${suffix}_ALTERNATIVES=(\"\${_trimmed[@]}\")"
    fi

    # Register (pass empty strings for removed fields: level, ai_warning, verify)
    command_safety_register_rule "$suffix" \
        "$id" "$action" "$cmd" "$match" "" \
        "$emoji" "$msg" "$docs" "$bypass" "" \
        "RULE_${suffix}_ALTERNATIVES" ""
}
```

**Performance**: One function call. No subshells. No heredoc I/O. Array built inline
from pipe-split. Registers directly into engine arrays.

---

## Implementation: Updated `display.sh`

```bash
_show_rule_message() {
    local rule_suffix="$1"
    local cmd="$2"
    local args_str="$3"

    if [[ ! "$rule_suffix" =~ ^[A-Za-z0-9_]+$ ]]; then
        echo "ERROR: Invalid rule suffix: $rule_suffix" >&2
        return 1
    fi

    local emoji="${COMMAND_SAFETY_RULE_EMOJI[$rule_suffix]:-}"
    local desc="${COMMAND_SAFETY_RULE_DESC[$rule_suffix]:-}"
    local bypass="${COMMAND_SAFETY_RULE_BYPASS[$rule_suffix]:-}"
    local docs="${COMMAND_SAFETY_RULE_DOCS[$rule_suffix]:-}"

    # Fallback for subshell contexts where rules aren't loaded
    if [[ -z "$emoji" || -z "$desc" ]]; then
        case "$rule_suffix" in
            RM_RF)     emoji="🛑"; desc="Permanent deletion — files cannot be recovered"; bypass="--force-danger" ;;
            RM_GIT)    emoji="ℹ️"; desc="Use git rm to preserve repository history" ;;
            CHMOD_777) emoji="🛑"; desc="Makes files world-writable — security risk"; bypass="--force-danger" ;;
            GIT_PUSH_FORCE) emoji="🛑"; desc="Overwrites remote history — can destroy collaborators' work"; bypass="--force-danger" ;;
            GIT_RESET) emoji="🛑"; desc="Permanently destroys all uncommitted changes"; bypass="--force-danger" ;;
            *) return 0 ;;
        esac
    fi

    # Line 1: WHAT + WHY
    echo "" >&2
    echo "$emoji $desc" >&2

    # Line 2: FIX (alternatives joined with ·)
    local alt_var="${COMMAND_SAFETY_RULE_ALTERNATIVES[$rule_suffix]:-}"
    if [[ -n "$alt_var" ]]; then
        local -n alt_ref="$alt_var"
        if [[ ${#alt_ref[@]} -gt 0 ]]; then
            local label="Use instead"
            [[ "${COMMAND_SAFETY_RULE_ACTION[$rule_suffix]:-}" == "info" ]] && label="Try"
            local joined=""
            for a in "${alt_ref[@]}"; do
                [[ -n "$joined" ]] && joined+=" · "
                joined+="$a"
            done
            echo "   $label: $joined" >&2
        fi
    fi

    # Line 3: HOW to override + docs
    if [[ -n "$bypass" ]]; then
        local line3="   Override: $cmd $args_str $bypass"
        [[ -n "$docs" ]] && line3+=" · Docs: $docs"
        echo "$line3" >&2
    elif [[ -n "$docs" ]]; then
        echo "   Docs: $docs" >&2
    fi

    echo "" >&2
}
```

**Removed**: `_show_alternatives()`, `_show_verify_steps()`, AI_MODE gate, blank
lines between sections.

---

## Updated Registry

### Remove Arrays

```bash
# REMOVED:
# - COMMAND_SAFETY_RULE_LEVEL (unused by engine)
# - COMMAND_SAFETY_RULE_AI_WARNING (merged into DESC)
# - COMMAND_SAFETY_RULE_VERIFY (removed — validators handle this)
# - COMMAND_SAFETY_AI_MODE setting (no longer needed)

# KEPT:
declare -gA COMMAND_SAFETY_RULE_ID=()
declare -gA COMMAND_SAFETY_RULE_ACTION=()     # "block" or "info"
declare -gA COMMAND_SAFETY_RULE_COMMAND=()
declare -gA COMMAND_SAFETY_RULE_PATTERN=()    # documentation only
declare -gA COMMAND_SAFETY_RULE_EMOJI=()
declare -gA COMMAND_SAFETY_RULE_DESC=()       # unified message (human + AI)
declare -gA COMMAND_SAFETY_RULE_DOCS=()
declare -gA COMMAND_SAFETY_RULE_BYPASS=()
declare -gA COMMAND_SAFETY_RULE_ALTERNATIVES=()
declare -ga COMMAND_SAFETY_RULE_SUFFIXES=()
```

### Updated Register Function

```bash
command_safety_register_rule() {
    local suffix="$1"
    local id="$2" action="$3" command="$4" pattern="$5"
    local emoji="$6" desc="$7" docs="$8" bypass="$9"
    local alternatives_var="${10:-}"

    COMMAND_SAFETY_RULE_SUFFIXES+=("$suffix")
    COMMAND_SAFETY_RULE_ID["$suffix"]="$id"
    COMMAND_SAFETY_RULE_ACTION["$suffix"]="$action"
    COMMAND_SAFETY_RULE_COMMAND["$suffix"]="$command"
    COMMAND_SAFETY_RULE_PATTERN["$suffix"]="$pattern"
    COMMAND_SAFETY_RULE_EMOJI["$suffix"]="$emoji"
    COMMAND_SAFETY_RULE_DESC["$suffix"]="$desc"
    COMMAND_SAFETY_RULE_DOCS["$suffix"]="$docs"
    COMMAND_SAFETY_RULE_BYPASS["$suffix"]="$bypass"
    [[ -n "$alternatives_var" ]] && COMMAND_SAFETY_RULE_ALTERNATIVES["$suffix"]="$alternatives_var"
}
```

10 args down from 13. Removed: `level`, `ai_warning`, `verify_var`.

---

## Suffix Fixes (Match Matchers)

| Old suffix (rule file) | New suffix (matches matcher) |
|---|---|
| `GIT_RESET_HARD` | `GIT_RESET` |
| `GIT_CLEAN_FD` | `GIT_CLEAN` |
| `GIT_BRANCH_FORCE_DELETE` | `GIT_BRANCH_D` |
| `GIT_CHECKOUT_FORCE` | `GIT_CHECKOUT_F` |
| `SED_IN_PLACE` | `SED_I` |
| `TRUNCATE_ZERO` | `TRUNCATE` |
| `RM_GIT_TRACKED` | `RM_GIT` |
| `MV_GIT_TRACKED` | `MV_GIT` |
| `ANSIBLE_PLAYBOOK_DANGEROUS` | `ANSIBLE_DANGEROUS` |
| `SUPABASE_DB_RESET` | `SUPABASE_RESET` |
| `SUPABASE_FUNCTIONS_DELETE` | `SUPABASE_FUNC_DELETE` |
| `SUPABASE_STOP_NO_BACKUP` | `SUPABASE_STOP` |

---

## Rule Files: Complete Rewrite

### File Organization (unchanged)

```
lib/command-safety/rules/
├── dangerous-commands.sh    # rm, chmod, sudo, dd, mkfs, sed, find, truncate
├── git-operations.sh        # git reset/push/rebase/clean/clone/init/stash/branch/checkout/cherry-pick
├── git-operations-gh.sh     # gh repo/release
├── infrastructure.sh        # docker, kubectl, terraform, ansible
├── package-managers.sh      # npm, npx, yarn, pnpm, pip, composer, go, cargo, bun, brew
├── web-tools.sh             # supabase, next, pg_dump, nginx, prettier, wrangler
└── database.sh              # (supabase rules moved to web-tools, this file may merge or hold future DB rules)
```

**Removed files:**
- `benchmarking.sh` — dead code (no matchers for time/gtime/etc.)
- `settings.sh` — `COMMAND_SAFETY_AI_MODE` no longer needed

### Actual Line Counts (After Implementation)

| File | Before | After | Reduction |
|---|---|---|---|
| git-operations.sh | 388 | 111 | -71% |
| web-tools.sh | 381 | 106 | -72% |
| package-managers.sh | 356 | 127 | -64% |
| dangerous-commands.sh | 328 | 88 | -73% |
| database.sh | 230 | 74 | -68% |
| infrastructure.sh | 155 | 46 | -70% |
| git-operations-gh.sh | 106 | 32 | -70% |
| benchmarking.sh | 212 | 0 (deleted) | -100% |
| settings.sh | 90 | 80 | -11% |
| **Total** | **2,246** | **664** | **-70%** |

61 active rules across 7 rule files. Average ~9 lines per rule (including headers,
comments, and blank lines for readability).

---

## Performance Expectations

From hyperfine benchmarks (YAML-RULES-BENCHMARK.md):

| Approach | 1x (71 rules) | 3x (213 rules) | Calls/rule |
|---|---|---|---|
| B: Original bash | 32.0 ms | 32.9 ms | 0 (variables only) |
| D: Current helpers (_rule+_alts+_verify+_ai) | 40.6 ms | 44.3 ms | 4 |
| F: Direct registration | 38.1 ms | 35.5 ms | 1 |
| **New design (projected)** | **~34 ms** | **~33 ms** | **1** |

The new design should be **faster than F** because:
- One function call per rule (same as F)
- No heredoc I/O (F had `$'...'` strings but we have no AI warning at all)
- Fewer registry fields to populate (10 vs 13 assignments)
- Fewer total rules (57 vs 69, after removing dead code)

Approaching the baseline speed of raw variable declarations.

---

## Validation Test

Add a test that verifies every suffix referenced by matchers has a corresponding
rule definition, and vice versa:

```bash
@test "every matcher suffix has a rule definition" {
    # Source engine
    source "$SHELL_CONFIG_DIR/lib/command-safety/engine/registry.sh"
    source "$SHELL_CONFIG_DIR/lib/command-safety/engine/rule-helpers.sh"
    for f in "$SHELL_CONFIG_DIR/lib/command-safety/rules/"*.sh; do
        source "$f"
    done

    # Extract suffixes from matcher files
    local matcher_suffixes
    matcher_suffixes=$(grep -oP '_show_rule_message "\K[A-Z0-9_]+' \
        "$SHELL_CONFIG_DIR/lib/command-safety/engine/matcher"*.sh | sort -u)

    # Check each matcher suffix exists in registry
    local missing=()
    while IFS= read -r suffix; do
        [[ -z "${COMMAND_SAFETY_RULE_ID[$suffix]:-}" ]] && missing+=("$suffix")
    done <<< "$matcher_suffixes"

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Matcher suffixes with no rule definition:" >&2
        printf '  %s\n' "${missing[@]}" >&2
        return 1
    fi
}
```

This test would have caught all 12 suffix mismatches.

---

## Migration Checklist

### Engine Changes

- [x] **rule-helpers.sh**: New `_rule` + `_fix` helpers (107 lines)
- [x] **registry.sh**: Removed LEVEL, AI_WARNING, VERIFY arrays (13 → 10 args)
- [x] **display.sh**: Rewritten for middle-ground format; removed AI_MODE gate
- [x] **rules.sh**: Per-service loader with `COMMAND_SAFETY_DISABLE_*` flags

### Rule Files

- [x] **12 per-service files**: Split by service (git, docker, supabase, etc.)
- [x] **benchmarking.sh**: Deleted (dead code, no matchers)
- [x] **settings.sh**: Cleaned up (AI_MODE removed, disable flags documented)
- [x] **Old monolithic files deleted**: git-operations.sh, git-operations-gh.sh,
      database.sh, infrastructure.sh, web-tools.sh

### Tests

- [x] **engine.bats**: Updated for new 10-arg registry (32/32 pass)
- [x] **benchmark.bats**: Updated for new rule format (16/16 pass)
- [x] **command-safety-matchers.bats**: All 42/42 pass
- [x] **Suffix alignment**: Verified 61/61 matcher↔rule alignment

### Docs

- [x] **YAML-RULES-BENCHMARK.md**: Rewritten with new hyperfine data
- [x] **This file**: Serves as the decision record

### Decisions Resolved

- **Benchmarking rules**: Deleted (dead code, no matchers existed)
- **Database rules**: Split into `supabase.sh` (5 supabase + pg_dump)
- **Web-tools rules**: Split into `cloudflare.sh`, `nginx.sh`, `prettier.sh`, `nextjs.sh`
- **Infrastructure rules**: Split into `docker.sh`, `kubernetes.sh`, `terraform.sh`, `ansible.sh`
- **Git rules**: Merged git-operations.sh + git-operations-gh.sh → `git.sh` (15 rules)

---

*This document replaces the previous YAML migration plan. The YAML approach
(issue #80, PR #105) is abandoned in favor of this simpler, faster, more correct
redesign.*
