# Hyperfine Quick Guide

A command-line benchmarking tool that provides statistical analysis across
multiple runs. [GitHub](https://github.com/sharkdp/hyperfine)

## Quick Start

```bash
# Basic benchmark
hyperfine 'sleep 0.1'

# With warmup runs (cache warming)
hyperfine --warmup 3 'my-command'

# Compare two commands
hyperfine 'fd pattern' 'find . -name pattern'

# Specify exact number of runs
hyperfine --runs 20 'my-command'
```

## Common Options

| Option | Description |
|--------|-------------|
| `-w, --warmup N` | Run N warmup iterations before benchmarking |
| `-r, --runs N` | Perform exactly N benchmarking runs |
| `-p, --prepare CMD` | Run CMD before each timing run (cache clearing) |
| `-c, --cleanup CMD` | Run CMD after each benchmark |
| `-N, --shell=none` | No shell (for fast commands <5ms) |
| `-S, --shell SHELL` | Use specific shell (zsh, bash, etc.) |

## Export Results

```bash
# Export to JSON
hyperfine --export-json results.json 'my-command'

# Export to Markdown table
hyperfine --export-markdown results.md 'cmd1' 'cmd2'

# Export to CSV
hyperfine --export-csv results.csv 'my-command'
```

## Parameterized Benchmarks

```bash
# Vary a numeric parameter
hyperfine --parameter-scan threads 1 8 'make -j {threads}'

# Custom step size
hyperfine --parameter-scan delay 0.1 1.0 -D 0.1 'sleep {delay}'

# List of values
hyperfine -L compiler gcc,clang '{compiler} -O2 main.c'
```

## Advanced Usage

```bash
# Cold cache benchmarks (Linux)
hyperfine --prepare 'sync; echo 3 | sudo tee /proc/sys/vm/drop_caches' 'grep -r TODO .'

# Benchmark shell functions
my_func() { echo "test"; }
export -f my_func
hyperfine --shell=bash my_func

# Fast commands (no shell overhead)
hyperfine -N 'echo test'

# Show output during runs
hyperfine --show-output 'ls -la'
```

## Output Explained

```
Benchmark 1: sleep 0.1
  Time (mean +/- σ):     106.0 ms +/-   1.0 ms    [User: 0.8 ms, System: 1.0 ms]
  Range (min ... max):   105.1 ms ... 107.1 ms    3 runs
```

- **mean +/- σ**: Average time with standard deviation
- **User**: CPU time in user mode
- **System**: CPU time in kernel mode  
- **Range**: Fastest and slowest runs
- **runs**: Number of benchmark iterations

## Why Hyperfine Over `time`?

| Feature | `time` | `hyperfine` |
|---------|--------|-------------|
| Multiple runs | No | Yes (auto or manual) |
| Statistical analysis | No | Mean, σ, min, max |
| Warmup runs | No | Yes |
| Outlier detection | No | Yes |
| Compare commands | No | Yes |
| Export results | No | JSON, Markdown, CSV |
| Shell startup correction | No | Yes |

## Tips

1. **Use warmup for disk I/O**: `hyperfine --warmup 3` warms filesystem caches
2. **Use `-N` for fast commands**: Avoids shell startup overhead noise
3. **Compare alternatives**: `hyperfine 'cmd1' 'cmd2' 'cmd3'`
4. **Export for CI**: `--export-json` for automated comparison
5. **Parameterize**: Test different configurations systematically

## Installation

```bash
brew install hyperfine  # macOS
apt install hyperfine   # Ubuntu/Debian
cargo install hyperfine # Rust/Cargo
```

## See Also

- [hyperfine GitHub](https://github.com/sharkdp/hyperfine)
- [Benchmarking scripts](https://github.com/sharkdp/hyperfine/tree/master/scripts)
