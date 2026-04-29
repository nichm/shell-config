Check if ~/.claude/CLAUDE.md already contains the shell-config tools section by looking for the text "BEGIN shell-config-tools".

If it already exists: report that it's already configured and stop.

If it doesn't exist:
1. Read the file at ~/.shell-config/config/claude/shell-config-tools.md
2. Show the user what will be added and briefly explain each section:
   - "Available CLI Tools" — tells Claude to prefer rg, ast-grep, fd, sd, bat, jq, yq, scc over defaults
   - "Python Tooling" — always use uv, never pip/python3
   - "Command Safety" — requires timeout wrappers on shell commands
   - "Subagent Routing" — when to dispatch parallel vs sequential vs background work
3. Ask: "Append this to your ~/.claude/CLAUDE.md? (yes/no)"
4. If yes:
   - Append a blank line then the contents of shell-config-tools.md to ~/.claude/CLAUDE.md
   - Report success
   - Note: to remove later, delete lines between "BEGIN shell-config-tools" and "END shell-config-tools"
5. If no: confirm that nothing was changed
