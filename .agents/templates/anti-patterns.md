## Anti-Patterns (Never)

### Workflow Bypass
- Trivial bypass: "task is simple" to skip workflow -> classify first and follow minimum steps.
- Direct implementation: code before `TodoWrite` -> call `TodoWrite({ status: "in_progress" })` first.
- Classification avoidance: no classification before implementation -> state classification before first TodoWrite.

### Skill Failures
- Skill avoidance: no skills loaded -> load at least verification-before-completion.
- Skill mention vs load: "I'll use TDD" without `Skill({ skill: "..." })` call -> actually invoke the tool.
- Checklist theater: listing skills in checklist without invoking Skill() tool -> checklist is not loading.
- Conditional skip: "shell scripts don't need TDD" -> TDD applies to all code, load the skill.
- Implicit knowledge: "I know TDD" without loading -> skill provides specific instructions, load it.

### Gate Failures
- Gate amnesia: output GATE-1, GATE-3, then forget the rest -> output ALL gates for your classification.
- Gate rushing: GATE-N CHECK with all boxes checked without doing the work -> gates verify work, not skip it.
- Proofless checkboxes: `[x] Requirement` without showing evidence -> add `— PROOF: [what you did]`.
- Early gate only: stop at GATE-3 because "implementation is done" -> GATE-4 through GATE-7 still required.
- False pass: marking STATUS: PASS when requirements not met -> BLOCKED until proof shown.

### Phase Skipping
- Phase 2 skip: "requirements are clear" -> ask anyway via `ask-questions-if-underspecified`.
- Phase 6 skip: "code is simple, doesn't need review" -> run `/review` regardless.
- Implicit phases: doing phase work without outputting the gate -> gate output is mandatory.
- Single iteration: doing 1 pass when classification requires 2+ -> track and show iteration count.

### Iteration Failures
- Iteration shortcut: "did 1 iteration, that's enough" for Standard -> Standard requires 2+ iterations.
- Shallow iteration: repeating same check without deepening -> each iteration must add: edge cases, error handling, test strategy.
- Uncounted iterations: not tracking iteration count -> output "Iteration N of M" for each pass.

### Verification Failures
- Unverified completion: claim done without verification -> run `Skill({ skill: "verification-before-completion" })` with evidence.
- Partial verification: "syntax check passed" as full verification -> run project CI if available.
- Stale evidence: "tests passed earlier" -> run fresh verification before completion claim.
- Load without execute: loaded verification skill but never ran it -> execute and show output.

### Evidence Failures
- Implied evidence: "I ran the tests" without showing output -> paste actual command output.
- Exit code assumption: "command succeeded" without checking -> show exit code 0 explicitly.
- Selective evidence: showing passing tests, hiding failures -> show full output.
