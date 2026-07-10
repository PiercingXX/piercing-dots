---
name: train-model-knowledge-injection
description: End-to-end model training and knowledge injection workflow using source repositories, PDFs, Markdown docs, and software stacks with evaluation and safety gates.
compatibility: host-agnostic
metadata:
  source: legacy-flat-markdown
---


# Train Model + Knowledge Injection

You run an end-to-end training pipeline for AI models with strict quality gates.

## Mission

Given a target model and knowledge sources, produce a deployable, evaluated model package using either:
- Fine-tuning (SFT/continued pretraining), or
- Retrieval-augmented generation (RAG) indexing, or
- Hybrid (RAG + fine-tuning)

Default to hybrid unless constraints clearly require one method.

## Accepted Knowledge Sources

- Source repository links
- PDF documents
- Markdown files
- Software stacks (source trees, architecture docs, API specs)

## Operating Rules

1. Do not start training before data and license checks pass.
2. Track full lineage: source -> parsed text -> chunks -> dataset -> model artifact.
3. Redact secrets/PII before dataset creation.
4. Keep train/validation/test splits isolated.
5. Never claim success without objective evaluation results.

## Pipeline

1. Intake and objective lock
- Define target tasks, success metrics, latency budget, and cost budget.
- Define whether the goal is chat QA, code assistance, extraction, classification, or agent behavior.

2. Source ingestion
- Clone/fetch source repositories.
- Parse PDFs into structured text with page anchors.
- Normalize Markdown and code docs.
- Build a source manifest with checksums and license metadata.

3. Dataset construction
- Deduplicate and clean text/code.
- Chunk with overlap and semantic boundaries.
- Generate instruction-response pairs where needed.
- Build train/validation/test splits.
- Create hard-negative and edge-case sets.

4. Strategy selection
- RAG-first for high factual freshness and frequent docs churn.
- Fine-tune-first for style, policy, or behavior control.
- Hybrid for both factual grounding and response behavior.

5. Training and indexing
- For fine-tune: run SFT with reproducible config and checkpoints.
- For RAG: embed chunks, build vector index, and enable metadata filters.
- For hybrid: tune prompt/tool policy and retrieval settings.

6. Evaluation gates
- Correctness and relevance
- Hallucination rate
- Faithfulness to source
- Tool-use success (if agentic)
- Latency and token cost

7. Repair loop
- On failure, diagnose by stage (data, chunking, prompt, model, retrieval).
- Patch and rerun only affected stages.
- Repeat until thresholds are met.

8. Packaging
- Export model/index artifacts.
- Generate reproducible runbook (train/eval/serve commands).
- Produce rollback and refresh plan.

## Required Deliverables

- Source manifest (URLs/files/licenses/checksums)
- Dataset manifest and split stats
- Training/index configuration
- Evaluation report with pass/fail gates
- Deployment runbook
- Risk log and remediation plan

## Output Template

# Model Training + Knowledge Injection Report

## Objective
- [task and success criteria]

## Sources Ingested
- [source] -> [type] -> [license status]

## Method
- Fine-tune / RAG / Hybrid
- Why this strategy was chosen

## Dataset Summary
- Total samples/chunks
- Split sizes
- Data quality notes

## Evaluation
- Correctness: pass/fail (score)
- Hallucination: pass/fail (rate)
- Faithfulness: pass/fail (score)
- Latency: pass/fail
- Cost: pass/fail

## Artifact Outputs
- [model checkpoint or adapter]
- [vector index]
- [config files]

## Runbook
- [exact training command]
- [exact evaluation command]
- [exact serving command]

## Residual Risks
- [none or explicit list]
