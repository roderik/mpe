# mpe

This repository contains a collection of skills and configurations for Claude Code and Codex. It aims to behave consistently across local CLI usage and web sessions.

To do this, skills and setups need to be local to the repository since the web versions cannot use plugins or install skills ad hoc. Dependencies need to be installed during startup as well.

## Quick Install (Local CLI)

```bash
curl -sL https://raw.githubusercontent.com/roderik/mpe/main/setup.sh | bash
```

Setup flags:

- `--lite` - skip post-install system/package setup (fast, minimal)
- `--skip-postinstall` - same as `--lite`, but explicit
- `--docs-only` - only refresh workflow/routing tables in `CLAUDE.md` and `AGENTS.md`
- `--skip-skills` - skip installing skills (useful for docs-only runs)

## What's Included

**Skills** for:
- TDD & debugging (obra/superpowers)
- Security analysis (trailofbits/skills - semgrep, codeql, sarif)
- React/TanStack Query best practices
- Document handling (xlsx, pptx)
- Code review workflows
- And more...

**Tools** installed via postInstall:
- jq, graphviz, poppler, semgrep, uv
- LibreOffice, CodeQL
- Node packages for browser automation and document processing

## Manual Setup

```bash
mkdir -p .agents
curl -sL https://raw.githubusercontent.com/roderik/mpe/main/.agents/setup.json -o .agents/setup.json
curl -sL https://raw.githubusercontent.com/roderik/mpe/main/.agents/setup.sh -o .agents/setup.sh
chmod +x .agents/setup.sh
bash .agents/setup.sh
```

## Local vs Web

| Environment | Auto setup | Manual step |
| --- | --- | --- |
| Claude Code (local) | `setup.sh` | None after install |
| Codex CLI (local) | `setup.sh` | None after install |
| Claude Web | Session-start hook runs `.claude/scripts/web/session-start/setup.sh` | Run script manually if the hook fails |
| Codex Web | No hook support | Run the web setup manually |

Manual web setup (Codex Web or as a fallback):

```bash
# Install system/python/node deps (best-effort) in web environments
CLAUDE_CODE_REMOTE=true bash .claude/scripts/web/session-start/setup.sh

# Install skills + update workflow tables
bash .agents/setup.sh --lite
```

## Refresh Workflow + Routing Tables

When you update skills or the workflow config, re-sync the docs:

```bash
./scripts/refresh-docs
```

## Structure

```
├── CLAUDE.md       # Claude Code instructions with skill routing table
├── AGENTS.md       # Codex instructions with skill routing table
└── .agents/
    ├── setup.json  # Skills configuration
    ├── setup.sh    # Installation script
    ├── templates/  # Template files for new projects
    └── skills/     # Installed skills (gitignored)
```
