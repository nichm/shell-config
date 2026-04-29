# Shell Config — Codex Agent Rules

Deployed to `~/.codex/AGENTS.md` by shell-config `install.sh`.
These rules apply globally to all Codex CLI sessions.

## CLI Tool Preferences

Use these instead of defaults (installed by `install.sh`):

- `rg` instead of `grep` — respects .gitignore, faster
- `ast-grep` (`sg`) — for structural/syntax-aware code search
- `fd` instead of `find`
- `sd` instead of `sed` for replacements
- `jq` for JSON, `yq` for YAML
- `bat` instead of `cat`
- `scc` for codebase stats

## Python

- **Always `uv`** — never `pip`, `pip3`, or `python3 -m pip`
- `uv add <pkg>` / `uv run <script>` / `uv sync`
- Commit `uv.lock`

## Command Safety

- Wrap commands: `timeout 60 <cmd>` (default), `timeout 300 <cmd>` (builds/installs)

## Subagent Routing

**Parallel**: 3+ independent tasks, no shared files
**Sequential**: B depends on A, shared files
**Background**: research/analysis not blocking work

Include in every subagent dispatch: scope, file refs, expected output, success criteria.
