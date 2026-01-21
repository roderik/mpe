# Claude

<workflows>
## Development Workflow

Follow this workflow for all implementation tasks. Each phase is mandatory.

### Phase 1: Planning

**Start:** `Skill({ skill: "plan-mode:planning-methodology" })` or `/plan`

1. **Gather context** - `Task({ subagent_type: "plan-mode:context-researcher" })`
2. **Check docs** - `Skill({ skill: "context7" })` - up-to-date library documentation
3. **Non-greenfield?** - `Skill({ skill: "systematic-debugging" })` - understand existing behavior first
4. **Draft plan** - exact file paths, code snippets, 2-5 minute tasks

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
2. `Skill({ skill: "deslop" })` - Remove AI-generated slop
3. `Skill({ skill: "knip" })` - Remove unused code/deps

### Phase 5: Testing

```bash
bun run ci
```

or if not available:

```bash
bun run lint
bun run test
```

1. `Skill({ skill: "agent-browser" })` *(if UI components)*
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
2. Run: `bun run test && bun run lint && bun run build`
3. **Verify exit codes, test counts, no warnings**
4. **If issues: Fix and restart loop**

**Iron Law:** Never claim completion without fresh verification evidence

### Quick Reference

| Phase | Tool | Purpose |
|-------|------|---------|
| Plan | `/plan` | Structure approach |
| Refine | `spec-reviewer + questions` | Perfect the plan |
| Build | `subagent-driven-development` | TDD implementation |
| Clean | `deslop + knip` | Remove cruft |
| Test | `vitest + agent-browser` | Verify behavior |
| Review | `/review` | Quality gate |
| Verify | `verification-before-completion` | Evidence-based completion |
</workflows>

