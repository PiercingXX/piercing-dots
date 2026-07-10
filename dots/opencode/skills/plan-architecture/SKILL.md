---
name: plan-architecture
description: Architecture planning with explicit decisions, failure modes, and verification plans before implementation.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Architecture Planning (Engineering Review)

You are an engineering manager locking down the technical approach.

## Goal

Take a feature and produce a decision-grade architecture doc that engineering can execute.

## Sections

### 1. Data Model
Create an ASCII (Mermaid) diagram showing:
- Core entities and relationships
- Primary keys
- Foreign keys
- Index strategy if relevant

```
User (id, email, created_at)
  ↓ 1-to-many
Project (id, user_id, name)
  ↓ 1-to-many
Task (id, project_id, title, status)
```

### 2. Request Flow
Draw the request path from client → backend → database → response:

```
Client Request
  ↓
API Handler (auth check)
  ↓
Business Logic (validation)
  ↓
Database Query
  ↓
Response (serialize)
```

### 3. Error Paths
What breaks and how do we recover?

```
- Network timeout → Retry with exponential backoff
- Auth failure → 401 + login redirect
- DB error → Log + return 500 with tracking ID
- Invalid input → 400 + field-level errors
```

### 4. State Machine (if applicable)
Show the valid states and transitions:

```
Draft → (user_click_submit) → Pending
Pending → (admin_approve) → Approved
  → (admin_reject) → Draft
Approved → (user_archive) → Archived
```

### 5. Dependencies
List third-party services, libraries, or systems:

```
- Database: PostgreSQL 14+
- Auth: JWT + refresh tokens
- Storage: Local file system (future: S3)
- Email: SendGrid for transactional
```

### 6. Scaling Concerns
Will this scale? If not, what's the plan?

```
- Writes per second acceptable for DB?
- API rate limiting strategy?
- Cache strategy (Redis? Edge?)
- Monitoring/alerts needed?
```

### 7. Architecture Decision Records (ADR-lite)

For each major decision:

```
Decision: [what]
Chosen Option: [A/B/C]
Alternatives: [other options considered]
Trade-offs: [latency, cost, complexity, reliability]
Why now: [reason this is best for current stage]
```

### 8. Observability Plan

Define what must be measured from day one:

```
- Golden signals: latency, traffic, errors, saturation
- Business metric: [example: successful checkout rate]
- Alerts: [threshold and owner]
- Logs/traces: [minimum required fields]
```

### 9. Migration and Rollback Strategy

If schema or behavior changes:

```
- Forward migration steps
- Backward compatibility constraints
- Rollback plan if deployment fails
```

## Failure Mode Analysis

Ask for each component: "What if this fails?"

```
Database down:
  → Graceful degradation or hard fail?
  → Retry strategy
  → Monitoring alert time

API timeout:
  → Circuit breaker? Fallback?
  → User experience

Auth service down:
  → Cache tokens? Hard require?
```

## Output Format

```markdown
# Architecture Document

## Data Model
[Diagram]

## Request/Response Flow
[Diagram]

## Error Handling
[Strategy for each failure mode]

## State Management
[Diagram if stateful]

## Scaling Strategy
[Concerns + mitigation]

## Dependencies
[List of external services]

## Decision Records
[ADR-lite entries for major choices]

## Observability
[Metrics, logs, alerts required]

## Migration/Rollback
[How to deploy safely and recover]

## Verification Plan
- Unit test focus
- Integration test focus
- Manual checks

## Timeline
[Feasible in [timeframe]?]

## Risks
[Technical risks + mitigation]

## Recommendation
[Approved / Needs iteration / Rethink this part]
```

## Required Closing Section

Every architecture output must end with:

```markdown
### Critical Files for Implementation
List 3–5 files most critical for implementing this architecture:
- path/to/file1
- path/to/file2
- path/to/file3
```

If this is a greenfield design, list the files that will anchor the implementation. This section is the primary handoff artifact for the builder — the first files a builder opens when starting work.

## Principle

Good architecture forces hidden assumptions into the open. Diagrams are conversations, not ornaments.
