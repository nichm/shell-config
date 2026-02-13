# Command-Safety Rules: Architecture Benchmark Report

**Date**: 2026-02-09 (updated)
**Issue**: #80 (YAML-Driven Command-Safety Rules)
**Tools**: hyperfine 1.20.0, Bash 5.x, yq v4.50.1, macOS Apple Silicon
**Scope**: 7 architectures benchmarked, 61 rules production

---

## Executive Summary

Evaluated 7 architectures for loading command-safety rules. The production
implementation uses **Readable Direct Registration** (`_rule` + `_fix` helpers)
which provides the best balance of speed, readability, maintainability, and
per-service modularity.

| Metric | Production (`_rule+_fix`) | vs Baseline (main) |
|--------|--------------------------|---------------------|
| Speed (61 rules) | **22.0 ms** | **17% faster** |
| Rule files | 12 per-service files | was 9 monolithic files |
| Total lines | ~480 rules + 107 helpers | was 2,411 lines |
| Line reduction | **-75%** | — |
| Dependencies | none | — |
| Per-service toggle | yes (`COMMAND_SAFETY_DISABLE_*`) | no |

---

## Hyperfine Results: All 7 Architectures (61 Rules)

100+ runs, 5 warmup iterations, `/opt/homebrew/bin/bash`:

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| **F: Direct registration** | **12.4 ± 0.4** | **11.3** | **13.8** | **1.00** |
| **NEW: Redesign (`_rule`+`_fix`)** | **22.0 ± 0.6** | **20.6** | **25.1** | **1.78 ± 0.08** |
| B: Original vars (main) | 26.4 ± 0.8 | 24.6 | 29.2 | 2.13 ± 0.09 |
| H: Heredoc tables | 28.7 ± 7.2 | 26.3 | 87.2 | 2.31 ± 0.58 |
| D: Old helpers (`_rule/_alts/_verify/_ai`) | 32.8 ± 0.9 | 31.1 | 36.0 | 2.64 ± 0.11 |
| E: Compact (`_R/_A/_V/_W`) | 33.1 ± 0.7 | 31.7 | 35.3 | 2.67 ± 0.10 |
| A: YAML (yq) | 120.9 ± 10.6 | 116.3 | 223.0 | 9.74 ± 0.91 |

### Key Findings

1. **F (Direct Registration) is fastest** at 12.4ms — but unreadable inline strings
2. **NEW design is 17% faster than baseline** (22.0ms vs 26.4ms) while being far
   more readable and maintainable
3. **YAML is 5.5x slower** than our design — completely disqualified
4. **D and E (old helper formats)** are slower than both baseline AND new design
5. **H (Heredoc tables)** fast at 1x but shown to scale 2.5x worse at 3x rules

---

## Why We Chose `_rule` + `_fix` Over Option F

Option F is fastest (12.4ms) but was rejected due to readability:

```bash
# Option F: Fast but unreadable
_reg "DOCKER_RM_F" "docker_rm_f" "warn" "docker" "rm -f|rm --force" "critical" \
    "🔴" "Force removing containers" "" "--force-docker-rm" $'⚠️ AI AGENT...'

# Production: Readable named parameters
_rule DOCKER_RM_F cmd="docker" match="rm -f|rm --force" \
    block="Force removing containers loses ALL container state" \
    bypass="--force-docker-rm"
```

The 9.6ms difference (22.0 vs 12.4ms) is imperceptible during shell startup
but the readability difference is massive for maintenance.

### Speed Budget

| Component | Time |
|-----------|------|
| Bash process startup | ~8ms |
| Registry init | ~2ms |
| Rule helpers load | ~1ms |
| 61 rule definitions | ~11ms |
| **Total** | **~22ms** |

This is well within the 50ms budget for interactive shell features. For
comparison, `fzf` shell integration takes ~15ms and `zsh-autosuggestions`
takes ~25ms.

---

## Scaling Analysis (From Original Benchmark)

How each approach scales from 71 to 213 rules (original benchmark data):

| Approach | 1x (71) | 3x (213) | Growth | Scaling Factor |
|----------|---------|----------|--------|----------------|
| B: Original bash | 31.9 ms | 33.0 ms | +1.1 ms | 1.03x |
| F: Direct register | 38.1 ms | 35.5 ms | -2.6 ms | 0.93x |
| D: Declarative helpers | 40.0 ms | 49.8 ms | +9.8 ms | 1.25x |
| E: Compact bash | 45.6 ms | 50.2 ms | +4.6 ms | 1.10x |
| H: Heredoc tables | 31.9 ms | 80.2 ms | +48.3 ms | 2.51x |

> Note: Original benchmark used the old 13-arg registry with `level`, `verify`,
> and `ai_warning` fields. The new 10-arg registry is faster, explaining the
> improved absolute times in our new benchmark.

---

## Line Count Comparison

