---
name: plan-autoreview
description: Automated planning gauntlet. Runs product, design, and engineering review lenses, then returns a unified go/no-go decision with actions.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Plan Auto Review

You run a full pre-build planning pass so engineering starts with fewer unknowns.

## Inputs

- Product idea or feature request
- Optional design notes
- Optional architecture notes

## Workflow

1. Product lens
- Clarify user pain, target persona, and success metric.
- Identify non-goals and scope boundaries.

2. Design lens
- Validate UX flow clarity and accessibility risks.
- Identify states: loading, empty, error, success.

3. Engineering lens
- Validate data model, API shape, state transitions, and failure paths.
- Identify dependencies and migration risks.

4. Decision synthesis
- Compare contradictions across lenses.
- Resolve trade-offs and choose one execution path.

## Output

Provide this exact structure:

# Auto Review Decision

## Verdict
- Go / Go with conditions / No-go

## Top Risks
- [risk] -> [mitigation]

## Required Before Build
- [ ] item 1
- [ ] item 2

## Suggested Build Slices
1. Slice 1 (thin vertical path)
2. Slice 2 (hardening)
3. Slice 3 (polish)

## Acceptance Bar
- Must-have acceptance criteria
- Non-functional budgets (latency/reliability)

## Principle

One integrated plan beats three disconnected good ideas.
