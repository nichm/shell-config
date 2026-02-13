#!/usr/bin/env bash
# =============================================================================
# 🔍 TOOLCHAIN SCANNER - Pre-Push Validator Definitions
# =============================================================================
# Heavier validation tools that run before pushing.

# Pre-push validators (run before pushing - heavier checks)
PREPUSH_VALIDATORS=(
    "tsc:tsc --noEmit:tsconfig.json:TypeScript type checking"
    "jest:jest --passWithNoTests:package.json:JavaScript tests"
    "vitest:vitest run:vitest.config.*:Vite-based tests"
    "pytest:pytest:pytest.ini,pyproject.toml:Python tests"
    "cargo-test:cargo test:Cargo.toml:Rust tests"
    "go-test:go test:go.mod:Go tests"
    "terraform-plan:terraform plan:*.tf:Infrastructure plan preview"
    "docker-build:docker build --check:Dockerfile:Docker build validation"
    "supabase-gen:supabase db diff:supabase/config.toml:Supabase schema check"
)
