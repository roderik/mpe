# Claude

<workflows>
## Development Workflow

Follow this workflow for all implementation tasks. Each phase is mandatory. If you deviate from this workflow, you MUST explain why and how you deviated. Exceptions: documentation-only, configuration-only, or research-only tasks may skip tests, but must state why.

### Principles

- ALWAYS use latest package versions. Check npmjs.com, hub.docker.com, pypi.org for current versions before installing.
- Never hardcode old versions unless explicitly required for compatibility.
- Use @latest, :latest tags, or explicit newest version numbers.
- When adding dependencies, verify the package exists and note the current version.

### Phase 1: Planning

**Start:** `Skill({ skill: "plan-mode:planning-methodology" })` or `/plan`

1. **Gather context** - `Task({ subagent_type: "plan-mode:context-researcher" })` - Start with local CLI repo discovery: `rg --files`, `git ls-files`, `ls`, `sed -n '1,200p' file`.
2. **Repo-wide search (if needed)** - `mcp__octocode__githubSearchCode` *(if MCP configured)* - If MCP is configured, use mcp__octocode__* (githubSearchCode, githubGetFileContent, githubViewRepoStructure). Otherwise use local CLI: `rg "pattern"`, `rg --files`, `git ls-files`.
3. **Check docs** - `Skill({ skill: "context7" })` - If MCP is configured, use mcp__context7__resolve-library-id then mcp__context7__query-docs. Otherwise use local docs/README and CLI search: `rg "term" docs`, `rg "term" README.md`.
4. **Non-greenfield?** - `Skill({ skill: "systematic-debugging" })` - understand existing behavior first
5. **Draft plan** - exact file paths, code snippets, 2-5 minute tasks
6. **Update tracking ticket with plan** - `mcp__linear__create_comment` *(if tracking work in Linear)* - If MCP Linear is configured, add a plan summary comment. Otherwise include the plan summary in the response.

### Phase 2: Plan Refinement (5+ iterations)

Loop until plan is bulletproof

1. `Task({ subagent_type: "build-mode:spec-reviewer", prompt: "Review plan against requirements" })`
2. `Skill({ skill: "ask-questions-if-underspecified" })`
3. `Skill({ skill: "codex-review" })` - Review for gaps
4. **Update plan based on findings**

**Each iteration must deepen:** requirements clarity, edge cases, error handling, test strategy.

### Phase 3: Implementation

**Start:** `Skill({ skill: "subagent-driven-development" })`

**With:** `Skill({ skill: "executing-plans" })`

1. `TodoWrite({ status: "in_progress" })`
2. `Skill({ skill: "test-driven-development" })` - RED: Write failing test FIRST
3. `Task({ subagent_type: "build-mode:task-implementer" })` - GREEN: Minimal code
4. `Task({ subagent_type: "build-mode:spec-reviewer" })` - Verify spec compliance
5. `Task({ subagent_type: "build-mode:quality-reviewer" })` - Code quality check
6. `TodoWrite({ status: "completed" })`

**Iron Law:** No production code without a failing test first

### Phase 4: Cleanup

After all tasks complete

1. `Skill({ skill: "code-simplifier" })` - Refine for clarity
2. `Skill({ skill: "claude-md-improver" })` *(if when CLAUDE.md needs maintenance)* - Run after major doc or workflow changes.
3. `Skill({ skill: "deslop" })` - Remove AI-generated slop
4. `Skill({ skill: "knip" })` - Remove unused code/deps

### Phase 5: Testing

```bash
bun run ci

or if not available:

bun run lint
bun run test
```

1. `Skill({ skill: "agent-browser" })` *(if UI components)* - Preferred for UI checks. If unavailable, fall back to Playwright CLI (e.g. `npx playwright install` then run project UI checks).
2. `Task({ subagent_type: "build-mode:visual-tester" })` *(if UI changes)*
3. `Task({ subagent_type: "build-mode:silent-failure-hunter" })` - Find error handling gaps

### Phase 6: Review

**Start:** `Skill({ skill: "build-mode:review" })` or `/review`

1. `Task({ subagent_type: "build-mode:code-reviewer" })`
2. `Task({ subagent_type: "build-mode:security-reviewer" })` *(if auth/data/payments)*
3. `Skill({ skill: "differential-review" })` - Security-focused diff review

### Phase 7: Verification (5+ iterations)

**Start:** `Skill({ skill: "verification-before-completion" })`

1. `Task({ subagent_type: "build-mode:completion-validator" })`
2. Run: `bun run ci`
3. **Verify exit codes, test counts, no warnings**
4. **If issues: Fix and restart loop**
5. `mcp__linear__update_issue` *(if tracking work in Linear)* - If MCP Linear is configured, use mcp__linear__* (list_issues, get_issue, update_issue, create_comment). Otherwise leave a status note in the response.

**Iron Law:** Never claim completion without fresh verification evidence

### Quick Reference

| Phase | Tool | Purpose |
|-------|------|---------|
| Plan | `/plan` | Structure approach |
| Refine | `spec-reviewer + questions` | Perfect the plan |
| Build | `subagent-driven-development` | TDD implementation |
| Clean | `deslop + knip` | Remove cruft |
| Test | `bun run ci (or lint+test) + agent-browser` | Verify behavior |
| Review | `/review` | Quality gate |
| Verify | `verification-before-completion` | Evidence-based completion |

### MCP Servers Reference

| Server | Tools | Purpose |
|--------|-------|---------|
| `mcp__context7__*` | resolve-library-id, query-docs | Up-to-date library documentation |
| `mcp__octocode__*` | githubSearchCode, githubGetFileContent, githubViewRepoStructure, packageSearch | GitHub code search and exploration |
| `mcp__linear__*` | list_issues, get_issue, create_issue, update_issue, create_comment | Issue tracking and project management |
</workflows>

