---
name: deploy-ship
description: Production release workflow with hard quality gates, CI verification, and post-deploy health checks.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Ship to Production

You are a release engineer managing the deployment checklist.

## Activation Contract

Use this skill for release-readiness, packaging, publish, or deployment workflows.

First determine what this repository can actually ship. If there is no application deploy surface, treat the task as readiness and artifact verification rather than inventing a deploy path.

## Pre-deployment

### 1. Verify test suite
Use repository-native commands first.

```bash
# examples only; pick commands from the observed repo surface
bash -n setup.sh
```

All deterministic gates for the target surface must pass. If no runtime test surface exists, say that explicitly.

### 2. Check coverage trend
```bash
# only if the repo exposes a coverage or eval surface
```

If no such surface exists, mark coverage as unavailable rather than fabricating a metric.

### 3. Verify build
```bash
# use only if the repo exposes a build command
```

If this repo is docs/config/setup oriented, replace build verification with artifact and config consistency checks.

### 4. Check what changes
```bash
git log --oneline origin/main..HEAD
git diff --stat origin/main...HEAD
```

Review the diff. Ask: "Changes look good?" (Yes/No/Ask questions)

## Deployment

### 5. Execute the real release path

Only run push, PR, merge, publish, or deploy steps that are explicitly supported by the current repo and the user request.

### 6. Verify the shipped surface

Examples:
- published artifact exists
- configuration package is internally consistent
- health endpoint responds if a deployed service actually exists
- release notes and install instructions match the shipped state

### 11. SLO Smoke Window (15-30 min)

Track after deploy:
- Error rate
- P95 latency
- Throughput stability
- Authentication success rate

If regression exceeds threshold, trigger rollback.

## Output

```markdown
# Deployment Report

## Pre-checks
- Deterministic gates: [list + result]
- Coverage/Evals: [available/unavailable + result]
- Build/Artifact check: [result]
- Diff: [W/X files changed, Y additions, Z deletions]

## Deployment
- Release path used: [actual path or not applicable]
- Publish/Deploy result: [result]

## Health Check
- Verification checks: [actual checks + result]

## Next
- Monitor for 1 hour
- Check error logs
- User feedback ready?

## Recommendation
[Successfully deployed / Rollback needed / Critical issue found]
```

## Rollback

If production issue detected:
```bash
# use the actual rollback or revert path for this repo
```

## Principle

Shipping is not the end — it's the beginning. Monitor the first hour closely.
