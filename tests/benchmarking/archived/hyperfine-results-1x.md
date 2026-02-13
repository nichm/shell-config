| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `B: Original bash` | 31.9 ± 1.2 | 29.0 | 35.3 | 1.00 ± 0.07 |
| `D: Declarative helpers` | 40.0 ± 1.8 | 37.3 | 48.1 | 1.25 ± 0.09 |
| `E: Compact bash` | 45.6 ± 19.1 | 36.1 | 168.9 | 1.43 ± 0.60 |
| `F: Direct register` | 38.1 ± 3.5 | 33.8 | 54.9 | 1.19 ± 0.13 |
| `G-warm: Cached YAML (hit)` | 154.0 ± 10.1 | 141.1 | 192.5 | 4.83 ± 0.41 |
| `H: Heredoc tables` | 31.9 ± 1.7 | 29.7 | 39.0 | 1.00 |
| `A: YAML runtime` | 132.9 ± 8.8 | 125.1 | 181.0 | 4.17 ± 0.36 |