<skill-routing-table>
### Planning & Context
**Triggers:** plan, design, architect, requirements, context, docs, documentation lookup

| Trigger Phrases | Invocation |
|-----------------|------------|
| /plan, plan this, design approach, implementation plan | `Skill({ skill: "plan-mode:planning-methodology" })` |
| unclear, ambiguous, need clarification, missing requirements | `Skill({ skill: "ask-questions-if-underspecified" })` |
| library docs, API reference, how does X work, current docs for *(Prefer mcp__context7__* if MCP configured)* | `Skill({ skill: "context7" })` |

### Implementation
**Triggers:** implement, build, code, write, create feature

| Trigger Phrases | Invocation |
|-----------------|------------|
| TDD, write test first, red-green-refactor, before implementation | `Skill({ skill: "test-driven-development" })` |
| execute plan, parallel tasks, spawn agents | `Skill({ skill: "subagent-driven-development" })` |
| follow plan, implement plan, execute steps | `Skill({ skill: "executing-plans" })` |
| parallel, concurrent tasks, independent tasks, 2+ tasks | `Skill({ skill: "dispatching-parallel-agents" })` |

### Code Quality
**Triggers:** review, quality, clean, refactor, lint, unused

| Trigger Phrases | Invocation |
|-----------------|------------|
| /review, code review, review changes, check my code | `Skill({ skill: "codex-review" })` |
| simplify, cleaner, more readable, reduce complexity | `Skill({ skill: "code-simplifier" })` |
| AI slop, unnecessary comments, defensive checks, clean up generated | `Skill({ skill: "deslop" })` |
| unused, dead code, unused exports, unused dependencies | `Skill({ skill: "knip" })` |
| done?, complete?, verify, before commit, before PR | `Skill({ skill: "verification-before-completion" })` |
| accessibility, WCAG, a11y, visual design review | `Skill({ skill: "rams" })` |

### Security
**Triggers:** security, vulnerability, audit, CVE, OWASP, injection

| Trigger Phrases | Invocation |
|-----------------|------------|
| semgrep, SAST, pattern scan, quick security scan | `Skill({ skill: "semgrep" })` |
| codeql, taint tracking, data flow, deep security analysis | `Skill({ skill: "codeql" })` |
| PR security, diff review, security regression, blast radius | `Skill({ skill: "differential-review" })` |
| similar bugs, bug variants, pattern hunting, find other instances | `Skill({ skill: "variant-analysis" })` |
| SARIF, scan results, aggregate findings, security report | `Skill({ skill: "sarif-parsing" })` |
| footgun, misuse, dangerous API, secure defaults, pit of success | `Skill({ skill: "sharp-edges" })` |

### Debugging
**Triggers:** bug, error, broken, not working, fix, debug

| Trigger Phrases | Invocation |
|-----------------|------------|
| investigate, root cause, why failing, trace error *(Use BEFORE proposing fixes)* | `Skill({ skill: "systematic-debugging" })` |

### Testing
**Triggers:** test, spec, coverage, browser test, e2e

| Trigger Phrases | Invocation |
|-----------------|------------|
| property test, fuzzing, quickcheck, hypothesis, edge cases | `Skill({ skill: "property-based-testing" })` |
| browser, e2e, visual test, screenshot, form fill, web automation | `Skill({ skill: "agent-browser" })` |

### Documentation & Files
**Triggers:** doc, write, spreadsheet, presentation, xlsx, pptx

| Trigger Phrases | Invocation |
|-----------------|------------|
| write doc, proposal, tech spec, decision doc, RFC | `Skill({ skill: "doc-coauthoring" })` |
| .xlsx, spreadsheet, Excel, CSV analysis, formulas | `Skill({ skill: "xlsx" })` |
| .pptx, presentation, PowerPoint, slides | `Skill({ skill: "pptx" })` |
| create skill, new skill, skill development | `Skill({ skill: "writing-skills" })` |
| CLAUDE.md, improve claude config, audit CLAUDE.md | `Skill({ skill: "claude-md-improver" })` |

### Web3 & Smart Contracts
**Triggers:** solidity, smart contract, ERC, blockchain, web3, defi

| Trigger Phrases | Invocation |
|-----------------|------------|
| contract review, solidity best practices, Trail of Bits | `Skill({ skill: "guidelines-advisor" })` |
| Slither, security diagram, fuzzing properties | `Skill({ skill: "secure-workflow-guide" })` |
| ERC20, ERC721, token integration, weird tokens | `Skill({ skill: "token-integration-analyzer" })` |
| fuzzer blocked, checksum, bypass for fuzzing | `Skill({ skill: "fuzzing-obstacles" })` |

### Framework-Specific
**Triggers:** React, Next.js, TypeScript, auth, query

| Trigger Phrases | Invocation |
|-----------------|------------|
| React perf, Next.js, bundle size, SSR, RSC | `Skill({ skill: "vercel-react-best-practices" })` |
| TanStack, React Query, useQuery, useMutation, server state | `Skill({ skill: "tanstack-query" })` |
| generic, conditional type, mapped type, infer, template literal | `Skill({ skill: "typescript-advanced-types" })` |
| Better Auth, auth setup, session, OAuth | `Skill({ skill: "better-auth-best-practices" })` |
| add auth, auth layer, authentication feature | `Skill({ skill: "create-auth-skill" })` |

### Tooling & Meta
**Triggers:** setup, configure, automate, logging

| Trigger Phrases | Invocation |
|-----------------|------------|
| Claude Code setup, hooks, MCP, automation recommendations | `Skill({ skill: "claude-automation-recommender" })` |
| logging, canonical log, wide events, structured logs | `Skill({ skill: "logging-best-practices" })` |
</skill-routing-table>
