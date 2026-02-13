#!/usr/bin/env bash
# =============================================================================
# ⚠️ PACKAGE MANAGER RULES
# =============================================================================
# Safety rules for package managers: npm/yarn/pnpm (blocked — use bun),
# pip/pip3/python/python3 (ALL blocked — use uv), brew, composer, go, cargo, bun.
# Special matching:
#   BREW_UNINSTALL - exempt="--zap" (so it doesn't trigger when --zap variant should)
# =============================================================================

# shellcheck disable=SC2034

# --- npm (blocked — use bun) ---
_rule NPM cmd="npm" \
    block="Use bun instead — this project uses bun exclusively" \
    bypass="--force-npm" docs="https://bun.sh/docs"

_fix NPM \
    "bun install     # Instead of: npm install" \
    "bun add <pkg>   # Instead of: npm install <pkg>" \
    "bunx <cmd>      # Instead of: npx <cmd>"

# --- npx (blocked — use bunx) ---
_rule NPX cmd="npx" \
    block="Use bunx instead of npx" \
    fix="bunx <package>" \
    bypass="--force-npx" docs="https://bun.sh/docs"

# --- yarn (blocked — use bun) ---
_rule YARN cmd="yarn" \
    block="Use bun instead of yarn" \
    bypass="--force-yarn" docs="https://bun.sh/docs"

_fix YARN \
    "bun install       # Instead of: yarn install" \
    "bun add <pkg>     # Instead of: yarn add <pkg>" \
    "bun run <script>  # Instead of: yarn run <script>"

# --- pnpm (blocked — use bun) ---
_rule PNPM cmd="pnpm" \
    block="Use bun instead of pnpm" \
    bypass="--force-pnpm"

_fix PNPM \
    "bun install   # Instead of: pnpm install" \
    "bun add <pkg> # Instead of: pnpm add <pkg>" \
    "bunx <pkg>    # Instead of: pnpm dlx <pkg>"

# =============================================================================
# 🐍 UV ENFORCEMENT: pip/pip3/python/python3 → uv
# =============================================================================
# uv is 10-100x faster than pip and manages Python versions automatically.
# ALL direct python/python3 invocations are blocked — use uv run instead.
# Rule ordering matters: specific -m pip rules MUST come before catch-all rules
# so users get the most helpful message for pip-specific commands.
# =============================================================================

# --- pip (blocked — use uv) ---
_rule PIP cmd="pip" \
    block="Use uv instead of pip — 10-100x faster with automatic venv management" \
    bypass="--force-pip" docs="https://docs.astral.sh/uv/"

_fix PIP \
    "uv pip install <package>  # Drop-in pip replacement (10-100x faster)" \
    "uv add <package>          # Add to project dependencies (pyproject.toml)" \
    "uvx <command>             # Run CLI tools without installing (like pipx)"

# --- pip3 (blocked — use uv) ---
_rule PIP3 cmd="pip3" \
    block="Use uv instead of pip3 — uv handles Python 3 automatically" \
    bypass="--force-pip3" docs="https://docs.astral.sh/uv/"

_fix PIP3 \
    "uv pip install <package>  # uv selects correct Python version automatically" \
    "uv add <package>          # Add to project dependencies (pyproject.toml)" \
    "uvx <command>             # Run CLI tools without installing"

# --- python -m pip (blocked — use uv, MUST be before PYTHON catch-all) ---
# Uses same bypass as catch-all so --force-python skips ALL python rules
_rule PYTHON_M_PIP cmd="python" match="-m pip" \
    block="Use uv instead of python -m pip — faster and manages venvs automatically" \
    bypass="--force-python" docs="https://docs.astral.sh/uv/"

_fix PYTHON_M_PIP \
    "uv pip install <package>  # Drop-in replacement for python -m pip install" \
    "uv add <package>          # Add to project dependencies"

