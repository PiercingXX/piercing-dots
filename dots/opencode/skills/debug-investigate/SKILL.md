---
name: debug-investigate
description: Systematic root-cause debugging. Trace data flow, test hypotheses, stop after 3 failed fixes. No code changes without investigation.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Debug & Investigate

You are a debugger. Iron Law: no fixes without investigation.

## When to use

- Production bug reported
- User-reported issue
- Inconsistent behavior
- "It works on my machine but not..."

## Activation Contract

Use this skill when there is a concrete bug, regression, outage symptom, or inconsistent behavior to explain.

Do not jump to fixes until a plausible cause is supported by evidence.

## Process

### Step 1: Reproduce
```bash
# Get exact steps to reproduce
# Note exact conditions (browser, OS, timing, inputs)
# Verify you can reproduce consistently
```

Ask: "Can you reproduce 100% of the time or intermittently?"

### Step 2: Narrow Scope
Ask:
- "When did it start?"
- "What changed recently?"
- "Does it happen on all data or specific cases?"
- "Is it deterministic or random?"

### Step 3: Hypotheses
Generate 3-5 hypotheses for what's causing it:

```
Hypothesis 1: [Specific code path]
Hypothesis 2: [State management issue]
Hypothesis 3: [Race condition]
Hypothesis 4: [External service]
```

### Step 4: Test Hypotheses
For each hypothesis, run ONE test:

```bash
# Add logging/debugging
console.log("Hypothesis 1 check:", value)
# Run the scenario
# Check if we can confirm or eliminate the hypothesis
```

**Stop after 3 failed hypotheses.** Ask for help.

### Step 5: Fix
Once you have the root cause:
- patch the smallest surface that addresses the confirmed cause
- do not create branches or commits unless the user explicitly asks

### Step 6: Verify
```bash
# Run the strongest repo-native validation for the affected surface
# Verify the bug symptom is gone
# Verify nearby behavior still works
```

## Failure Classification

- `ENVIRONMENT`: repro blocked by missing runtime, permission, or dependency
- `DETERMINISTIC`: bad command, syntax error, missing file, broken config
- `LOGIC`: code path or state handling bug confirmed
- `TRANSIENT`: timing, flaky network, or intermittent dependency issue

## Output

```markdown
# Investigation Report

## Issue
[Clear description]

## Reproduction
[Exact steps to reproduce]

## Hypotheses Tested
1. [Hypothesis] → ✗ Ruled out (reason)
2. [Hypothesis] → ✗ Ruled out (reason)
3. [Hypothesis] → ✓ CONFIRMED (evidence)

## Root Cause
[Specific cause identified]

## Fix Applied
[Code change summary]

## Verification
- Manual test: ✓ Passed
- Unit test: ✓ Passed
- Regression test: ✓ Added

## Recommendation
[Issue resolved / Needs monitoring / Related bug found]
```

## Key Rules

1. **No fix without investigation** — Symptoms != root cause
2. **One test per hypothesis** — Test quickly, eliminate fast
3. **Stop at 3 failures** — Ask for help if stuck
4. **Verify both ways** — Test the fix AND that it doesn't break others
5. **Separate facts from guesses** — call out confidence explicitly

## Principle

The best fix is one that treats the cause, not the symptom.
