# Shell Config Tools

Standalone development and analysis utilities for the shell-config system.

These are **one-time use** scripts for debugging, analysis, and discovery - they
are not loaded by the shell configuration and don't run automatically.

## Available Tools

### benchmarking/

Complete performance benchmarking suite for shell-config. All benchmarking tools
are now organized in the `benchmarking/` subdirectory.

**Main Tool: `benchmarking/benchmark.sh`**

Uses hyperfine for accurate statistical analysis across multiple runs.

**Modes:**

| Mode | Description |
|------|-------------|
| `startup` | Shell initialization benchmarks (default) |
| `functions` | Detailed function-level benchmarks |
| `git` | Git operations and wrapper overhead |
| `validation` | File validation & pre-commit checks |
| `all` | Run all benchmark suites |
| `quick` | Fast smoke test (3 runs, minimal output) |

**Usage:**

```bash
# Quick smoke test
./benchmarking/benchmark.sh quick

# Full startup analysis
./benchmarking/benchmark.sh startup

# Function-level benchmarks
./benchmarking/benchmark.sh functions

# All benchmarks with CSV export
./benchmarking/benchmark.sh all -o results.csv

# Custom runs and warmup
./benchmarking/benchmark.sh startup --runs 10 --warmup 3
```

**What it measures:**

- **Startup**: Full init, minimal init, welcome message, feature flags
- **Functions**: Platform detection, colors, file ops, terminal status
- **Git**: Native vs wrapper commands, GHLS performance
- **Validation**: Shellcheck, actionlint, file validators

**Example Output:**

```
🚀 Shell-Config Benchmark
Mode: quick | Runs: 3 | Warmup: 1

═══ STARTUP BENCHMARKS - Quick ═══

  zsh (no config)                           1.4ms GREAT
  zsh -i (full)                           218.4ms OK
  welcome_message                         55.6ms MID

═══ BENCHMARK REPORT ═══

Summary:
  Total: 3 | GREAT: 1 | MID: 1 | OK: 1 | SLOW: 0

Results saved to: ./benchmark-results.csv
```

**Requirements:**

- `hyperfine` - Install with `brew install hyperfine`

**Related Files:**

- `benchmarking/README.md` - Complete documentation
- `benchmarking/PERFORMANCE-BENCHMARK-REPORT.md` - Current performance report
- `benchmarking/OPTIMIZATION.md` - Optimization guide
- `benchmarking/hyperfine-guide.md` - Hyperfine usage guide

---

### toolchain-scanner.sh

Scans repositories and system for packages, tools, and configurations. Analyzes
your toolchain to identify opportunities for automated validation and safety
rules.

**Two modes:**

1. **Default Mode** - Find tools with config validators (nginx -t, terraform
   validate, etc.) for setting up comprehensive git hooks
2. **Dangerous Mode** (`--dangerous-only`) - Focus on CLI tools with destructive
   actions for adding to command-safety rules

**Usage:**

```bash
# Find all tools needing config validation (for git hooks)
./toolchain-scanner.sh

# Focus on dangerous CLI tools (for command-safety rules)
./toolchain-scanner.sh --dangerous-only

# Include system-installed packages
./toolchain-scanner.sh --include-system

# Output formats
./toolchain-scanner.sh --format=json --output=report.json
./toolchain-scanner.sh --format=md --output=report.md
./toolchain-scanner.sh --format=txt

# Custom repos directory
./toolchain-scanner.sh --repos-dir=/path/to/repos

# Verbose output
./toolchain-scanner.sh --verbose
```

**Discovered Validators:**

| Category | Tools |
|----------|-------|
| Pre-commit (fast) | oxlint, eslint, ruff, shellcheck, yamllint, prettier, biome, hadolint, nginx -t, terraform validate, docker-compose config |
| Pre-push (heavy) | tsc, jest, vitest, pytest, cargo test, go test, terraform plan, mypy |
| Dangerous CLIs | prisma, drizzle-kit, supabase, vercel, wrangler, terraform, kubectl, docker, gh, git |

**Example Output:**

```bash
$ ./toolchain-scanner.sh --repos-dir=~/github

# Toolchain Scanner Report

## Summary
| Metric | Count |
|--------|-------|
| Total Validator Opportunities | 42 |
| Unique Tools | 15 |
| Repositories Scanned | 8 |

## Recommended Pre-Commit Validators
| Tool | Command | Repos Using |
|------|---------|-------------|
| `nginx` | `nginx -t` | my-web-project |
| `oxlint` | `oxlint` | app1, app2, app3 |
...
```

## Purpose

These tools help you:

1. **Discover validation opportunities** - Find tools in your projects that have
   config validators you should add to git hooks
2. **Audit command-safety coverage** - Identify dangerous CLI tools that need
   safety rules
3. **Plan git hook setup** - Get recommendations for pre-commit and pre-push
   hooks based on your tech stack

## Related

- `lib/command-safety/` - The command safety system these tools help audit
- `lib/validation/validators/core/syntax-validator.sh` - The syntax validator for git hooks
- `lib/git/hooks/pre-commit` - The pre-commit hook implementation
