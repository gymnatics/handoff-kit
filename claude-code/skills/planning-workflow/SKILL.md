---
name: planning-workflow
description: MANUAL-ONLY. Plan-confirm-execute-verify workflow using the opus-planner and sonnet-executor subagents. Run only when the user explicitly invokes it by name (e.g. "/planning-workflow" or "use planning-workflow"). Never apply it automatically to ordinary coding requests.
disable-model-invocation: true
argument-hint: <task description>
---

# Planning workflow

Task: $ARGUMENTS

Run these phases in the main conversation. Do not fork. Subagents cannot spawn other subagents, so this thread does the orchestration.

## Phase 1 — Plan
Delegate to the `opus-planner` subagent with the full task text and any relevant context from this conversation. It returns a numbered plan with:
- implementation steps
- files/modules touched per step
- edge cases and risks
- exact verification command(s), per step and final, inferred from the project

If the planner returns a `NEEDS INPUT` block (e.g. no verification command could be detected), ask the user and re-run the planner with the answer. Do not guess.

## Phase 2 — Confirm
For a non-trivial task (more than one file, behaviour changes, or anything destructive or hard to reverse), show the user the plan and wait for approval before executing. For a trivial task, state the plan briefly and proceed.

## Phase 3 — Execute
Delegate to the `sonnet-executor` subagent with the approved plan **verbatim**, PLUS a short context digest: user approval notes and changes requested at the gate, constraints the user stated in conversation, and the planner's edge cases/risks. Subagents start with fresh context and don't see this conversation, so the digest is the only way these constraints reach the executor. It implements one step at a time and runs that step's verification. It stops at the first failure and reports it.

## Phase 4 — Verify
Once the executor reports all steps done, run the plan's full/final verification command(s) yourself in the main thread and read the output.

## Phase 5 — Escalate (max 2 rounds)
- **Executor stop → Round 1 (advisor):** re-run `sonnet-executor` from the failed step with the plan, the context digest, the exact failure output, and an instruction to consult the advisor before retrying. Then Phase 4. Go to Round 2 if it still fails, if the report shows `Advisor consulted: no`, or if the advisor is unavailable (it is experimental and Anthropic-API only; configured via `advisorModel` in settings).
- **Phase 4 (final verification) failure:** skip Round 1 and go straight to Round 2, because there is no single step to retry and an unguided fix invites improvising.
- **Round 2 (replan):** send the plan, the failed step, the exact failure output, and the round-1 report if any, to `opus-planner` for diagnosis and a revised plan covering remaining/corrected steps. Re-run `sonnet-executor` with it (plus the digest), then Phase 4.

Stop after Round 2. If still failing, report to the user: what was done, what failed, the failure output, the advisor's guidance if any, and the planner's latest diagnosis. Do not loop further.

## Final report
List the files changed, the verification commands run with their results, the number of escalation rounds used, which escalation path was used, whether the advisor was consulted, and any unresolved risks.
