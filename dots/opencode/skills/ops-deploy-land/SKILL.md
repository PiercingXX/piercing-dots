---
name: ops-deploy-land
description: Post-deploy operations. Health verification, rollback procedure, canary monitoring, failure response. Ensure smooth production deployment.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Post-Deploy Operations

You are an operations engineer. Your job is to ensure the deployment succeeds and catch problems in the first 30 minutes.

## When to use

- Just merged a PR to main/production
- Need to canary roll out (gradual 5% → 50% → 100%)
- Monitoring + alerting setup
- Rollback procedure
- Error rate / latency spikes detected

First determine what post-deploy surface this repository actually has. If there is no live service, canary mechanism, or production telemetry, degrade to release-readiness checks, artifact consistency, and rollback planning instead of inventing a SaaS-style ops path.

## Step 1: Pre-Deploy Checklist (Before Merge)

```bash
# Discover repo-native commands from the observed surface first:
# - package.json / Makefile / pyproject.toml / Cargo.toml / scripts/
# - CI config or release workflow docs
#
# Then verify the relevant checks for this repo:
# - tests
# - build or artifact generation
# - staging or smoke environment, if it exists
# - migration validation, if it exists
# - rollback procedure is documented
```

## Step 2: Merge to Main

```bash
# Verify the release diff one more time
git log --oneline origin/main..HEAD
git diff --stat origin/main...HEAD
```

Only perform merge, tag, publish, or promotion steps that are explicitly supported by this repo and requested by the user.

## Step 3: Canary Deployment (If Your Setup Supports)

Deploy to 5% of users first:

```bash
# Examples only:
# - feature-flag percentage rollout
# - load-balancer traffic split
# - lowest-traffic region first
#
# Use the actual rollout mechanism exposed by this repo/infrastructure.
```

## Step 4: Health Verification (First 30 Minutes Post-Deploy)

Watch these metrics every 2 minutes for 30 minutes:

### Errors
```bash
# Error rate should stay < 0.1% (or your baseline)
curl https://monitoring.internal/metrics/error-rate
# If spikes above baseline → ROLLBACK

# Critical errors
curl https://monitoring.internal/metrics/critical-errors
# Any spikes → Investigate immediately
```

### Performance
```bash
# Latency should stay within baseline
# p95 latency (95th percentile): 
#   Before: 200ms
#   After: Should be ≈ 200ms
# If > 250ms → Investigate (could be legitimate)
# If > 500ms → ROLLBACK
```

### User Sessions
```bash
# Are users logging in successfully?
curl https://monitoring.internal/metrics/login-success-rate
# If < 99% → Problem with auth changes
```

### Database Performance
```bash
# Query times should stay normal
# If your app is waiting on DB → rollback

# Active connections should be stable
# If climbing → Connection leak
```

### External Services
```bash
# Are 3rd-party APIs responding?
# Payment API, email service, etc.
# If they're down, your app is broken even if code is good
```

## Step 5: Gradual Rollout

If canary is healthy:

```bash
# After 10 minutes:
toggleFeatureFlag("new-feature", percentage: 25)

# After another 10 minutes:
toggleFeatureFlag("new-feature", percentage: 100)

# If any issues during canary → ROLLBACK (see Step 6)
```

## Step 6: Rollback Procedure

If health checks fail:

```bash
# Use the actual rollback path for this repo:
# - feature-flag reversal
# - rollback command from deploy system
# - revert + redeploy
# - migration rollback if supported
#
# After rollback:
# 1. Watch health metrics until baseline returns
# 2. Record what failed and why the gate missed it
# 3. Add or improve the missing detection/verification step
```

## Step 7: Post-Deployment Monitoring

For 24 hours after deploy, watch for:

### Slow creeping issues
```
- Memory leaks (memory grows slowly over hours)
- Connection leaks (connections climb then crash at 100)
- Queue backlog building (jobs not processing fast enough)
- Cache miss rates increasing
```

### User-reported issues
- Have a Slack channel for support
- Monitor error reports from bug trackers
- If pattern emerges → Correlate with deployment time

### Background job failures
```bash
# If background jobs failing → Could indicate data format mismatch
# Check error queue
npm run jobs:status
```

## Health Check Commands

```bash
# Create these health check endpoints in your app

# Basic health (is server responding?)
GET /health
Response: { status: "ok", uptime: 3600 }

# Detailed health (can reach database, external APIs?)
GET /health/detailed
Response: {
  database: { status: "ok", latency: 45 },
  redis: { status: "ok", latency: 2 },
  external_api: { status: "ok", latency: 120 },
  uptime: 3600
}

# Error rate endpoint
GET /metrics/errors
Response: { rate: 0.005 }  # 0.5%

# Latency percentiles
GET /metrics/latency
Response: {
  p50: 50,
  p95: 200,
  p99: 500,
  p99_9: 1200
}
```

## Incident Response

If something is clearly broken:

```bash
### IMMEDIATE (Next 5 minutes)
1. Declare incident: "Deployment rollback in progress"
2. Rollback (see Step 6)
3. Verify metrics return to normal
4. Notify stakeholders: "Issue resolved"

### SHORT TERM (Next hour)
1. Analyze logs: What failed?
2. Identify root cause
3. Write fix + test

### FOLLOW UP (Next day)
1. Deploy fix
2. Post-mortem document: What happened? How do we prevent it?
3. Add test to prevent recurrence
```

## Output

```markdown
# Deployment Report

## Pre-Deployment
- [✓] All tests passing
- [✓] Staging verified
- [✓] Rollback procedure documented

## Deployment
- Started: [time]
- Completed: [time]
- Canary: [% traffic]

## Health Verification (30 min)
- Error rate: [baseline] → [post-deploy] ✓
- P95 latency: [baseline] → [post-deploy] ✓
- Login success: 99.9% ✓
- Database: Normal ✓

## Rollout (if canary)
- 5% at [time] ✓
- 25% at [time] ✓
- 100% at [time] ✓

## Status
✅ DEPLOYED SUCCESSFULLY

## Monitoring
- Continue health checks for 24 hours
- Alert on: Error rate > 0.1%, P95 > 250ms
```

## Key Rules

1. **Speed is essential** — Every second of bad code costs users
2. **Health checks before rollout** — Never drive blind
3. **Rollback is not failure** — It's showing good judgment
4. **Measure twice, deploy once** — More time in pre-deploy saves you in ops

## Principle

A good deployment is invisible to users. They never notice it happened.
