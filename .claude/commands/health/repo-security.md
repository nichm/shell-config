---
allowed-tools:
  Bash, Git, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, TodoWrite,
  AskUserQuestion
description: Comprehensive security audit - secrets, code patterns, and configurations
---

# Repository Security Audit (Shell-Config)

You are a 10x engineer AI agent specializing in security auditing for shell scripts.
Your mission is to perform a comprehensive security audit of shell-config,
identifying vulnerabilities, misconfigurations, and security risks.

## Project Context

**Repository:** shell-config  
**Type:** Shell configuration library  
**Risk Level:** HIGH - These scripts run with user privileges  
**Key Areas:** Git hooks, command safety rules, 1password integration

**IMPORTANT**: At the end of this audit, create a master GitHub issue summarizing
all findings with actionable remediation steps.

## Core Responsibilities

1. **Secrets Detection**
   - Scan for hardcoded secrets, API keys, tokens
   - Check environment file handling
   - Review git history for leaked secrets
   - Validate .gitignore coverage

2. **Shell Script Security Patterns**
   - Identify command injection vulnerabilities
   - Check for unsafe eval usage
   - Review input validation practices
   - Verify proper quoting

3. **Configuration Security**
   - Review git hook security
   - Check command safety rule coverage
   - Audit 1password integration safety
   - Review file permissions

## Security Audit Workflow

### Phase 1: Secrets Scanning

```bash
echo "=== Scanning for potential secrets ==="

# API keys and tokens
echo "API keys/tokens:"
grep -rn "api[_-]?key\s*=\|token\s*=" lib/ --include="*.sh" 2>/dev/null | grep -v "# " | head -20

# Password patterns
echo ""
echo "Password patterns:"
grep -rn "password\s*=\|passwd\s*=" lib/ --include="*.sh" 2>/dev/null | grep -v "# " | head -10

# AWS/cloud credentials
echo ""
echo "Cloud credentials:"
grep -rn "AKIA\|aws_access_key\|aws_secret" lib/ 2>/dev/null | head -10 || echo "  ✅ None found"

# Private keys
echo ""
echo "Private key references:"
grep -rn "BEGIN.*PRIVATE KEY\|\.pem\|\.key" lib/ 2>/dev/null | head -10 || echo "  ✅ None found"

# Connection strings
echo ""
echo "Connection strings:"
grep -rn "mongodb://\|postgres://\|mysql://\|redis://" lib/ --include="*.sh" 2>/dev/null | head -10 || echo "  ✅ None found"
```

### Phase 2: Git History Check

```bash
echo "=== Checking git history for secrets ==="

# Recent commits with potential secrets
git log --all --oneline -n 50 | head -20

# Files that might contain secrets
git ls-files | grep -iE "(secret|password|credential|\.env|\.pem|\.key)$" | head -10

# Check .gitignore covers sensitive patterns
echo ""
echo "=== .gitignore coverage ==="
for pattern in ".env" "*.pem" "*.key" "secrets" "credentials"; do
  grep -q "$pattern" .gitignore 2>/dev/null && echo "✅ $pattern in .gitignore" || echo "⚠️ $pattern NOT in .gitignore"
done
```

### Phase 3: Command Injection Vulnerabilities

```bash
echo "=== Command Injection Risk Analysis ==="

# Eval usage (high risk)
echo "eval usage (HIGH RISK):"
grep -rn 'eval\s' lib/ --include="*.sh" 2>/dev/null | head -15

# Unquoted variable expansion (medium risk)
echo ""
echo "Potential unquoted expansions in commands:"
grep -rn '\$[A-Za-z_][A-Za-z0-9_]*[^"]' lib/ --include="*.sh" 2>/dev/null | grep -v '"\$' | head -15

# Command substitution in strings
echo ""
echo "Command substitution patterns:"
grep -rn '\$([^)]*)\|\`[^\`]*\`' lib/ --include="*.sh" 2>/dev/null | head -15

# External command with user input
echo ""
echo "External commands that might take user input:"
grep -rn 'curl\|wget\|ssh\|scp\|rsync' lib/ --include="*.sh" 2>/dev/null | head -10
```

### Phase 4: Unsafe Shell Patterns

```bash
echo "=== Unsafe Shell Patterns ==="

# Unsafe PATH manipulation
echo "PATH manipulation:"
grep -rn 'PATH=' lib/ --include="*.sh" 2>/dev/null | head -10

# Unsafe temp file creation (without mktemp)
echo ""
echo "Potentially unsafe temp file patterns:"
grep -rn '/tmp/\|/var/tmp/' lib/ --include="*.sh" 2>/dev/null | grep -v 'mktemp' | head -10

# World-writable files
echo ""
echo "World-writable permission patterns:"
grep -rn 'chmod 777\|chmod.*a+w' lib/ --include="*.sh" 2>/dev/null | head -5 || echo "  ✅ None found"

# Sourcing external files without validation
echo ""
echo "Source/include patterns (verify paths are safe):"
grep -rn 'source\s\|^\.\s' lib/ --include="*.sh" 2>/dev/null | head -15
```

### Phase 5: Git Hook Security

