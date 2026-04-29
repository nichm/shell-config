<!-- BEGIN shell-config-tools — managed by shell-config, do not edit this block manually -->

## Available CLI Tools

Prefer these over defaults (installed by shell-config `install.sh`):

**Search:**
- `rg` — use instead of `grep`. Respects .gitignore automatically.
- `ast-grep` (`sg`) — structural/syntax-aware code search (function calls, patterns, refactors)
- `fd` — use instead of `find`

**Replace / view:**
- `sd` — use instead of `sed` for string replacement
- `bat` — use instead of `cat` for file viewing
- `difft` — use for reviewing diffs (AST-aware, ignores whitespace noise)

**Data:**
- `jq` — all JSON querying and filtering
- `yq` — all YAML querying and filtering
- `scc` — codebase stats (faster than cloc)

**Code quality:**
- `jscpd --reporter ai` — duplicate code detection (compact LLM-friendly output)
- `depcruise` — circular dependency and architecture violation checks

---

## Python Tooling

- **Always use `uv`** for Python package operations — never `pip`, `pip3`, or `python3 -m pip`
- `uv add <pkg>` instead of `pip install <pkg>`
- `uv run <script>` instead of `python3 <script>` when a venv is expected
- `uv sync` instead of `pip install -r requirements.txt`
- Commit `uv.lock` — never commit bare `requirements.txt` without a lock file

---

## Command Safety

- Always wrap shell commands with a timeout: `timeout 60 <command>`
- For long operations (builds, installs, test suites): `timeout 300 <command>`
- Use `--timeout` flags when tools support them natively (e.g. `rg --timeout 30`)

---

## Subagent Routing

**Parallel** (all must be true): 3+ independent tasks, no shared files, no state dependency
**Sequential** (any triggers): task B needs output from A, shared files, unclear scope
**Background**: research/analysis that isn't blocking current work

Every subagent dispatch must include: scope, specific file references, expected output, success criteria.

<!-- END shell-config-tools -->