# --- python3 -m pip (blocked — use uv, MUST be before PYTHON3 catch-all) ---
# Uses same bypass as catch-all so --force-python3 skips ALL python3 rules
_rule PYTHON3_M_PIP cmd="python3" match="-m pip" \
    block="Use uv instead of python3 -m pip — faster and manages venvs automatically" \
    bypass="--force-python3" docs="https://docs.astral.sh/uv/"

_fix PYTHON3_M_PIP \
    "uv pip install <package>  # Drop-in replacement for python3 -m pip install" \
    "uv add <package>          # Add to project dependencies"

# --- python (catch-all — use uv run) ---
# Catches: python script.py, python -c "code", python -m module, piped python
_rule PYTHON_DIRECT cmd="python" \
    block="Use uv run instead of python — uv manages Python versions and venvs automatically" \
    bypass="--force-python" docs="https://docs.astral.sh/uv/guides/scripts/"

_fix PYTHON_DIRECT \
    "uv run script.py              # Run script with managed Python + dependencies" \
    "uv run python -c 'code'       # Run inline code with managed Python" \
    "uv run python -m module       # Run module (venv, http.server, etc.)" \
    "... | uv run python -c 'code' # Pipe data through managed Python"

# --- python3 (catch-all — use uv run) ---
# Catches: python3 script.py, python3 -c "code", python3 -m module, piped python3
_rule PYTHON3_DIRECT cmd="python3" \
    block="Use uv run instead of python3 — uv manages Python versions and venvs automatically" \
    bypass="--force-python3" docs="https://docs.astral.sh/uv/guides/scripts/"

_fix PYTHON3_DIRECT \
    "uv run script.py              # Run script with managed Python + dependencies" \
    "uv run python -c 'code'       # Run inline code with managed Python" \
    "uv run python -m module       # Run module (venv, http.server, etc.)" \
    "... | uv run python -c 'code' # Pipe data through managed Python"

# --- composer (blocked — use bun) ---
_rule COMPOSER_BLOCK cmd="composer" \
    block="Use bun instead — Composer is for PHP-specific subprojects only" \
    bypass="--force-composer"

_fix COMPOSER_BLOCK \
    "bun install  # For Node.js dependencies"

# --- brew uninstall ---
_rule BREW_UNINSTALL cmd="brew" match="uninstall|remove|rm" \
    block="Uninstalling Homebrew packages may break other packages that depend on them" \
    bypass="--force-brew-uninstall" \
    exempt="--zap"

_fix BREW_UNINSTALL \
    "brew unlink <formula>  # Disable without removing" \
    "brew pin <formula>     # Prevent accidental upgrades"

# --- brew uninstall --zap ---
_rule BREW_UNINSTALL_ZAP cmd="brew" match="uninstall --zap|remove --zap|rm --zap" \
    block="Zap removes ALL config files, user data, and dependencies — not just the package" \
    bypass="--force-brew-zap"

_fix BREW_UNINSTALL_ZAP \
    "brew unlink <formula>      # Disable without removing" \
    "brew uninstall <formula>   # Remove without deleting configs"

# --- go install ---
_rule GO_INSTALL cmd="go" match="install" \
    block="Go packages install to \$GOBIN which may not be in PATH" \
    bypass="--force-go-install"

_fix GO_INSTALL \
    "go run <package>@version  # Run without installing"

# --- cargo uninstall ---
_rule CARGO_UNINSTALL cmd="cargo" match="uninstall" \
    block="Uninstalling Rust packages may break dependent tools" \
    bypass="--force-cargo-rm"

# --- bun remove ---
_rule BUN_REMOVE cmd="bun" match="remove|rm|uninstall" \
    block="Removing packages may break dependencies in the project" \
    bypass="--force-bun-rm"

_fix BUN_REMOVE \
    "bun update <package>  # Update instead of remove"

# --- bun pm cache rm ---
_rule BUN_CACHE_RM cmd="bun" match="pm cache rm" \
    block="Cache removal slows down all subsequent installs" \
    bypass="--force-bun-cache-rm"

_fix BUN_CACHE_RM \
    "bun pm cache clean <package>   # Remove specific package only" \
    "bun install --frozen-lockfile  # Fast reinstall from lockfile"
