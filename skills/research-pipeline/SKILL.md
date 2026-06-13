---
name: research-pipeline
description: "Full research pipeline: Knowledge Base Setup → Idea Discovery → Deep Experiment Loop → Paper Writing → Cross-Stage Iterative Review. Goes from a broad research direction to a submission-ready PDF with domain-aware multi-stage quality control. Use when user says \"全流程\", \"full pipeline\", \"从找idea到投稿\", \"end-to-end research\", or wants the complete autonomous research lifecycle."
argument-hint: [research-direction]
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Skill, mcp__codex__codex, mcp__codex__codex-reply
---

# Full Research Pipeline

End-to-end autonomous research workflow for: **$ARGUMENTS**

## Architecture

```
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 (iterative, ≤5 cycles)
```

| Phase | Skill | Output |
|-------|-------|--------|
| 0: Knowledge Base | /knowledge-builder | research-wiki/knowledge_base/ |
| 1: Idea Discovery | /idea-discovery | idea-stage/IDEA_REPORT.md |
| 2: Deep Experiment | /deep-experiment-loop | src/, FIGURES/, BIBLIOGRAPHY, reproduce.sh |
| 3: Paper Writing | /paper-writing | paper/main.pdf |
| 4: Cross-Stage Review | /domain-reviewer → Codex MCP | review-stage/SUBMISSION_READY.md |

## Resume from Phase

Add `--from-phase: N` to skip completed Phases. Must have required inputs (see Stage Contracts).

## Stage Contracts

| Phase | Required Inputs | Produced Outputs |
|-------|----------------|-----------------|
| 0 | $ARGUMENTS | KB (domain_overview.md, metrics_and_baselines.md, field_conventions.md, papers/, search.py) |
| 1 | KB | IDEA_REPORT.md |
| 2 | IDEA_REPORT.md, CLAUDE.md | FINAL_REPORT.md, FIGURES/, BIBLIOGRAPHY, EXPERIMENT_HISTORY.tsv, reproduce.sh |
| 3 | FINAL_REPORT.md, FIGURES/, BIBLIOGRAPHY | main.pdf, sections/*.tex, references.bib |
| 4 | main.pdf, idea + experiment artifacts | STAGE*_REVIEW.md, SUBMISSION_READY.md |

## Constants

| Constant | Default | Description |
|----------|---------|-------------|
| AUTO_PROCEED | true | Auto-select top idea |
| ARXIV_DOWNLOAD | false | Download arXiv PDFs |
| BASE_REPO | false | GitHub repo for experiment codebase |
| AUTO_WRITE | false | Auto paper writing + review |
| VENUE | ICLR | Target venue. Any name works — auto-researched. |
| DEEP_MODE | false | 30 experiment rounds + 3 paper improvement rounds |
| MAX_REVIEW_ROUNDS | 5 | Cross-stage review cycles |
| RENDER_HTML | true | Auto-render NARRATIVE_REPORT.md |

## Phase 0: Knowledge Base

MANDATORY. Invoke `/knowledge-builder "$ARGUMENTS"`. Auto-builds domain RAG + downloads papers.

## Phase 1: Idea Discovery

Invoke `/idea-discovery "$ARGUMENTS"`. Literature survey → ideas → novelty check → ranked.

## Phase 2: Deep Experiment Loop

Invoke `/deep-experiment-loop "$CHOSEN_IDEA_TITLE"`. Up to 30 rounds. Each round audited by round_sentinel.sh.
Cannot exit until all SYNTHESIZE conditions + experiment-reviewer PASS.

## Phase 3: Paper Writing

Invoke `/paper-writing "NARRATIVE_REPORT.md" --venue: $VENUE`. Template detection → write → compile → improve.

## Phase 4: Cross-Stage Iterative Review

```
For REVIEW_ROUND = 1 to MAX_REVIEW_ROUNDS (5):

  /domain-reviewer "full"
  → Factual audit (factual_audit.sh) → Codex MCP review (5 criteria + hard bottom lines)
  → Produces: STAGE1/2/3_REVIEW.md, each with verdict + rollback_to + fix_target

  If ALL THREE PASS → SUBMISSION_READY.md → DONE
  If any REVISE → read rollback_to + fix_target, roll back to specific sub-phase, fix, re-run forward
  If BLOCKED → document limitation, treat as PASS for that issue
```

### Sub-Phase Rollback Targets

| Issue Type | rollback_to | fix_target |
|-----------|------------|-----------|
| Idea fundamentally wrong | Phase 1 | idea |
| Wrong baselines chosen | Phase 1 | baselines |
| Method hard-error (metric off >10×, reproduce.sh fails) | Phase 2.1 | experiment_code |
| Training insufficient (<100 epochs, <5 seeds) | Phase 2.2 | hyperparams |
| Baseline implementation bug | Phase 2.3 | baselines |
| Analysis/claim wrong (p-values, metric interpretation) | Phase 2.4 | analysis |
| Data pipeline error | Phase 2.5 | data |
| Missing/poor figures | Phase 2.6 | plotting |
| Writing structure issues | Phase 3.1 | writing |
| Citations, formatting, LaTeX errors | Phase 3.2 | format |
| Paper misrepresents results | Phase 3.3 | claims |

### Hard Bottom Lines (MUST REVISE — non-negotiable)

1. Technical Soundness < 4 → REVISE
2. Core metric off by >10× vs baseline → REVISE
3. Statistical fraud (p>0.05 claimed as p<0.01, seeds<5 claimed as 5+) → REVISE
4. Reproduce.sh fails or <3 checkpoints → BLOCKED

## Output Structure

```
project/
├── src/ reproduce.sh pyproject.toml .gitignore README.md BASELINE_SOURCES.md
├── checkpoints/
├── deep-experiment-logs/ (ROUND_00..30, FINAL_REPORT, FIGURES/, BIBLIOGRAPHY, EXPERIMENT_HISTORY.tsv)
├── paper/ (main.pdf, sections/*.tex, references.bib, figures/)
├── review-stage/ (STAGE*_REVIEW.md, SUBMISSION_READY.md)
└── research-wiki/knowledge_base/
```

## Key Rules

0. NEVER ASK WHETHER TO CONTINUE. Autonomous for 10+ hours.
1. Phases run in order. Gate checks are ABSOLUTE — exit 1 = STOP.
2. Phase 4 is the quality gate. REVISE → rollback to sub-phase → fix → re-run forward.
3. Buggy baselines invalidate everything. Factual audit catches them.
4. Figures must exist. Citations must be bidirectional.
5. Embrace iterative rework. 30 rounds exist for a reason.
6. Domain knowledge matters. Use the KB. Don't default to AI-conference conventions.
