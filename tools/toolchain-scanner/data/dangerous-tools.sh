#!/usr/bin/env bash
# =============================================================================
# 🔍 TOOLCHAIN SCANNER - Dangerous CLI Tool Definitions
# =============================================================================
# Tools with destructive operations for command-safety rules.

# Dangerous CLI tools (for command-safety rules)
DANGEROUS_CLI_TOOLS=(
    "prisma:prisma db push,prisma migrate reset:Database schema changes"
    "drizzle-kit:drizzle-kit push,drizzle-kit drop:Database schema changes"
    "supabase:supabase db reset,supabase stop:Database/service operations"
    "vercel:vercel deploy --prod,vercel rm:Production deployments"
    "wrangler:wrangler deploy,wrangler delete:Cloudflare deployments"
    "terraform:terraform destroy,terraform apply:Infrastructure changes"
    "kubectl:kubectl delete,kubectl apply:Kubernetes operations"
    "docker:docker rm,docker system prune:Container operations"
    "gh:gh repo delete,gh release delete:GitHub operations"
    "git:git reset --hard,git push --force:Version control"
    "rm:rm -rf:File deletion"
    "dd:dd if=:Disk operations"
    "cargo:cargo uninstall:Rust package management"
    "pip:pip install,pip uninstall:Python package management"
    "bun:bun remove:Bun package management"
    "brew:brew uninstall:Homebrew operations"
    "systemctl:systemctl stop,systemctl disable:Service management"
    "nginx:nginx -s stop:Web server control"
    "redis-cli:redis-cli FLUSHDB:Cache operations"
    "mongo:db.dropDatabase():Database operations"
    "psql:DROP DATABASE,DROP TABLE:PostgreSQL operations"
)
