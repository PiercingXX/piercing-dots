---
name: ops-canary
description: Post-deploy canary monitoring for errors, latency regressions, and core journey failures with rollback triggers.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Canary Monitoring

You protect production immediately after deployment.

## Activation Contract

Use this skill only when a real post-deploy signal surface exists: metrics, logs, health checks, or critical journey probes.

If no live signal surface exists, do not fake canary confidence. Switch to release-readiness or smoke-check language instead.

## Monitoring Window

- First 30 minutes: check every 2 minutes
- Next 2 hours: check every 10 minutes

## Track

- Error rate
- P95 latency
- Throughput changes
- Authentication success
- Critical user journey success

Track only the signals that actually exist for the current system.

## Rollback Triggers

- Error rate > baseline by 2x for 5+ minutes
- P95 latency regression > 40% for 10+ minutes
- Any critical journey failure (auth, checkout, save)

## Signal Classification

- `DETERMINISTIC`: clear trigger fired from stable telemetry or probe failures
- `TRANSIENT`: short spike, flaky probe, or noisy window
- `ENVIRONMENT`: missing dashboards, missing logs, unreachable health endpoint
- `CAPABILITY`: system lacks enough telemetry to justify a canary decision

## Procedure

1. Capture baseline from pre-deploy metrics.
2. Compare live metrics against baseline.
3. If trigger fires, initiate rollback and confirm recovery.
4. Log incident timeline and corrective actions.

## Verification States

- `PASS`: monitored signals remain inside the allowed window
- `FAIL`: rollback trigger fired and was confirmed
- `AMBIGUOUS`: signals are incomplete, noisy, or unavailable

## Output

# Canary Report

## Status
- PASS / AMBIGUOUS / FAIL

## Metrics Delta
- Error rate: before -> after
- P95 latency: before -> after
- Throughput: before -> after

## Signal Confidence
- [signal] -> stable / noisy / unavailable

## Actions
- [action taken]

## Follow-up
- [owner + due date]

## Principle

Deploy is a hypothesis. Canary is the proof.

## Optional Telemetry (Opt-In)

If you add a local telemetry hook, record `skill`, `outcome`, and `durationMs` in your chosen sink.
