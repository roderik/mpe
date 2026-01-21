# mpe

The idea is that this repository contains a collection of skills and configurations for Claude Code and Codex, which can be easily installed and managed. And they should work similarly in Claude, Codex, both locally and on the web.

To do this, skills and setups need to be local to the repository since the web versions cannot use plugins or install skills ad hoc. Dependencies need to be installed during startup as well.

## Quick Install

```bash
curl -sL https://raw.githubusercontent.com/roderik/mpe/main/setup.sh | bash
```

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

## Structure

```
.agents/
├── setup.json      # Skills configuration
├── setup.sh        # Installation script
└── skills/         # Installed skills (gitignored)
```
