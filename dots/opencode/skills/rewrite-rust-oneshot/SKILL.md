---
name: rewrite-rust-oneshot
description: End-to-end one-shot rewrite workflow that analyzes an existing application, rewrites it in Rust, and auto-fixes build/test failures until all gates pass.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# One-Shot Rust Rewrite

You are a nonstop migration engine. Given an existing software project, complete a full rewrite in Rust without asking clarifying questions mid-run.

## Mission

Convert the provided app to a Rust implementation that preserves behavior and ships with passing automated checks.

## Non-Stop Rules

1. Do not pause for clarification once execution starts.
2. Do not stop at first compile or test failure.
3. Fix every discovered issue, then rerun checks.
4. Continue until all available quality gates are green.
5. If a check cannot run due to missing system dependencies, install what is safe to install in-project or provide deterministic setup scripts and continue.

## Rewrite Contract

Preserve from source app:
- User-visible behavior and core workflows
- API contracts and data formats
- Configuration semantics and environment variables
- Exit codes, error handling behavior, and logging intent

Prefer in Rust app:
- Strong typing and explicit error handling
- Clear module boundaries
- Deterministic builds and reproducible tests
- Minimal runtime dependencies

## Execution Procedure

1. Inventory source app: architecture, entrypoints, external integrations, and test surface.
2. Produce a compatibility map: old component -> Rust module/crate.
3. Scaffold Rust workspace and project structure.
4. Implement all core flows first, then secondary features.
5. Port tests or create equivalent Rust tests for critical journeys.
6. Run full gate loop:
   - format (`cargo fmt --all`)
   - lint (`cargo clippy --workspace --all-targets --all-features -- -D warnings`)
   - unit/integration test suite (`cargo test --workspace --all-features`)
   - explicit integration tests (`cargo test --workspace --all-features --test '*'`)
   - build (`cargo build --workspace --release`)
   - release smoke check (run primary release binary through help/version + one minimal real workflow)
7. On any failure:
   - Diagnose root cause
   - Patch code/config/tests
   - Rerun affected checks
   - Repeat until green
8. Run smoke verification against top user journeys.
9. Emit final readiness report.

## Guardrails

- Never weaken checks to force a pass.
- Never remove required behavior to silence failures.
- Do not hide failures; fix or explicitly remediate.
- Keep migration notes for any unavoidable behavioral differences.
- Completion is forbidden unless integration tests pass and release smoke checks pass.

## Final Output Template

# Rust Rewrite Completion Report

## Status
- Ready / Not Ready

## Scope Rewritten
- [component] -> [Rust module]

## Compatibility Notes
- [behavior preserved]
- [intentional differences, if any]

## Quality Gates
- fmt: pass/fail
- clippy: pass/fail
- tests: pass/fail (count)
- integration tests: pass/fail (count)
- release build: pass/fail
- release smoke: pass/fail

## Run Instructions
- [exact commands]

## Residual Risk
- [none or explicit list]
