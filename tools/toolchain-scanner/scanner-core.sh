#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# 🔍 TOOLCHAIN SCANNER - Core Scanning Logic
# =============================================================================
# Scans repositories and system for packages, tools, and configurations.
# Identifies opportunities for automated validation and safety rules.
#
# This module contains the core scanning functions.
# =============================================================================

# PACKAGE SCANNING

scan_package_json() {
    local file="$1"
    local repo="$2"

    [[ -f "$file" ]] || return 0

    log "    Scanning package.json in $repo"

    if command -v jq &>/dev/null; then
        # Get all dependency types
        for dep_type in dependencies devDependencies peerDependencies optionalDependencies; do
            jq -r ".$dep_type // {} | keys[]" "$file" 2>/dev/null | while IFS= read -r pkg; do
                [[ -z "$pkg" ]] && continue
                echo "npm|$pkg|$repo" >> "$PACKAGES_FILE"

                # Map to CLI tools with validators
                case "$pkg" in
                    # === PRE-COMMIT VALIDATORS (fast) ===
                    # Linters
                    typescript) echo "precommit|tsc|$repo|tsc --noEmit|TypeScript type checking" >> "$VALIDATORS_FILE" ;;
                    eslint) echo "precommit|eslint|$repo|eslint|JavaScript/TypeScript linting" >> "$VALIDATORS_FILE" ;;
                    prettier) echo "precommit|prettier|$repo|prettier --check|Code formatting" >> "$VALIDATORS_FILE" ;;
                    oxlint) echo "precommit|oxlint|$repo|oxlint|Fast JS/TS linting (Rust)" >> "$VALIDATORS_FILE" ;;
                    biome|@biomejs/biome) echo "precommit|biome|$repo|biome check|Fast linting + formatting" >> "$VALIDATORS_FILE" ;;

                    # Code quality tools
                    knip) echo "precommit|knip|$repo|knip|Unused code detection" >> "$VALIDATORS_FILE" ;;
                    madge) echo "precommit|madge|$repo|madge --circular|Circular dependency detection" >> "$VALIDATORS_FILE" ;;
                    jscpd) echo "precommit|jscpd|$repo|jscpd|Copy-paste detection" >> "$VALIDATORS_FILE" ;;

                    # === PRE-PUSH VALIDATORS (heavier) ===
                    # Test frameworks
                    jest) echo "prepush|jest|$repo|jest --passWithNoTests|JavaScript testing" >> "$VALIDATORS_FILE" ;;
                    vitest) echo "prepush|vitest|$repo|vitest run|Vite-based testing" >> "$VALIDATORS_FILE" ;;
                    "@testing-library/react") echo "prepush|testing-library|$repo|bun test|React component testing" >> "$VALIDATORS_FILE" ;;

                    # === DANGEROUS CLI TOOLS ===
                    # Database CLIs
                    prisma|@prisma/*)
                        echo "dangerous|prisma|$repo|db push, migrate reset|Database schema changes" >> "$DANGEROUS_TOOLS_FILE"
                        ;;
                    drizzle-kit)
                        echo "dangerous|drizzle-kit|$repo|push, drop|Database migrations" >> "$DANGEROUS_TOOLS_FILE"
                        ;;

                    # Deployment CLIs
                    vercel)
                        echo "dangerous|vercel|$repo|deploy --prod, rm|Production deployment" >> "$DANGEROUS_TOOLS_FILE"
                        ;;
                    wrangler)
                        echo "dangerous|wrangler|$repo|deploy, delete|Cloudflare deployment" >> "$DANGEROUS_TOOLS_FILE"
                        ;;

                    # Supabase (both validator and dangerous)
                    supabase)
                        echo "dangerous|supabase|$repo|db reset, stop|Database operations" >> "$DANGEROUS_TOOLS_FILE"
                        echo "precommit|supabase|$repo|supabase db diff|Schema diff check" >> "$VALIDATORS_FILE"
                        ;;

                    # Build tools (with lint commands)
                    next) echo "precommit|next|$repo|next lint|Next.js linting" >> "$VALIDATORS_FILE" ;;
                    turbo) echo "precommit|turbo|$repo|turbo run lint|Turborepo orchestration" >> "$VALIDATORS_FILE" ;;
                esac
            done
        done
    else
        # Fallback: basic grep extraction
        grep -oE '"[^"]+":' "$file" 2>/dev/null | tr -d '":' | while IFS= read -r pkg; do
            [[ -n "$pkg" ]] && echo "npm|$pkg|$repo" >> "$PACKAGES_FILE"
        done || true
    fi
}

scan_infrastructure_configs() {
    local repo_path="$1"
    local repo="$2"

    # Nginx configs
    if [[ -f "$repo_path/nginx.conf" ]] || [[ -d "$repo_path/nginx" ]] || [[ -d "$repo_path/infrastructure/nginx" ]]; then
        log "    Found nginx config in $repo"
        echo "validator|nginx|$repo|nginx -t" >> "$VALIDATORS_FILE"
        echo "dangerous|nginx|$repo|nginx -s stop/reload" >> "$DANGEROUS_TOOLS_FILE"
    fi

    # Docker Compose
    for compose_file in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        if [[ -f "$repo_path/$compose_file" ]]; then
            log "    Found $compose_file in $repo"
            echo "validator|docker-compose|$repo|docker-compose config" >> "$VALIDATORS_FILE"
            break
        fi
    done

    # Dockerfile
    if [[ -f "$repo_path/Dockerfile" ]]; then
        log "    Found Dockerfile in $repo"
        echo "validator|hadolint|$repo|hadolint Dockerfile" >> "$VALIDATORS_FILE"
        echo "validator|docker|$repo|docker build --check" >> "$VALIDATORS_FILE"
        echo "dangerous|docker|$repo|rm, prune" >> "$DANGEROUS_TOOLS_FILE"
    fi

    # Terraform
    if ls "$repo_path"/*.tf &>/dev/null 2>&1 || [[ -d "$repo_path/terraform" ]]; then
        log "    Found Terraform files in $repo"
        echo "validator|terraform|$repo|terraform validate" >> "$VALIDATORS_FILE"
        echo "validator|terraform|$repo|terraform plan (pre-push)" >> "$VALIDATORS_FILE"
        echo "dangerous|terraform|$repo|destroy, apply" >> "$DANGEROUS_TOOLS_FILE"
    fi

    # Kubernetes
    local has_k8s_yaml=false
    for yaml_file in "$repo_path"/*.yaml; do
        [[ -f "$yaml_file" ]] && [[ "$(basename "$yaml_file")" =~ deployment|service|ingress ]] && has_k8s_yaml=true && break
    done
    if [[ -d "$repo_path/k8s" ]] || [[ -d "$repo_path/kubernetes" ]] || [[ "$has_k8s_yaml" == true ]]; then
        log "    Found Kubernetes configs in $repo"
        echo "validator|kubectl|$repo|kubectl --dry-run=client" >> "$VALIDATORS_FILE"
        echo "dangerous|kubectl|$repo|delete, apply" >> "$DANGEROUS_TOOLS_FILE"
    fi

    # Ansible
    if [[ -d "$repo_path/ansible" ]] || [[ -f "$repo_path/playbook.yml" ]] || [[ -f "$repo_path/ansible.cfg" ]]; then
        log "    Found Ansible configs in $repo"
        echo "validator|ansible-lint|$repo|ansible-lint" >> "$VALIDATORS_FILE"
        echo "dangerous|ansible-playbook|$repo|destructive tags" >> "$DANGEROUS_TOOLS_FILE"
    fi

    # Helm
    if [[ -f "$repo_path/Chart.yaml" ]] || [[ -d "$repo_path/charts" ]]; then
        log "    Found Helm charts in $repo"
        echo "validator|helm|$repo|helm lint" >> "$VALIDATORS_FILE"
    fi

    # Packer
    if ls "$repo_path"/*.pkr.hcl &>/dev/null 2>&1; then
        log "    Found Packer templates in $repo"
        echo "validator|packer|$repo|packer validate" >> "$VALIDATORS_FILE"
    fi

    # Vercel
    if [[ -f "$repo_path/vercel.json" ]]; then
        log "    Found vercel.json in $repo"
        echo "dangerous|vercel|$repo|deploy --prod, rm" >> "$DANGEROUS_TOOLS_FILE"
    fi

    # Wrangler/Cloudflare
    if [[ -f "$repo_path/wrangler.toml" ]] || [[ -f "$repo_path/wrangler.json" ]]; then
        log "    Found wrangler config in $repo"
        echo "dangerous|wrangler|$repo|deploy, delete" >> "$DANGEROUS_TOOLS_FILE"
    fi

    # Supabase
    if [[ -d "$repo_path/supabase" ]]; then
        log "    Found supabase directory in $repo"
        echo "validator|supabase|$repo|supabase db diff" >> "$VALIDATORS_FILE"
        echo "dangerous|supabase|$repo|db reset, stop" >> "$DANGEROUS_TOOLS_FILE"
    fi
}

scan_language_configs() {
    local repo_path="$1"
    local repo="$2"

    # Python
    if [[ -f "$repo_path/pyproject.toml" ]] || [[ -f "$repo_path/requirements.txt" ]] || [[ -f "$repo_path/setup.py" ]]; then
        log "    Found Python project in $repo"
        {
            echo "validator|ruff|$repo|ruff check"
            echo "validator|mypy|$repo|mypy"
            echo "validator|pytest|$repo|pytest"
        } >> "$VALIDATORS_FILE"
        if [[ -f "$repo_path/pyproject.toml" ]]; then
            echo "validator|black|$repo|black --check" >> "$VALIDATORS_FILE"
        fi
    fi

    # Rust
    if [[ -f "$repo_path/Cargo.toml" ]]; then
        log "    Found Rust project in $repo"
        {
            echo "validator|clippy|$repo|cargo clippy"
            echo "validator|rustfmt|$repo|rustfmt --check"
            echo "validator|cargo-test|$repo|cargo test"
        } >> "$VALIDATORS_FILE"
    fi

    # Go
    if [[ -f "$repo_path/go.mod" ]]; then
        log "    Found Go project in $repo"
        {
            echo "validator|go-vet|$repo|go vet"
            echo "validator|go-test|$repo|go test"
            echo "validator|golangci-lint|$repo|golangci-lint run"
        } >> "$VALIDATORS_FILE"
    fi

    # Shell scripts
    if ls "$repo_path"/*.sh &>/dev/null 2>&1 || [[ -d "$repo_path/scripts" ]]; then
        log "    Found shell scripts in $repo"
        echo "validator|shellcheck|$repo|shellcheck" >> "$VALIDATORS_FILE"
    fi

    # TypeScript config
    if [[ -f "$repo_path/tsconfig.json" ]]; then
        log "    Found TypeScript config in $repo"
        echo "validator|tsc|$repo|tsc --noEmit" >> "$VALIDATORS_FILE"
    fi

    # YAML files (many)
    if ls "$repo_path"/*.yml &>/dev/null 2>&1 || ls "$repo_path"/*.yaml &>/dev/null 2>&1; then
        log "    Found YAML files in $repo"
        echo "validator|yamllint|$repo|yamllint" >> "$VALIDATORS_FILE"
    fi

    # SQL files
    if ls "$repo_path"/*.sql &>/dev/null 2>&1 || [[ -d "$repo_path/migrations" ]] || [[ -d "$repo_path/sql" ]]; then
        log "    Found SQL files in $repo"
        echo "validator|sqruff|$repo|sqruff check" >> "$VALIDATORS_FILE"
    fi
}

scan_github_workflows() {
    local dir="$1"
    local repo="$2"

    [[ -d "$dir" ]] || return 0

    for wf in "$dir"/*.yml "$dir"/*.yaml; do
        [[ -f "$wf" ]] || continue
        log "    Scanning workflow: $(basename "$wf") in $repo"

        # Check for validation tools used in CI that should also be in pre-commit
        for tool in eslint prettier oxlint biome ruff mypy pytest jest vitest shellcheck yamllint terraform kubectl; do
            if grep -qw "$tool" "$wf" 2>/dev/null; then
                log "      Found $tool usage in workflow"
            fi
        done

        # Check for dangerous operations
        for danger in "terraform apply" "kubectl apply" "docker push" "vercel deploy" "wrangler deploy"; do
            if grep -q "$danger" "$wf" 2>/dev/null; then
                local tool
                tool=$(echo "$danger" | cut -d' ' -f1)
                echo "dangerous|$tool|$repo|$danger" >> "$DANGEROUS_TOOLS_FILE"
            fi
        done
    done
}

scan_repository() {
    local repo_path="$1"
    local repo_name
    repo_name=$(basename "$repo_path")

    # Skip hidden directories and common non-project dirs
    [[ "$repo_name" =~ ^\. ]] && return 0
    [[ ! -d "$repo_path" ]] && return 0

    log "Scanning repository: $repo_name"

    # Scan package manifests
    scan_package_json "$repo_path/package.json" "$repo_name"

    # Scan infrastructure configs
    scan_infrastructure_configs "$repo_path" "$repo_name"

    # Scan language-specific configs
    scan_language_configs "$repo_path" "$repo_name"

    # Scan GitHub workflows
    scan_github_workflows "$repo_path/.github/workflows" "$repo_name"
}

# SYSTEM SCANNING

scan_system_tools() {
    log "Scanning system tools..."

    # Check for installed validators
    for validator_def in "${PRECOMMIT_VALIDATORS[@]}"; do
        local tool cmd
        tool=$(echo "$validator_def" | cut -d: -f1)
        cmd=$(echo "$validator_def" | cut -d: -f2)

        if command -v "$tool" &>/dev/null; then
            echo "system-validator|$tool|SYSTEM|$cmd" >> "$VALIDATORS_FILE"
        fi
    done

    # Check for dangerous tools
    for danger_def in "${DANGEROUS_CLI_TOOLS[@]}"; do
        local tool cmds
        tool=$(echo "$danger_def" | cut -d: -f1)
        cmds=$(echo "$danger_def" | cut -d: -f2)

        if command -v "$tool" &>/dev/null; then
            echo "system-dangerous|$tool|SYSTEM|$cmds" >> "$DANGEROUS_TOOLS_FILE"
        fi
    done
}

# EXISTING RULES EXTRACTION

extract_existing_rules() {
    log "Extracting existing command-safety rules..."

    : > "$EXISTING_RULES_FILE"

    if [[ ! -d "$COMMAND_SAFETY_RULES_DIR" ]]; then
        log "  Rules directory not found: $COMMAND_SAFETY_RULES_DIR"
        return 0
    fi

    for file in "$COMMAND_SAFETY_RULES_DIR"/*.sh; do
        [[ -f "$file" ]] || continue
        [[ "$(basename "$file")" == "settings.sh" ]] && continue

        local category
        category=$(basename "$file" .sh)
        log "  Parsing: $category"

        # Extract commands from rule definitions
        grep -E '^RULE_[A-Z0-9_]+_COMMAND=' -- "$file" 2>/dev/null | while IFS= read -r line; do
            local command
            command=$(printf '%s' "$line" | sed 's/.*="//' | sed 's/"$//')
            printf '%s|%s\n' "$command" "$category" >> "$EXISTING_RULES_FILE"
        done
    done

    sort -u -o "$EXISTING_RULES_FILE" "$EXISTING_RULES_FILE" 2>/dev/null || true
}

# ANALYSIS

analyze_validators() {
    log "Analyzing validator coverage..."

    local analysis_file="$TEMP_DIR/analysis.txt"
    : > "$analysis_file"

    # Deduplicate validators
    sort "$VALIDATORS_FILE" 2>/dev/null | uniq > "$TEMP_DIR/validators_unique.txt" 2>/dev/null || true

    # Group by repository
    echo "=== VALIDATORS BY REPOSITORY ===" >> "$analysis_file"
    cut -d'|' -f3 "$TEMP_DIR/validators_unique.txt" 2>/dev/null | sort -u | while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue
        echo "REPO:$repo" >> "$analysis_file"
        grep "|$repo|" "$TEMP_DIR/validators_unique.txt" 2>/dev/null | while IFS='|' read -r _type tool _repo cmd; do
            echo "  $tool|$cmd" >> "$analysis_file"
        done
    done

    # Group by tool
    echo "" >> "$analysis_file"
    echo "=== VALIDATORS BY TOOL ===" >> "$analysis_file"
    cut -d'|' -f2 "$TEMP_DIR/validators_unique.txt" 2>/dev/null | sort | uniq -c | sort -rn | while read -r count tool; do
        echo "$tool|$count" >> "$analysis_file"
    done

    echo "$analysis_file"
}

analyze_dangerous() {
    log "Analyzing dangerous tool coverage..."

    local analysis_file="$TEMP_DIR/dangerous_analysis.txt"
    : > "$analysis_file"

    # Deduplicate
    sort "$DANGEROUS_TOOLS_FILE" 2>/dev/null | uniq > "$TEMP_DIR/dangerous_unique.txt" 2>/dev/null || true

    # Check against existing rules
    echo "=== DANGEROUS TOOLS WITH RULES ===" >> "$analysis_file"
    while IFS='|' read -r _type tool repo cmds; do
        [[ -z "$tool" ]] && continue
        local has_rule="NO"
        if grep -q "^$tool|" "$EXISTING_RULES_FILE" 2>/dev/null; then
            has_rule="YES"
        fi
        echo "$tool|$repo|$cmds|$has_rule" >> "$analysis_file"
    done < "$TEMP_DIR/dangerous_unique.txt"

    # Tools without rules
    echo "" >> "$analysis_file"
    echo "=== DANGEROUS TOOLS WITHOUT RULES ===" >> "$analysis_file"
    cut -d'|' -f2 "$TEMP_DIR/dangerous_unique.txt" 2>/dev/null | sort -u | while IFS= read -r tool; do
        [[ -z "$tool" ]] && continue
        if ! grep -q "^$tool|" "$EXISTING_RULES_FILE" 2>/dev/null; then
            local usage_count
            usage_count=$(grep -c "|$tool|" "$TEMP_DIR/dangerous_unique.txt" 2>/dev/null || echo "1")
            echo "$tool|$usage_count" >> "$analysis_file"
        fi
    done

    echo "$analysis_file"
}
