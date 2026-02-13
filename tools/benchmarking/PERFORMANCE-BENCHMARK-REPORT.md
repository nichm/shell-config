# Shell-Config Performance Benchmark Report

**Date:** 2026-02-03  
**Shell:** zsh 5.9  
**System:** macOS (darwin 25.2.0)  
**Tool:** hyperfine (3 warmup, 8-10 measured runs per test)

---

## Executive Summary

| Metric | Value | Rating |
|--------|-------|--------|
| **Full Shell Startup** | 218.4ms | OK |
| **init.sh Load Time** | 194.2ms | OK |
| **Raw zsh (no config)** | 1.4ms | GREAT |
| **Config Overhead** | ~217ms | Focus Area |
| **Git Wrapper Overhead** | ~7ms | GREAT |
| **Welcome Message** | 55.6ms | MID |

**Overall Assessment:** Shell-config adds approximately **217ms** to shell startup. Most individual functions are highly optimized (< 5ms), but the welcome system and sourcing chain account for the bulk of startup time.

---

## Rating Thresholds

| Rating | Function-Level | Real-World |
|--------|---------------|------------|
| **GREAT** | < 5ms | < 50ms |
| **MID** | < 20ms | < 150ms |
| **OK** | < 50ms | < 500ms |
| **SLOW** | ≥ 50ms | ≥ 500ms |

---

## Detailed Results by Category

### 🚀 Shell Startup (Critical)

| Operation | Time (ms) | Rating | Impact |
|-----------|-----------|--------|--------|
| zsh (no config) | 1.4 | GREAT | Baseline |
| zsh -i (full startup) | 218.4 | OK | Every new shell |
| source init.sh only | 194.2 | OK | Core overhead |

**Analysis:** The 217ms overhead is noticeable but acceptable. The bulk comes from:

- Welcome message generation (~56ms)
- Tool detection and lazy loading setup
- Git wrapper initialization

### 👋 Welcome Message System (High Impact)

| Function | Time (ms) | Rating | Notes |
|----------|-----------|--------|-------|
| welcome_message (full) | 55.6 | MID | Complete render |
| _welcome_detect_style | 34.8 | OK | Style detection |
| _welcome_is_git_repo | 34.2 | OK | Git repo check |
| _welcome_get_python_version | 30.6 | OK | External cmd |
| _welcome_get_repo_name | 30.5 | OK | Git query |
| _welcome_get_node_version | 30.2 | OK | External cmd |
| _welcome_get_git_branch | 29.9 | OK | Git query |
| _welcome_get_git_status | 29.9 | OK | Git query |
| _welcome_init_cache | 28.4 | OK | Cache setup |
| source main.sh (welcome) | 28.8 | OK | Initial source |

**Root Cause:** Each function includes the full dependency sourcing overhead (~28ms), not just the function execution itself.

### 🔧 Git Operations (Per-Command)

| Operation | Time (ms) | Rating | Wrapper Overhead |
|-----------|-----------|--------|------------------|
| git status (native) | 10.2 | GREAT | baseline |
| git status (wrapper) | 17.2 | GREAT | +7ms |
| git branch (native) | 5.8 | GREAT | baseline |
| git branch (wrapper) | 11.8 | GREAT | +6ms |
| git log -5 | 6.7 | GREAT | - |
| git diff --stat | 7.1 | GREAT | - |
| git_statusline | 6.2 | MID | optimized |

**Analysis:** The git wrapper adds ~6-7ms overhead per command for safety checks. This is acceptable given the security benefits (secrets scanning, dangerous command prevention).

### ⚡ Command Lookup Patterns (100x iterations)

| Pattern | Time (ms) | Per-Call (µs) | Recommendation |
|---------|-----------|---------------|----------------|
| `(($+commands[]))` | 1.5 | 15 | **Best for zsh** |
| `whence -p` | 2.3 | 23 | Good |
| `which` | 2.3 | 23 | Avoid (external) |
| `type` | 2.4 | 24 | Good |
| `command -v` | 2.5 | 25 | **Best for POSIX** |

