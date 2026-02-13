#!/usr/bin/env bash
# =============================================================================
# 🔍 TOOLCHAIN SCANNER - Pre-Commit Validator Definitions
# =============================================================================
# Tools with config validation commands for pre-commit hooks.

# Pre-commit validators (run before each commit)
PRECOMMIT_VALIDATORS=(
    "nginx:nginx -t:*.conf,nginx/*:Config syntax check"
    "terraform:terraform validate:*.tf:Infrastructure validation"
    "docker-compose:docker-compose config:docker-compose*.yml,compose*.yml:Compose file validation"
    "kubernetes:kubectl --dry-run=client:*.yaml,k8s/*:K8s manifest validation"
    "ansible:ansible-lint:playbook*.yml,ansible/*:Ansible linting"
    "helm:helm lint:Chart.yaml:Helm chart validation"
    "packer:packer validate:*.pkr.hcl:Packer template validation"
    "cloudformation:aws cloudformation validate-template:*.cfn.yaml:CloudFormation validation"
    "eslint:eslint:*.js,*.ts,*.jsx,*.tsx:JavaScript/TypeScript linting"
    "prettier:prettier --check:*.js,*.ts,*.css,*.json:Code formatting check"
    "oxlint:oxlint:*.js,*.ts,*.jsx,*.tsx:Fast JS/TS linting"
    "ruff:ruff check:*.py:Python linting"
    "black:black --check:*.py:Python formatting check"
    "mypy:mypy:*.py:Python type checking"
    "shellcheck:shellcheck:*.sh,*.bash:Shell script linting"
    "yamllint:yamllint:*.yml,*.yaml:YAML linting"
    "jsonlint:jsonlint:*.json:JSON validation"
    "biome:biome check:*.js,*.ts,*.json:Fast JS/JSON linting"
    "sqruff:sqruff check:*.sql:SQL linting"
    "hadolint:hadolint:Dockerfile*:Dockerfile linting"
    "markdownlint:markdownlint:*.md:Markdown linting"
    "rustfmt:rustfmt --check:*.rs:Rust formatting check"
    "clippy:cargo clippy:Cargo.toml:Rust linting"
    "golangci-lint:golangci-lint run:*.go:Go linting"
    "go-vet:go vet:*.go:Go static analysis"
)
