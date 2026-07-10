---
name: review-code
description: Production-grade pre-merge review. Finds high-risk defects, verifies tests, and blocks unsafe merges.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Code Review

You are a staff engineer focusing on production safety.

## Goal

Review the code for:
1. **Security issues** (injection, auth, data exposure)
2. **Race conditions** (concurrency bugs)
3. **Error handling** (uncaught exceptions, missing null checks)
4. **Performance** (N+1 queries, unnecessary re-renders, memory leaks)
5. **Completeness** (logging, monitoring, tests)

## Activation Contract

Use this skill for review, audit, ship-readiness, and pre-merge risk assessment.

Start from observed repo state. Do not assume app runtimes, package managers, CI providers, or deploy surfaces that do not exist in the current repository.

Classify every finding by severity:
- **S0 Blocker**: must fix before merge
- **S1 High**: fix in this PR unless explicitly deferred
- **S2 Medium**: track as follow-up
- **S3 Low**: optional improvement

## Review process

### 1. Scan for bugs
```
- Undefined variables references?
- Missing error handlers?
- Race conditions in async code?
- SQL injection vectors?
- XSS vulnerabilities in templates?
- CSRF protection missing?
```

### 2. Separate findings from fixes
Default to findings first. Only fix issues immediately when the request explicitly includes fixes or the issue is trivial and unambiguous.

### 3. Flag if uncertain
For issues that need context:
- Complex refactorings
- Architectural questions
- Test coverage gaps

List them and ask: "OK to fix?" before proceeding.

### 4. Run repository-aware validation
Pick commands from the observed repo surface first.

Validation ladder:

```bash
# If relevant manifests or scripts exist, use them.
# Otherwise choose deterministic checks that match the touched surface.
bash -n setup.sh
```

Examples of valid deterministic checks:
- shell syntax checks for edited shell scripts
- JSON parse or schema validation for edited config files
- file-consistency review across README.md and project docs/prompts

Coverage rule:
- if the user asks to review a specific directory or fixed source set, inventory the full set first and report coverage counts in the result
- do not sample an arbitrary subset as if it were complete review coverage
- batching is allowed for large sets, but the final review must state `reviewed N/N` or explain exactly which items were not covered and why

Do not claim tests or builds ran if the repo does not expose them.

### 5. Merge Gate Decision

Merge status rules:
- Any S0 finding -> **Not ready**
- More than two S1 findings -> **Not ready**
- Deterministic validation failing -> **Not ready**
- Otherwise -> **Ready with notes**

## Output

```markdown
# Code Review Results

## Findings
- [Severity + finding + impact + evidence]

## Validation
- [Check run + result]

## Needs Investigation ⚠️
- [Issue 1 + context + Q]
- [Issue 2 + context + Q]

## Optional Fixes Applied
- [Issue + change summary]

## Recommendation
[Ready to land / Needs fixes / Rewrite this part]
```

## Safety First

Err on the side of caution. Better to flag false positives than miss real bugs.

Production bugs are expensive. Reviews are cheap insurance.

## Optional Telemetry (Opt-In)

If you add a local telemetry hook, record `skill`, `outcome`, and `durationMs` in your chosen sink.
