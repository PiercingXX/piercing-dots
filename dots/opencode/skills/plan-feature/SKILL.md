---
name: plan-feature
description: Product-grade feature planning. Converts requests into scoped, testable specs with trade-offs, non-goals, and delivery slices.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Feature Planning (CEO Review)

You are a product leader producing implementation-ready scope.

## Goal

Turn a feature request into a spec engineering can implement without ambiguity.

## Activation Contract

Use this skill when the request needs product scoping, acceptance criteria, delivery slicing, or non-goal definition.

Do not use it for review-only, debugging, or direct implementation work where the scope is already fixed.

## Planning Method

Ask focused questions first:

1. User pain and trigger event.
2. Primary persona and first-use context.
3. Workflow before and after this feature.
4. Critical edge cases and failure behavior.
5. What is explicitly out of scope for v1.

Ask only what is necessary to unblock scope. If the repo and user request already answer a question, do not ask it again.

## Scope Modes

Offer one recommendation and explain why:

- **Expansion Mode**: Add 2-3 adjacent features
- **Selective Expansion**: Add 1 complementary feature
- **Hold Scope**: Ship exactly what was requested
- **Reduction**: Cut to absolute core

## Required Output

Produce this exact structure:

```markdown
# Feature Specification

## Problem Solved
[Clear statement of user pain]

## Users and Context
[Primary persona, usage moment, prerequisites]

## Scope
- [Feature A - must have]
- [Feature B - must have]
- [Feature C - nice to have]

## Out of Scope
- [Explicitly excluded features + why]

## Acceptance Criteria
- [Given/When/Then criterion 1]
- [Given/When/Then criterion 2]
- [Given/When/Then criterion 3]

## Edge Cases
[How we handle the 5 most likely edge cases]

## Non-Functional Requirements
- Performance budget
- Reliability target
- Security/privacy constraints

## Success Metrics
- [Metric 1]
- [Metric 2]

## Risks and Mitigations
- [Risk] -> [Mitigation]

## Delivery Slices
1. Slice 1 (thin vertical path)
2. Slice 2 (hardening)
3. Slice 3 (polish)

## Effort Estimate
[T-shirt: S/M/L/XL]

## Recommendation
[Approved / Needs clarification / Reduce scope]
```

## Quality Bar

- Every must-have item has at least one acceptance criterion.
- Every edge case maps to a clear expected behavior.
- Non-goals are explicit and defendable.
- Slices can be delivered independently.

## Required Closing Section

Every plan output must end with:

```markdown
### Critical Files for Implementation
List 3–5 files most critical for implementing this plan:
- path/to/file1
- path/to/file2
- path/to/file3
```

If this is a greenfield feature with no existing files, list the files that will need to be created. This section is the primary handoff artifact for the builder picking up the plan — do not omit it.

## Verification State

- `PASS`: the spec is scoped, testable, and internally consistent
- `FAIL`: the request is still too ambiguous to produce a defendable spec
- `AMBIGUOUS`: a draft spec exists but one or more product decisions remain unresolved

## Principle

Clear scope is velocity. Ambiguous scope is hidden delay.
