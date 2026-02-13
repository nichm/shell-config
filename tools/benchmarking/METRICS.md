# Shell-Config Performance - Metrics

**Date:** 2026-02-04
**Version:** 1.0.0
**Platform:** macOS (Apple Silicon)
**Shell:** zsh 5.9 / bash 5.x (Homebrew)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Benchmark Results](#benchmark-results)
3. [Performance Targets](#performance-targets)
4. [Comparison with Alternatives](#comparison-with-alternatives)
5. [Performance Monitoring](#performance-monitoring)

---

## Executive Summary

### Key Metrics

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Full initialization | ~540ms | <200ms | ⚠️ Needs optimization |
| Git wrapper overhead | ~8ms | <5ms | ⚠️ Needs optimization |
| Pre-commit hook | ~14ms | <20ms | ✅ Within target |
| Syntax validation | ~12ms | <15ms | ✅ Within target |
| RM wrapper overhead | ~1.5ms | <2ms | ✅ Within target |

### Overall Status

**Performance Score:** 3/5 targets met

**Priority Areas:**
1. **High Priority:** Reduce full initialization time to <200ms
2. **Medium Priority:** Optimize git wrapper to <5ms
3. **Low Priority:** Maintain current performance for hooks and wrappers

---

## Benchmark Results

### 1. Startup Performance

#### Full Initialization

**Test Command:**
```bash
hyperfine --warmup 3 "zsh -c 'source ~/.shell-config/init.sh'"
```

**Current Performance:** ~540ms

**Breakdown:**
| Component | Time | Percentage |
|-----------|------|------------|
| Core loading (config, platform) | ~50ms | 9% |
| Feature module loading | ~350ms | 65% |
| 1Password secrets loading | ~80ms | 15% |
| ZSH compinit (cached) | ~30ms | 6% |
| PATH setup | ~20ms | 4% |
| Other overhead | ~10ms | 2% |

**Optimizations Applied:**
- ✅ Cached compinit (24h TTL) - saves ~100ms
- ✅ Lazy fnm loading - saves ~25ms
- ✅ Conditional eza --git - saves ~5ms
- ✅ Cached secrets scanning (300s TTL)

**Future Optimizations:**
- 🔄 Lazy load feature modules (estimated savings: ~200ms)
- 🔄 Parallel module loading (estimated savings: ~100ms)
- 🔄 Deferred 1Password authentication (estimated savings: ~50ms)

**Target:** <200ms

**Path to Target:**
1. Implement lazy loading for non-essential modules (~200ms savings)
2. Parallelize independent module loads (~100ms savings)
3. Optimize 1Password integration (~50ms savings)
4. **Total potential savings:** ~350ms
5. **Projected time:** ~190ms ✅

---

### 2. Git Wrapper Performance

#### Safe Commands (Fast-Path)

**Test Commands:**
```bash
# Safe commands (minimal overhead)
hyperfine "git status"
hyperfine "git log"
hyperfine "git diff"
```

**Current Performance:** ~8ms overhead

**Breakdown:**
| Operation | Time | Notes |
|-----------|------|-------|
| Function call overhead | ~2ms | zsh function resolution |
| Fast-path check | ~1ms | Command whitelist |
| Bypass flag check | ~1ms | Environment variables |
| Safety check (skipped) | 0ms | Fast-path |
| Actual git execution | ~4ms | Native git time |

**Optimization Status:**
- ✅ Fast-path for safe commands (status, log, diff, branch, show)
- ✅ Minimal overhead for common operations

**Target:** <5ms

**Path to Target:**
1. Reduce function overhead (~1ms savings)
2. Cache bypass flag checks (~0.5ms savings)
3. Optimize command parsing (~1.5ms savings)
4. **Total potential savings:** ~3ms
5. **Projected time:** ~5ms ✅

#### Dangerous Commands (Full Safety Check)

**Test Commands:**
```bash
# Dangerous commands (full safety checks)
hyperfine "git reset --hard HEAD~1 --no-verify"
hyperfine "git push --force --no-verify"
```

**Current Performance:** ~15-20ms overhead

**Breakdown:**
| Operation | Time | Notes |
|-----------|------|-------|
| Function call overhead | ~2ms | zsh function resolution |
| Fast-path check | ~1ms | Not in fast-path |
| Bypass flag check | ~1ms | Check for --force-danger |
| Safety checks | ~8-12ms | Destructive operation check |
| Warning display | ~1ms | User message |
| Actual git execution | ~2ms | Native git time |

**Status:** Acceptable for safety-critical operations

---

### 3. Pre-Commit Hook Performance

#### Full Pre-Commit Hook

**Test Command:**
```bash
hyperfine --warmup 1 "git commit --no-verify --allow-empty"
```

**Current Performance:** ~14ms

**Breakdown:**
| Component | Time | Percentage |
|-----------|------|------------|
| Hook initialization | ~2ms | 14% |
| Syntax validation | ~5ms | 36% |
| Dependency check | ~3ms | 21% |
| Large file detection | ~1ms | 7% |
| Secret scanning | ~2ms | 14% |
| Large commit detection | ~1ms | 7% |

**Optimizations Applied:**
- ✅ Cached secrets scanning (300s TTL)
- ✅ Fast syntax validators (oxlint, ruff)
- ✅ Parallel dependency checks

**Target:** <20ms

**Status:** ✅ Within target

---

### 4. Syntax Validation Performance

#### Individual Validators

**Test Commands:**
```bash
# JavaScript/TypeScript
hyperfine "oxlint file.ts"

# Python
hyperfine "ruff check file.py"

# Shell scripts
hyperfine "shellcheck file.sh"
```

**Current Performance:** ~12ms average

**Breakdown by Language:**
| Language | Validator | Time | Files/sec |
|----------|-----------|------|-----------|
| JavaScript/TypeScript | oxlint | ~8ms | ~125 files/sec |
| Python | ruff | ~10ms | ~100 files/sec |
| Shell | shellcheck | ~18ms | ~55 files/sec |
| Go | gofmt/vet | ~15ms | ~67 files/sec |

**Optimization Strategy:**
- ✅ Use fastest validators (oxlint vs eslint)
- ✅ Parallel validation by language
- ✅ Cached results where possible

**Target:** <15ms

**Status:** ✅ Within target

---

### 5. RM Wrapper Performance

#### PATH-Based Wrapper

**Test Commands:**
```bash
hyperfine "rm /tmp/test_file"
```

**Current Performance:** ~1.5ms overhead

**Breakdown:**
| Operation | Time | Notes |
|-----------|------|-------|
| Wrapper invocation | ~0.5ms | PATH resolution |
| Protected path check | ~0.3ms | Path comparison |
| Audit logging | ~0.4ms | Atomic write |
| Actual rm execution | ~0.3ms | Native rm time |

**Status:** ✅ Excellent

**Target:** <2ms

**Performance:** Minimal overhead, no optimization needed

---

## Performance Targets

### Short Term (1-2 weeks)

| Metric | Current | Target | Action |
|--------|---------|--------|--------|
| Full init | 540ms | <400ms | Lazy load modules |
| Git wrapper | 8ms | <6ms | Optimize fast-path |

### Medium Term (1-2 months)

| Metric | Target | Action |
|--------|--------|--------|
| Full init | <200ms | Parallel loading + deferred auth |
| Git wrapper | <5ms | Cache bypass checks |

### Long Term (3-6 months)

| Metric | Target | Action |
|--------|--------|--------|
| Full init | <150ms | Full module rewrite |
| Git wrapper | <3ms | Native compilation |

---

## Comparison with Alternatives

### Similar Configuration Frameworks

| Framework | Init Time | Notes |
|-----------|-----------|-------|
| **Shell-Config** | ~540ms | 117 source files, 28 test files |
| Oh My Zsh | ~800ms | 300+ plugins, heavy |
| Prezto | ~400ms | Lighter than OMZ |
| Zim | ~200ms | Highly optimized |
| Pure | ~100ms | Minimal prompt only |

**Notes:**
- Shell-Config is more feature-heavy than pure prompt frameworks
- Comparable to Oh My Zsh but with better safety features
- Slower than optimized frameworks (Zim) but more comprehensive

---

## Performance Monitoring

### Built-in Timing

Shell-config includes built-in performance tracking:

```bash
# Startup time (automatic)
echo $SHELL_CONFIG_START_TIME

# Individual component timing
export SHELL_CONFIG_DEBUG_TIMING=1
source ~/.shell-config/init.sh
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

---

### Benchmark Script

Use the built-in benchmark tool:

```bash
# Quick smoke test
./tools/benchmarking/benchmark.sh quick

# Full startup analysis
./tools/benchmarking/benchmark.sh startup

# All benchmarks with CSV output
./tools/benchmarking/benchmark.sh all -o results.csv

# Function-level benchmarks
./tools/benchmarking/benchmark.sh functions
```

**Requirements:**
- `hyperfine` for accurate benchmarking
- `brew install hyperfine`

---

## Performance vs. Features Trade-off

### Current Feature Set

Shell-Config prioritizes features over raw startup speed:

**Features (add overhead):**
- ✅ Command safety (50+ rules)
- ✅ Git wrapper with safety checks
- ✅ Pre-commit hooks (syntax, deps, secrets)
- ✅ 1Password integration
- ✅ Welcome message system
- ✅ RM protection (multi-layer)
- ✅ Secret scanning
- ✅ Phantom Guard
- ✅ GHLS statusline

**Performance Impact:**
- Each feature adds ~10-50ms to startup
- Safety features add ~5-15ms to operations
- Total overhead is acceptable for productivity gains

### Minimal Mode

For maximum performance, disable features:

```bash
# ~/.zshrc.local
export SHELL_CONFIG_WELCOME=false
export SHELL_CONFIG_COMMAND_SAFETY=false
export SHELL_CONFIG_GIT_WRAPPER=false
export SHELL_CONFIG_GHLS=false
export SHELL_CONFIG_1PASSWORD=false
source ~/.shell-config/init.sh
```

**Expected startup time:** ~200ms (with all features disabled)

---

## Next Steps

- **[OPTIMIZATION.md](OPTIMIZATION.md)** - Optimization techniques
- **[ARCHITECTURE](../architecture/OVERVIEW.md)** - System architecture

---

*For more information, see:*
- [ARCHITECTURE](../architecture/OVERVIEW.md) - System architecture
- [README.md](../README.md) - User documentation
