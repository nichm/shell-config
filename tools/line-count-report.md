# Shell-Config Line Count Report

*Generated: 2026-02-03*

---

## Summary

| Category | Lines | Notes |
|----------|------:|-------|
| **Code Only** (excluding config/markdown) | 32,773 | Shell scripts + tests + hooks |
| **Code + Config** | 36,680 | Above + config/ + YAML/TOML/JSON |
| **Code + Markdown** | 50,121 | Code + documentation |
| **Everything** | 54,028 | All tracked files |

---

## Breakdown by Type

### Shell Code (*.sh, *.bats, hooks)

| Component | Lines |
|-----------|------:|
| lib/ (*.sh only) | 19,442 |
| tests/ (*.bats) | 8,957 |
| tools/ (*.sh) | 1,498 |
| Extensionless (bin, hooks) | 3,291 |
| **Total Shell Code** | **33,188** |

### Configuration Files

| Type | Lines |
|------|------:|
| config/ (bashrc, zshrc, etc.) | 186 |
| YAML/YML files | 3,907 |
| **Total Config** | **4,093** |

### Documentation

| Type | Lines |
|------|------:|
| Markdown (*.md) | 17,348 |

---

## lib/ Subdirectory Breakdown

| Module | Lines | % of lib/ |
|--------|------:|----------:|
| terminal/ | 4,355 | 22.4% |
| validation/ | 3,546 | 18.2% |
| git/ | 3,331 | 17.1% |
| command-safety/ | 3,226 | 16.6% |
| welcome/ | 1,015 | 5.2% |
| core/ | 986 | 5.1% |
| gha-security/ | 779 | 4.0% |
| 1password/ | 531 | 2.7% |
| integrations/ | 309 | 1.6% |
| ghls/ | 224 | 1.2% |
| core/ | 130 | 0.7% |
| phantom-guard/ | 119 | 0.6% |
| bin/ | ~400 | 2.1% |
| standalone (*.sh) | ~500 | 2.6% |

---

## Top 20 Largest Files

| File | Lines | Status |
|------|------:|--------|
| tools/toolchain-scanner.sh | 220 | OK (modularized into tools/toolchain-scanner/) |
| lib/validation/api.sh | 721 | ⚠️ OVER LIMIT |
| tests/welcome.bats | 692 | Test file OK |
| tests/bats/syntax_validator_enhanced.bats | 593 | Test file OK |
| lib/command-safety/engine/matcher.sh | 562 | ⚠️ Consider split |
| tests/bats/git_wrapper_integration.bats | 546 | Test file OK |
| tests/validation.bats | 544 | Test file OK |
| tests/op_secrets.bats | 541 | Test file OK |
| lib/terminal/installation/kitty.sh | 528 | ⚠️ Consider split |
| tests/git_wrapper.bats | 495 | Test file OK |
| tests/gha_security.bats | 484 | Test file OK |
| lib/validation/validators/infra-validator.sh | 479 | OK |
| tests/bats/op_secrets.bats | 459 | Test file OK |
| tests/git_hooks.bats | 456 | Test file OK |
| tools/benchmarking/benchmark.sh | 555 | OK |
| tests/git_syntax_enhanced.bats | 446 | Test file OK |
| lib/git/hooks/shared/validation-loop.sh | 444 | OK |
| tests/security_loaders.bats | 425 | Test file OK |
| lib/terminal/setup/setup-ubuntu-terminal.sh | 423 | OK |

### Files Over 600-Line Limit (Require Split)

1. `lib/validation/api.sh` - 721 lines

### Files Near Limit (500-600 lines)

1. `lib/command-safety/engine/matcher.sh` - 562 lines
2. `lib/terminal/installation/kitty.sh` - 528 lines

---

## File Count by Extension

| Extension | Count |
|-----------|------:|
| .sh | 130 |
| .md | 68 |
| .bats | 28 |
| .yml | 13 |
| .yaml | 5 |
| .txt | 5 |
| (no extension) | ~20 |
| Other | ~10 |

---

## Quick Reference

```bash
# Regenerate this report
cd ~/github/shell-config

# Code only (no markdown, no config)
find . -type f \( -name "*.sh" -o -name "*.bats" \) ! -path "./.git/*" | xargs wc -l | tail -1

# Check files over limit
wc -l lib/**/*.sh | awk '$1 > 500' | sort -rn

# By directory
for dir in lib tests tools; do 
  echo -n "$dir: "
  find ./$dir -name "*.sh" -o -name "*.bats" | xargs wc -l | tail -1
done
```
