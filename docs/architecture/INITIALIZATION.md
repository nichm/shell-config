# Shell-Config Architecture - Initialization

**Version:** 1.0.0
**Last Updated:** 2026-02-04

---

## Table of Contents

1. [Startup Sequence](#startup-sequence)
2. [Performance Timing](#performance-timing)
3. [Configuration Loading](#configuration-loading)
4. [Feature Flags](#feature-flags)
5. [Debugging Initialization](#debugging-initialization)

---

## Startup Sequence

### Full Initialization Flow

```
1. Shell Launch (zsh/bash)
   └─> ~/.zshrc sources init.sh

2. init.sh Execution
   ├─> Track startup time (SHELL_CONFIG_START_TIME)
   ├─> Detect script directory (SHELL_CONFIG_DIR)
   ├─> Load config.sh (configuration system)
   ├─> Load platform.sh (platform detection)
   │
   ├─> Evaluate Feature Flags
   │   ├─> Environment variables (highest priority)
   │   ├─> YAML config (~/.config/shell-config/config.yml)
   │   ├─> Simple config (~/.config/shell-config/config)
   │   └─> Defaults
   │
   ├─> Load Core Modules
   │   ├─> logging.sh → Rotate logs
   │   ├─> ensure-audit-symlink.sh → Create log symlink
   │   └─> Set up PATH & environment
   │
   └─> Load Feature Modules (conditional)
       ├─> 1password/secrets.sh (if SHELL_CONFIG_1PASSWORD=true)
       ├─> git/wrapper.sh (if SHELL_CONFIG_GIT_WRAPPER=true)
       ├─> command-safety/init.sh (if SHELL_CONFIG_COMMAND_SAFETY=true)
       ├─> eza.sh (if SHELL_CONFIG_EZA=true)
       ├─> fzf.sh (if SHELL_CONFIG_FZF=true)
       ├─> ripgrep.sh (if SHELL_CONFIG_RIPGREP=true)
       ├─> terminal/autocomplete.sh (if SHELL_CONFIG_AUTOCOMPLETE=true)
       ├─> welcome.sh (if SHELL_CONFIG_WELCOME=true)
       ├─> ghls/statusline.sh + auto.sh (if SHELL_CONFIG_GHLS=true)
       └─> security.sh (if SHELL_CONFIG_SECURITY=true)

3. ZSH-Specific (if zsh)
   ├─> Cached compinit (7ms savings)
   ├─> PROMPT_SUBST option
   └─> git_statusline hook

4. Ready State
   └─> Shell ready with all features loaded
```

---

## Performance Timing

### Current Performance (macOS Apple Silicon)

| Component | Time | Percentage | Optimization Status |
|-----------|------|------------|---------------------|
| **Core loading** | ~50ms | 9% | ✅ Optimized |
| **Feature modules** | ~350ms | 65% | ⚠️ Needs lazy loading |
| **1Password secrets** | ~80ms | 15% | ⚠️ Could defer |
| **ZSH compinit** | ~30ms | 6% | ✅ Cached |
| **PATH setup** | ~20ms | 4% | ✅ Optimized |
| **Other overhead** | ~10ms | 2% | ✅ Acceptable |
| **Total** | **~540ms** | 100% | ⚠️ Target: <200ms |

### Optimization Timeline

**Implemented:**
- ✅ Cached compinit (24h TTL) - saves ~100ms
- ✅ Lazy fnm loading - saves ~25ms
- ✅ Conditional eza --git - saves ~5ms
- ✅ Cached secrets scanning (300s TTL)

**Planned:**
- 🔄 Lazy load feature modules - estimated ~200ms savings
- 🔄 Parallel module loading - estimated ~100ms savings
- 🔄 Deferred 1Password authentication - estimated ~50ms savings

**Target Performance:** ~190ms (with all planned optimizations)

---

## Configuration Loading

### Priority Order

```
1. Environment Variables (highest priority)
   └─> SHELL_CONFIG_*=true overrides all

2. YAML Configuration
   └─> ~/.config/shell-config/config.yml
   └─> Requires: yq

3. Simple Configuration
   └─> ~/.config/shell-config/config
   └─> Bash variable assignment

4. Defaults (lowest priority)
   └─> Hardcoded in init.sh
```

### YAML Configuration

**Location:** `~/.config/shell-config/config.yml`

**Example:**
```yaml
# Feature flags
git_wrapper_enabled: true
command_safety_enabled: true
welcome_enabled: true
fzf_enabled: true
eza_enabled: true
ripgrep_enabled: true

# Advanced settings
secrets_cache_ttl: 300
welcome_cache_ttl: 60
welcome_style: auto
autocomplete_guide: true
shortcuts: true

# Disable specific features
npm_blocking: false
```

**Parsing:**
```bash
if command -v yq >/dev/null 2>&1; then
  SHELL_CONFIG_GIT_WRAPPER=$(yq eval '.git_wrapper_enabled' ~/.config/shell-config/config.yml)
fi
```

---

## Feature Flags

### Available Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| `SHELL_CONFIG_GIT_WRAPPER` | `true` | Git command safety wrapper |
| `SHELL_CONFIG_COMMAND_SAFETY` | `true` | Dangerous command blocking |
| `SHELL_CONFIG_WELCOME` | `true` | Welcome message on shell open |
| `SHELL_CONFIG_FZF` | `true` | FZF fuzzy finder integration |
| `SHELL_CONFIG_EZA` | `true` | Eza ls replacement |
| `SHELL_CONFIG_RIPGREP` | `true` | Ripgrep integration |
| `SHELL_CONFIG_AUTOCOMPLETE` | `true` | Shell autocomplete setup |
| `SHELL_CONFIG_GHLS` | `true` | GitHub List Status integration |
| `SHELL_CONFIG_1PASSWORD` | `false` | 1Password secrets loading |
| `SHELL_CONFIG_SECURITY` | `true` | Security hardening |

### Setting Feature Flags

**Temporarily (current session only):**
```bash
export SHELL_CONFIG_WELCOME=false
source ~/.zshrc
```

**Permanently (via environment variable):**
```bash
# Add to ~/.zshrc.local
export SHELL_CONFIG_WELCOME=false
export SHELL_CONFIG_GIT_WRAPPER=true
```

**Permanently (via YAML config):**
```yaml
# ~/.config/shell-config/config.yml
welcome_enabled: false
git_wrapper_enabled: true
```

**Permanently (via simple config):**
```bash
# ~/.config/shell-config/config
SHELL_CONFIG_WELCOME=false
SHELL_CONFIG_GIT_WRAPPER=true
```

---

## Debugging Initialization

### Enable Debug Timing

```bash
# Enable detailed timing output
export SHELL_CONFIG_DEBUG_TIMING=1
source ~/.zshrc
```

**Output:**
```
Shell-Config Initialization Time: 540ms
  Core loading: 50ms
  Feature modules: 350ms
  1Password secrets: 80ms
  ZSH compinit: 30ms
  PATH setup: 20ms
  Other: 10ms
```

### Check Loaded Features

```bash
# View startup time
echo $SHELL_CONFIG_START_TIME

# View platform info
echo $SHELL_CONFIG_PLATFORM
echo $SHELL_CONFIG_ARCH
echo $SHELL_CONFIG_SHELL

# View feature flags
env | grep SHELL_CONFIG_
```

### Debug Specific Module Loading

Create a debug script:

```bash
#!/usr/bin/env bash
# debug-init.sh - Debug initialization issues

# Enable bash debugging
set -x

# Source init.sh
source ~/.shell-config/init.sh

# Disable debugging
set +x

# Show loaded features
echo "=== Loaded Features ==="
validator_list
```

### Common Issues

**Issue: Slow startup (>1 second)**
```bash
# Check what's taking time
export SHELL_CONFIG_DEBUG_TIMING=1
source ~/.zshrc

# Disable non-essential features
export SHELL_CONFIG_WELCOME=false
export SHELL_CONFIG_GHLS=false
```

**Issue: Feature not loading**
```bash
# Check feature flag
env | grep SHELL_CONFIG_MY_FEATURE

# Check if file exists
ls -la ~/.shell-config/lib/my-feature.sh

# Check for syntax errors
bash -n ~/.shell-config/lib/my-feature.sh
```

**Issue: Configuration not applied**
```bash
# Check config priority (env > yaml > simple > default)
env | grep SHELL_CONFIG_  # Environment variables
cat ~/.config/shell-config/config.yml  # YAML
cat ~/.config/shell-config/config  # Simple
```

---

## Performance Profiling

### Using hyperfine

```bash
# Install hyperfine
brew install hyperfine

# Benchmark full initialization
hyperfine --warmup 3 "zsh -c 'source ~/.shell-config/init.sh'"

# Benchmark with specific features enabled
SHELL_CONFIG_WELCOME=false hyperfine "zsh -c 'source ~/.shell-config/init.sh'"
```

### Built-in Benchmark Script

```bash
# Quick smoke test
./tools/benchmarking/benchmark.sh quick

# Full startup analysis
./tools/benchmarking/benchmark.sh startup

# All benchmarks with JSON output
./tools/benchmarking/benchmark.sh all -o results/ -j
```

---

## Next Steps

- **[OVERVIEW.md](OVERVIEW.md)** - High-level architecture
- **[MODULES.md](MODULES.md)** - Module structure
- **[INTEGRATIONS.md](INTEGRATIONS.md)** - Integration layer

---

*For more information, see:*
- [README.md](../README.md) - User documentation
- [PERFORMANCE](../performance/METRICS.md) - Performance metrics
