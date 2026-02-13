# Rule Architecture Benchmark Archive

**Status: ARCHIVED** — These are benchmark artifacts from evaluating 8 different
approaches to command-safety rule definitions (Issue #80, Feb 2026).

The winner was **Readable Direct Registration** (`_rule` + `_fix` helpers), now
implemented in production at `lib/command-safety/engine/rule-helpers.sh`.

See `docs/YAML-RULES-BENCHMARK.md` for the full analysis and hyperfine results.

## Contents

| Directory | Option | Description |
|-----------|--------|-------------|
| `option-a/` | YAML Runtime | Single-call yq loader |
| `option-d/` | Declarative Helpers | Named params with intermediary vars |
| `option-e/` | Compact Bash | Single-letter helpers (`_R`, `_A`, `_V`) |
| `option-f/` | Direct Registration | Positional-arg compact format |
| `option-h/` | Heredoc Tables | Custom text format parsed by bash |
| `harnesses/` | - | Benchmark harness scripts for hyperfine |

## Hyperfine Results (Original Run)

- `hyperfine-results-1x.md` — 71 rules (production scale at time of test)
- `hyperfine-results-3x.md` — 213 rules (3x scale test)
- `convert-rules.py` — Python converter used to generate test variants
