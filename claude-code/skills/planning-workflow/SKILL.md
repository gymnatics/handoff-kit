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
Delegate to the `sonnet-executor` subagent with the approved plan **verbatim**. It implements one step at a time and runs that step's verification. It stops at the first failure and reports it.

## Phase 4 — Verify
Once the executor reports all steps done, run the plan's full/final verification command(s) yourself in the main thread and read the output.

## Phase 5 — Escalate (max 2 rounds)
On any failure (executor stop or Phase 4 failure):
1. Send the plan, the step that failed, and the exact failure output to `opus-planner` for diagnosis and a revised plan, covering the remaining or corrected steps.
2. Re-run `sonnet-executor` with the revised plan, then Phase 4 again.

Stop after **2 escalation rounds**. If it is still failing, stop and report to the user: what was done, what failed, the failure output, and the planner's latest diagnosis. Do not loop further.

## Final report
List the files changed, the verification commands run with their results, the number of escalation rounds used, and any unresolved risks.
