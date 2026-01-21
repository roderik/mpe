## Hard Requirements (No Exceptions)

**ALWAYS**
- `TodoWrite({ status: "in_progress" })` before any implementation code.
- `TodoWrite({ status: "completed" })` after implementation.
- Load skills via `Skill({ skill: "name" })` tool call - listing is not loading.
- Output EVERY gate check (GATE-1 through GATE-7) - not just first few.
- Provide verification evidence (command output/test results with exit code 0) before claiming done.
- Use at least one skill per implementation task (minimum: verification-before-completion).
- Immediately after classification, output the Classification Checklist.

**NEVER**
- Skip phases/gates because "simple" or "trivial".
- Skip Phase 2 (Plan Refinement) or Phase 6 (Review) - commonly forgotten.
- Write production code before TodoWrite.
- Claim completion without evidence.
- Skip skills or "acknowledge" them without loading via Skill() tool.
- Say "Done", "should work", or "looks good" without evidence.
- Proceed past a gate without meeting requirements.
- Stop outputting gates after the first few pass.
- Check a gate box without showing proof in that same message.

### Skill Loading (MANDATORY)

**Checklist is not loading.** You must invoke `Skill({ skill: "name" })` tool.

Before GATE-3, you MUST have tool invocations for:
```
Skill({ skill: "test-driven-development" })
Skill({ skill: "verification-before-completion" })
```

If Standard/Complex, also before GATE-2:
```
Skill({ skill: "ask-questions-if-underspecified" })
```

**Self-check:** Search your context for `<invoke name="Skill">`. If not found, you have not loaded skills.

### Classification Checklist (MANDATORY)

Output immediately after classification:

```
CLASSIFICATION: [Trivial|Simple|Standard|Complex]

REQUIRED SKILLS (load before implementation):
- [ ] verification-before-completion (ALL tasks)
- [ ] [skill-2 if applicable]
- [ ] [skill-3 if applicable]

REQUIRED PHASES:
- [ ] Phase 1: Planning
- [ ] Phase 3: Implementation
- [ ] Phase 7: Verification
- [ ] [additional phases per classification]

ITERATIONS: Plan Refinement [1|2|5+] | Review [1|2|5+] | Verification [1|2|5+]
```

### Phase Gates (MANDATORY - ALL OF THEM)

Before each phase, output a gate check. Do not proceed if BLOCKED. Do not skip gates.

⚠️ **Gate amnesia is a failure mode.** You must output EVERY applicable gate, not just early ones.

⚠️ **Gate rushing is a failure mode.** Each checked box requires proof in the same message.

Gate requirements:
- GATE-1 Planning: classification stated + checklist output.
- GATE-2 Plan Refinement: `ask-questions-if-underspecified` loaded + questions asked OR explicit justification.
- GATE-3 Implementation: Skill() tool calls visible in context for TDD + verification.
- GATE-4 Cleanup: all implementation todos complete.
- GATE-5 Testing: test output with exit code shown.
- GATE-6 Review: `/review` or `Skill({ skill: "review" })` output shown.
- GATE-7 Verification: `verification-before-completion` execution output shown.
- GATE-DONE Completion: all evidence compiled.

Gate format (use verbatim):
```
GATE-[N] CHECK:
- [x] Requirement 1 — PROOF: [what you did]
- [x] Requirement 2 — PROOF: [what you did]
- [ ] Requirement 3 (BLOCKED: reason)

STATUS: PASS | BLOCKED
```

### Pre-Completion Gate

Before saying "done" or "complete", confirm evidence for:
- TodoWrite start
- Classification + checklist
- All gates output (count them: did you output GATE-1 through GATE-7?)
- Phase 2 executed (not skipped) — show questions asked
- Phase 6 executed (not skipped) — show review output
- Required skills loaded via Skill() tool (not just mentioned) — search for `<invoke name="Skill">`
- Verification skill executed (not just loaded)
- Verification command exit code 0

**Banned phrases:** "looks good", "should work", "Done!", "that's it", "requirements are clear"

**Required completion format:** evidence summary + verification output + gates passed list + iteration counts