**Recommendation:** Use `(($+commands[cmd]))` for zsh scripts, `command -v` for POSIX compatibility.

### 📄 File Sourcing

| Operation | Time (ms) | Rating |
|-----------|-----------|--------|
| source colors.sh | 0.4 | GREAT |
| source platform.sh | 0.2 | GREAT |
| source file-operations.sh | 0.2 | GREAT |
| source reporters.sh | 0.2 | GREAT |
| source config.sh | 0.2 | GREAT |
| source 3 common libs | 0.5 | GREAT |
| source validation stack | 0.8 | GREAT |
| source welcome stack | 29.7 | OK |

**Analysis:** Individual source operations are fast. The welcome stack is slow because it includes subprocess calls (node/python version detection).

### ✅ Validators (Pre-commit)

| Validator | Time (ms) | Rating |
|-----------|-----------|--------|
| shellcheck (1 file) | 31.2 | GREAT |
| shellcheck (5 files) | 44.0 | GREAT |
| actionlint (1 workflow) | 42.9 | GREAT |
| actionlint (all workflows) | 143.9 | MID |
| zizmor (1 workflow) | 24.4 | GREAT |
| validate_file_length | 3.0 | GREAT |
| validate_sensitive_filename | 3.0 | GREAT |
| security_validator | 5.4 | GREAT |

### 🔍 Terminal Status Checks

| Check | Time (ms) | Rating |
|-------|-----------|--------|
| _ts_check_1password | 0.3 | GREAT |
| _ts_check_ssh | 0.3 | GREAT |
| _ts_check_safe_rm | 0.3 | GREAT |
| _ts_check_git_wrapper | 0.3 | GREAT |
| _ts_check_eza | 0.4 | GREAT |
| _ts_check_fzf | 0.3 | GREAT |
| _ts_check_hyperfine | 0.3 | GREAT |
| _ts_count_aliases | 0.2 | GREAT |
| _ts_format_check | 0.2 | GREAT |

**Analysis:** All terminal status checks are highly optimized at ~0.3ms each.

### 🔧 External Tools

| Tool | Time (ms) | Rating |
|------|-----------|--------|
| eza (basic) | 3.4 | GREAT |
| eza (git status) | 3.5 | GREAT |
| eza (tree) | 3.9 | GREAT |
| fzf --version | 2.1 | GREAT |
| node --version | 17.6 | GREAT |
| python3 --version | 5.2 | GREAT |

---

## Category Summary

| Category | Avg Time (ms) | Test Count | Rating |
|----------|---------------|------------|--------|
| baseline | 0.10 | 10 | GREAT |
| cmd-check | 0.18 | 8 | GREAT |
| colors | 0.04 | 5 | GREAT |
| config | 0.31 | 2 | GREAT |
| terminal-status | 0.28 | 11 | GREAT |
| file-ops | 1.16 | 11 | GREAT |
| validation | 1.75 | 3 | GREAT |
| syntax | 1.34 | 4 | GREAT |
| file-validator | 1.49 | 5 | GREAT |
| security | 2.49 | 5 | GREAT |
| workflow | 1.18 | 5 | GREAT |
| doctor | 2.88 | 3 | GREAT |
| reporters | 0.29 | 5 | GREAT |
| platform | 0.49 | 10 | GREAT |
| source | 4.99 | 6 | MID |
| infra | 5.78 | 4 | MID |
| git | 6.33 | 5 | MID |
| ghls | 6.07 | 1 | MID |
| **welcome** | **30.84** | 11 | **OK** |
| **startup** | **138.0** | 3 | **MID** |

---

## Simple Optimization Recommendations

### 1. Welcome Message Optimization (Potential: -50ms)

**Current:** Each `_welcome_*` function re-sources dependencies (~28ms overhead each)

