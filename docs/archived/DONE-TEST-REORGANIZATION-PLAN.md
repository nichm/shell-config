# ✅ Test Reorganization Plan — COMPLETED

> **Status:** ✅ **CORE RESTRUCTURING COMPLETE** — Executed as part of Phases 1-8  
> **Completed:** 2026-02-04  
> **Archived:** 2026-02-09  
> **Result:** Tests moved to module-based folders, helpers split, fixtures created, run_all.sh + run_module.sh updated  
> **Note:** Minor items (new test creation, large file splits) tracked in separate issues

---

**Date:** 2026-02-03  
**Scope:** 27 test files, 7,686 total lines  
**Goal:** Align test organization with new lib/ structure

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Organizational Options Considered](#organizational-options-considered)
3. [Recommended Structure](#recommended-structure)
4. [Migration Strategy](#migration-strategy)
5. [Path Updates Required](#path-updates-required)
6. [File Splitting Requirements](#file-splitting-requirements)

---

## Current State Analysis

### File Inventory

| Test File | Lines | Tests Module | Current Path References |
|-----------|-------|--------------|------------------------|
| `welcome.bats` | 692 | welcome/ | lib/welcome/ |
| `syntax_validator_enhanced.bats` | 593 | validation/ | lib/validation/ |
| `git_wrapper_integration.bats` | 546 | git/ | lib/git/wrapper.sh |
| `validation.bats` | 544 | validation/ | lib/validation/ |
| `op_secrets.bats` | 541 | integrations/1password/ | lib/1password/ |
| `gha_security.bats` | 484 | validation/gha/ | lib/gha-security/ |
| `git_hooks.bats` | 456 | git/ | lib/git/hooks/ |
| `git_syntax_enhanced.bats` | 446 | validation/ | lib/git/ |
| `security_loaders.bats` | 425 | security/ | lib/security/init.sh, lib/core/loaders/ssh.sh |
| `git_safety.bats` | 374 | git/ | lib/git/shared/ |
| `git_utils.bats` | 336 | git/ | lib/git/shared/ |
| `common_additions.bats` | 316 | core/ | lib/core/ |
| `terminal.bats` | 275 | terminal/ | lib/terminal/ |
| `phantom_guard.bats` | 270 | validation/security/ | lib/phantom-guard/ |
| `tool_integrations.bats` | 267 | integrations/ | lib/eza.sh, lib/fzf.sh, lib/ripgrep.sh |
| `git_wrapper.bats` | 495 | git/ | lib/git/wrapper.sh |
| `logging.bats` | 85 | core/ | lib/core/logging.sh |
| `config_loader.bats` | 82 | core/ | lib/core/config.sh |
| `rm_wrapper.bats` | 74 | security/ | lib/bin/rm |
| `colors.bats` | 68 | core/ | lib/core/colors.sh |
| `aliases.bats` | 65 | aliases/ | lib/aliases.sh |
| `init.bats` | 55 | init/ | init.sh |
| `install.bats` | 52 | init/ | install.sh |
| `version.bats` | 48 | init/ | VERSION |
| `doctor.bats` | 45 | core/ | lib/doctor.sh |
| `shell_config_cli.bats` | 42 | bin/ | lib/bin/shell-config |

### Current Problems

| Problem | Impact | Files Affected |
|---------|--------|----------------|
| **Flat structure** | Hard to find tests for specific modules | All 27 files |
| **Inconsistent naming** | `git_wrapper` vs `op_secrets` vs `gha_security` | 15+ files |
| **Path references to old locations** | Will break after lib/ refactor | 20+ files |
| **Large files (>500 lines)** | Hard to maintain | 5 files |
| **Scattered git tests** | 6 files, hard to run together | git_*.bats |
| **Vague naming** | `common_additions.bats` unclear purpose | 2-3 files |
| **Mixed test types** | Unit and integration tests interleaved | 10+ files |
| **No fixtures folder** | Test data inline in files | All files |
| **Mocks in single file** | `test_helpers.bash` is 958 lines | 1 file |

### Test Categories Identified

| Category | File Count | Total Lines | Description |
|----------|------------|-------------|-------------|
| Git | 6 | 2,653 | Wrapper, safety, hooks, utils |
| Validation | 5 | 2,067 | Syntax, file, GHA, API |
| Integrations | 3 | 1,108 | 1Password, tools (eza/fzf/rg) |
| Security | 3 | 769 | rm wrapper, loaders, phantom |
| Core | 5 | 596 | Colors, logging, config, doctor |
| Terminal | 2 | 967 | Terminal, welcome |
| Init | 3 | 155 | Init, install, version |
| CLI | 1 | 42 | shell-config CLI |

---

## Organizational Options Considered

### Option A: Mirror lib/ Structure Exactly

```
tests/
├── core/
│   ├── colors.bats
│   ├── logging.bats
│   └── loaders/
│       └── loaders.bats
├── validation/
│   └── validators/
│       ├── core/
│       │   └── syntax.bats
│       ├── security/
│       │   └── secrets.bats
│       └── gha/
│           └── gha.bats
└── ...
```

**Verdict:** ❌ Rejected - Too deep nesting, overkill for test files

### Option B: Top-Level Module Groups Only

```
tests/
├── core/
├── git/
├── validation/
├── security/
├── integrations/
├── terminal/
└── init/
```

**Verdict:** ⚠️ Partial - Good but missing test-type separation

### Option C: Category-Based (Unit/Integration/E2E)

```
tests/
├── unit/
│   └── (all unit tests)
├── integration/
│   └── (all integration tests)
└── e2e/
    └── (end-to-end tests)
```

**Verdict:** ❌ Rejected - Makes finding module tests hard

### Option D: Hybrid Module + Type Suffixes (RECOMMENDED)

```
tests/
├── core/           # Module-based organization
├── git/
├── validation/
├── ...
└── helpers/        # Test infrastructure
```

**Verdict:** ✅ Selected - Best balance of organization and practicality

---

## Recommended Structure

```
tests/
├── core/                              # Core module tests
│   ├── colors.bats                   # lib/core/colors.sh
│   ├── logging.bats                  # lib/core/logging.sh
│   ├── config.bats                   # lib/core/config.sh (renamed)
│   ├── platform.bats                 # lib/core/platform.sh (NEW)
│   ├── doctor.bats                   # lib/core/doctor.sh
│   └── loaders.bats                  # lib/core/loaders/*.sh (extracted)
│
├── aliases/                           # Aliases module tests
│   └── aliases.bats                  # lib/aliases/*.sh
│
├── command-safety/                    # Command safety tests
│   └── command_safety.bats           # lib/command-safety/
│
├── security/                          # Security module tests
│   ├── rm_wrapper.bats               # lib/security/rm/
│   ├── loaders.bats                  # lib/security/init.sh (extracted)
│   └── audit.bats                    # lib/security/audit.sh (NEW)
│
├── git/                               # Git module tests
│   ├── wrapper.bats                  # lib/git/wrapper.sh (renamed)
│   ├── wrapper.integration.bats      # Integration tests (renamed)
│   ├── safety.bats                   # lib/git/shared/safety-checks.sh
│   ├── hooks.bats                    # lib/git/hooks/
│   ├── utils.bats                    # lib/git/shared/
│   └── stages.bats                   # lib/git/stages/ (NEW)
│
├── validation/                        # Validation module tests
│   ├── api.bats                      # lib/validation/api*.sh
│   ├── core/                         # Core validators
│   │   ├── file.bats                # file-validator.sh
│   │   ├── syntax.bats              # syntax-validator.sh
│   │   └── syntax.enhanced.bats     # Enhanced tests
│   ├── security/                     # Security validators
│   │   ├── secrets.bats             # secrets-validator.sh
│   │   ├── opengrep.bats            # opengrep-validator.sh (NEW)
│   │   └── phantom.bats             # phantom-validator.sh (from phantom_guard.bats)
│   ├── gha/                          # GHA validators
│   │   └── gha.bats                 # gha-security validators (renamed)
│   └── infra/                        # Infrastructure validators
│       └── benchmark.bats           # benchmark-validator.sh (NEW)
│
├── terminal/                          # Terminal module tests
│   ├── terminal.bats                 # lib/terminal/
│   └── installation.bats             # lib/terminal/installation/ (NEW)
│
├── welcome/                           # Welcome module tests
│   ├── main.bats                     # lib/welcome/main.sh (split from welcome.bats)
│   ├── shortcuts.bats               # lib/welcome/shortcuts.sh (split)
│   └── status.bats                  # lib/welcome/terminal-status.sh (split)
│
├── integrations/                      # Integrations tests
│   ├── 1password/                    # 1Password tests
│   │   ├── secrets.bats             # lib/integrations/1password/secrets.sh
│   │   ├── login.bats               # lib/integrations/1password/login.sh (NEW)
│   │   └── ssh_sync.bats            # lib/integrations/1password/ssh-sync.sh (NEW)
│   ├── ghls/                         # GHLS tests
│   │   └── ghls.bats                # lib/integrations/ghls/ (NEW)
│   ├── eza.bats                      # lib/integrations/eza.sh
│   ├── fzf.bats                      # lib/integrations/fzf.sh
│   └── ripgrep.bats                  # lib/integrations/ripgrep.sh
│
├── bin/                               # Executable tests
│   ├── shell_config.bats             # lib/bin/shell-config
│   ├── gha_scan.bats                 # lib/bin/gha-scan (NEW)
│   └── validate.bats                 # lib/bin/validate (NEW)
│
├── init/                              # Initialization tests
│   ├── init.bats                     # init.sh
│   ├── install.bats                  # install.sh
│   └── version.bats                  # VERSION
│
├── helpers/                           # Test infrastructure
│   ├── test_helpers.bash             # Main helper library
│   ├── assertions.bash               # Custom assertions (extracted)
│   ├── mocks/                        # Mock command scripts
│   │   ├── git.bash                 # Git mock
│   │   ├── op.bash                  # 1Password mock
│   │   ├── validators.bash          # Validator mocks
│   │   └── README.md                # Mock usage docs
│   ├── fixtures/                     # Test data files
│   │   ├── configs/                 # Sample config files
│   │   ├── workflows/               # Sample GitHub workflows
│   │   └── scripts/                 # Sample scripts to validate
│   └── README.md                     # Helper documentation
│
├── run_all.sh                         # Test runner (enhanced)
├── run_module.sh                      # Run tests by module (NEW)
└── README.md                          # Test documentation (updated)
```

### Why This Structure

| Decision | Rationale |
|----------|-----------|
| **Top-level module folders** | Matches lib/ organization, easy to find tests |
| **validation/core/, validation/security/, validation/gha/** | Mirrors validators subfolder structure |
| **integrations/1password/** | 1Password is complex, warrants subfolder |
| **helpers/ not shared/** | "helpers" is clearer for test utilities |
| **Mocks in separate folder** | Cleaner than embedding in test_helpers.bash |
| **Fixtures folder** | Reusable test data, not inline strings |
| **.integration.bats suffix** | Clear test type without separate folders |
| **No command-safety subfolder** | Module is already well-organized, single test file sufficient |

---

## Migration Strategy

### Phase T1: Prepare Infrastructure

#### Stage T1.1: Create Directory Structure
- [ ] Create `tests/core/` directory
- [ ] Create `tests/aliases/` directory
- [ ] Create `tests/command-safety/` directory
- [ ] Create `tests/security/` directory
- [ ] Create `tests/git/` directory
- [ ] Create `tests/validation/` directory
- [ ] Create `tests/validation/core/` directory
- [ ] Create `tests/validation/security/` directory
- [ ] Create `tests/validation/gha/` directory
- [ ] Create `tests/validation/infra/` directory
- [ ] Create `tests/terminal/` directory
- [ ] Create `tests/welcome/` directory
- [ ] Create `tests/integrations/` directory
- [ ] Create `tests/integrations/1password/` directory
- [ ] Create `tests/integrations/ghls/` directory
- [ ] Create `tests/bin/` directory
- [ ] Create `tests/init/` directory
- [ ] Create `tests/helpers/` directory
- [ ] Create `tests/helpers/mocks/` directory
- [ ] Create `tests/helpers/fixtures/` directory

#### Stage T1.2: Split test_helpers.bash
- [ ] Extract mock functions → `helpers/mocks/git.bash`
- [ ] Extract mock functions → `helpers/mocks/op.bash`
- [ ] Extract mock functions → `helpers/mocks/validators.bash`
- [ ] Extract assertion functions → `helpers/assertions.bash`
- [ ] Keep core helpers in `helpers/test_helpers.bash`
- [ ] Update `load` statements in all tests

#### Stage T1.3: Create Fixtures
- [ ] Create sample config files in `helpers/fixtures/configs/`
- [ ] Create sample workflows in `helpers/fixtures/workflows/`
- [ ] Create sample scripts in `helpers/fixtures/scripts/`
- [ ] Update tests to use fixtures

---

### Phase T2: Core Module Tests

#### Stage T2.1: Move Core Tests
- [ ] Move `colors.bats` → `core/colors.bats`
- [ ] Move `logging.bats` → `core/logging.bats`
- [ ] Rename `config_loader.bats` → `core/config.bats`
- [ ] Move `doctor.bats` → `core/doctor.bats`
- [ ] Extract loaders tests from `security_loaders.bats` → `core/loaders.bats`
- [ ] Merge relevant parts of `common_additions.bats` → `core/`

#### Stage T2.2: Update Path References
- [ ] Update `lib/core/` → `lib/core/` in all core tests
- [ ] Update `lib/doctor.sh` → `lib/core/doctor.sh`
- [ ] Update load paths for test_helpers

#### Stage T2.3: Verify
- [ ] Run `bats tests/core/`
- [ ] Verify all tests pass

---

### Phase T3: Git Module Tests

#### Stage T3.1: Rename and Move
- [ ] Rename `git_wrapper.bats` → `git/wrapper.bats`
- [ ] Rename `git_wrapper_integration.bats` → `git/wrapper.integration.bats`
- [ ] Rename `git_safety.bats` → `git/safety.bats`
- [ ] Rename `git_hooks.bats` → `git/hooks.bats`
- [ ] Rename `git_utils.bats` → `git/utils.bats`
- [ ] Move `git_syntax_enhanced.bats` → `validation/core/syntax.enhanced.bats`

#### Stage T3.2: Update Path References
- [ ] Update `lib/git/wrapper.sh` → `lib/git/wrapper.sh`
- [ ] Update `lib/git/shared/` → `lib/git/shared/`
- [ ] Update `lib/git/shared/` → `lib/git/shared/`
- [ ] Update `lib/git/hooks/shared/` → `lib/git/shared/`
- [ ] Update `lib/git/secrets/` → `lib/validation/validators/security/config/`

#### Stage T3.3: Verify
- [ ] Run `bats tests/git/`
- [ ] Verify all tests pass

---

### Phase T4: Validation Module Tests

#### Stage T4.1: Reorganize
- [ ] Move `validation.bats` → `validation/api.bats`
- [ ] Move `syntax_validator.bats` → `validation/core/syntax.bats`
- [ ] Move `syntax_validator_enhanced.bats` → `validation/core/syntax.enhanced.bats`
- [ ] Move `gha_security.bats` → `validation/gha/gha.bats`
- [ ] Move `phantom_guard.bats` → `validation/security/phantom.bats`

#### Stage T4.2: Update Path References
- [ ] Update `lib/gha-security/` → `lib/validation/validators/gha/`
- [ ] Update `lib/phantom-guard/` → `lib/validation/validators/security/`
- [ ] Update validator paths to new subfolder structure

#### Stage T4.3: Verify
- [ ] Run `bats tests/validation/`
- [ ] Verify all tests pass

---

### Phase T5: Security Module Tests

#### Stage T5.1: Reorganize
- [ ] Move `rm_wrapper.bats` → `security/rm_wrapper.bats`
- [ ] Extract security parts from `security_loaders.bats` → `security/loaders.bats`
- [ ] Delete empty `security_loaders.bats`

#### Stage T5.2: Update Path References
- [ ] Update `lib/security/init.sh` → `lib/security/init.sh`
- [ ] Update rm wrapper paths

#### Stage T5.3: Verify
- [ ] Run `bats tests/security/`
- [ ] Verify all tests pass

---

### Phase T6: Integrations Tests

#### Stage T6.1: Reorganize
- [ ] Move `op_secrets.bats` → `integrations/1password/secrets.bats`
- [ ] Split `tool_integrations.bats`:
  - [ ] Extract eza tests → `integrations/eza.bats`
  - [ ] Extract fzf tests → `integrations/fzf.bats`
  - [ ] Extract ripgrep tests → `integrations/ripgrep.bats`
- [ ] Delete empty `tool_integrations.bats`

#### Stage T6.2: Update Path References
- [ ] Update `lib/1password/` → `lib/integrations/1password/`
- [ ] Update `lib/ghls/` → `lib/integrations/ghls/`
- [ ] Update `lib/eza.sh` → `lib/integrations/eza.sh`
- [ ] Update `lib/fzf.sh` → `lib/integrations/fzf.sh`
- [ ] Update `lib/ripgrep.sh` → `lib/integrations/ripgrep.sh`

#### Stage T6.3: Verify
- [ ] Run `bats tests/integrations/`
- [ ] Verify all tests pass

---

### Phase T7: Remaining Modules

#### Stage T7.1: Terminal & Welcome
- [ ] Move `terminal.bats` → `terminal/terminal.bats`
- [ ] Split `welcome.bats` (692 lines) into:
  - [ ] `welcome/main.bats` (~200 lines)
  - [ ] `welcome/shortcuts.bats` (~200 lines)
  - [ ] `welcome/status.bats` (~200 lines)

#### Stage T7.2: Aliases & CLI
- [ ] Move `aliases.bats` → `aliases/aliases.bats`
- [ ] Move `shell_config_cli.bats` → `bin/shell_config.bats`

#### Stage T7.3: Init
- [ ] Move `init.bats` → `init/init.bats`
- [ ] Move `install.bats` → `init/install.bats`
- [ ] Move `version.bats` → `init/version.bats`

#### Stage T7.4: Verify
- [ ] Run `bats tests/terminal/`
- [ ] Run `bats tests/welcome/`
- [ ] Run `bats tests/aliases/`
- [ ] Run `bats tests/bin/`
- [ ] Run `bats tests/init/`

---

### Phase T8: Final Cleanup

#### Stage T8.1: Update Test Runner
- [ ] Update `run_all.sh` to find tests in new locations
- [ ] Create `run_module.sh` for per-module testing
- [ ] Update CI configuration if needed

#### Stage T8.2: Update Documentation
- [ ] Update `tests/README.md`
- [ ] Create `tests/helpers/README.md`
- [ ] Create `tests/helpers/mocks/README.md`

#### Stage T8.3: Verify All
- [ ] Run `./tests/run_all.sh`
- [ ] Verify all 27 test files pass
- [ ] Verify CI passes

---

## Path Updates Required

### lib/git/ Path Changes

| Old Path | New Path | Test Files Affected |
|----------|----------|---------------------|
| `lib/git/wrapper.sh` | `lib/git/wrapper.sh` | wrapper.bats, wrapper.integration.bats |
| `lib/git/shared/` | `lib/git/shared/` | safety.bats |
| `lib/git/shared/` | `lib/git/shared/` | utils.bats |
| `lib/git/hooks/shared/` | `lib/git/shared/` | hooks.bats |
| `lib/git/secrets/` | `lib/validation/validators/security/config/` | safety.bats |

### lib/validation/ Path Changes

| Old Path | New Path | Test Files Affected |
|----------|----------|---------------------|
| `lib/validation/validators/file-validator.sh` | `lib/validation/validators/core/file-validator.sh` | validation.bats |
| `lib/validation/validators/syntax-validator.sh` | `lib/validation/validators/core/syntax-validator.sh` | syntax_validator.bats |
| `lib/validation/validators/security-validator.sh` | `lib/validation/validators/security/security-validator.sh` | validation.bats |
| `lib/gha-security/` | `lib/validation/validators/gha/` | gha_security.bats |
| `lib/phantom-guard/` | `lib/validation/validators/security/phantom-validator.sh` | phantom_guard.bats |

### lib/ Root Path Changes

| Old Path | New Path | Test Files Affected |
|----------|----------|---------------------|
| `lib/1password/` | `lib/integrations/1password/` | op_secrets.bats |
| `lib/ghls/` | `lib/integrations/ghls/` | (new test) |
| `lib/eza.sh` | `lib/integrations/eza.sh` | tool_integrations.bats |
| `lib/fzf.sh` | `lib/integrations/fzf.sh` | tool_integrations.bats |
| `lib/ripgrep.sh` | `lib/integrations/ripgrep.sh` | tool_integrations.bats |
| `lib/security/init.sh` | `lib/security/init.sh` | security_loaders.bats |
| `lib/core/loaders/ssh.sh` | `lib/core/loaders/*.sh` | security_loaders.bats |
| `lib/aliases.sh` | `lib/aliases/*.sh` | aliases.bats |
| `lib/doctor.sh` | `lib/core/doctor.sh` | doctor.bats |
| `lib/core/` | `lib/core/` | common_additions.bats |

---

## File Splitting Requirements

### Large Files to Split

| File | Current Lines | Target | Split Into |
|------|--------------|--------|------------|
| `welcome.bats` | 692 | <250 each | `welcome/main.bats`, `welcome/shortcuts.bats`, `welcome/status.bats` |
| `syntax_validator_enhanced.bats` | 593 | <300 each | `validation/core/syntax.enhanced.bats`, `validation/core/parallel.bats` |
| `git_wrapper_integration.bats` | 546 | <300 each | `git/wrapper.integration.bats`, `git/wrapper.e2e.bats` |
| `validation.bats` | 544 | <300 each | `validation/api.bats`, `validation/core/file.bats` |
| `op_secrets.bats` | 541 | <300 each | `integrations/1password/secrets.bats`, `integrations/1password/auth.bats` |

### test_helpers.bash Split

| Current | Lines | Extract To |
|---------|-------|------------|
| Mock functions | ~220 | `helpers/mocks/*.bash` |
| Assertions | ~120 | `helpers/assertions.bash` |
| Environment setup | ~100 | Keep in `test_helpers.bash` |
| File creation | ~100 | Keep in `test_helpers.bash` |
| Debug helpers | ~50 | Keep in `test_helpers.bash` |
| Utilities | ~100 | Keep in `test_helpers.bash` |
| Exports | ~30 | Keep in `test_helpers.bash` |

---

## Summary

| Metric | Before | After |
|--------|--------|-------|
| Directory depth | 1 | 2-3 |
| Module folders | 0 | 10 |
| Test files | 27 | ~35 (after splits) |
| Files >500 lines | 5 | 0 |
| Average file size | 285 lines | ~200 lines |
| Path references to update | - | ~150 |

**Estimated Effort:** 4-6 hours for full migration

**Dependencies:** Complete lib/ refactor first (Phases 1-6), then update tests

**Recommendation:** Execute test refactor as Phase 9 after lib/ refactor Phase 8

---

*Last updated: 2026-02-03 | Document version: 1.0*
