# Global Agent Rules

These conventions apply to every agent and every project unless a project-level
`AGENTS.md` overrides them.

---

## 1) Runtime Environment

- Treat the current message as the active task. Do not revive prior-turn
  objectives unless the user restates them.
- Use the current host model by default. Model selection is a host concern;
  switch models only when the task needs capabilities the current model
  cannot provide.

---

## 2) Agent Roster

### Primary Entry Points

| Agent | Role | Scope |
|---|---|---|
| `execution-orchestrator` | Primary entry point. Deterministic plan-exec harness. | Orchestration, complex multi-step work |
| `build` | Implementation agent. | Feature execution, code changes, quality gates |
| `fast-build` | Speed lane. | Small, obvious, single-surface tasks |
| `plan` | Planning agent. No file edits. | Specs, decomposition, architecture plans |

### Specialist and Support Agents

| Agent | Role | Scope |
|---|---|---|
| `architect` | Architecture specialist. | Failure-aware design options and implementation planning |
| `deep-thinker` | Deep reasoning specialist. | Architecture decisions, security, risk analysis |
| `reasoning-fast` | Lower-latency reasoning lane. | Medium-complexity planning and analysis |
| `research` | Read-heavy research specialist. | Repo mapping, dependency impact, evidence gathering |
| `reviewer` | Review specialist. | Production bug/security/test gap review |
| `qa-lead` | QA specialist. | Journey verification and release-risk validation |
| `release-manager` | Release orchestration. | CI gates, deploy, post-deploy verification |
| `incident-commander` | Incident response lead. | Triage, containment, rollback, postmortem |
| `performance-engineer` | Performance specialist. | Regression analysis, optimization, cost/perf review |
| `design-engineer` | Design artifact specialist. | Prototypes, design systems, decks, dashboards |
| `rust-rewrite` | Rewrite specialist. | Rust migration and compile/test repair loops |
| `model-trainer` | Training specialist. | Model tuning and knowledge injection workflows |

---

## 3) Multi-Agent Dispatch Protocol

Two modes exist for routing work to another agent. Choose based on how many
specialists are needed.

### Accountable Delegation (default)

Use when a specialist can execute part of the work, but the current agent
still owns end-to-end completion.

- The specialist gets the relevant slice and returns structured results.
- The current agent merges those results, checks gates, and decides the next
  action.
- **Rule: do not assume host-level agent transfer preserves execution state.**
  Unless the runtime proves native handoff and the user explicitly wants to
  switch agents, stay accountable in the current agent.

### True Handoff (explicit and rare)

Use only when both conditions are met:

- the active runtime proves native agent handoff as a real control-flow primitive
- the user explicitly wants to switch ownership to another agent

If either condition is not satisfied, use Accountable Delegation instead.

### Parallel Delegation (two or more independent subtasks)

Use when two or more specialist subtasks can run simultaneously and their
outputs must be merged.

- Dispatch the subagents in parallel; collect outputs and synthesize a unified result.
- Never use parallel delegation for a single-specialist task merely to simulate handoff.
- Concurrency cap: maximum 3 parallel subagents per dispatch.
- Spawn depth cap: maximum 2 levels deep.

### Delegated Result Contract

Every delegated subtask must return a compact, mergeable result block:

```markdown
## Summary
- ...

## Facts
- ...

## Touched Files
- path or `None`

## Verification
- command/check -> result

## Open Questions
- ... or `None`
```

Rules:

- `Facts` contains only observed evidence, not guesses.
- `Verification` records deterministic checks when they exist; if none exist, say why.
- Use `None` rather than omitting an empty section.
- Parent agents merge child results from this structure rather than paraphrasing from memory.

### Planning and Reasoning Routing

| Agent | Default use |
|---|---|
| `plan` | Scoped feature/spec planning and executable plan packages |
| `architect` | Architecture options, structural design choices |
| `reasoning-fast` | Medium-complexity trade-off requests where low latency matters |
| `deep-thinker` | Ambiguous, high-stakes, or multi-trade-off reasoning |

---

## 4) Workflow State

For orchestrated or multi-session work, keep planning, decisions, status, and
outputs in a project-local `WORKFLOW_STATE.md` (or a todo/plan file the user
names) instead of relying on chat history. Update it every iteration so the
next session or agent can resume from disk.

---

## 5) Out-of-Scope Requests

When a request arrives that belongs to a different agent:

1. **Do not attempt the task.** Do not produce partial work or guess.
2. **State what you handle** and which agent owns the request.
3. **Do not ask for confirmation.** Use accountable delegation by default.
4. **Do not stop after naming the owner agent.** Either complete the work,
   delegate a bounded slice and continue, or perform an explicit handoff when
   the runtime supports it.

---

## 6) Ignore Files And Context Boundaries

Respect ignore files before broad search, indexing, or packaging:

1. `.gitignore`
2. tool-native excludes configured by the active host

Ignore generated artifacts, caches, vendored dependencies, secrets, build
outputs, and bulky media unless the task explicitly targets them.

---

## 7) Prompt-Caching Policy

Altering context mid-conversation forces cache invalidation and increases
token cost. Do not change system prompts, tool definitions, or toolsets
mid-conversation, and do not reload memory or rebuild agent context within an
active turn. If a command would mutate system-prompt state, default to
deferred effect (next session) unless the user explicitly wants it now. The
only acceptable in-flight context modification is an explicit context
compression step.

---

## 8) File Delivery

- When you create or modify files, always include the file paths in your response.
- Do not paste large file contents into chat unless the user explicitly asks
  for raw source; prefer a brief completion summary with paths.

---

## 9) Design Content Pack

Design assets live in the global config directory:

- `~/.config/opencode/design/design-systems/` — brand `DESIGN.md` files
- `~/.config/opencode/design/design-skills/` — aesthetic style `SKILL.md` + `DESIGN.md` pairs
- `~/.config/opencode/design/DESIGN-CATALOG.md` — full index
- design workflow skills (web-prototype, dashboard, simple-deck, …) are
  installed as regular skills in `~/.config/opencode/skills/`

Use `design-engineer` or the `design-prototype` skill for design artifact work.
