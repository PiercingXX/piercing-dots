---
name: reflect-retrospective
description: Post-project retrospective. What went well? What was hard? What to do differently? Extract lessons learned for next time.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Retrospective & Lessons Learned

You are a facilitator. Your job is to help the team reflect on what happened and extract lessons for next time.

## Activation Contract

Start from the actual delivery surface.

- If the work was a feature, use feature/project retrospective language.
- If the work was an outage or regression, use incident/post-mortem language.
- If the repo is docs/config/setup-oriented, reflect on decision quality, tooling, review flow, and delivery friction instead of inventing production metrics or customer impact.
- Treat all timelines, metrics, and action items below as examples to adapt to the real scope and evidence.

## When to use

- Project shipped (demo day, launch, sprint end)
- Major incident happened (post-mortem)
- Team learning session
- Feature completed
- Quarter/year review

## Quick Retro (30 minutes)

For small projects or features:

```
Setup: 5 min
- Gather the team (who was involved?)
- Set tone: This is blame-free. We're learning.

Went Well: 10 min
- What are we proud of?
- What surprised us (good)?
- What did we learn?
- Go around the room. Each person says 1-2 things.

Went Badly: 10 min
- What was hard?
- What surprised us (bad)?
- What slowed us down?
- Again, go around. This is where the real learning is.

Action Items: 5 min
- From the "went badly" list, pick 2-3 things to fix for next time
- Assign someone to each item
- Make them specific: "Add type checking to CI" not "Better testing"
```

## Full Retro (1-2 hours)

For shipped projects or completed delivery milestones:

### Part 1: Timeline (15 min)

Draw a timeline on a whiteboard:

```
Week 1        Week 2        Week 3        Week 4
[Planning] → [Building] → [Testing] → [Launch]
   ✓           ✓ 😱           ✓          ✓
      Smooth    Crisis!    Recovery     Success
```

Mark:
- ✓ Things that went well
- 😱 Problems or unexpected events
- ⚠️  Things you worried about

This gives everyone a shared memory.

### Part 2: What Went Well (30 min)

For each success, dig deeper:

```
WHAT: "We shipped on time"
WHY:  "Team stayed focused"
HOW:  "Daily standup + blocking issues list"
KEEP: "Continue daily standups"
```

Go deep. Don't just list. Understand the root.

### Part 3: What Was Hard (30 min)

For each difficulty:

```
WHAT:     "Database migrations took 2 weeks"
WHY:      "Didn't plan schema upfront"
ROOT:     "No technical design review step"
PREVENT:  "Add architecture review before coding"
NEXT:     "Architect will review all schema changes before implementation"
```

This is the gold. This is where you prevent future pain.

### Part 4: Surprised (15 min)

What did you not expect?

```
Positive surprises:
- Team learned TypeScript faster than expected
- User feedback was super positive
- Performance was better than we thought

Negative surprises:
- Dependency caused unexpected issues
- Browser compatibility nightmare
- Customer wanted different feature than we built
```

### Part 5: Metrics (10 min)

Look at the numbers:

```
Time tracking:
- Estimated 4 weeks → Actual 6 weeks (Why? Schema changes took longer)
- Feature A: 30 hours → Feature B: 5 hours (Why the difference?)

Quality:
- Example: bugs found before release vs after release
- Example: test or review coverage trend if the repo exposes it

Team:
- Burnout: Did anyone work > 60 hours/week? (Red flag)
- Learning: Did everyone level up? (Good sign)
```

### Part 6: Action Items

Pick 3 things to change for next time. Make them specific:

```
NOT:  "Better testing next time"
YES:  "Require 80% test coverage before code review. QA has final say."

NOT:  "Communicate more"
YES:  "Daily 9am standup, 15 min max. Blockers get escalated immediately."

NOT:  "Plan better"
YES:  "Architecture design review meeting. Sign-off before coding starts."
```

Assign owners:

```
Item 1: Add code coverage requirement
  Owner: @lead-engineer
  Due: Before next project
  Success: "New projects start at 80% coverage, stay above 85%"

Item 2: Implement architecture review step
  Owner: @architect
  Due: Next sprint
  Success: "All new services have signed-off design doc before coding"

Item 3: Setup automated performance testing
  Owner: @qa-lead
  Due: Within 2 weeks
  Success: "CI rejects deployments that degrade p95 latency by > 10%"
```

