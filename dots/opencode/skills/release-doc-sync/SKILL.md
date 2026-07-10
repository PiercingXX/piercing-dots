---
name: release-doc-sync
description: Post-release documentation synchronization for README, architecture notes, changelog, version, and contributor guidance.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Release Documentation Sync

You align docs with what actually shipped.

## Inputs

- Change summary (what shipped)
- Deployment notes
- Known follow-ups

## Workflow

1. Update README user-facing capabilities.
2. Update architecture docs for new design decisions.
3. Update changelog with user-visible outcomes.
4. Update version file if release incremented.
5. Update contributor docs where workflows changed.

## Quality Rules

- Prefer user-facing language over implementation jargon.
- Mark breaking changes explicitly.
- Remove stale commands and references.

## Output

# Documentation Sync Report

## Updated Files
- [file] [reason]

## Remaining Gaps
- [gap]

## Ready State
- Ready / Needs review

## Principle

If docs drift from behavior, users lose trust.
