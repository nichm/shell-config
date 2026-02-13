# =============================================================================
# Makefile - Unified Task Runner for Shell Config
# =============================================================================
# Usage: make <target>
#
# Examples:
#   make lint          # Run all linters
#   make format        # Format all shell scripts
#   make test          # Run all tests
#   make validate      # Run all validation checks
#   make install-deps  # Install development dependencies
# =============================================================================

.PHONY: help lint test validate install-deps check-deps install-hooks verify-hooks clean

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# -----------------------------------------------------------------------------
# Help Target
# -----------------------------------------------------------------------------
help: ## Show this help message
	@echo "$(BLUE)Shell Config Development Tasks$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make lint       # Run ShellCheck on all scripts"
	@echo "  make test       # Run BATS tests"
	@echo "  make validate   # Run all checks (lint + test)"

# -----------------------------------------------------------------------------
# Linting Targets
# -----------------------------------------------------------------------------
lint: ## Run all linters (ShellCheck, actionlint)
	@echo "$(BLUE)🔍 Running ShellCheck...$(NC)"
	@find lib -name "*.sh" -type f -exec shellcheck --severity=warning --shell=bash {} +
	@find . -maxdepth 1 -type f -name "*.sh" -exec shellcheck --severity=warning --shell=bash {} +
	@echo "$(GREEN)✅ ShellCheck complete$(NC)"
	@echo ""
	@echo "$(BLUE)🔍 Running actionlint on GitHub Actions...$(NC)"
	@if command -v actionlint >/dev/null 2>&1; then \
		if [ -f .github/actionlint.yaml ]; then \
			actionlint -config-file .github/actionlint.yaml .github/workflows/*.yml; \
		else \
			actionlint .github/workflows/*.yml; \
		fi; \
		echo "$(GREEN)✅ actionlint complete$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  actionlint not installed (brew install actionlint)$(NC)"; \
	fi

lint-ci: ## Run ShellCheck with CI severity (error only)
	@echo "$(BLUE)🔍 Running ShellCheck (CI mode)...$(NC)"
	@find lib -name "*.sh" -type f -exec shellcheck --severity=error --shell=bash {} + || exit 1
	@echo "$(GREEN)✅ ShellCheck CI mode complete$(NC)"

# -----------------------------------------------------------------------------
# Testing Targets
# -----------------------------------------------------------------------------
test: ## Run all BATS tests
	@echo "$(BLUE)🧪 Running BATS tests...$(NC)"
	@if command -v bats >/dev/null 2>&1; then \
		SHELL_CONFIG_DIR="$$(pwd)" bats tests/*.bats; \
		echo "$(GREEN)✅ All tests passed$(NC)"; \
	else \
		echo "$(RED)❌ bats not installed (brew install bats-core)$(NC)"; \
		exit 1; \
	fi

test-verbose: ## Run BATS tests with verbose output
	@echo "$(BLUE)🧪 Running BATS tests (verbose)...$(NC)"
	@if command -v bats >/dev/null 2>&1; then \
		SHELL_CONFIG_DIR="$$(pwd)" bats --verbose tests/*.bats; \
		echo "$(GREEN)✅ All tests passed$(NC)"; \
	else \
		echo "$(RED)❌ bats not installed (brew install bats-core)$(NC)"; \
		exit 1; \
	fi

test-single: ## Run a single test file (usage: make test-single TEST=tests/command-safety.bats)
	@if [ -z "$$TEST" ]; then \
		echo "$(RED)❌ ERROR: TEST parameter required$(NC)" >&2; \
		echo "WHY: Cannot run tests without specifying which test file" >&2; \
		echo "FIX: Run 'make test-single TEST=tests/command-safety.bats'" >&2; \
		exit 1; \
	fi
	@echo "$(BLUE)🧪 Running $$TEST...$(NC)"
	@if command -v bats >/dev/null 2>&1; then \
		SHELL_CONFIG_DIR="$$(pwd)" bats "$$TEST"; \
		echo "$(GREEN)✅ Test passed$(NC)"; \
	else \
		echo "$(RED)❌ ERROR: bats not installed$(NC)" >&2; \
		echo "WHY: Required for running BATS test suite" >&2; \
		echo "FIX: brew install bats-core" >&2; \
		exit 1; \
	fi

# -----------------------------------------------------------------------------
# Validation Targets
# -----------------------------------------------------------------------------
validate: lint-ci test ## Run all validation checks (lint + test)
	@echo ""
	@echo "$(GREEN)🎉 All validation checks passed!$(NC)"

validate-quick: lint ## Quick validation (lint only, no tests)
	@echo ""
	@echo "$(GREEN)✅ Quick validation complete$(NC)"

# -----------------------------------------------------------------------------
# Dependency Management
# -----------------------------------------------------------------------------
install-deps: ## Install all development dependencies
	@echo "$(BLUE)📦 Installing development dependencies...$(NC)"
	@echo ""
	@if brew install shellcheck bats-core actionlint bash-language-server; then \
		echo "$(GREEN)✅ Dependencies installed$(NC)"; \
	else \
		echo "$(RED)❌ ERROR: One or more dependencies failed to install$(NC)" >&2; \
		echo "WHY: Development tools are required for validation and testing" >&2; \
		echo "FIX: Review errors above and run 'brew install <failed-tool>' manually" >&2; \
		exit 1; \
	fi
	@echo ""
	@echo "$(YELLOW)Recommended VS Code extensions:$(NC)"
	@echo "  - timonwong.shellcheck"
	@echo "  - foxundermoon.shell-format"
	@echo "  - mads-hartmann.bash-ide-vscode"
	@echo "  - batista.jekey"

check-deps: ## Check which development dependencies are installed
	@echo "$(BLUE)🔍 Checking installed dependencies...$(NC)"
	@echo ""
	@echo -n "ShellCheck: "
	@if command -v shellcheck >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Installed$(NC) $$(shellcheck --version | head -1)"; \
	else \
		echo "$(RED)❌ Not installed$(NC)"; \
	fi
	@echo -n "bats: "
	@if command -v bats >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Installed$(NC) $$(bats --version)"; \
	else \
		echo "$(RED)❌ Not installed$(NC)"; \
	fi
	@echo -n "actionlint: "
	@if command -v actionlint >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Installed$(NC) $$(actionlint --version)"; \
	else \
		echo "$(RED)❌ Not installed$(NC)"; \
	fi
	@echo -n "bash-language-server: "
	@if command -v bash-language-server >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Installed$(NC)"; \
	else \
		echo "$(RED)❌ Not installed$(NC)"; \
	fi

install-hooks: ## Install git hooks for pre-commit validation
	@echo "$(BLUE)🪝 Installing git hooks...$(NC)"
	@if [ -d .github/hooks ]; then \
		cp .github/hooks/* .git/hooks/ 2>/dev/null || true; \
		chmod +x .git/hooks/* 2>/dev/null || true; \
		echo "$(GREEN)✅ Git hooks installed$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  No hooks found in .github/hooks/$(NC)"; \
	fi

verify-hooks: ## Verify git hooks are properly installed
	@echo "$(BLUE)🔍 Verifying git hooks...$(NC)"
	@if [ -f .git/hooks/pre-commit ]; then \
		echo "$(GREEN)✅ Pre-commit hook installed$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  Pre-commit hook not found$(NC)"; \
	fi

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------
clean: ## Clean temporary files and artifacts
	@echo "$(BLUE)🧹 Cleaning temporary files...$(NC)"
	@echo "$(YELLOW)⚠️  This will delete .tmp and .bak files recursively$(NC)"
	@find . -type f -name "*.tmp" -delete 2>/dev/null || true
	@find . -type f -name "*.bak" -delete 2>/dev/null || true
	@find . -type d -name ".tmp" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)✅ Clean complete$(NC)"

stats: ## Show project statistics
	@echo "$(BLUE)📊 Project Statistics$(NC)"
	@echo ""
	@echo "Shell scripts:"
	@find lib -name "*.sh" | wc -l | xargs echo "  - Total files:"
	@find lib -name "*.sh" -exec cat {} \; | wc -l | xargs echo "  - Total lines:"
	@echo ""
	@echo "Test files:"
	@find tests -name "*.bats" | wc -l | xargs echo "  - Total test files:"
	@echo ""
	@echo "File length violations (>700 lines):"
	@find lib -name "*.sh" -exec wc -l {} \; | awk '$$1 > 700 {print $$2}' | wc -l | xargs echo "  - Files over 700 lines:"

# -----------------------------------------------------------------------------
# CI/CD Helpers
# -----------------------------------------------------------------------------
ci-validate: ## Run CI validation checks (same as validate)
	@$(MAKE) validate

ci-install: ## Install dependencies for CI environment
	@echo "$(BLUE)📦 Installing CI dependencies...$(NC)"
	@brew install shellcheck bats-core actionlint
