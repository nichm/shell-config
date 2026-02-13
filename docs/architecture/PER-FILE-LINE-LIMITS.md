# Per-File Line Length Limits

Language-specific file length validation with a three-tier blocking system.

## Three-Tier System

| Tier | Threshold | Behavior |
|------|-----------|----------|
| **INFO** | 60% of limit | Warning only, doesn't block |
| **WARNING** | 75% of limit | Blocks, bypass available |
| **EXTREME** | 100% of limit | Blocks, requires GitHub issue |

**Bypass:** `GIT_SKIP_FILE_LENGTH_CHECK=1 git commit -m "message"`

## Language Limits

| Category | Languages | Limit |
|----------|-----------|-------|
| **Systems** | Rust, Go, C, C++ | 1500 lines |
| **Web** | TypeScript, JavaScript, Vue, PHP | 800 lines |
| **Application** | Python, Ruby, Swift, Java, C# | 700-800 lines |
| **Shell** | Bash, Zsh, Fish | 600 lines |
| **Data** | JSON, YAML, Markdown | 5000 lines |

### Extensions Reference

```
Systems (1500): .rs, .go, .c, .cpp, .cc, .h, .hpp
Web (800): .ts, .tsx, .js, .jsx, .vue, .svelte, .php
Application (800): .py, .rb, .swift, .java, .cs, .scala, .kt
Shell (600): .sh, .bash, .zsh, .fish
Data (5000): .json, .yaml, .yml, .toml, .md, .csv
```

## Special Files

```
Dockerfile, Makefile, CMakeLists.txt: 2000 lines
Lock files (package-lock, yarn.lock, etc.): 5000 lines
.gitignore: 5000 lines
```

## Usage

### Normal Flow

```bash
git add my-component.tsx
git commit -m "Add feature"
# Blocked if exceeds WARNING/EXTREME threshold
```

### Bypass (WARNING tier)

```bash
GIT_SKIP_FILE_LENGTH_CHECK=1 git commit -m "message"
```

### Bypass (EXTREME tier)

```bash
# Create GitHub issue first
gh issue create --title "Tech Debt: Large file" --label "technical-debt"
# Then bypass
GIT_SKIP_FILE_LENGTH_CHECK=1 git commit -m "message"
```

## Example Output

**WARNING:**

```
⚠️ components/UserProfile.tsx (610 lines / 800 limit = 76%)
Consider breaking into smaller modules.
💡 Bypass: GIT_SKIP_FILE_LENGTH_CHECK=1 git commit -m 'message'
```

**EXTREME:**

```
❌ components/UserProfile.tsx (850 lines / 800 limit = 6% over)
⚠️ Create a GitHub issue documenting this technical debt first
```

## Technical Details

- **O(n) single-pass** using `wc -l`
- **Only staged files** analyzed (not entire repo)
- **Early optimization**: Skips files < 300 lines
- Runs as step 5 in pre-commit hook

## When to Bypass

**OK to bypass:**

- Generated code, migrations
- Data files legitimately large
- External libraries being vendored

**Don't bypass:**

- Application code you're developing
- Components you own and maintain

## When to Refactor

- File exceeds WARNING tier (75%)
- Multiple responsibilities in one file
- Hard to navigate or test

**Strategies:** Extract modules, separate concerns, use composition.
