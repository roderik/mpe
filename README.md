# mpe

Portable agent setup for Claude Code and Codex that works identically in local CLI and cloud environments.

**The problem:** Cloud/web versions of these agents can't install skills or plugins on-the-fly. You get a vanilla agent with no workflow enforcement, no specialized skills, and no tooling.

**The solution:** Bundle everything in the repository—skills, workflows, commands, and dependency setup scripts—so the agent behaves the same whether you're running locally or in the cloud.

## Quick Install (Local CLI)

```bash
curl -sL https://raw.githubusercontent.com/roderik/mpe/main/setup.sh | bash
```

This installs into the **current directory** and will download the full `.agents` folder if it’s missing.

Setup flags:

- `--lite` - skip post-install system/package setup (fast, minimal)
- `--skip-postinstall` - same as `--lite`, but explicit
- `--skip-codex-mcp` - skip updating Codex MCP config in `~/.codex/config.toml`
- `--docs-only` - only refresh workflow/routing tables in `CLAUDE.md` and `AGENTS.md`
- `--skip-skills` - skip installing skills (useful for docs-only runs)

## What's Included

**Workflow enforcement** via `CLAUDE.md` / `AGENTS.md`:
- Task classification (Trivial → Complex) with mandatory phases
- Gate checks requiring proof before proceeding
- Skill routing table mapping triggers to capabilities

**37 skills** across domains:
- Development: TDD, systematic debugging, verification
- Security: Semgrep, CodeQL, differential review, SARIF parsing
- Quality: Code review, code simplifier, knip (dead code)
- Docs: xlsx, pptx, doc-coauthoring
- Frameworks: React/Next.js, TanStack Query, Better Auth

**10 commands**: `/commit`, `/review`, `/pr`, `/branch`, `/sync`, etc.

**Auto-installed tooling**: jq, ripgrep, graphviz, semgrep, CodeQL, playwright, and more

## Manual Setup

```bash
curl -sL https://github.com/roderik/mpe/archive/refs/heads/main.tar.gz | tar -xz --strip-components=1 "mpe-main/.agents"
bash .agents/setup.sh
```

## Cloud Setup

Both Claude Code and Codex require specific configuration for cloud/web environments.

### Claude Code (claude.ai/code)

1. **Network Permissions**: Set to **Full** in project settings
   - Required for installing dependencies and accessing package registries

2. **Dependency Installation**: Automatic via session-start hook
   - The hook at `.claude/settings.json` triggers `.claude/scripts/web/session-start/setup.sh`
   - Installs system tools (jq, ripgrep, graphviz, etc.)
   - Installs Python packages (markitdown, semgrep)
   - Installs Node packages (agent-browser, playwright, knip)
   - Sets up CodeQL for security analysis

### Codex (codex.openai.com)

1. **Network Permissions**: Set to **Full** in project settings
   - Required for installing dependencies and accessing package registries

2. **Setup Script**: Configure in project settings
   - Add to **Setup script** field:
     ```
     bash ./.claude/scripts/web/session-start/setup.sh
     ```

3. **Maintenance Script**: Configure in project settings
   - Add to **Maintenance script** field:
     ```
     bash ./.claude/scripts/web/session-start/setup.sh
     ```

### What the Setup Script Installs

The web setup script (`.claude/scripts/web/session-start/setup.sh`) installs:

| Category | Packages |
| --- | --- |
| System tools | jq, ripgrep, graphviz, poppler-utils |
| Python | markitdown[pptx], defusedxml, semgrep |
| Node.js | agent-browser, pptxgenjs, playwright, knip |
| Security | CodeQL CLI |

The script only runs in remote environments (checks for `CLAUDE_CODE_REMOTE` or detects cloud environment).

## Refresh Workflow + Routing Tables

When you update skills or the workflow config, re-sync the docs:

```bash
./scripts/refresh-docs
```

## Structure

```
├── CLAUDE.md           # Claude Code instructions (generated from templates/claude/)
├── AGENTS.md           # Codex instructions (generated from templates/codex/)
├── .claude/
│   ├── settings.json   # Hooks configuration (session-start)
│   ├── commands/       # Slash commands (/commit, /review, etc.)
│   └── scripts/        # Session scripts for web environments
└── .agents/
    ├── setup.json      # Skills and MCP configuration
    ├── setup.sh        # Installation script
    ├── commands/       # Command templates (copied to .claude/commands/)
    ├── templates/
    │   ├── claude/     # Claude Code templates (CLAUDE.md + sections)
    │   └── codex/      # Codex templates (AGENTS.md + sections)
    └── skills/         # Installed skills (gitignored)
```
