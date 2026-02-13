# Shell-Config Benchmarking Suite

This directory contains all performance benchmarking tools and utilities for the shell-config project.

## Overview

The benchmarking suite provides comprehensive performance analysis using hyperfine for statistical accuracy. It includes tools for measuring startup time, function performance, git wrapper overhead, and validation operations.

## Files

| File | Description |
|------|-------------|
| `benchmark.sh` | Main benchmarking tool with hyperfine integration |
| `benchmark-validator.sh` | Performance validation utilities |
| `benchmarking-rules.sh` | Command safety rules for benchmarking commands |
| `benchmark-hook.sh` | Git hook benchmarking utilities |
| `PERFORMANCE-BENCHMARK-REPORT.md` | Current performance report |
| `OPTIMIZATION.md` | Performance optimization guide |
| `METRICS.md` | Performance metrics documentation |
| `hyperfine-guide.md` | Hyperfine usage guide |

## Usage

### Quick Benchmark
```bash
./benchmark.sh quick
```

### Full Benchmark Suite
```bash
./benchmark.sh all
```

### Specific Categories
```bash
./benchmark.sh startup      # Shell startup performance
./benchmark.sh functions    # Function-level benchmarks
./benchmark.sh git         # Git wrapper overhead
./benchmark.sh validation  # File validation performance
```

### Export Results
```bash
./benchmark.sh all -o results.csv
```

## Dependencies

- **hyperfine**: Required for all benchmarks
- **zsh**: Target shell for benchmarks (bash 5.x compatible)
- **Optional**: actionlint, zizmor for GitHub Actions validation

## Performance Thresholds

| Rating | Function-Level | Real-World |
|--------|----------------|------------|
| GREAT  | < 5ms         | < 50ms     |
| MID    | < 20ms        | < 150ms    |
| OK     | < 50ms        | < 500ms    |
| SLOW   | ≥ 50ms        | ≥ 500ms    |

## Integration

The benchmarking tools are integrated throughout the shell-config system:

- **Command Safety**: Rules in `benchmarking-rules.sh` guide users to use hyperfine
- **Git Hooks**: `benchmark-hook.sh` provides timing utilities for pre-commit hooks
- **Validators**: `benchmark-validator.sh` validates performance in CI/CD pipelines

## Contributing

When adding new benchmarks:

1. Add the benchmark function to `benchmark.sh`
2. Update the appropriate benchmark category
3. Run `./benchmark.sh all` to verify
4. Update performance reports as needed

## See Also

- [Hyperfine Documentation](https://github.com/sharkdp/hyperfine)
- [Performance Optimization Guide](OPTIMIZATION.md)
- [Shell-Config Main README](../../../README.md)