<skill-routing-table>
| When to use | Invocation |
| ----------- | ---------- |
| Clarify requirements before implementing. Use when serious doubts araise. | `Skill({ skill: "ask-questions-if-underspecified" })` |
| Automates browser interactions for web testing, form filling, screenshots, and data extraction. Use when the user needs to navigate websites, interact with web pages, fill forms, take screenshots, test web applications, or extract information from web pages. | `Skill({ skill: "agent-browser" })` |
| Use when implementing any feature or bugfix, before writing implementation code | `Skill({ skill: "test-driven-development" })` |
| Comprehensive token integration and implementation analyzer based on Trail of Bits' token integration checklist. Analyzes token implementations for ERC20/ERC721 conformity, checks for 20+ weird token patterns, assesses contract composition and owner privileges, performs on-chain scarcity analysis, and evaluates how protocols handle non-standard tokens. Context-aware for both token implementations and token integrations. (project, gitignored) | `Skill({ skill: "token-integration-analyzer" })` |
| Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes | `Skill({ skill: "systematic-debugging" })` |
| Retrieve up-to-date documentation for software libraries, frameworks, and components via the Context7 API. This skill should be used when looking up documentation for any programming library or framework, finding code examples for specific APIs or features, verifying correct usage of library functions, or obtaining current information about library APIs that may have changed since training. | `Skill({ skill: "context7" })` |
| Guide users through a structured workflow for co-authoring documentation. Use when user wants to write documentation, proposals, technical specs, decision docs, or similar structured content. This workflow helps users efficiently transfer context, refine content through iteration, and verify the doc works for readers. Trigger when user mentions writing docs, creating proposals, drafting specs, or similar documentation tasks. | `Skill({ skill: "doc-coauthoring" })` |
| Skill for creating auth layers in TypeScript/JavaScript apps using Better Auth. | `Skill({ skill: "create-auth-skill" })` |
| Audit and improve CLAUDE.md files in repositories. Use when user asks to check, audit, update, improve, or fix CLAUDE.md files. Scans for all CLAUDE.md files, evaluates quality against templates, outputs quality report, then makes targeted updates. Also use when the user mentions "CLAUDE.md maintenance" or "project memory optimization". | `Skill({ skill: "claude-md-improver" })` |
| Manage server state in React with TanStack Query v5. Covers useMutationState, simplified optimistic updates, throwOnError, network mode (offline/PWA), and infiniteQueryOptions. Use when setting up data fetching, fixing v4→v5 migration errors (object syntax, gcTime, isPending, keepPreviousData), or debugging SSR/hydration issues with streaming server components. | `Skill({ skill: "tanstack-query" })` |
| Run Semgrep static analysis for fast security scanning and pattern matching. Use when asked to scan code with Semgrep, write custom YAML rules, find vulnerabilities quickly, use taint mode, or set up Semgrep in CI/CD pipelines. | `Skill({ skill: "semgrep" })` |
| Provides guidance for property-based testing across multiple languages and smart contracts. Use when writing tests, reviewing code with serialization/validation/parsing patterns, designing features, or when property-based testing would provide stronger coverage than example-based tests. | `Skill({ skill: "property-based-testing" })` |
| Performs security-focused differential review of code changes (PRs, commits, diffs). Adapts analysis depth to codebase size, uses git history for context, calculates blast radius, checks test coverage, and generates comprehensive markdown reports. Automatically detects and prevents security regressions. | `Skill({ skill: "differential-review" })` |
| Use when facing 2+ independent tasks that can be worked on without shared state or sequential dependencies | `Skill({ skill: "dispatching-parallel-agents" })` |
| Run accessibility and visual design review on components. Use when reviewing UI code for WCAG compliance and design issues. | `Skill({ skill: "rams" })` |
| Run knip to find and remove unused files, dependencies, and exports. Use for cleaning up dead code and unused dependencies. | `Skill({ skill: "knip" })` |
| Techniques for patching code to overcome fuzzing obstacles. Use when checksums, global state, or other barriers block fuzzer progress. | `Skill({ skill: "fuzzing-obstacles" })` |
| Master TypeScript's advanced type system including generics, conditional types, mapped types, template literals, and utility types for building type-safe applications. Use when implementing complex type logic, creating reusable type utilities, or ensuring compile-time type safety in TypeScript projects. | `Skill({ skill: "typescript-advanced-types" })` |
| Comprehensive spreadsheet creation, editing, and analysis with support for formulas, formatting, data analysis, and visualization. When Claude needs to work with spreadsheets (.xlsx, .xlsm, .csv, .tsv, etc) for: (1) Creating new spreadsheets with formulas and formatting, (2) Reading or analyzing data, (3) Modify existing spreadsheets while preserving formulas, (4) Data analysis and visualization in spreadsheets, or (5) Recalculating formulas | `Skill({ skill: "xlsx" })` |
| Parse, analyze, and process SARIF (Static Analysis Results Interchange Format) files. Use when reading security scan results, aggregating findings from multiple tools, deduplicating alerts, extracting specific vulnerabilities, or integrating SARIF data into CI/CD pipelines. | `Skill({ skill: "sarif-parsing" })` |
| Use when you have a written implementation plan to execute in a separate session with review checkpoints | `Skill({ skill: "executing-plans" })` |
| Find similar vulnerabilities and bugs across codebases using pattern-based analysis. Use when hunting bug variants, building CodeQL/Semgrep queries, analyzing security vulnerabilities, or performing systematic code audits after finding an initial issue. | `Skill({ skill: "variant-analysis" })` |
| Run CodeQL static analysis for security vulnerability detection, taint tracking, and data flow analysis. Use when asked to analyze code with CodeQL, create CodeQL databases, write custom QL queries, perform security audits, or set up CodeQL in CI/CD pipelines. | `Skill({ skill: "codeql" })` |
| Presentation creation, editing, and analysis. When Claude needs to work with presentations (.pptx files) for: (1) Creating new presentations, (2) Modifying or editing content, (3) Working with layouts, (4) Adding comments or speaker notes, or any other presentation tasks | `Skill({ skill: "pptx" })` |
| Remove AI-generated code slop from the current branch. Use after writing code to clean up unnecessary comments, defensive checks, and inconsistent style. | `Skill({ skill: "deslop" })` |
| Skill for integrating Better Auth - the comprehensive TypeScript authentication framework. | `Skill({ skill: "better-auth-best-practices" })` |
| Guide you through Trail of Bits' 5-step secure development workflow. Runs Slither scans, checks special features (upgradeability/ERC conformance/token integration), generates visual security diagrams, helps document security properties for fuzzing/verification, and reviews manual security areas. (project, gitignored) | `Skill({ skill: "secure-workflow-guide" })` |
| Use when creating new skills, editing existing skills, or verifying skills work before deployment | `Skill({ skill: "writing-skills" })` |
| Analyze a codebase and recommend Claude Code automations (hooks, subagents, skills, plugins, MCP servers). Use when user asks for automation recommendations, wants to optimize their Claude Code setup, mentions improving Claude Code workflows, asks how to first set up Claude Code for a project, or wants to know what Claude Code features they should use. | `Skill({ skill: "claude-automation-recommender" })` |
| Identifies error-prone APIs, dangerous configurations, and footgun designs that enable security mistakes. Use when reviewing API designs, configuration schemas, cryptographic library ergonomics, or evaluating whether code follows 'secure by default' and 'pit of success' principles. Triggers: footgun, misuse-resistant, secure defaults, API usability, dangerous configuration. | `Skill({ skill: "sharp-edges" })` |
| React and Next.js performance optimization guidelines from Vercel Engineering. This skill should be used when writing, reviewing, or refactoring React/Next.js code to ensure optimal performance patterns. Triggers on tasks involving React components, Next.js pages, data fetching, bundle optimization, or performance improvements. | `Skill({ skill: "vercel-react-best-practices" })` |
| Logging best practices focused on wide events (canonical log lines) for powerful debugging and analytics | `Skill({ skill: "logging-best-practices" })` |
| Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always | `Skill({ skill: "verification-before-completion" })` |
| Simplifies and refines code for clarity, consistency, and maintainability while preserving all functionality. Focuses on recently modified code unless instructed otherwise. | `Skill({ skill: "code-simplifier" })` |
| Use when executing implementation plans with independent tasks in the current session | `Skill({ skill: "subagent-driven-development" })` |
| Comprehensive smart contract development advisor based on Trail of Bits' best practices. Analyzes codebase to generate documentation/specifications, review architecture, check upgradeability patterns, assess implementation quality, identify pitfalls, review dependencies, and evaluate testing. Provides actionable recommendations. (project, gitignored) | `Skill({ skill: "guidelines-advisor" })` |
| Professional code review skill for Claude Code. Automatically collects file changes and task status. Triggers when working directory has uncommitted changes, or reviews latest commit when clean. Triggers: code review, review, 代码审核, 代码审查, 检查代码 | `Skill({ skill: "codex-review" })` |
</skill-routing-table>
