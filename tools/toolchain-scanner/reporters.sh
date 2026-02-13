#!/usr/bin/env bash
# =============================================================================
# 🔍 TOOLCHAIN SCANNER - Output Reporters
# =============================================================================
# Formats and outputs scan results in various formats (markdown, JSON, text).
#
# This module contains all output formatting functions.
# =============================================================================

format_markdown_validators() {
    local analysis_file="$1"

    local validator_count tool_count repo_count
    validator_count=$(wc -l < "$TEMP_DIR/validators_unique.txt" 2>/dev/null | tr -d ' ')
    tool_count=$(cut -d'|' -f2 "$TEMP_DIR/validators_unique.txt" 2>/dev/null | sort -u | wc -l | tr -d ' ')
    repo_count=$(cut -d'|' -f3 "$TEMP_DIR/validators_unique.txt" 2>/dev/null | sort -u | wc -l | tr -d ' ')

    cat <<EOF
# Toolchain Scanner Report

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**Repos Directory:** \`$REPOS_DIR\`
**Mode:** Config Validators (for git hooks)

## Summary

| Metric | Count |
|--------|-------|
| Total Validator Opportunities | $validator_count |
| Unique Tools | $tool_count |
| Repositories Scanned | $repo_count |

## Recommended Pre-Commit Validators

Tools that should run before every commit (fast checks):

| Tool | Command | Repos Using |
|------|---------|-------------|
EOF

    # Pre-commit validators found
    for tool in oxlint eslint ruff shellcheck yamllint prettier biome hadolint nginx terraform docker-compose sqruff tsc; do
        local count repos
        count=$(grep -c "|$tool|" "$TEMP_DIR/validators_unique.txt" 2>/dev/null || echo "0")
        if [[ $count -gt 0 ]]; then
            repos=$(grep "|$tool|" "$TEMP_DIR/validators_unique.txt" 2>/dev/null | cut -d'|' -f3 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
            local cmd=""
            case "$tool" in
                oxlint) cmd="oxlint" ;;
                eslint) cmd="eslint" ;;
                ruff) cmd="ruff check" ;;
                shellcheck) cmd="shellcheck" ;;
                yamllint) cmd="yamllint" ;;
                prettier) cmd="prettier --check" ;;
                biome) cmd="biome check" ;;
                hadolint) cmd="hadolint Dockerfile" ;;
                nginx) cmd="nginx -t" ;;
                terraform) cmd="terraform validate" ;;
                docker-compose) cmd="docker-compose config" ;;
                sqruff) cmd="sqruff check" ;;
                tsc) cmd="tsc --noEmit" ;;
            esac
            echo "| \`$tool\` | \`$cmd\` | $repos |"
        fi
    done

    cat <<EOF

## Recommended Pre-Push Validators

Tools that should run before pushing (heavier checks):

| Tool | Command | Repos Using |
|------|---------|-------------|
EOF

    # Pre-push validators found
    for tool in tsc jest vitest pytest cargo-test go-test terraform mypy clippy; do
        local count repos
        count=$(grep -c "|$tool|" "$TEMP_DIR/validators_unique.txt" 2>/dev/null || echo "0")
        if [[ $count -gt 0 ]]; then
            repos=$(grep "|$tool|" "$TEMP_DIR/validators_unique.txt" 2>/dev/null | cut -d'|' -f3 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
            local cmd=""
            case "$tool" in
                tsc) cmd="tsc --noEmit" ;;
                jest) cmd="jest --passWithNoTests" ;;
                vitest) cmd="vitest run" ;;
                pytest) cmd="pytest" ;;
                cargo-test) cmd="cargo test" ;;
                go-test) cmd="go test" ;;
                terraform) cmd="terraform plan" ;;
                mypy) cmd="mypy" ;;
                clippy) cmd="cargo clippy" ;;
            esac
            echo "| \`$tool\` | \`$cmd\` | $repos |"
        fi
    done

    cat <<EOF

## Code Quality Tools

Additional tools for code quality checks:

| Tool | Command | Purpose | Repos Using |
|------|---------|---------|-------------|
EOF

    # Code quality tools
    for tool in knip madge jscpd supabase next turbo; do
        local count repos
        count=$(grep -c "|$tool|" "$TEMP_DIR/validators_unique.txt" 2>/dev/null || echo "0")
        if [[ $count -gt 0 ]]; then
            repos=$(grep "|$tool|" "$TEMP_DIR/validators_unique.txt" 2>/dev/null | cut -d'|' -f3 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
            local cmd="" purpose=""
            case "$tool" in
                knip) cmd="knip"; purpose="Find unused code" ;;
                madge) cmd="madge --circular"; purpose="Detect circular deps" ;;
                jscpd) cmd="jscpd"; purpose="Find duplicate code" ;;
                supabase) cmd="supabase db diff"; purpose="Schema validation" ;;
                next) cmd="next lint"; purpose="Next.js linting" ;;
                turbo) cmd="turbo run lint"; purpose="Monorepo orchestration" ;;
            esac
            echo "| \`$tool\` | \`$cmd\` | $purpose | $repos |"
        fi
    done

    cat <<EOF

## Installation Commands

### Quick Install (macOS)

\`\`\`bash
# Fast linters (Rust-based)
brew install oxlint ruff sqruff shellcheck yamllint biome

# Infrastructure validators
brew install terraform helm packer hadolint

# Optional: heavier tools
brew install ansible-lint golangci-lint
\`\`\`

## Git Hook Integration

Add to your \`.git/hooks/pre-commit\`:

\`\`\`bash
#!/bin/bash
# Auto-generated validator checks

# Run fast validators on changed files (handles spaces in filenames)
git diff --cached --name-only --diff-filter=ACM | while IFS= read -r file; do
    [[ -z "\$file" ]] && continue
    case "\${file##*.}" in
        js|ts|jsx|tsx) oxlint "\$file" || exit 1 ;;
        py) ruff check "\$file" || exit 1 ;;
        sh) shellcheck "\$file" || exit 1 ;;
        yml|yaml) yamllint "\$file" || exit 1 ;;
        sql) sqruff check "\$file" || exit 1 ;;
    esac
done

# Config validators (run if configs changed)
if echo "\$files" | grep -q "nginx"; then
    nginx -t || exit 1
fi

if echo "\$files" | grep -q "docker-compose"; then
    docker-compose config -q || exit 1
fi

if echo "\$files" | grep -q ".tf\$"; then
    terraform validate || exit 1
fi
\`\`\`

EOF
}

format_markdown_dangerous() {
    local analysis_file="$1"

    local dangerous_count without_rules_count
    dangerous_count=$(wc -l < "$TEMP_DIR/dangerous_unique.txt" 2>/dev/null | tr -d ' ')
    without_rules_count=$(sed -n '/=== DANGEROUS TOOLS WITHOUT RULES ===/,$p' "$analysis_file" 2>/dev/null | grep -cv "===" 2>/dev/null || echo "0")

    cat <<EOF
# Dangerous Tools Audit Report

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**Repos Directory:** \`$REPOS_DIR\`
**Command Safety Rules:** \`$COMMAND_SAFETY_RULES_DIR\`
**Mode:** Dangerous CLI Tools (for command-safety rules)

## Summary

| Metric | Count |
|--------|-------|
| Total Dangerous Tool Usages | $dangerous_count |
| Tools Without Safety Rules | $without_rules_count |

## Tools Without Safety Rules

These dangerous tools are used but have no command-safety rules:

| Tool | Usage Count | Priority |
|------|-------------|----------|
EOF

    sed -n '/=== DANGEROUS TOOLS WITHOUT RULES ===/,$p' "$analysis_file" | grep -v "===" | sort -t'|' -k2 -rn | while IFS='|' read -r tool count; do
        [[ -z "$tool" ]] && continue
        local priority="Low"
        [[ $count -gt 3 ]] && priority="Medium"
        [[ $count -gt 7 ]] && priority="High"
        echo "| \`$tool\` | $count | $priority |"
    done

    cat <<EOF

## Tools With Existing Rules

| Tool | Dangerous Commands | Has Rule |
|------|-------------------|----------|
EOF

    sed -n '/=== DANGEROUS TOOLS WITH RULES ===/,/=== DANGEROUS TOOLS WITHOUT RULES ===/p' "$analysis_file" | grep "YES$" | while IFS='|' read -r tool repo cmds has_rule; do
        [[ -z "$tool" ]] && continue
        echo "| \`$tool\` | $cmds | ✅ |"
    done | sort -u

    cat <<EOF

## All Dangerous Tools by Repository

EOF

    cut -d'|' -f3 "$TEMP_DIR/dangerous_unique.txt" 2>/dev/null | sort -u | while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue
        echo "### $repo"
        echo ""
        echo "| Tool | Dangerous Operations |"
        echo "|------|---------------------|"
        grep "|$repo|" "$TEMP_DIR/dangerous_unique.txt" 2>/dev/null | while IFS='|' read -r _type tool _repo cmds; do
            echo "| \`$tool\` | $cmds |"
        done | sort -u
        echo ""
    done

    cat <<EOF

## Recommendations

### High Priority - Add Safety Rules

EOF

    sed -n '/=== DANGEROUS TOOLS WITHOUT RULES ===/,$p' "$analysis_file" | grep -v "===" | sort -t'|' -k2 -rn | head -5 | while IFS='|' read -r tool count; do
        [[ -z "$tool" ]] && continue
        echo "- **\`$tool\`** - Used $count times, no safety rules"
    done

    cat <<EOF

### Sample Rule Template

\`\`\`bash
# Add to shell-config/lib/command-safety/rules/<category>.sh

# Rule: tool_dangerous_action
RULE_TOOL_ACTION_ID="tool_dangerous_action"
RULE_TOOL_ACTION_ACTION="warn"  # or "block"
RULE_TOOL_ACTION_COMMAND="tool"
RULE_TOOL_ACTION_PATTERN="--dangerous-flag"
RULE_TOOL_ACTION_LEVEL="high"
RULE_TOOL_ACTION_EMOJI="🔴"
RULE_TOOL_ACTION_DESC="This operation is risky because..."
RULE_TOOL_ACTION_BYPASS="--force-tool-action"
RULE_TOOL_ACTION_ALTERNATIVES=(
    "safer-alternative"
)
RULE_TOOL_ACTION_VERIFY=(
    "Run X to check first"
)
RULE_TOOL_ACTION_AI_WARNING="⚠️ AI agents should verify first"
\`\`\`

EOF
}

format_json() {
    local validator_analysis="$1"
    local dangerous_analysis="$2"

    # Build JSON using jq for proper escaping
    local scan_date repos_dir mode
    scan_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    repos_dir="$REPOS_DIR"
    mode="$(if [[ "$DANGEROUS_ONLY" == true ]]; then echo "dangerous"; else echo "validators"; fi)"

    # Build validators array
    local validators_json=""
    if [[ -s "$TEMP_DIR/validators_unique.txt" ]]; then
        validators_json=$(sort "$TEMP_DIR/validators_unique.txt" 2>/dev/null | uniq | \
            jq -R -s -c 'split("\n") | map(select(length > 0) | split("|")) |
            map({tool: .[1], repo: .[2], command: .[3]}) | .')
    else
        validators_json="[]"
    fi

    # Build dangerous_tools array
    local dangerous_json=""
    if [[ -s "$TEMP_DIR/dangerous_unique.txt" ]]; then
        dangerous_json=$(sort "$TEMP_DIR/dangerous_unique.txt" 2>/dev/null | uniq | \
            while IFS='|' read -r _type tool repo cmds; do
                [[ -z "$tool" ]] && continue
                local has_rule="false"
                grep -q "^$tool|" "$EXISTING_RULES_FILE" 2>/dev/null && has_rule="true"
                printf '%s|%s|%s|%s\n' "$tool" "$repo" "$cmds" "$has_rule"
            done | jq -R -s -c 'split("\n") | map(select(length > 0) | split("|")) |
            map({tool: .[0], repo: .[1], dangerous_commands: .[2], has_rule: (.[3] == "true")}) | .')
    else
        dangerous_json="[]"
    fi

    # Assemble final JSON
    jq -n \
        --arg date "$scan_date" \
        --arg dir "$repos_dir" \
        --arg mode "$mode" \
        --argjson validators "$validators_json" \
        --argjson dangerous "$dangerous_json" \
        '{
            scan_date: $date,
            repos_directory: $dir,
            mode: $mode,
            validators: $validators,
            dangerous_tools: $dangerous
        }'
}

format_txt() {
    # Parameters $1 (validator_analysis) and $2 (dangerous_analysis) reserved for future use
    # Current implementation reads from TEMP_DIR files directly

    cat <<EOF
VALIDATOR DISCOVERY REPORT
=====

Generated: $(date '+%Y-%m-%d %H:%M:%S')
Repos Dir: $REPOS_DIR
Mode: $(if [[ "$DANGEROUS_ONLY" == true ]]; then echo "Dangerous Tools"; else echo "Config Validators"; fi)

VALIDATORS FOUND
----------------
EOF
    printf "%-20s %-40s %s\n" "TOOL" "COMMAND" "REPO"
    printf "%-20s %-40s %s\n" "----" "-------" "----"
    sort "$TEMP_DIR/validators_unique.txt" 2>/dev/null | uniq | while IFS='|' read -r _type tool repo cmd; do
        [[ -z "$tool" ]] && continue
        printf "%-20s %-40s %s\n" "$tool" "$cmd" "$repo"
    done

    cat <<EOF

DANGEROUS TOOLS
---------------
EOF
    printf "%-15s %-30s %-10s %s\n" "TOOL" "COMMANDS" "HAS RULE" "REPO"
    printf "%-15s %-30s %-10s %s\n" "----" "--------" "--------" "----"
    sort "$TEMP_DIR/dangerous_unique.txt" 2>/dev/null | uniq | while IFS='|' read -r _type tool repo cmds; do
        [[ -z "$tool" ]] && continue
        local has_rule="NO"
        grep -q "^$tool|" "$EXISTING_RULES_FILE" 2>/dev/null && has_rule="YES"
        printf "%-15s %-30s %-10s %s\n" "$tool" "$cmds" "$has_rule" "$repo"
    done
}