## Post-Mortem (When Something Broke)

Use this for incidents or major failures:

### Step 1: Timeline of Events

```
14:00 - Change released or merged
14:05 - Failure signal detected
14:07 - Scope and impact triaged
14:10 - Owners engaged
14:15 - Root cause identified
14:20 - Mitigation or rollback initiated
14:25 - Service or workflow recovered
14:30 - Recovery confirmed
15:00 - Post-mortem started
```

### Step 2: Root Cause

Ask "Why?" five times:

```
Q: Why did login fail?
A: Token validation code returned wrong error.

Q: Why did code return wrong error?
A: Condition checking was inverted (should be "is valid" not "not valid").

Q: Why did tests not catch this?
A: Tests only checked happy path, not the error conditions.

Q: Why no test for error condition?
A: No test requirement for error paths in code review.

Q: Why no requirement?
A: Testing guidelines weren't enforced.
```

Root cause → "Lack of error condition test requirements"

### Step 3: Impact

```
Duration: [actual duration]
Affected surface: [users / internal workflow / docs consumers / release pipeline]
Business or delivery impact: [actual impact]
Severity: [actual severity]
```

### Step 4: Immediate Fix

```
What we did: Reverted the commit
Why it worked: Restored previous token validation logic
Time to fix: 5 minutes (rollback + re-deploy)
```

### Step 5: Preventive Measures

```
SHORT-TERM (Do immediately):
- Add test for token validation error conditions
- Require error path tests in code review

MEDIUM-TERM (Do next sprint):
- Audit all authentication code for similar issues
- Add pre-deployment security review

LONG-TERM (Do next quarter):
- Implement canary deployment (5% before 100%)
- Add automated performance tests
```

## Output Format

### Quick Retro

```markdown
# Retro: [Project Name]

## Went Well
- Built feature on time (team coordination)
- Performance exceeded expectations
- Customer very happy with UX

## Went Badly
- Database schema changes took 2x planned time
- Dependency had unexpected bugs
- Mobile testing discovered late

## Action Items
1. Add architecture review before coding (next project)
2. Require mobile testing in QA step (effective immediately)
3. Test dependencies before committing to them (new team rule)

## Quotes
"The daily standup kept us focused"
"We should have designed the schema with the customer first"
```

### Full Retro

```markdown
# Retrospective: Project [Name]

## Timeline
[Whiteboard drawing or text timeline]

## What Went Well
1. [Item] → [Root cause of success] → [Keep doing]
2. ...

## What Was Hard
1. [Item] → [Root cause] → [Prevent next time by...]
2. ...

## Metrics
- Time: Estimated 4w → Actual 6w (2w schema changes)
- Coverage: 45% → 60%
- Bugs: 23 (testing) → 150 (production) [Too fast?]
- Team: 0 burnouts, 100% level up

## Action Items
1. [Item] - Owner: [Name] - Due: [Date]
2. [Item] - Owner: [Name] - Due: [Date]
3. [Item] - Owner: [Name] - Due: [Date]
```

### Post-Mortem

```markdown
# Post-Mortem: Login Service Outage

## Timeline
14:00 - Deploy, 14:05 - Failure, 14:20 - RCA, 14:25 - Recovered

## Root Cause
Inverted token validation condition + lack of error path tests

## Impact
25 min outage, 8% of users affected, ~$5K revenue loss

## Immediate Fix
Reverted commit, restored service

## Preventive Measures
- SHORT: Add error path tests
- MEDIUM: Audit all auth code
- LONG: Implement canary deployment
```

## Key Rules

1. **Blame-free** — Focus on systems, not people
2. **Go deep** — "It was hard" is not enough. Why was it hard?
3. **Write it down** — Lessons vanish if not documented
4. **Track action items** — Nothing changes without follow-up
5. **Celebrate wins** — Equally important to identify problems

## Principle

The team that reflects together, learns together, and ships better code next time.
