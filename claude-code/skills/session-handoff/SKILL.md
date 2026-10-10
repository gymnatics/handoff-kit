---
name: session-handoff
description: >-
  Bidirectional work transfer between AI coding tools (Cursor, Claude Code,
  Codex, or any other). Handles incoming handoffs (pick up work from another
  session, with Opus review of plan and code before continuing) and outgoing
  handoffs (produce a handoff.md with full embedded plan for another session).
  Use when the user mentions handing off, continuing from Cursor, continuing
  from Codex, picking up where they left off, transferring work to or from
  another AI tool, or references a handoff.md or HANDOFF.md file.
disable-model-invocation: false
---

# Session Handoff

Bidirectional work transfer between AI coding tools. Incoming handoffs
include an Opus review phase (plan + code) before the executor continues.

## Handoff File Format

The standardized `handoff.md` lives at the project root. Template:

```
<!-- Generated: YYYY-MM-DDTHH:MM:SS+TZ -->
<!-- Git HEAD: abc1234 -->
<!-- Source: cursor | claude-code | codex -->
# Handoff — [Task Title]

## Original Task
[one-sentence description]

<!-- DURABLE — valid even when progress is outdated -->

## Architecture
[system design, key components, tech stack]

## Repo and Access
[clone path, remote URLs, auth, branch conventions]

## Gotchas
[hard-won lessons, constraints, failed approaches not to retry]

## Key Files
[important files and their purpose]

<!-- VOLATILE — must match current git state to be trusted -->

## Plan

Goal: <one-line goal>

### Steps
1. <action>
   - Files: <paths>
   - Verify: `<exact command>` -- expected: <what success looks like>
   - Status: done | in-progress | not started
2. ...

### Edge cases / risks
- ...

### Final verification
- `<exact command(s)>`

## Files Changed
- path/to/file — what changed

## Current State
[what works, what does not]

## Blockers
[anything stopping progress]

## Next Steps
[what to do next, starting from which step]

## Context
[decisions, constraints for the next session]
```

Sections above the VOLATILE comment stay useful even when stale.
Sections below it must match git state — discard if stale.

## Direction A — Incoming Handoff

### Tier 1: handoff.md exists

1. Check project root for `handoff.md` or `HANDOFF.md`.
2. **Staleness check:**
   - Read `Generated:` timestamp and `Git HEAD:` hash from the metadata.
   - Compare against `git log -1 --format=%ci` and
     `git rev-parse --short HEAD`.
   - If HEAD hash mismatch or mtime predates latest commit, flag as
     **likely stale**.
3. **Always confirm with the user:**
   - Fresh: "Found handoff.md from [time]. Continue this task?"
   - Stale: "This handoff.md looks outdated (written at [time], HEAD was
     [old] but now [new]). Current task or leftover?"
4. If confirmed current -> use fully.
5. If stale -> **partial trust**: keep durable sections (architecture,
   gotchas, access, key files) as background. Discard volatile sections
   (plan progress, next steps). Fall through to Tier 2.

### Tier 2: Reconstruct from evidence

When no handoff.md exists, or volatile sections were discarded as stale:

1. Ask the user to describe the task. Also ask what they remember about
   decisions, failed approaches, and context.
2. Read raw state from the local project:
   - `git log --oneline -10`
   - `git diff` and `git diff --cached`
   - `git branch`
   - `find . -mmin -60 -type f` (recently modified files)
   - Check for plan files, PRD, CLAUDE.md, README
3. Reconstruct task and plan from evidence. Verify with user.
4. Flag uncertainty: "I am inferring step N was done based on git log
   -- confirm?"

### Review Phase (after Tier 1 or 2)

Before continuing with new work, delegate to `opus-planner` for a review
of both the incoming plan AND any implemented code. This catches plan
weaknesses and code issues from token-limited or weaker model sessions
before the executor builds on top of them.

1. Delegate to `opus-planner` with:
   - The handoff context (durable + reconstructed volatile sections)
   - The full embedded plan from the handoff
   - `git diff` of work done since the last known-good state (use the
     Git HEAD from the handoff metadata as the base)
   - Prompt: "Review this incoming work AND its plan from [source tool].
     For the PLAN: check if steps are correctly ordered, verification
     commands are valid for this project, edge cases are covered, and
     nothing critical is missing. For IMPLEMENTED CODE: check for
     correctness issues, missed edge cases, deviations from project
     conventions (see CLAUDE.md). Then either confirm the existing plan
     for remaining steps (if sound) or produce a revised plan with
     corrections."
2. Opus returns one of:
   - **LGTM**: "Plan and code look sound. Remaining steps: [plan]"
   - **Plan issues**: "Plan needs adjustment: [issues]. Revised plan:
     [corrected steps with verification commands]"
   - **Code issues**: "Found N code issues: [list]. Revised plan: fix
     these first, then continue with [remaining steps]"
3. Show the review result to the user for confirmation (same as
   planning-workflow Phase 2 -- confirm before executing).
4. Execute the approved plan using `planning-workflow` Phases 3-5: hand
   it to `sonnet-executor` verbatim plus a context digest (the handoff's
   Gotchas, Context, and Blockers, the review's risks, and any changes
   the user requested), verify in the main thread, and escalate per
   Phase 5 (advisor round, then opus-planner replan) on failure.

### After receiving

- Restate task and plan for confirmation before making changes.
- Never redo completed work — verify via file/git state first.
- Follow the original plan if one exists rather than re-planning.
- Report: "Picking up from step N. Opus review: [LGTM / N issues fixed]."

## Direction B — Outgoing Handoff

When the user wants to continue work in another tool:

1. **Generate handoff.md** from the current session:
   - Original task (from conversation context or CLAUDE.md/PRD)
   - **Full plan**: extract the complete plan from the opus-planner
     output in this conversation — steps with file targets, verification
     commands, edge cases, and assumptions. Embed it verbatim in the
     Plan section. Mark each step status (done/in-progress/not started)
     based on git state and conversation context. If no plan exists in
     the conversation, reconstruct from project state.
   - Files changed (`git diff`, `git log`)
   - Blockers, decisions, context
   - Fill the template above with metadata:
     - `Generated:` — current ISO 8601 timestamp
     - `Git HEAD:` — `git rev-parse --short HEAD`
     - `Source: claude-code`

2. **Deliver the file** — choose based on context (ask user if unclear):
   - **SSH write** (cross-machine, SSH available): write directly to the
     remote project root via SSH.
   - **Git commit+push** (cross-machine, no SSH, shared repo): commit
     with message "[handoff] ..." and push. Tell user to `git pull`.
   - **Local write** (same machine, different tool): save to project root.

3. **Always also show in chat** — display the full handoff in a code
   block for copy-paste regardless of delivery method.

4. Suggest the receiving session "keep handoff.md updated as you work."

## Rules

- handoff.md format is tool-agnostic.
- For outgoing: include enough context for zero prior knowledge.
- Never redo completed work — verify state first.
- Follow the original plan if one exists.
- Report which tier was used, review result, and confidence level.
- The review phase only runs on incoming handoffs, not outgoing.
