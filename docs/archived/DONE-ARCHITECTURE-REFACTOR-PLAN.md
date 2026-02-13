# ✅ Shell-Config Architecture Refactor Plan — COMPLETED

> **Status:** ✅ **ALL 8 PHASES COMPLETE** — 229/229 tasks done  
> **Completed:** 2026-02-04  
> **Archived:** 2026-02-09  
> **Commits:** ef2a66b → 0e4e984 (8 phase commits)  
> **Result:** All tests passing, health score 95/100  
> **Tracking:** See [DONE-ARCHITECTURE-REFACTOR-LOG.md](archived/DONE-ARCHITECTURE-REFACTOR-LOG.md)

---

**Date:** 2026-02-03  
**Scope:** Entire repository (~10,000 lines, 117+ source files)  
**Goal:** Clean architecture with clear separation of concerns

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Target Structure](#target-structure)
3. [Large File Split Strategies](#large-file-split-strategies)
4. [Migration Strategy](#migration-strategy)
5. [Test Migration](#test-migration)
6. [Feature Flags Reference](#feature-flags-reference)
7. [Complete File Migration Map](#complete-file-migration-map)

---

## Executive Summary

### The Problem

The current `lib/` folder has **mixed concerns**:

- 8 loose files at root (`aliases.sh`, `security.sh`, `fzf.sh`, etc.)
- Duplicate folders (`core/` vs `common/`)
- Overlapping systems (`git/hooks/` vs `integrations/git/`)
- 3 files over 500 lines (api.sh: 721, ghls: 560, kitty.sh: 528)
- Secrets scanning not in validation (should be a validator)
- 1password in lib/ not integrations

### The Solution

Reorganize around **9 top-level modules**:

| Module | Purpose | Key Contents |
|--------|---------|--------------|
| **core/** | Foundation | colors, logging, platform, config, paths, loaders |
| **aliases/** | All command aliases | ai-cli, git, package-managers, etc. |
| **command-safety/** | Command pattern protection | Engine + 73 rules (KEEP name) |
| **security/** | Non-command security | rm protection, trash, filesystem, hardening |
| **git/** | Git lifecycle hooks | Stages call validators (NO duplicate checks/) |
| **validation/** | ALL validators | syntax, secrets, GHA, opengrep, phantom-guard |
| **terminal/** | Terminal setup | iTerm2, Kitty, Ghostty, Warp (TOP-LEVEL) |
| **welcome/** | MOTD system | Core feature (NOT an integration) |
| **integrations/** | External services + CLI tools | 1password, ghls, eza, fzf, ripgrep |

Plus: `bin/` (executables on PATH), root `tools/` (dev scripts)

### Key Architectural Decisions

1. **command-safety vs security = different concerns** - Pattern matching on commands vs path/filesystem protection
2. **Validation is standalone** - API works without git context; hooks are just consumers
3. **Secrets scanning = validator** - Gitleaks, OpenGrep, Phantom Guard all become validators
4. **Git organized by lifecycle** - commit/, push/, merge/ stages, not by check type
5. **1Password aliases vs functions** - Functions in `integrations/1password/`, short aliases in `aliases/1password.sh`

---

## Target Structure

```
lib/
├── core/                              # FOUNDATION
│   ├── colors.sh                     # ANSI colors, logging functions
│   ├── config.sh                     # Configuration loading
│   ├── logging.sh                    # Log rotation, audit logging
│   ├── platform.sh                   # OS/package manager detection
│   ├── paths.sh                      # PATH setup (NEW)
│   ├── doctor.sh                     # Diagnostic command
│   ├── ensure-audit-symlink.sh       # From common/
│   └── loaders/                      # Lazy loaders
│       ├── ssh.sh                   # SSH agent loader
│       ├── fnm.sh                   # Fast Node Manager
│       ├── broot.sh                 # Broot file manager
│       └── completions.sh           # Shell completions
│
├── aliases/                           # ALL ALIASES
│   ├── init.sh                       # Module loader
│   ├── core.sh                       # Navigation, safety (mv -i)
│   ├── ai-cli.sh                     # Claude, Codex, CCM
│   ├── git.sh                        # gs, ga, gc, gp
│   ├── package-managers.sh           # Bun, UV, Cloudflare
│   ├── formatting.sh                 # Prettier wrappers
│   ├── gha.sh                        # gha-scan aliases
│   └── 1password.sh                  # ops, opd (ONLY alias statements)
│
├── command-safety/                    # UNCHANGED - keep as-is
│   ├── init.sh                       # Module entry point
│   ├── engine.sh                     # Main engine loader
│   ├── rules.sh                      # Rules aggregator
│   ├── test.sh                       # Testing utilities
│   ├── README.md                     # Documentation
│   ├── engine/                       # Engine internals
│   │   ├── display.sh               # Output formatting
│   │   ├── loader.sh                # Rule loading logic
│   │   ├── logging.sh               # Audit logging
│   │   ├── matcher.sh               # Pattern matching core
│   │   ├── utils.sh                 # Helper functions
│   │   └── wrapper.sh               # Command wrapping
│   └── rules/                        # 8 rule files (73+ rules)
│       ├── benchmarking.sh          # Benchmark command rules
│       ├── dangerous-commands.sh    # Destructive command rules
│       ├── database.sh              # Database operation rules
│       ├── git-operations.sh        # Git command rules
│       ├── infrastructure.sh        # Infra/cloud rules
│       ├── package-managers.sh      # npm/pnpm/pip rules
│       ├── settings.sh              # Rule configuration
│       └── web-tools.sh             # curl/wget rules
│
├── security/                          # NEW - from security.sh split
│   ├── init.sh                       # Module loader
│   ├── rm/                           # rm wrapper subsystem
│   │   ├── wrapper.sh               # Main rm wrapper
│   │   ├── paths.sh                 # Protected paths
│   │   └── audit.sh                 # Audit logging
│   ├── trash/                        # Trash subsystem
│   │   └── trash.sh                 # Trash functions
│   ├── filesystem/                   # Filesystem protection
│   │   └── protect.sh               # Protection functions
│   ├── audit.sh                      # security-audit, clear-violations
│   └── hardening.sh                  # umask, TMPDIR
│
├── git/                               # REORGANIZED by lifecycle
│   ├── init.sh                       # Module entry point
│   ├── wrapper.sh                    # Git command wrapper (renamed from core.sh)
│   ├── setup.sh                      # Git hooks installation
│   ├── stages/                       # Lifecycle stage logic
│   │   ├── commit/                  # Commit stage
│   │   │   ├── pre-commit.sh       # Pre-commit checks
│   │   │   ├── prepare-commit-msg.sh # Message preparation
│   │   │   ├── commit-msg.sh       # Message validation
│   │   │   └── post-commit.sh      # Post-commit actions
│   │   ├── push/                    # Push stage
│   │   │   └── pre-push.sh         # Pre-push checks
│   │   └── merge/                   # Merge stage
│   │       ├── pre-merge-commit.sh # Pre-merge checks
│   │       └── post-merge.sh       # Post-merge actions
│   ├── hooks/                        # Symlinked to ~/.githooks
│   │   ├── pre-commit               # Hook entry → stages/commit/
│   │   ├── prepare-commit-msg       # Hook entry → stages/commit/
│   │   ├── commit-msg               # Hook entry → stages/commit/
│   │   ├── post-commit              # Hook entry → stages/commit/
│   │   ├── pre-push                 # Hook entry → stages/push/
│   │   ├── pre-merge-commit         # Hook entry → stages/merge/
│   │   └── post-merge               # Hook entry → stages/merge/
│   └── shared/                       # Shared utilities
│       ├── git-utils.sh             # Common git helpers
│       ├── timeout.sh               # Timeout wrapper
│       ├── reporters.sh             # Output formatting
│       ├── file-scanner.sh          # File scanning
│       ├── clone-check.sh           # Clone validation
│       ├── safety-checks.sh         # Safety rules
│       ├── audit.sh                 # Audit logging
│       └── command-parser.sh        # Command parsing
│
├── validation/                        # EXPANDED - all validators unified
│   ├── api.sh                        # Public API (~150 lines after split)
│   ├── api-internal.sh              # Internal helpers (NEW from split)
│   ├── api-output.sh                # Output formatting (NEW from split)
│   ├── api-parallel.sh              # Parallel execution (NEW from split)
│   ├── core.sh                       # Core validation logic
│   ├── README.md                     # Documentation
│   ├── shared/                       # Shared utilities
│   │   ├── config.sh                # Configuration loading
│   │   ├── file-operations.sh       # File handling
│   │   ├── patterns.sh              # Pattern matching
│   │   ├── reporters.sh             # Output reporters
│   │   └── workflow-scanners.sh     # Workflow scanning
│   └── validators/                   # All validators (themed subfolders)
│       ├── core/                    # Core validators
│       │   ├── file-validator.sh   # File size/structure
│       │   ├── file-length-validator.sh  # Line count limits (from hooks/)
│       │   ├── syntax-validator.sh # Shell/YAML syntax
│       │   └── format-validator.sh # Code formatting
│       ├── security/                # Security validators
│       │   ├── security-validator.sh    # General security
│       │   ├── secrets-validator.sh     # Gitleaks (from git/shared/)
│       │   ├── opengrep-validator.sh    # OpenGrep rules (from hooks/)
│       │   ├── phantom-validator.sh     # Phantom Guard (from phantom-guard/)
│       │   ├── sensitive-files-validator.sh  # Sensitive filenames (from hooks/)
│       │   └── config/                  # Security validator configs
│       │       ├── gitleaks.toml       # Gitleaks config (from git/secrets/)
│       │       ├── allowed.txt         # Allowed patterns (from git/secrets/)
│       │       ├── prohibited.txt      # Prohibited patterns (from git/secrets/)
│       │       ├── purge.txt           # Purge patterns (from git/secrets/)
│       │       └── phantom.yml         # Phantom Guard config
│       ├── gha/                     # GitHub Actions validators
│       │   ├── actionlint-validator.sh  # Actionlint
│       │   ├── zizmor-validator.sh      # Zizmor
│       │   ├── poutine-validator.sh     # Poutine
│       │   ├── octoscan-validator.sh    # Octoscan
│       │   ├── pinact-validator.sh      # Pinact
│       │   └── config/                  # GHA validator configs
│       │       ├── .poutine.yml        # Poutine config
│       │       └── .zizmor.yml         # Zizmor config
│       └── infra/                   # Infrastructure validators
│           ├── infra-validator.sh       # Infrastructure checks
│           ├── workflow-validator.sh    # Workflow validation
│           └── benchmark-validator.sh   # Performance benchmarks
│
├── terminal/                          # UNCHANGED structure
│   ├── autocomplete.sh              # Autocomplete setup
│   ├── common.sh                    # Common utilities
│   ├── install.sh                   # Main installer
│   ├── install-terminal.sh          # Terminal installer
│   ├── uninstall-terminal-setup.sh  # Uninstaller
│   ├── INSTALLATION.md              # Documentation
│   ├── installation/                 # Per-terminal installers
│   │   ├── common.sh               # Shared installation code
│   │   ├── ghostty.sh              # Ghostty installer
│   │   ├── iterm2.sh               # iTerm2 installer
│   │   ├── kitty.sh*               # Kitty installer (needs split)
│   │   ├── kitty-config.sh         # Kitty config generation (NEW)
│   │   ├── kitty-theme.sh          # Kitty theme setup (NEW)
│   │   └── warp.sh                 # Warp installer
│   ├── integration/                  # Shell integrations
│   │   ├── bash-integration.sh     # Bash integration
│   │   ├── common.sh               # Common integration code
│   │   └── zsh-integration.sh      # Zsh integration
│   └── setup/                        # Setup scripts
│       ├── terminal-setup-common.sh # Common setup
│       ├── setup-macos-terminal.sh  # macOS setup
│       ├── setup-ubuntu-terminal.sh # Ubuntu setup
│       └── setup-autocomplete-tools.sh # Autocomplete tools
│
├── welcome/                           # UNCHANGED
│   ├── main.sh                      # Main welcome script
│   ├── autocomplete-guide.sh        # Autocomplete help
│   ├── git-hooks-status.sh          # Git hooks status
│   ├── shell-startup-time.sh        # Startup timing
│   ├── shortcuts.sh                 # Keyboard shortcuts
│   └── terminal-status.sh           # Terminal status
│
├── integrations/                      # CONSOLIDATED
│   ├── 1password/                    # 1Password integration
│   │   ├── init.sh                  # Module loader
│   │   ├── secrets.sh               # Secrets loading
│   │   ├── ssh-sync.sh              # SSH key sync
│   │   ├── login.sh                 # Login helper
│   │   └── diagnose.sh              # Diagnostics
│   ├── ghls/                         # GitHub repo listing
│   │   ├── ghls                     # Main CLI (needs split)
│   │   ├── status.sh                # Status functions (NEW)
│   │   ├── display.sh               # Display formatting (NEW)
│   │   ├── statusline.sh            # Status line
│   │   └── auto.sh                  # Auto-refresh
│   ├── eza.sh                        # eza integration
│   ├── fzf.sh                        # fzf integration
│   ├── ripgrep.sh                    # ripgrep integration
│   ├── cat.sh                        # cat/bat integration
│   ├── verification.sh               # Tool verification
│   └── README.md                     # Documentation
│
└── bin/                               # EXECUTABLES
    ├── gha-scan                      # GHA security scanner (merged)
    ├── rm                            # rm wrapper
    ├── shell-config                  # Main CLI
    ├── shell-config-init             # Initialization
    └── validate                      # Validation CLI (from integrations/cli/)
```

*Files marked with * need splitting (see Large File Split Strategies)

---

## Large File Split Strategies

### api.sh (721 → 4 files, ~150-200 lines each)

| New File | Contents |
|----------|----------|
| `api.sh` | Public API: `validator_api_run`, `validator_api_validate_staged`, etc. |
| `api-internal.sh` | `_validator_api_init`, `_validator_api_cleanup`, `_validator_validate_file` |
| `api-output.sh` | `_validator_api_print_console`, `_validator_api_build_json`, `_validator_api_print_json` |
| `api-parallel.sh` | `_validator_validate_parallel`, worker logic |

### ghls (560 → 3 files, ~150-200 lines each)

| New File | Contents |
|----------|----------|
| `ghls` | Main CLI: argument parsing, dispatch, entry point |
| `status.sh` | `_get_repo_status`, `_get_pr_counts`, `_get_branch_info` |
| `display.sh` | Table formatting, colors, output rendering |

### kitty.sh (528 → 3 files, ~150-200 lines each)

| New File | Contents |
|----------|----------|
| `kitty.sh` | Main installer entry point |
| `kitty-config.sh` | `kitty.conf` generation, key mappings |
| `kitty-theme.sh` | Font setup, color schemes |

---

## Migration Strategy

> **NOTE:** The detailed migration strategy, phase-by-phase task breakdown, and agent collaboration workflow have been moved to **docs/REFACTOR-STATUS.md** for active tracking. This file retains the reference material below.

Each phase follows this granular workflow:

```
┌─────────────────────────────────────────────────────────────────────┐
│  STAGE 1: Analyze    │ Read files, verify current state, plan      │
│  STAGE 2: Prepare    │ Create directories, backup if needed        │
│  STAGE 3: Move/Split │ Execute file moves, renames, or splits      │
│  STAGE 4: Update     │ Update source/require statements            │
│  STAGE 5: Test       │ Run relevant test suite                     │
│  STAGE 6: Cleanup    │ Delete old files, remove empty dirs         │
│  STAGE 7: Verify     │ Full integration test, shellcheck           │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Phase 1: Foundation (Low Risk)

**Goal:** Merge `common/` → `core/`, cleanup stubs

#### Stage 1.1: Analyze
- [ ] Read all files in `lib/core/` and `lib/core/`
- [ ] Identify which files exist in both (duplicates vs unique)
- [ ] List all `source` statements referencing `common/`

#### Stage 1.2: Prepare
- [ ] Verify `lib/core/` directory exists
- [ ] Document backup: `git stash` or branch checkpoint

#### Stage 1.3: Move
- [ ] Move `lib/core/ensure-audit-symlink.sh` → `lib/core/`
- [ ] Move any other unique files from `common/` → `core/`
- [ ] Delete `lib/welcome.sh` stub file
- [ ] Move `lib/integrations/cli/validate` → `lib/bin/validate`

#### Stage 1.4: Update Sources
- [ ] Update all `source "*common/colors.sh"` → `source "*core/colors.sh"`
- [ ] Update all `source "*common/logging.sh"` → `source "*core/logging.sh"`
- [ ] Update all `source "*common/config.sh"` → `source "*core/config.sh"`
- [ ] Update all `source "*common/platform.sh"` → `source "*core/platform.sh"`
- [ ] Update paths in `lib/bin/validate`

#### Stage 1.5: Test
- [ ] Run `./tests/run_all.sh`
- [ ] Run `shellcheck lib/core/*.sh`
- [ ] Verify no broken source statements

#### Stage 1.6: Cleanup
- [ ] Delete `lib/core/` directory
- [ ] Remove any empty directories

#### Stage 1.7: Verify
- [ ] Source `init.sh` in new shell
- [ ] Run doctor command
- [ ] Confirm all features load

---

### Phase 2: Shell Components (Low Risk)

**Goal:** Organize aliases and loaders into proper modules

#### Stage 2.1: Analyze
- [ ] Read `lib/aliases.sh` - count alias categories
- [ ] Read `lib/core/loaders/ssh.sh` - identify lazy loaders
- [ ] Read `init.sh` - identify PATH setup code

#### Stage 2.2: Prepare
- [ ] Create `lib/aliases/` directory
- [ ] Create `lib/core/loaders/` directory

#### Stage 2.3: Split
- [ ] Split `aliases.sh` → `aliases/init.sh` (module loader)
- [ ] Split `aliases.sh` → `aliases/core.sh` (navigation, safety)
- [ ] Split `aliases.sh` → `aliases/ai-cli.sh` (claude, codex)
- [ ] Split `aliases.sh` → `aliases/git.sh` (gs, ga, gc, gp)
- [ ] Split `aliases.sh` → `aliases/package-managers.sh`
- [ ] Split `aliases.sh` → `aliases/formatting.sh`
- [ ] Split `aliases.sh` → `aliases/gha.sh`
- [ ] Split `aliases.sh` → `aliases/1password.sh`
- [ ] Split `loaders.sh` → `core/loaders/ssh.sh`
- [ ] Split `loaders.sh` → `core/loaders/fnm.sh`
- [ ] Split `loaders.sh` → `core/loaders/broot.sh`
- [ ] Split `loaders.sh` → `core/loaders/completions.sh`
- [ ] Extract PATH setup from `init.sh` → `core/paths.sh`

#### Stage 2.4: Move
- [ ] Move `lib/eza.sh` → `lib/integrations/eza.sh`
- [ ] Move `lib/fzf.sh` → `lib/integrations/fzf.sh`
- [ ] Move `lib/ripgrep.sh` → `lib/integrations/ripgrep.sh`

#### Stage 2.5: Update Sources
- [ ] Update `init.sh` to source `aliases/init.sh`
- [ ] Update `init.sh` to source `core/paths.sh`
- [ ] Update any references to moved integrations

#### Stage 2.6: Test
- [ ] Run `./tests/run_all.sh`
- [ ] Verify all aliases work in new shell
- [ ] Test each integration (eza, fzf, ripgrep)

#### Stage 2.7: Cleanup
- [ ] Delete `lib/aliases.sh`
- [ ] Delete `lib/core/loaders/ssh.sh`
- [ ] Delete old integration locations

---

### Phase 3: Integrations Consolidation (Medium Risk)

**Goal:** Move 1password, ghls to integrations; absorb gha-security

#### Stage 3.1: Analyze
- [ ] Read `lib/1password/` structure and dependencies
- [ ] Read `lib/ghls/` structure and dependencies
- [ ] Read `lib/gha-security/` - map validators and configs
- [ ] Identify all external callers of these modules

#### Stage 3.2: Prepare
- [ ] Create `lib/integrations/1password/` directory
- [ ] Create `lib/integrations/ghls/` directory
- [ ] Create `lib/validation/validators/gha/` directory
- [ ] Create `lib/validation/validators/gha/config/` directory

#### Stage 3.3: Move
- [ ] Move `lib/1password/*` → `lib/integrations/1password/`
- [ ] Move `lib/ghls/*` → `lib/integrations/ghls/`
- [ ] Move `lib/gha-security/validators/*` → `lib/validation/validators/gha/`
- [ ] Move `lib/gha-security/config/*` → `lib/validation/validators/gha/config/`

#### Stage 3.4: Merge gha-scan
- [ ] Merge `lib/gha-security/scanner.sh` → `lib/bin/gha-scan`
- [ ] Merge `lib/gha-security/core.sh` → `lib/bin/gha-scan`
- [ ] Merge `lib/gha-security/shared/*` → `lib/bin/gha-scan`
- [ ] Merge `lib/gha-security/reporters/*` → `lib/bin/gha-scan`

#### Stage 3.5: Update Sources
- [ ] Update all `source "*1password/"` paths
- [ ] Update all `source "*ghls/"` paths
- [ ] Update `gha-scan` to source from new locations
- [ ] Update validation API to find gha validators

#### Stage 3.6: Test
- [ ] Run `./tests/run_all.sh`
- [ ] Test 1Password integration (`ops`, `opd`)
- [ ] Test ghls command
- [ ] Test `gha-scan` command
- [ ] Run shellcheck on moved files

#### Stage 3.7: Cleanup
- [ ] Delete `lib/1password/` (old location)
- [ ] Delete `lib/ghls/` (old location)
- [ ] Delete `lib/gha-security/` entirely

---

### Phase 4: Git Reorganization (Medium Risk)

**Goal:** Reorganize git by lifecycle stages, consolidate shared utils

#### Stage 4.1: Analyze
- [ ] Read all files in `lib/git/hooks/`
- [ ] Read all files in `lib/git/shared/`
- [ ] Read all files in `lib/git/shared/`
- [ ] Map hook → stage relationships
- [ ] Identify shared code between hooks

#### Stage 4.2: Prepare
- [ ] Create `lib/git/stages/commit/` directory
- [ ] Create `lib/git/stages/push/` directory
- [ ] Create `lib/git/stages/merge/` directory
- [ ] Create `lib/git/shared/` directory
- [ ] Create `lib/validation/validators/security/config/` directory

#### Stage 4.3: Rename/Move
- [ ] Rename `lib/git/wrapper.sh` → `lib/git/wrapper.sh`
- [ ] Move `lib/git/shared/clone-check.sh` → `lib/git/shared/`
- [ ] Move `lib/git/shared/dangerous-commands.sh` → `lib/git/shared/safety-checks.sh`
- [ ] Move `lib/git/shared/*` → `lib/git/shared/`
- [ ] Move `lib/git/hooks/shared/timeout-wrapper.sh` → `lib/git/shared/timeout.sh`
- [ ] Move `lib/git/hooks/shared/file-scanner.sh` → `lib/git/shared/`
- [ ] Move `lib/git/hooks/shared/reporters.sh` → `lib/git/shared/`
- [ ] Merge `lib/git/hooks/shared/git-hooks-common.sh` → `lib/git/shared/git-utils.sh`

#### Stage 4.4: Move Secrets Configs to Validators
- [ ] Move `lib/git/secrets/gitleaks.toml` → `lib/validation/validators/security/config/`
- [ ] Move `lib/git/secrets/allowed.txt` → `lib/validation/validators/security/config/`
- [ ] Move `lib/git/secrets/prohibited.txt` → `lib/validation/validators/security/config/`
- [ ] Move `lib/git/secrets/purge.txt` → `lib/validation/validators/security/config/`

#### Stage 4.5: Create Stage Files
- [ ] Create `lib/git/stages/commit/pre-commit.sh`
- [ ] Create `lib/git/stages/commit/prepare-commit-msg.sh`
- [ ] Create `lib/git/stages/commit/commit-msg.sh`
- [ ] Create `lib/git/stages/commit/post-commit.sh`
- [ ] Create `lib/git/stages/push/pre-push.sh`
- [ ] Create `lib/git/stages/merge/pre-merge-commit.sh`
- [ ] Create `lib/git/stages/merge/post-merge.sh`

#### Stage 4.6: Convert Hook Validators
- [ ] Move `lib/git/shared/secrets-check.sh` → `lib/validation/validators/security/secrets-validator.sh`
- [ ] Move `lib/git/hooks/opengrep-hook.sh` → `lib/validation/validators/security/opengrep-validator.sh`
- [ ] Move `lib/git/hooks/check-file-length.sh` → `lib/validation/validators/core/file-length-validator.sh`
- [ ] Move `lib/git/hooks/check-sensitive-filenames.sh` → `lib/validation/validators/security/sensitive-files-validator.sh`
- [ ] Move `lib/git/hooks/benchmark-hook.sh` → `lib/validation/validators/infra/benchmark-validator.sh`

#### Stage 4.7: Update Sources
- [ ] Update all references to `git/wrapper.sh` → `git/wrapper.sh`
- [ ] Update all references to `git/shared/` → `git/shared/`
- [ ] Update secrets validator to find config in new location
- [ ] Update hook symlinks to call stage files

#### Stage 4.8: Test
- [ ] Run `./tests/run_all.sh`
- [ ] Test git wrapper with `git status`
- [ ] Test pre-commit hook
- [ ] Test pre-push hook
- [ ] Verify secrets scanning works

#### Stage 4.9: Cleanup
- [ ] Archive `lib/git/hooks/hooks.disabled/` to branch
- [ ] Delete `lib/git/hooks/hooks.disabled/`
- [ ] Delete `lib/git/shared/` (old location)
- [ ] Delete `lib/git/shared/` (old location)
- [ ] Delete `lib/git/secrets/` (old location)
- [ ] Delete `lib/git/hooks/shared/` (merged)
- [ ] Delete redundant `lib/git/syntax.sh`

---

### Phase 5: Security Module Split (Medium Risk)

**Goal:** Split monolithic security.sh into organized submodules

#### Stage 5.1: Analyze
- [ ] Read `lib/security/init.sh` - identify all functions
- [ ] Group functions by concern (rm, trash, filesystem, audit, hardening)
- [ ] Count lines per group

#### Stage 5.2: Prepare
- [ ] Create `lib/security/` directory
- [ ] Create `lib/security/rm/` directory
- [ ] Create `lib/security/trash/` directory
- [ ] Create `lib/security/filesystem/` directory

#### Stage 5.3: Split
- [ ] Create `lib/security/init.sh` (module loader)
- [ ] Extract rm wrapper code → `lib/security/rm/wrapper.sh`
- [ ] Extract rm paths code → `lib/security/rm/paths.sh`
- [ ] Extract rm audit code → `lib/security/rm/audit.sh`
- [ ] Extract trash functions → `lib/security/trash/trash.sh`
- [ ] Extract filesystem protection → `lib/security/filesystem/protect.sh`
- [ ] Extract audit functions → `lib/security/audit.sh`
- [ ] Extract hardening functions → `lib/security/hardening.sh`

#### Stage 5.4: Update Sources
- [ ] Update `init.sh` to source `security/init.sh`
- [ ] Update any direct references to security functions

#### Stage 5.5: Test
- [ ] Run `./tests/run_all.sh`
- [ ] Test rm wrapper protection
- [ ] Test trash functionality
- [ ] Test security audit commands

#### Stage 5.6: Cleanup
- [ ] Delete `lib/security/init.sh`

#### Stage 5.7: Verify
- [ ] Run full security test suite
- [ ] Verify audit logging works

---

### Phase 6: Validation Validators Reorganization (Medium Risk)

**Goal:** Organize validators into themed subfolders

#### Stage 6.1: Analyze
- [ ] Read all existing validators in `lib/validation/validators/`
- [ ] Categorize: core, security, gha, infra
- [ ] Read phantom-guard files

#### Stage 6.2: Prepare
- [ ] Create `lib/validation/validators/core/` directory
- [ ] Create `lib/validation/validators/security/` directory
- [ ] Create `lib/validation/validators/security/config/` directory (if not done)
- [ ] Create `lib/validation/validators/gha/` directory (if not done in Phase 3)
- [ ] Create `lib/validation/validators/gha/config/` directory (if not done)
- [ ] Create `lib/validation/validators/infra/` directory

#### Stage 6.3: Move Validators
- [ ] Move `file-validator.sh` → `validators/core/`
- [ ] Move `syntax-validator.sh` → `validators/core/`
- [ ] Create `validators/core/format-validator.sh`
- [ ] Move `security-validator.sh` → `validators/security/`
- [ ] Move `infra-validator.sh` → `validators/infra/`
- [ ] Move `workflow-validator.sh` → `validators/infra/`

#### Stage 6.4: Absorb Phantom Guard
- [ ] Convert `lib/phantom-guard/setup.sh` → `validators/security/phantom-validator.sh`
- [ ] Move `lib/phantom-guard/config.yml` → `lib/validation/validators/security/config/phantom.yml`

#### Stage 6.5: Update Sources
- [ ] Update validation API to find validators in subfolders
- [ ] Update any direct validator references

#### Stage 6.6: Test
- [ ] Run `./tests/run_all.sh`
- [ ] Test each validator category
- [ ] Run validation API tests

#### Stage 6.7: Cleanup
- [ ] Delete `lib/phantom-guard/` directory
- [ ] Delete any orphaned validator files

---

### Phase 7: Large File Splits (Medium Risk)

**Goal:** Split 3 files over 500 lines

#### Stage 7.1: Split api.sh (721 lines)

##### 7.1.1: Analyze
- [ ] Read `lib/validation/api.sh`
- [ ] Identify function boundaries
- [ ] Plan split: public API, internal, output, parallel

##### 7.1.2: Split
- [ ] Extract public API (~150 lines) → keep in `api.sh`
- [ ] Extract internal helpers → `api-internal.sh`
- [ ] Extract output formatting → `api-output.sh`
- [ ] Extract parallel logic → `api-parallel.sh`

##### 7.1.3: Update & Test
- [ ] Add source statements in `api.sh` for split files
- [ ] Run validation tests
- [ ] Verify line counts < 200 each

#### Stage 7.2: Split ghls (560 lines)

##### 7.2.1: Analyze
- [ ] Read `lib/integrations/ghls/ghls`
- [ ] Identify: CLI parsing, status logic, display formatting

##### 7.2.2: Split
- [ ] Keep CLI/dispatch in `ghls` (~150 lines)
- [ ] Extract status functions → `status.sh`
- [ ] Extract display/formatting → `display.sh`

##### 7.2.3: Update & Test
- [ ] Add source statements in `ghls`
- [ ] Test ghls command
- [ ] Verify line counts < 200 each

#### Stage 7.3: Split kitty.sh (528 lines)

##### 7.3.1: Analyze
- [ ] Read `lib/terminal/installation/kitty.sh`
- [ ] Identify: installer, config generation, theme setup

##### 7.3.2: Split
- [ ] Keep installer entry point in `kitty.sh` (~150 lines)
- [ ] Extract config generation → `kitty-config.sh`
- [ ] Extract theme/font setup → `kitty-theme.sh`

##### 7.3.3: Update & Test
- [ ] Add source statements in `kitty.sh`
- [ ] Test kitty installation
- [ ] Verify line counts < 200 each

---

### Phase 8: Final Cleanup (Low Risk)

**Goal:** Final consolidation and documentation

#### Stage 8.1: Binary Consolidation
- [ ] Review `lib/bin/shell-config` vs `init.sh` `shell-config()` function
- [ ] Merge if appropriate

#### Stage 8.2: Documentation Updates
- [ ] Update all path references in docs/
- [ ] Update README.md with new structure
- [ ] Update CLAUDE.md if paths changed
- [ ] Regenerate any auto-docs

#### Stage 8.3: Final Test
- [ ] Run `./tests/run_all.sh`
- [ ] Run shellcheck on all files
- [ ] Check file lengths: `wc -l lib/**/*.sh | awk '$1 > 600'`
- [ ] Fresh shell source test

#### Stage 8.4: Final Verification
- [ ] Verify all feature flags work
- [ ] Test doctor command
- [ ] Verify welcome message displays correctly
- [ ] Confirm no regressions

---

## Test Migration

| Test File | Updates Required |
|-----------|------------------|
| `git_wrapper.bats` | `lib/git/wrapper.sh` → `lib/git/wrapper.sh` |
| `git_safety.bats` | `lib/git/shared/` → `lib/git/shared/` |
| `git_hooks.bats` | `lib/git/hooks/shared/` → `lib/git/shared/` |
| `security_loaders.bats` | `lib/security/init.sh` → `lib/security/init.sh` |
| `gha_security.bats` | `lib/gha-security/` → `lib/validation/validators/gha/*.sh` |
| `op_secrets.bats` | `lib/1password/` → `lib/integrations/1password/` |
| `tool_integrations.bats` | `lib/eza.sh` → `lib/integrations/eza.sh` |

**Tests unchanged:** init.bats, install.bats, colors.bats, logging.bats, validation.bats, terminal.bats, welcome.bats

**Verification:** Run `./tests/run_all.sh` after each phase

---

## Feature Flags Reference

### Module Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `SHELL_CONFIG_WELCOME` | `true` | Show MOTD |
| `SHELL_CONFIG_COMMAND_SAFETY` | `true` | Command pattern protection |
| `SHELL_CONFIG_GIT_WRAPPER` | `true` | Git safety wrapper |
| `SHELL_CONFIG_GHLS` | `true` | GitHub repo listing |
| `SHELL_CONFIG_EZA` | `true` | eza integration |
| `SHELL_CONFIG_FZF` | `true` | fzf integration |
| `SHELL_CONFIG_RIPGREP` | `true` | ripgrep integration |
| `SHELL_CONFIG_SECURITY` | `true` | Security module |
| `SHELL_CONFIG_1PASSWORD` | `true` | 1Password integration |
| `SHELL_CONFIG_LOG_ROTATION` | `true` | Auto log rotation |

### Security Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `RM_AUDIT_ENABLED` | `1` | Log rm operations |
| `RM_PROTECT_ENABLED` | `1` | Block protected paths |

### Git Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `GIT_SKIP_HOOKS` | unset | Skip all hooks |
| `GIT_SKIP_SECRETS` | unset | Skip secrets scan |

### Validation Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `VALIDATOR_OUTPUT` | `text` | Output format (`text`/`json`) |
| `VALIDATOR_PARALLEL` | `4` | Parallel jobs |

---

## Complete File Migration Map

### Files to DELETE

| File/Folder | Reason |
|-------------|--------|
| `lib/aliases.sh` | Split → `aliases/*.sh` |
| `lib/security/init.sh` | Split → `security/*.sh` |
| `lib/core/loaders/ssh.sh` | Split → `core/loaders/*.sh` |
| `lib/eza.sh`, `lib/fzf.sh`, `lib/ripgrep.sh` | Move → `integrations/` |
| `lib/welcome.sh` | Stub file |
| `lib/doctor.sh` | Move → `core/doctor.sh` |
| `lib/core/` | Merge → `core/` |
| `lib/gha-security/` | Absorb → `validation/validators/gha/` + `bin/gha-scan` |
| `lib/phantom-guard/` | Absorb → `validation/validators/security/phantom-validator.sh` |
| `lib/integrations/cli/`, `lib/integrations/git/` | Consolidate |
| `lib/1password/`, `lib/ghls/` | Move → `integrations/` |
| `lib/git/syntax.sh` | Redundant |
| `lib/git/shared/` | Move → `git/shared/` + `validators/security/` |
| `lib/git/shared/` | Move → `git/shared/` |
| `lib/git/secrets/` | Move → `validators/security/config/` |
| `lib/git/hooks/hooks.disabled/` | Archive branch, delete |
| `lib/git/hooks/shared/` | Merge → `git/shared/` |
| `lib/git/hooks/check-file-length.sh` | Move → `validators/core/file-length-validator.sh` |
| `lib/git/hooks/check-sensitive-filenames.sh` | Move → `validators/security/sensitive-files-validator.sh` |
| `lib/git/hooks/opengrep-hook.sh`, `benchmark-hook.sh` | Convert → validators |
| `lib/git/hooks/pre-commit-display.sh`, `pre-commit-parallel` | Merge → stages/ |

### Files to MOVE

| Current | Target |
|---------|--------|
| `lib/core/ensure-audit-symlink.sh` | `lib/core/ensure-audit-symlink.sh` |
| `lib/doctor.sh` | `lib/core/doctor.sh` |
| `lib/1password/*` | `lib/integrations/1password/*` |
| `lib/ghls/*` | `lib/integrations/ghls/*` |
| `lib/eza.sh`, `lib/fzf.sh`, `lib/ripgrep.sh` | `lib/integrations/` |
| `lib/integrations/cli/validate` | `lib/bin/validate` |
| `lib/git/wrapper.sh` | `lib/git/wrapper.sh` (rename) |
| `lib/git/shared/clone-check.sh` | `lib/git/shared/clone-check.sh` |
| `lib/git/shared/dangerous-commands.sh` | `lib/git/shared/safety-checks.sh` |
| `lib/git/shared/secrets-check.sh` | `lib/validation/validators/security/secrets-validator.sh` |
| `lib/git/shared/*` | `lib/git/shared/*` |
| `lib/git/hooks/shared/timeout-wrapper.sh` | `lib/git/shared/timeout.sh` |
| `lib/git/hooks/shared/file-scanner.sh` | `lib/git/shared/file-scanner.sh` |
| `lib/git/hooks/shared/reporters.sh` | `lib/git/shared/reporters.sh` |
| `lib/git/hooks/shared/git-hooks-common.sh` | Merge → `lib/git/shared/git-utils.sh` |
| `lib/git/secrets/gitleaks.toml` | `lib/validation/validators/security/config/gitleaks.toml` |
| `lib/git/secrets/allowed.txt` | `lib/validation/validators/security/config/allowed.txt` |
| `lib/git/secrets/prohibited.txt` | `lib/validation/validators/security/config/prohibited.txt` |
| `lib/git/secrets/purge.txt` | `lib/validation/validators/security/config/purge.txt` |
| `lib/git/hooks/check-file-length.sh` | `lib/validation/validators/core/file-length-validator.sh` |
| `lib/git/hooks/check-sensitive-filenames.sh` | `lib/validation/validators/security/sensitive-files-validator.sh` |
| `lib/gha-security/validators/*` | `lib/validation/validators/gha/*.sh` |
| `lib/gha-security/config/*` | `lib/validation/validators/gha/config/*` |
| `lib/gha-security/scanner.sh`, `core.sh`, `shared/*`, `reporters/*` | Merge → `lib/bin/gha-scan` |
| `lib/phantom-guard/setup.sh` | `lib/validation/validators/security/phantom-validator.sh` |
| `lib/phantom-guard/config.yml` | `lib/validation/validators/security/config/phantom.yml` |
| `lib/git/hooks/opengrep-hook.sh` | `lib/validation/validators/security/opengrep-validator.sh` |
| `lib/git/hooks/benchmark-hook.sh` | `lib/validation/validators/infra/benchmark-validator.sh` |

### Files to CREATE

| File | From |
|------|------|
| **Core Module** | |
| `lib/core/paths.sh` | Extract from init.sh |
| **Aliases Module** | |
| `lib/aliases/init.sh` | New module loader |
| `lib/aliases/core.sh` | Split from aliases.sh |
| `lib/aliases/ai-cli.sh` | Split from aliases.sh |
| `lib/aliases/git.sh` | Split from aliases.sh |
| `lib/aliases/package-managers.sh` | Split from aliases.sh |
| `lib/aliases/formatting.sh` | Split from aliases.sh |
| `lib/aliases/gha.sh` | Split from aliases.sh |
| `lib/aliases/1password.sh` | Split from aliases.sh |
| **Security Module** | |
| `lib/security/init.sh` | New module loader |
| `lib/security/rm/wrapper.sh` | Split from security.sh |
| `lib/security/rm/paths.sh` | Split from security.sh |
| `lib/security/rm/audit.sh` | Split from security.sh |
| `lib/security/trash/trash.sh` | Split from security.sh |
| `lib/security/filesystem/protect.sh` | Split from security.sh |
| `lib/security/audit.sh` | Split from security.sh |
| `lib/security/hardening.sh` | Split from security.sh |
| **Git Module** | |
| `lib/git/init.sh` | New module loader |
| `lib/git/stages/commit/pre-commit.sh` | New stage structure |
| `lib/git/stages/commit/prepare-commit-msg.sh` | New stage structure |
| `lib/git/stages/commit/commit-msg.sh` | New stage structure |
| `lib/git/stages/commit/post-commit.sh` | New stage structure |
| `lib/git/stages/push/pre-push.sh` | New stage structure |
| `lib/git/stages/merge/pre-merge-commit.sh` | New stage structure |
| `lib/git/stages/merge/post-merge.sh` | New stage structure |
| **Integrations Module** | |
| `lib/integrations/1password/init.sh` | New module loader |
| `lib/integrations/cat.sh` | Extract from aliases |
| `lib/integrations/verification.sh` | Extract from security.sh |
| `lib/integrations/ghls/status.sh` | Split from ghls |
| `lib/integrations/ghls/display.sh` | Split from ghls |
| **Validation Module** | |
| `lib/validation/api-internal.sh` | Split from api.sh |
| `lib/validation/api-output.sh` | Split from api.sh |
| `lib/validation/api-parallel.sh` | Split from api.sh |
| `lib/validation/validators/core/format-validator.sh` | New validator |
| **Terminal Module** | |
| `lib/terminal/installation/kitty-config.sh` | Split from kitty.sh |
| `lib/terminal/installation/kitty-theme.sh` | Split from kitty.sh |

### Files UNCHANGED

- `lib/core/` (colors.sh, config.sh, logging.sh, platform.sh)
- `lib/command-safety/` (entire directory - see expanded structure above)
- `lib/validation/core.sh`, `lib/validation/shared/`
- `lib/terminal/` (structure unchanged, kitty.sh split only)
- `lib/welcome/` (entire directory)
- `lib/bin/` (gha-scan, rm, shell-config, shell-config-init)
- `config/` (all files)
- Root files (init.sh, install.sh, uninstall.sh, README.md, CLAUDE.md, VERSION)
- `tools/` (entire directory)

### Validators Reorganization

**Current flat structure:**
```
lib/validation/validators/
├── file-validator.sh
├── infra-validator.sh
├── security-validator.sh
├── syntax-validator.sh
└── workflow-validator.sh
```

**Target themed subfolders (configs co-located):**
```
lib/validation/validators/
├── core/                        # Core validation
│   ├── file-validator.sh       # File size/structure
│   ├── file-length-validator.sh # Line count limits (from hooks/)
│   ├── syntax-validator.sh     # Shell/YAML syntax
│   └── format-validator.sh     # Code formatting (NEW)
├── security/                    # Security scanning
│   ├── security-validator.sh   # General security
│   ├── secrets-validator.sh    # Gitleaks (from git/shared/)
│   ├── opengrep-validator.sh   # OpenGrep (from hooks/)
│   ├── phantom-validator.sh    # Phantom Guard (from phantom-guard/)
│   ├── sensitive-files-validator.sh # Sensitive filenames (from hooks/)
│   └── config/                 # Security configs
│       ├── gitleaks.toml      # Gitleaks config (from git/secrets/)
│       ├── allowed.txt        # Allowed patterns (from git/secrets/)
│       ├── prohibited.txt     # Prohibited patterns (from git/secrets/)
│       ├── purge.txt          # Purge patterns (from git/secrets/)
│       └── phantom.yml        # Phantom Guard config
├── gha/                         # GitHub Actions
│   ├── actionlint-validator.sh # Actionlint
│   ├── zizmor-validator.sh     # Zizmor
│   ├── poutine-validator.sh    # Poutine
│   ├── octoscan-validator.sh   # Octoscan
│   ├── pinact-validator.sh     # Pinact
│   └── config/                 # GHA configs
│       ├── .poutine.yml       # Poutine config
│       └── .zizmor.yml        # Zizmor config
└── infra/                       # Infrastructure
    ├── infra-validator.sh      # Infrastructure checks
    ├── workflow-validator.sh   # Workflow validation
    └── benchmark-validator.sh  # Performance (from hooks/)
```

---

## Summary

| Metric | Before | After |
|--------|--------|-------|
| Loose files at lib/ root | 8 | 0 |
| Duplicate folders | 2 | 0 |
| Files over 500 lines | 3 | 0 |
| Overlapping git hooks | 2 locations | 1 |
| Total files | 117+ | ~105 (consolidation) |

**Risk Assessment:** Phases 1-2 (Low), Phases 3-7 (Medium), Phase 8 (Low)

**Recommendation:** Execute as separate PRs per phase for easy rollback. Each phase has 7 granular stages with verification checkpoints.

---

*Last updated: 2026-02-03 | Document version: 3.0 (granular stages, themed validators, configs co-located)*
