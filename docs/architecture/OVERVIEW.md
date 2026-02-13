# Shell-Config Architecture - Overview

**Version:** 1.0.0
**Last Updated:** 2026-02-04

---

## Table of Contents

1. [Overview](#overview)
2. [High-Level Architecture](#high-level-architecture)
3. [Design Philosophy](#design-philosophy)
4. [Performance Metrics](#performance-metrics)
5. [Security Considerations](#security-considerations)

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
│ • config.sh  │    │ • git/       │    │ • cli/       │
│ • platform.sh│    │ • fzf.sh     │    │ • git/       │
│ • colors.sh  │    │ • eza.sh     │    │              │
│ • logging.sh │    │ • ripgrep.sh │    │              │
│              │    │ • command-   │    │              │
│              │    │   safety/    │    │              │
│              │    │ • welcome/   │    │              │
│              │    │ • 1password/ │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │ provides
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Validation & Safety                         │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  • Pre-commit Hooks (syntax, deps, secrets, size)         │  │
│  │  • Command Safety (npm blocks, rm warnings)               │  │
│  │  • Git Wrapper (dangerous operation warnings)             │  │
│  │  • RM Protection (PATH wrapper + function override)       │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Design Philosophy

### Unix Principles

- **Do one thing well:** Each module has a single, clear purpose
- **Compose together:** Modules work independently but integrate seamlessly

### Fail Loudly

- **Clear error messages:** Every error explains WHAT, WHY, and HOW to fix
- **Non-zero exit codes:** Failures are explicit and trackable
- **Audit logging:** All bypass operations logged for review

### Non-Interactive

- **No prompts:** All commands run without user input
- **Automatable:** Safe for use in scripts and CI/CD
- **Deterministic:** Same input produces same output

### Bash 5.x Required

- **Modern features:** Uses associative arrays, readarray, case conversion, etc.
- **macOS setup:** Requires `brew install bash` (system bash 3.2.57 not supported)
- **Cross-platform:** Works on macOS (Homebrew bash) and Linux (bash 5.x)
- See [docs/BASH-5-UPGRADE.md](../BASH-5-UPGRADE.md) for rationale

---

## Performance Metrics

### Current Performance (macOS Apple Silicon)

| Component | Time | Optimization Status |
|-----------|------|---------------------|
| Full initialization | ~540ms | ⚠️ Needs optimization (target: <200ms) |
| Git wrapper overhead | ~8ms | ⚠️ Needs optimization (target: <5ms) |
| Pre-commit hook | ~14ms | ✅ Within target (target: <20ms) |
| Syntax validation | ~12ms | ✅ Within target (target: <15ms) |
| RM wrapper overhead | ~1.5ms | ✅ Excellent (target: <2ms) |

### Optimization Strategies

1. **Lazy Loading**
   - fnm loaded lazily (~25ms savings)
   - Eza --git conditional
   - Cached secrets scanning

2. **Fast-Path Execution**
   - Safe git commands bypass checks
   - Cached compinit (24h TTL)
   - Cached validator results

3. **Parallel Execution**
   - Independent validators run in parallel
   - File operations batched

4. **Caching**
   - Secrets cache (300s TTL)
   - Welcome cache (60s TTL)
   - Validator results cache

---

## Security Considerations

### Threat Model

1. **Accidental Data Loss**
   - Mitigation: RM protection, trash integration
   - Layer 1-4 protection

2. **Secret Leakage**
   - Mitigation: Pre-commit secret scanning
   - 40+ patterns, false positive handling

3. **Destructive Git Operations**
   - Mitigation: Git wrapper warnings
   - Bypass flags with audit logging

4. **Malicious Scripts**
   - Mitigation: Command safety blocks
   - npm/npx blocking by default

### Audit Logging

All bypass usage logged to `~/.shell-config-audit.log`:
- Bypass flags
- RM operations
- Safety violations
- Secret scanning skips

Review: `tail -20 ~/.shell-config-audit.log`

---

## Platform Compatibility

### macOS (Primary)

- Bash 5.x via Homebrew required (`brew install bash`)
- System bash 3.2.57 not supported
- Homebrew paths auto-detected
- Python framework detection
- BSD stat commands

### Linux (Secondary)

- Bash 5.x (native)
- Standard paths
- GNU stat commands
- No Homebrew

### Compatibility Notes

- **No Windows support** (never)
- **Bash 4.0+ minimum** (5.x recommended)
- Zsh 5.9+ required for interactive shell features
- Cross-platform stat handling
- See [BASH-5-UPGRADE.md](../BASH-5-UPGRADE.md) for migration details

---

## Next Steps

- **[MODULES.md](MODULES.md)** - Detailed module structure
- **[INITIALIZATION.md](INITIALIZATION.md)** - Startup flow and timing
- **[INTEGRATIONS.md](INTEGRATIONS.md)** - Integration layer
- **[API](../api/API-QUICKSTART.md)** - Validator API documentation

---

*For more information, see:*
- [README.md](../README.md) - User documentation
- [CLAUDE.md](../CLAUDE.md) - AI development guidelines
