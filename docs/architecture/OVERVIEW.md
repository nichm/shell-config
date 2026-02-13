# Shell-Config Architecture - Overview

**Last Updated:** 2026-02-13

---

## Overview

Shell-Config is a modular shell configuration system for bash and zsh that provides:

- **Modular Architecture:** Feature-based loading with conditional initialization
- **Safety Systems:** Multi-layer protection against destructive operations
- **Integration Framework:** Pluggable validators, hooks, and integrations
- **Performance Optimization:** Lazy loading, caching, and fast-path execution
- **Cross-Platform:** macOS (primary) and Linux support with bash 5.x

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Shell Session                       │
│                    (zsh/bash with ~/.zshrc)                      │
└────────────────────────────┬────────────────────────────────────┘
                             │ sources
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                         init.sh (Master)                         │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  1. Configuration Loading (config.sh)                      │  │
│  │  2. Platform Detection (platform.sh)                      │  │
│  │  3. Feature Flags Evaluation                              │  │
│  │  4. Conditional Module Loading                            │  │
│  │  5. PATH & Environment Setup                              │  │
│  └───────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │ loads
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Core Modules │    │ Feature Mods │    │Integrations  │
│              │    │              │    │              │
│ • config.sh  │    │ • git/       │    │ • 1password/ │
│ • platform.sh│    │ • command-   │    │ • fzf.sh     │
│ • colors.sh  │    │   safety/    │    │ • eza.sh     │
│ • logging.sh │    │ • validation/│    │ • ripgrep.sh │
│ • paths.sh   │    │ • security/  │    │ • ghls/      │
│ • traps.sh   │    │ • welcome/   │    │ • cat.sh     │
│ • cmd-cache  │    │ • aliases/   │    │ • broot.sh   │
└──────────────┘    └──────────────┘    └──────────────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │ provides
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Validation & Safety                         │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  • 7 Git Hooks (pre-commit through post-merge)            │  │
│  │  • 15 Pre-commit Validators (syntax, deps, secrets, size) │  │
│  │  • Command Safety (61 rules across 30+ commands)          │  │
│  │  • Git Wrapper (dangerous operation warnings)             │  │
│  │  • RM Protection (4-layer: PATH + function + trash +      │  │
│  │    chflags)                                               │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Module Inventory

### Core (`lib/core/`)

| Module | Purpose |
|--------|---------|
| `config.sh` | Config loading (env vars → YAML → simple → defaults) |
| `platform.sh` | OS/arch detection, `is_macos()`, `is_linux()` |
| `colors.sh` | ANSI color constants (`$RED`, `$GREEN`, `$NC`) |
| `logging.sh` | Atomic writes, log rotation |
| `paths.sh` | PATH setup (`lib/bin` first) |
| `command-cache.sh` | Cached `command_exists` lookups |
| `protected-paths.sh` | Centralized path validation for destructive ops |
| `traps.sh` | Cleanup trap handlers |
| `doctor.sh` | Health check diagnostics |

### Safety (`lib/command-safety/`, `lib/security/`, `lib/bin/`)

| Module | Purpose |
|--------|---------|
| `command-safety/engine/` | Rule matching, display, logging (8 engine files) |
| `command-safety/rules/` | 61 rules across 13 rule files (git, docker, k8s, terraform, etc.) |
| `bin/rm` | PATH-based rm wrapper with protected paths |
| `bin/command-enforce` | Universal PATH wrapper (26 symlinked commands) |
| `security/hardening.sh` | Security settings |
| `security/filesystem/protect.sh` | chflags kernel-level protection |
| `security/rm/wrapper.sh` | Function override for interactive shells |

### Git (`lib/git/`)

| Module | Purpose |
|--------|---------|
| `wrapper.sh` | Safety checks on all git operations |
| `setup.sh` | Git hooks installation |
| `stages/commit/` | pre-commit, prepare-commit-msg, commit-msg, post-commit |
| `stages/push/` | pre-push (test runner) |
| `stages/merge/` | pre-merge-commit, post-merge (auto-install deps) |
| `shared/` | Command parser, file scanner, safety checks, metrics |