**Simple Fix:** Move dependency sourcing to the top of `welcome_message()` once:

```bash
# BEFORE (in each function):
_welcome_get_git_branch() {
    # This includes ~28ms of sourcing overhead
    git branch --show-current 2>/dev/null
}

# AFTER (at top of welcome_message):
welcome_message() {
    # Source once, use throughout
    local git_branch=$(git branch --show-current 2>/dev/null)
    local git_status=$(git status --porcelain 2>/dev/null)
    # ... use variables directly
}
```

### 2. Batch Git Queries (Potential: -20ms)

**Current:** Multiple separate git calls (5-10ms each)

**Simple Fix:** Combine into single batch:

```bash
# BEFORE:
local branch=$(git branch --show-current)
local status=$(git status --porcelain)
local is_git=$(git rev-parse --is-inside-work-tree)

# AFTER:
local git_info
git_info=$(git rev-parse --show-toplevel --is-inside-work-tree 2>/dev/null && \
           git branch --show-current && \
           git status --porcelain | head -5)
```

### 3. Use Fastest Command Lookup

**Instead of:**

```bash
command -v tool >/dev/null 2>&1
```

**Use (zsh only):**

```bash
(( $+commands[tool] ))
```

This is ~40% faster (15µs vs 25µs per lookup). Over 100+ lookups during startup, this saves ~1ms.

### 4. Defer Non-Essential Loading

Move rarely-used features to lazy loading:

```bash
# Instead of sourcing at startup:
source lib/bin/gha-scan

# Load on first use:
gha_scan() {
    [[ -z "$_GHA_LOADED" ]] && source "$SHELL_CONFIG_DIR/lib/bin/gha-scan"
    _GHA_LOADED=1
    _gha_scan "$@"
}
```

### 5. Skip Version Detection When Not Needed

**Current:** Always detect node/python versions

**Simple Fix:** Only when in a project:

```bash
_welcome_get_node_version() {
    # Skip if no package.json nearby
    [[ ! -f package.json && ! -f ../package.json ]] && return
    node --version 2>/dev/null
}
```

---

## Performance Targets

| Metric | Current | Target | Priority |
|--------|---------|--------|----------|
| Full Startup | 218ms | <150ms | High |
| Welcome Message | 56ms | <30ms | Medium |
| Git Wrapper Overhead | 7ms | <10ms | ✅ Met |
| Individual Functions | <5ms | <5ms | ✅ Met |

---

## Conclusion

**Strengths:**

- Individual functions are highly optimized (97% under 5ms)
- Terminal status checks are excellent (~0.3ms each)
- Git wrapper overhead is minimal (~7ms)
- File operations are fast (~1-3ms)
- Validators are efficient for external tools

**Focus Areas:**

1. **Welcome message system** - Accounts for ~56ms of startup
2. **init.sh sourcing chain** - ~194ms total
3. **Version detection** - node/python add ~23ms combined

**No Complex Changes Needed:**

- No caching systems required
- No database or file-based caching
- No architectural changes
- Just consolidate git queries and reduce redundant sourcing

---

## Running Benchmarks

Single unified benchmark tool with multiple modes:

```bash
cd shell-config

# Quick smoke test (fast)
./tools/benchmarking/benchmark.sh quick

# Shell startup & welcome message
./tools/benchmarking/benchmark.sh startup

# Detailed function-level analysis
./tools/benchmarking/benchmark.sh functions

# Git operations & wrapper overhead
./tools/benchmarking/benchmark.sh git

# Validation & pre-commit checks
./tools/benchmarking/benchmark.sh validation

# Run everything
./tools/benchmarking/benchmark.sh all

# Options
./tools/benchmarking/benchmark.sh startup -r 10    # 10 runs per test
./tools/benchmarking/benchmark.sh all -o out.csv   # Export to specific file
./tools/benchmarking/benchmark.sh all -q           # Quiet mode
```

Results saved to: `tools/benchmarking/benchmark-results.csv`