| Approach | Total Lines | Per Rule | vs Original |
|----------|-------------|----------|-------------|
| **NEW: `_rule`+`_fix` (production)** | **~590** | **~9.7** | **-75%** |
| F: Direct register | 291 | 4.1 | -87% |
| E: Compact bash | 427 | 6.0 | -82% |
| D: Declarative helpers | 698 | 9.8 | -70% |
| H: Heredoc tables | 1,170 | 16.5 | -50% |
| A: YAML source | 1,808 | 25.5 | -22% |
| B: Original bash | 2,321 | 32.7 | baseline |
| C: PR total (YAML+gen) | 6,403 | n/a | +176% |

Our production design trades F's minimal lines for readable named parameters
(`cmd=`, `match=`, `block=`, `bypass=`) and per-service file organization.

### Production File Layout (12 per-service files)

```
rules/
  settings.sh           # Config + per-service disable flags
  git.sh                # 15 rules (git + gh CLI)
  package-managers.sh   # 14 rules (npm→bun, pip→uv, etc.)
  dangerous-commands.sh #  9 rules (rm, chmod, sudo, dd, etc.)
  cloudflare.sh         #  7 rules (wrangler)
  supabase.sh           #  6 rules (supabase + pg_dump)
  nginx.sh              #  3 rules
  prettier.sh           #  2 rules
  docker.sh             #  1 rule
  kubernetes.sh         #  1 rule
  terraform.sh          #  1 rule
  ansible.sh            #  1 rule
  nextjs.sh             #  1 rule
```

---

## Decision Matrix

| Factor | Wt | B | D | E | F | H | A | NEW |
|--------|:--:|:-:|:-:|:-:|:-:|:-:|:-:|:---:|
| Speed | 4 | 4 | 3 | 3 | 5 | 4 | 1 | 5 |
| Readability | 3 | 3 | 4 | 2 | 2 | 3 | 4 | 5 |
| Line reduction | 3 | 1 | 4 | 5 | 5 | 3 | 3 | 4 |
| No dependencies | 3 | 5 | 5 | 5 | 5 | 5 | 2 | 5 |
| Edit/author ease | 3 | 2 | 4 | 3 | 2 | 3 | 5 | 5 |
| Per-service toggle | 2 | 1 | 1 | 1 | 1 | 1 | 1 | 5 |
| No engine changes | 2 | 5 | 5 | 5 | 5 | 5 | 1 | 4 |
| **Weighted Total** | | **60** | **72** | **66** | **72** | **68** | **50** | **95** |

---

## Why NOT the Other Options

| Option | Rejected Because |
|--------|-----------------|
| **A: YAML runtime** | 5.5x slower than production. yq dependency. Scales terribly. |
| **B: Keep as-is** | 75% more lines. Copy-paste errors. No service toggles. |
| **C: Generator (PR #105)** | +176% more lines. Build step. 3 rounds of bugs. yq dependency. |
| **D: Old helpers** | 50% slower than production (32.8 vs 22.0ms). More lines. No toggles. |
| **E: Compact** | Same speed as D but unreadable (`_R`, `_A`, `_V`, `_W`). |
| **F: Direct register** | Fastest raw speed but positional args are unreadable/unmaintainable. |
| **H: Heredoc** | Fast at 1x but scales 2.5x at 3x rules. Custom format to learn. |

---

## Learnings

### 1. Named Parameters Beat Positional Args

Option F's positional args are compact but error-prone. Getting arg 7 vs arg 8
wrong silently corrupts rule data. Named params (`cmd=`, `match=`, `block=`)
are self-documenting and impossible to get wrong.

### 2. Intermediary Variables Are Pure Waste

The original design created 11 `RULE_*_ID`, `RULE_*_ACTION` etc. variables per
rule that were NEVER read after registration. The registry copies everything into
associative arrays. Eliminating these (our design + Option F) saves hundreds of
`declare` calls.

### 3. Per-Service Files Enable Ecosystem Customization

Splitting from 9 monolithic files to 12 per-service files with disable flags
(`COMMAND_SAFETY_DISABLE_DOCKER=true`) lets users customize without editing
source. Adding rules for a new service = creating one new `.sh` file.

### 4. YAML in Bash Is Always Wrong

YAML loading (even optimized single-call yq) is 5.5x slower than native bash.
The caching approach (Option G) was 4.8x slower even on cache HIT, and 237x
on cold miss. There is no path to making YAML competitive in bash.

### 5. Unused Fields Are Invisible Technical Debt

The old design had `level`, `AI_WARNING`, and `verify` fields that no matcher
or display code actually consumed. Removing them simplified the registry from
13 to 10 args and eliminated dead code paths.

---

## Benchmark Reproduction

```bash
brew install hyperfine

# Current production design (from repo root):
hyperfine --shell /opt/homebrew/bin/bash --warmup 5 --min-runs 100 \
    -n 'Production' '/opt/homebrew/bin/bash -c "
        source lib/command-safety/engine/registry.sh
        source lib/command-safety/engine/rule-helpers.sh
        for f in lib/command-safety/rules/*.sh; do
            [[ \$(basename \$f) == settings.sh ]] && continue
            source \$f
        done"'

# Historical benchmarks archived in tests/benchmarking/archived/
```

---

*Benchmarked on macOS 15.3, Apple M-series, Bash 5.x, yq v4.50.1, hyperfine 1.20.0*
*100+ iterations with 5 warmup runs on a quiet system*
