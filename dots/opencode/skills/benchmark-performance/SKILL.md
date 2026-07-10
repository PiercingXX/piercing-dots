---
name: benchmark-performance
description: Detect performance regressions against baseline using build size, response latency, and key user-flow timings.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Performance Benchmark

You run regression-focused performance checks.

## Activation Contract

Use this skill only when the repo or deployed system exposes a measurable performance surface.

Do not invent latency, bundle, or throughput metrics for repos that are primarily docs, prompts, or setup/configuration.

## Baseline

Record baseline before changes:
- Bundle/build artifact size
- API latency (p50/p95)
- Time-to-interactive for key page
- Critical journey completion time

If no baseline exists, create one from the strongest available current measurement and mark the result as provisional.

## Compare

After changes, compare against baseline.

Regression thresholds:
- Bundle size +10%
- P95 latency +25%
- TTI +20%
- Journey time +20%

## Workflow

1. Gather baseline metrics.
2. Run current metrics.
3. Compute deltas.
4. Flag regressions by severity.
5. Recommend optimizations with expected impact.

## Measurement Rules

- Prefer deterministic measurements over intuition.
- Compare like with like: same hardware, same environment, same route or journey.
- Separate unavailable metrics from passing metrics.
- If only partial measurements exist, report only those and mark the rest unavailable.

## Failure Taxonomy

- `ENVIRONMENT`: benchmark tool, endpoint, or metric source is unavailable
- `TRANSIENT`: one-off spike, timeout, or noisy sample
- `DETERMINISTIC`: clear reproducible regression in measured numbers
- `CAPABILITY`: the current environment cannot measure the desired signal reliably

Recovery policy:

- `ENVIRONMENT`: fall back to the next real measurement surface
- `TRANSIENT`: rerun once and compare spread
- `DETERMINISTIC`: treat as a real regression candidate
- `CAPABILITY`: downgrade the conclusion to directional only

## Verification States

- `PASS`: measured deltas stay within thresholds
- `FAIL`: measured deltas exceed thresholds
- `AMBIGUOUS`: partial or noisy evidence prevents a firm conclusion

## Output

# Performance Benchmark Report

## Summary
- PASS / AMBIGUOUS / FAIL

## Deltas
- Metric: baseline -> current (delta %)

## Availability
- [metric] -> measured / unavailable / noisy

## Regressions
- [severity] [metric] [likely cause]

## Optimizations
- [change] -> [expected impact]

## Principle

What gets measured gets improved; what is not measured regresses.

## Optional Telemetry (Opt-In)

If you add a local telemetry hook, record `skill`, `outcome`, and `durationMs` in your chosen sink.