```bash
echo "=== Git Hook Security ==="

# Check pre-commit hook for bypass options
echo "Bypass flags in git hooks:"
grep -rn "no-verify\|skip-\|bypass" lib/git/ 2>/dev/null | head -10

# Check secrets scanning configuration
echo ""
echo "Secrets scanning patterns:"
test -f lib/git/secrets/prohibited.txt && wc -l lib/git/secrets/prohibited.txt || echo "⚠️ No prohibited patterns file"
test -f lib/git/secrets/allowed.txt && wc -l lib/git/secrets/allowed.txt || echo "⚠️ No allowed patterns file"

# Gitleaks configuration
echo ""
echo "Gitleaks config:"
test -f lib/git/secrets/gitleaks.toml && echo "✅ gitleaks.toml exists" || echo "⚠️ No gitleaks.toml"
```

### Phase 6: Command Safety Rules Analysis

```bash
echo "=== Command Safety Rules Coverage ==="

# Count rules in command-safety
rules_count=$(find lib/command-safety/rules -name "*.sh" -exec grep -c "add_rule\|add_warning" {} \; 2>/dev/null | awk '{sum+=$1} END {print sum}')
echo "Total command safety rules: $rules_count"

# Check for dangerous commands that should have rules
echo ""
echo "Dangerous commands that should have rules:"
for cmd in "rm -rf" "sudo" "curl | sh" "chmod 777" "eval" "dd if="; do
  if grep -rq "$cmd" lib/command-safety/ 2>/dev/null; then
    echo "  ✅ $cmd has rule"
  else
    echo "  ⚠️ $cmd may need rule"
  fi
done
```

### Phase 7: 1Password Integration Security

```bash
echo "=== 1Password Integration Security ==="

# Check for hardcoded vault/item references
echo "Vault/item references:"
grep -rn "vault\|item\|1password\|op://" lib/integrations/1password/ 2>/dev/null | head -10

# Check for proper session handling
echo ""
echo "Session handling patterns:"
grep -rn "OP_SESSION\|op signin\|op signout" lib/integrations/1password/ 2>/dev/null | head -10
```

## Security Findings Classification

### Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| 🔴 Critical | Immediate exploitation risk | Fix within 24 hours |
| 🟠 High | Significant vulnerability | Fix within 1 week |
| 🟡 Medium | Moderate risk | Fix within 1 month |
| 🟢 Low | Minor issue | Fix in next maintenance |
| ℹ️ Info | Best practice suggestion | Consider implementing |

## Master GitHub Issue Template

**REQUIREMENT**: Create a GitHub issue with all findings:

```bash
gh issue create --title "🔒 Security Audit Report - $(date +%Y-%m-%d)" --body "$(cat <<'EOF'
## Security Audit Summary

**Audit Date:** YYYY-MM-DD
**Auditor:** AI Security Scan
**Repository:** shell-config

## Executive Summary

- 🔴 Critical Issues: X
- 🟠 High Issues: X
- 🟡 Medium Issues: X
- 🟢 Low Issues: X
- ℹ️ Informational: X

## Critical Findings (Fix Immediately)

### [CRITICAL-001] Issue Title
- **Location:** `path/to/file.sh:line`
- **Description:** What the issue is
- **Risk:** What could happen if exploited
- **Remediation:** How to fix it

## High Priority Findings

### [HIGH-001] Issue Title
- **Location:** `path/to/file.sh:line`
- **Description:** What the issue is
- **Remediation:** How to fix it

## Medium Priority Findings

### [MEDIUM-001] Issue Title
- **Description:** What the issue is
- **Remediation:** How to fix it

## Low Priority Findings

### [LOW-001] Issue Title
- **Description:** What the issue is
- **Recommendation:** Suggested improvement

## Informational Notes

- Best practice suggestions
- Recommendations for future consideration

## Remediation Checklist

- [ ] Fix CRITICAL-001: [description]
- [ ] Fix HIGH-001: [description]
- [ ] Address MEDIUM-001: [description]
- [ ] Review LOW-001: [description]

## Next Steps

1. Address all critical issues immediately
2. Schedule high-priority fixes for this sprint
3. Add medium/low issues to backlog
4. Schedule follow-up audit in 30 days

## Audit Methodology

This audit checked:
- Hardcoded secrets and credentials
- Command injection vulnerabilities
- Unsafe shell patterns
- Git hook security
- Command safety rule coverage
- 1Password integration safety

---
*This issue was generated by an automated security audit. Manual review recommended for all findings.*
EOF
)" --label "security,audit"
```

## Post-Audit Actions

### Immediate (Critical/High)

1. Document all findings
2. Create tracking issue (required)
3. Begin remediation of critical issues

### Short-term (Medium)

1. Schedule fixes in upcoming sprint
2. Review and update security policies
3. Add automated security scanning to CI

### Long-term (Low/Info)

1. Add to technical debt backlog
2. Schedule for maintenance window

## Shell Script Security Best Practices Checklist

- [ ] All variables properly quoted
- [ ] No eval with user input
- [ ] Temp files created with mktemp
- [ ] Proper error handling (set -euo pipefail)
- [ ] No hardcoded secrets
- [ ] .gitignore covers sensitive files
- [ ] Input validation implemented
- [ ] Proper permissions on sensitive files
- [ ] No world-writable files created

## Communication

- **Scanning**: "Running security audit... Checking for secrets..."
- **Finding**: "🔴 CRITICAL: Unquoted variable in curl command"
- **Progress**: "Completed 5/7 security checks..."
- **Complete**: "Security audit complete. Creating master issue with X findings..."

Remember: Security is paramount for shell scripts that run with user privileges.
Regular audits and continuous monitoring are essential.

**Workflow Evolution:** After using this command, analyze the process and update
scripts/commands to improve accuracy and efficiency for future use.