### Validation (`lib/validation/`)

| Module | Purpose |
|--------|---------|
| `core.sh` + `api*.sh` | Pluggable validation engine with parallel execution |
| `validators/core/` | File length, syntax (shellcheck, oxlint, ruff, yamllint, etc.) |
| `validators/security/` | OpenGrep SAST, sensitive files, Phantom Guard |
| `validators/gha/` | actionlint, zizmor, octoscan, pinact, poutine |
| `validators/infra/` | Dockerfile, Terraform, K8s manifest validation |
| `validators/typescript/` | env-security, framework-config, test-coverage |

### Integrations (`lib/integrations/`)

| Module | Purpose |
|--------|---------|
| `1password/` | SSH agent, secrets loading, key sync, diagnostics |
| `fzf.sh` | Fuzzy finder (fe, fcd, fh, fbr, fkill) |
| `eza.sh` | Modern ls with git icons |
| `ripgrep.sh` | Fast search aliases (rgcode, rgtest, rgfunc) |
| `ghls/` | Git repo list with PR/branch status |
| `cat.sh` | Enhanced cat (bat → ccat → pygmentize → cat) |

### Other

| Module | Purpose |
|--------|---------|
| `aliases/` | 9 alias files (git, AI, GHA, package managers, servers, etc.) |
| `welcome/` | MOTD: greeting, terminal status grid, git hooks grid, shortcuts |
| `terminal/` | Terminal installers (Ghostty, iTerm2, Kitty, Warp), autocomplete |
| `setup/` | Symlink manager for install/uninstall |

---

## Performance (Feb 2026, macOS Apple Silicon)

| Metric | Time | Rating |
|--------|------|--------|
| Full startup (`zsh -i`) | ~123ms | MID |
| `source init.sh` only | ~98ms | MID |
| Minimal init (all features off) | ~42ms | GREAT |
| Welcome message | ~2ms | GREAT |
| Git wrapper overhead | ~7ms | GREAT |
| compinit (cached) | ~11ms | GREAT |

Per-feature cost (disabled individually from ~98ms baseline):

| Feature Disabled | Init Time | Cost |
|-----------------|-----------|------|
| GIT_WRAPPER | ~79ms | ~19ms |
| LOG_ROTATION | ~85ms | ~13ms |
| COMMAND_SAFETY | ~103ms | ~(-5ms) |
| WELCOME | ~107ms | ~(-9ms) |

See [tools/benchmarking/](../../tools/benchmarking/) for full reports and `benchmark.sh`.

---

## Security Model

| Threat | Mitigation |
|--------|-----------|
| Accidental data loss | 4-layer RM protection, trash integration |
| Secret leakage | Pre-commit gitleaks scanning (40+ patterns) |
| Destructive git ops | Git wrapper warnings, bypass flags with audit logging |
| Dangerous commands | Command safety engine (61 rules), PATH wrappers |
| Supply chain | Phantom Guard typosquatting, GHA security scanners |

All bypass usage logged to `~/.shell-config-audit.log`.

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| macOS (Apple Silicon) | Primary | `brew install bash` required |
| macOS (Intel) | Primary | Homebrew paths auto-detected |
| Linux (Ubuntu/Debian/Fedora/Arch) | Supported | Native bash 5.x |
| Windows | Never | No support planned |

See [BASH-5-UPGRADE.md](BASH-5-UPGRADE.md) for rationale.

---

## Related Docs

- **[INITIALIZATION.md](INITIALIZATION.md)** — Startup flow and timing
- **[GIT-HOOKS-PIPELINE.md](GIT-HOOKS-PIPELINE.md)** — All 7 git hooks in detail
- **[INTEGRATIONS.md](INTEGRATIONS.md)** — Integration layer and templates
- **[API Reference](api/API-REFERENCE.md)** — Validator API
- **[README.md](../../README.md)** — User documentation
