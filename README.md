# Handoff Kit

Cross-tool session handoff system for AI coding agents. Seamlessly transfer work between **Cursor**, **Claude Code**, and **Codex** — including plans, progress, context, and gotchas — without losing institutional knowledge.

## The Problem

When you hit token limits, need to switch machines, or want to use a different AI coding tool, you lose all the context: what the task was, what's been done, what failed, what decisions were made. Starting fresh in another tool means rediscovering all of that.

## The Solution

A standardized `handoff.md` file format and matching skills for each tool that handle:

- **Outgoing handoffs** — Generate a `handoff.md` with all context, delivered via SSH, git push, or copy-paste
- **Incoming handoffs** — Read the `handoff.md`, check for staleness, optionally review the work with a stronger model, then continue
- **Partial trust for stale handoffs** — Architecture/gotchas sections stay useful even when progress sections are outdated

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       handoff.md                             │
│  ┌─────────────────────┐  ┌──────────────────────────────┐  │
│  │  DURABLE             │  │  VOLATILE                     │  │
│  │  (always trustworthy) │  │  (must match git state)       │  │
│  │                       │  │                               │  │
│  │  • Architecture       │  │  • Plan + progress            │  │
│  │  • Gotchas            │  │  • Files changed              │  │
│  │  • Repo & access      │  │  • Current state              │  │
│  │  • Key files          │  │  • Next steps                 │  │
│  └─────────────────────┘  └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
           │                              │
     Kept if stale               Reconstructed from git if stale
```

### Incoming Handoff Flow

```
handoff.md exists? ──Yes──► Staleness check (HEAD hash + timestamp)
        │                         │
        No                   Fresh? ──Yes──► Use fully
        │                         │
        ▼                        No (stale)
  Tier 2: Reconstruct             │
  from git + user memory    Partial trust:
        │                   keep durable, discard volatile
        │                         │
        ▼                         ▼
  ┌──────────────────────────────────┐
  │  Review Phase (Claude Code/Codex) │
  │  Stronger model audits incoming   │
  │  plan + code before executing     │
  └──────────────────────────────────┘
                  │
                  ▼
          Continue from step N
```

## What's Included

```
handoff-kit/
├── cursor/
│   └── session-handoff/
│       └── SKILL.md              # Cursor skill (incoming + outgoing)
├── claude-code/
│   ├── agents/
│   │   ├── opus-planner.md       # Planning/review agent (model: opus)
│   │   └── sonnet-executor.md    # Execution agent (model: sonnet)
│   └── skills/
│       ├── session-handoff/
│       │   └── SKILL.md          # Claude Code handoff skill (+ opus review)
│       └── planning-workflow/
│           └── SKILL.md          # Plan → execute → verify workflow
├── codex/
│   ├── agents/
│   │   ├── sol-planner.toml      # Planning/review agent (model: gpt-6-sol)
│   │   └── luna-executor.toml    # Execution agent (model: gpt-6-luna)
│   └── skills/
│       └── session-handoff/
│           └── SKILL.md          # Codex handoff skill (+ sol review)
└── install.sh                    # Symlink installer
```

## Installation

### Quick install (symlinks from repo to config directories)

```bash
./install.sh
```

### Manual install

Copy or symlink the files for the tools you use:

**Cursor:**
```bash
cp -r cursor/session-handoff/ ~/.cursor/skills/session-handoff/
```

**Claude Code:**
```bash
cp claude-code/agents/*.md ~/.claude/agents/
cp -r claude-code/skills/session-handoff/ ~/.claude/skills/session-handoff/
cp -r claude-code/skills/planning-workflow/ ~/.claude/skills/planning-workflow/
```

**Codex:**
```bash
cp codex/agents/*.toml ~/.codex/agents/
cp -r codex/skills/session-handoff/ ~/.agents/skills/session-handoff/
```

## Usage

### Hand off FROM Cursor to Claude Code/Codex

In Cursor, say:
> "Hand off this work to Claude Code on the remote server at `ssh user@host`"

The skill generates `handoff.md` and delivers it via SSH, git push, or shows it for copy-paste.

### Pick up IN Claude Code / Codex

In the receiving tool, say:
> "Pick up where Cursor left off"

The skill reads `handoff.md`, checks for staleness, runs an Opus/Sol review of the incoming **plan and code**, then continues with the executor.

### Hand off FROM Claude Code/Codex back to Cursor

> "Create a handoff for Cursor"

Same flow in reverse.

## Model Mapping

| Role | Claude Code | Codex | Purpose |
|------|-------------|-------|---------|
| Planner/Reviewer | Opus | GPT-6 Sol | Deep reasoning, plan creation, work review |
| Executor | Sonnet | GPT-6 Luna | Follow plans exactly, run verification |

## License

MIT
