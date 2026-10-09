---
name: session-handoff
description: >-
  Bidirectional work transfer between AI coding tools (Cursor, Claude Code,
  Codex, or any other). Handles both incoming handoffs (pick up work from
  another session) and outgoing handoffs (produce a handoff.md for another
  session to continue). Use when the user mentions handing off, continuing
  from Claude Code, continuing from Codex, picking up where they left off,
  transferring work to or from another AI tool, passing work to another
  session, says "session handoff", or references a handoff.md or HANDOFF.md
  file. Also trigger when the user asks to continue work from a remote
  machine, SSH session, remote server, or another device.
disable-model-invocation: false
---

# Session Handoff

Bidirectional work transfer between AI coding tools. Two directions, two
tiers for incoming.

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
[what works, what doesn't]

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

1. Check project root for `handoff.md` (local, or via SSH).
2. **Staleness check:**
   - Read `Generated:` timestamp and `Git HEAD:` hash from the metadata
     header.
   - Compare against current `git log -1 --format=%ci` and
     `git rev-parse --short HEAD`.
   - If the HEAD hash doesn't match or mtime predates the latest commit,
     flag as **likely stale**.
3. **Always confirm with the user:**
   - Fresh: "Found handoff.md from [time]. Continue this task?"
   - Stale: "This handoff.md looks outdated (written at [time], HEAD was
     [old] but now [new]). Current task or leftover?"
4. If confirmed current → use fully, continue from first incomplete step.
5. If stale → **partial trust**: keep durable sections (architecture,
   gotchas, access, key files) as background context. Discard volatile
   sections (plan progress, next steps, current state). Fall through to
   Tier 2 to reconstruct current progress from git.

### Tier 2: Reconstruct from evidence

When no handoff.md exists, or volatile sections were discarded as stale:

1. Ask the user to describe the task — even one sentence. Also ask what
   they remember about decisions made, failed approaches, and anything
   the next session should know.
2. If SSH is available, read raw state:
   - `git log --oneline -10`
   - `git diff` and `git diff --cached`
   - `git branch`
   - `find . -mmin -60 -type f` (recently modified files)
   - Optionally, conversation transcripts:
     - Claude Code: `~/.claude/projects/*/conversations/*.jsonl`
     - Codex: `~/.codex/` (confirm path with user)
     - Cursor: `~/.cursor/projects/*/agent-transcripts/*.jsonl`
3. If no SSH, ask the user to paste `git log` and `git diff` output, or
   just describe what they remember.
4. Reconstruct task and plan from all evidence. Verify with user.
5. Flag uncertainty explicitly: "I'm inferring step N was done based on
   the git log — confirm?"

### After receiving (both tiers)

- Restate task and plan for confirmation before making changes.
- Never redo completed work — verify via file/git state first.
- Follow the original plan if one exists rather than re-planning.
- Report: "Picking up from step N of the original plan."

## Direction B — Outgoing Handoff

When the user wants to continue work in another tool:

1. **Generate handoff.md** from the current session:
   - Original task (from conversation context)
   - **Full plan**: read the active plan from `.cursor/plans/*.plan.md`
     (most recently modified). Extract the complete plan — steps with
     file targets, verification commands, edge cases, and assumptions.
     Embed it verbatim in the Plan section. Mark each step's status
     (done/in-progress/not started) based on git state and conversation
     context. If no plan file exists, reconstruct from conversation.
     For Claude Code, extract the plan from the opus-planner's output
     in the conversation. For Codex, from the sol-planner's output.
   - Files changed (`git diff`, `git log`)
   - Blockers, decisions, context
   - Fill the template above with metadata:
     - `Generated:` — current ISO 8601 timestamp
     - `Git HEAD:` — `git rev-parse --short HEAD`
     - `Source:` — which tool produced it

2. **Deliver the file** — choose based on context (ask user if unclear):
   - **SSH write** (cross-machine, SSH available): write directly to the
     remote project root via SSH. Best for common case (e.g. Cursor on
     laptop to Claude Code on a remote server). Ask user for SSH host and project
     path if not already known from an earlier incoming handoff.
   - **Git commit+push** (cross-machine, no SSH, shared repo): commit
     handoff.md with message "[handoff] ..." and push. Tell the user to
     `git pull` on the other side.
   - **Local write** (same machine, different tool): save to project root.

3. **Always also show in chat** — display the full handoff in a code
   block so the user can copy-paste manually regardless of delivery
   method. This is the fallback if SSH/git aren't available.

4. Suggest the user ask the receiving session to "keep handoff.md updated
   as you work" so the cycle continues.

## Rules

- handoff.md format is tool-agnostic — works for any AI coding tool.
- For outgoing: include enough context that someone with zero prior
  knowledge can pick up.
- Never redo completed work — verify state first.
- Follow the original plan if one exists.
- Report which tier was used and confidence level.
