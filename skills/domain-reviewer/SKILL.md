---
name: domain-reviewer
description: "Multi-modal, domain-aware adversarial reviewer that evaluates ALL research stages (idea, code/experiment, paper writing). Reads images, uses RAG knowledge base, has field-specific expertise. Drives iterative revision loop across all stages until publication quality or max rounds. Use when user wants thorough review before submission, or as an integrated pipeline quality gate."
argument-hint: "[review-scope: full|idea|experiment|paper]"
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Skill, mcp__codex__codex, mcp__codex__codex-reply
---

# Domain Reviewer: Cross-Stage Multi-Modal Review

Review scope: **$ARGUMENTS**

## Overview

This reviewer evaluates ALL three research stages with domain-specific expertise.
It reads images, consults a RAG knowledge base, and provides actionable feedback that
drives iterative revision across idea → experiment → paper writing.

## CRITICAL: Load RAG Knowledge Base First

Before ANY review, load the domain knowledge base:

### Step 1: Read Project Context
Read the project's `CLAUDE.md` for:
- Research direction, GPU specs, codebase paths
- Project-specific quality requirements and baseline expectations
- Domain constraints (physics, evaluation standards)

### Step 2: Load RAG Knowledge Base (AUTOMATIC)

**This is automatic. Do NOT ask the user. Do NOT skip.**

The knowledge base is built by Phase 0 of the pipeline. Just load it:

1. Read `research-wiki/knowledge_base/domain_overview.md`
2. Read `research-wiki/knowledge_base/metrics_and_baselines.md`
3. Read `research-wiki/knowledge_base/field_conventions.md`
4. For specific queries: `python research-wiki/knowledge_base/search.py "<query>"`

If the KB is missing (pipeline Phase 0 was skipped), stop and run:
`/knowledge-builder "<research topic>"` before continuing.

### Step 1.5: Factual Audit (AUTOMATIC — before Codex MCP)

Run a factual audit BEFORE sending anything to Codex MCP. This catches provable errors
that don't need model judgment:

```bash
# Resolve audit script
AUDIT=".aris/tools/factual_audit.sh"; [ -f "$AUDIT" ] || AUDIT="tools/factual_audit.sh"
bash "$AUDIT" paper/ deep-experiment-logs/
EXIT_CODE=$?
```

The factual audit checks:
1. **Metric mismatch**: numbers in paper/ `.tex` vs numbers in deep-experiment-logs/ `metrics.json`.
   If claimed value differs from actual by >10× → FAIL.
2. **Seed count fraud**: paper claims ≥5 seeds, but results directory shows 1 seed → FAIL.
3. **Reproducibility**: `bash reproduce.sh` runs successfully (checks script exists + executable).
4. **Checkpoint requirement**: `checkpoints/*.pt` ≥ 3 files.

If the audit fails (exit ≠ 0): send the FAIL items to Codex MCP as mandatory review context.
The hard bottom lines are applied AFTER Codex MCP's review, using the audit findings
as ground truth (not subject to model interpretation).

### Step 3: Codex MCP Review Protocol (MANDATORY — MUST invoke mcp__codex__codex)

**This is the core of the review. You MUST call the Codex MCP tool. Do NOT simulate it.**

For EACH stage review, execute this exact sequence:

1. Assemble the review prompt (domain KB context + artifacts + CLAUDE.md requirements)
2. **Call the tool**: `mcp__codex__codex` with:
   ```
   config: {"model_reasoning_effort": "xhigh"}
   prompt: [assembled review prompt with full context]
   ```
3. **Read the response**: Codex returns the adversarial review verdict
4. Write the response to the appropriate `review-stage/STAGE*_REVIEW.md` file
5. Claude evaluates the verdict and routes: PASS → next stage, REVISE → loop back, BLOCKED → document limitation

**If `mcp__codex__codex` is unavailable**: STOP. Tell the user:
"Codex MCP is required for domain review but is not available. Please configure it."
Do NOT simulate the review yourself. Do NOT write a review without calling the MCP.

The Codex model is GPT-5.5 — a separate, independent model that is NOT the same
as the model that wrote the code/paper. This cross-model independence is essential.

## Review Architecture

```
                    ┌─────────────────────┐
                    │   Domain Reviewer    │
                    │  (multi-modal, RAG)  │
                    └──────┬──────────────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ Stage 1  │    │ Stage 2  │    │ Stage 3  │
    │ IDEA     │    │ CODE/DATA│    │ PAPER    │
    └──────────┘    └──────────┘    └──────────┘
```

Each stage review produces a verdict: PASS / REVISE / BLOCKED, scored on 5 criteria:

| Criterion | What it evaluates |
|-----------|------------------|
| **Originality** | Is the contribution novel compared to published work? Does it go beyond incremental improvement? |
| **Scientific Importance** | Would results matter to researchers in this field? Does it open new questions or applications? |
| **Interdisciplinary Readership** | Can a nonspecialist grasp the core claim? Is the method clearly explained? |
| **Technical Soundness** | Are methods correct? Are baselines properly implemented? Are statistics rigorous? |
| **Readability** | Is the writing clear? Are figures well-designed? Are claims supported by evidence? |

Each criterion scored 1-10. Overall verdict = soft judgment informed by scores, but
CONSTRAINED by the hard bottom lines below. A paper cannot PASS if any hard rule triggers,
regardless of how good the writing or originality scores are.

### Hard Bottom Lines (MUST REVISE — non-negotiable)

1. **Technical Soundness < 4** → mandatory REVISE. A broken method cannot be rescued by prose.
2. **Core metric off by >10× vs baseline** (e.g., φ MAE 0.79 vs baseline 0.07) → mandatory REVISE.
   If our method is WORSE than the best baseline on the PRIMARY metric → cannot PASS.
3. **Statistical fraud** → mandatory REVISE: p > 0.05 but paper claims p < 0.01, or claimed
   n≥5 seeds but only 1 seed found in results, or claimed test set ≥1000 but only 200 found.
4. **Reproducibility failure** → mandatory BLOCKED: `bash reproduce.sh` fails (exit ≠ 0) or
   `checkpoints/*.pt` < 3 files.

If any hard bottom line triggers, the verdict is automatically REVISE (lines 1-3) or
BLOCKED (line 4). The soft scores are recorded but do not override the hard lines.

### Soft Judgment (applies when no hard bottom line triggers)

Overall verdict is Codex MCP's holistic judgment of the 5 scores + factual audit report.
Soft criteria (Originality, Importance, Readership, Readability) influence the verdict
but cannot override a hard bottom line. A paper with Technical Soundness=9 but metric
off by >10× is STILL REVISE due to hard line 2.

If REVISE or BLOCKED: the pipeline MUST return to that stage and fix the issue.
The reviewer then re-evaluates after fixes are applied.

## Stage 1: Idea Review

Review `idea-stage/IDEA_REPORT.md` and related files against reviewer expectations
(from HKUST Supervisor-Skills, Dr. Luo Yuyu):

**Reviewers want**: Novel Problem | Novel Method | Nice Story | Nice Presentation
**Reviewers hate**: Old problem + simple combination | Existing methods without adaptation | Poor presentation | Weak experiments

### 1A. Domain Plausibility Check
- Is the problem formulation consistent with domain conventions?
- Are the claimed contributions actually novel in this field?
- Do the evaluation metrics match what the field cares about?
- Are the baseline methods the RIGHT baselines for this field?

### 1B. Physics/Theory Validity
- Are there obvious physical inconsistencies in the problem setup?
- Are assumptions stated and justified?
- Is the data generation strategy realistic for this domain?
- If synthetic data: are the noise models physically motivated?

### 1C. Scope and Feasibility
- Can this idea realistically produce publication-quality results?
- Are the compute requirements feasible given available hardware?
- Is the proposed method appropriate for the stated venue?

### Stage 1 Verdict
Write `review-stage/STAGE1_IDEA_REVIEW.md` with:
- Score (1-10) per dimension
- Specific issues found (quote claims, cite domain knowledge)
- PASS / REVISE / BLOCKED verdict
- If REVISE: `rollback_to: Phase N` + exact list of changes needed

## Stage 2: Code & Experiment Review

Review experiment code, datasets, results, and figures.

### Stage 2 Review: 6 Sub-Gates. ANY gate FAIL = REVISE. No soft passes.

#### Sub-Gate 2A: Experimental Design (if this fails, everything is invalid)
- [ ] Randomization: train/val/test split randomized + seeded. No systematic assignment.
- [ ] Pseudoreplication: repeated measures on same unit ≠ independent replicates.
- [ ] Blocking: stratified by key conditions. Per-SNR/noise-type reporting.
- [ ] Power: MDE = 2.8σ/√N. Can test set detect claimed improvement?
- [ ] Controls: all baselines on SAME split, SAME compute budget.
- fix_target: `2.5 data` (design flaw) or `2.2 hyperparams` (power insufficient)

#### Sub-Gate 2B: Code Quality (read .py files — not results summaries)
- [ ] Baseline correctness: code matches paper method. Read side-by-side.
- [ ] Our method: forward pass verified, loss correct, no silent bugs.
- [ ] Edge cases: NaN/empty/extreme input handled, not crashed.
- [ ] Code structure: organized (src/models/, src/baselines/), not monolithic.
- [ ] Import hygiene: no `import *`, no bare `except:`, no hardcoded paths.
- [ ] GPU: batch size tuned, OOM recovery, mixed precision.
- fix_target: `2.1 experiment_code` (our bug) or `2.3 baselines` (baseline bug)

#### Sub-Gate 2C: Training Volume (hard numbers — no excuses)
- [ ] ≥100 epochs MINIMUM per method? If <100 → REVISE. No "early convergence" excuses.
- [ ] ≥5 seeds ALL methods? Single seed → REVISE. Report mean ± std.
- [ ] ≥30 GPU-minutes total? 6 minutes is INSUFFICIENT.
- [ ] ≥3 .pt checkpoints saved (best + final + intermediate)?
- [ ] Train/val loss curves logged every epoch? Plateaus documented?
- fix_target: `2.2 hyperparams` — increase epochs/seeds

#### Sub-Gate 2D: Results Quality (numbers must be credible)
- [ ] Physical plausibility: if baseline gives 2.235 rad but expected 0.1-0.5 → BUG.
- [ ] Error distributions with histograms + Gaussian fit. Not just mean/MAE.
- [ ] Per-condition stratification (SNR bins, noise types, parameter ranges).
- [ ] Paired t-test + Wilcoxon. Exact p-values reported. No cherry-picked best-of-N.
- fix_target: `2.4 analysis` — re-run properly

#### Sub-Gate 2E: Figure Quality (10-item checklist, every figure)
- [ ] Vector PDF, ≥300 DPI. Font ≥8pt. All axes labeled with units.
- [ ] Error bars on ALL points (≥5 seeds). Sample size in caption. Legend complete.
- [ ] Colorblind-friendly (not tab10). Y-axis honest (not truncated). Architecture (Fig1) present.
- [ ] ≥8 figures in FIGURES/. paper/figures/ has ≥4 files. Domain-appropriate plot types.
- fix_target: `2.6 plotting` — regenerate specific figures

#### Sub-Gate 2F: Reproducibility
- [ ] `bash reproduce.sh` runs end-to-end without error?
- [ ] pyproject.toml / requirements.txt with pinned versions? .gitignore exists?
- [ ] README.md with quick-start? BASELINE_SOURCES.md with paper citations?
- fix_target: `2.1 experiment_code` — fix reproduce.sh

### Stage 2 Verdict

**If ANY sub-gate has an unchecked item → REVISE. No exceptions.**
Write `review-stage/STAGE2_EXPERIMENT_REVIEW.md` with every failed check
(sub-gate: item + evidence), fix_target for each, minimum changes before re-review.
Only ALL 6 PASS → proceed to Stage 3.

## Stage 3: Paper Review

Review the compiled paper PDF and LaTeX source.

### Stage 3 Review: 5 Sub-Gates. ANY gate FAIL = REVISE.

#### Sub-Gate 3A: Format & Template
- [ ] Venue LaTeX template (.cls/.sty) downloaded and used?
- [ ] Page/figure/abstract word limits respected?
- [ ] VENUE_CONSTRAINTS.md exists and is followed?
- fix_target: `3.2 format` — download template, recompile

#### Sub-Gate 3B: Figure Audit (run grep — no guessing)
- [ ] Every `\includegraphics` points to an existing file: `grep -rn "includegraphics" paper/ | while read f; do [ -f "$f" ] || echo "MISSING: $f"; done` — must return empty
- [ ] Figures visible in compiled PDF? Paper opened as image to verify.
- [ ] All figures referenced in body text (`\ref{fig:...}`)?
- [ ] Figure 1 = architecture diagram? Captions complete and self-contained?
- fix_target: `3.2 format` — fix figures

#### Sub-Gate 3C: Citation Audit (bidirectional — run grep)
- [ ] Every `\cite{key}` has corresponding `@article{key,` in .bib? No orphans.
- [ ] Every bib entry cited in body text? No uncited fillers.
- [ ] Spot-check 3 key citations: do the cited papers actually exist and support the claim?
- fix_target: `3.2 format` — fix citations

#### Sub-Gate 3D: Content Quality (9 writing standards from Supervisor-Skills)
- [ ] Logic clear: every claim traces to evidence. No gaps in reasoning.
- [ ] Overview-first: abstract → sections → paragraphs. Each paragraph has leading sentence.
- [ ] Flow: paragraphs connect. Sentences build. No orphans.
- [ ] Paragraph unity: one idea per paragraph. No tangents.
- [ ] Text+figures: skimming figures+captions gives core contribution.
- [ ] Self-contained: all notation defined. No "as shown in [X]" without explanation.
- [ ] Focused: every section/sentence serves the thesis. Cut irrelevant content.
- [ ] AI disclosure absent: `grep -qi "claude\|ai-assisted\|chatgpt" paper/sections/*.tex` → empty.
- [ ] No formatting errors: "540dB" → "5–40 dB", names formatted correctly.
- fix_target: `3.1 writing` — rewrite sections

#### Sub-Gate 3E: Claim-Evidence Alignment
- [ ] Every numerical claim in paper matches a number in experiment results.
  Run `bash tools/factual_audit.sh paper/ deep-experiment-logs/` → must exit 0.
- [ ] No overclaimed conclusions: "revolutionary" out, "we demonstrate" fine.
- [ ] Limitations honestly discussed: sample size, data source, hardware constraints.
- fix_target: `3.3 claims` — align claims with evidence or `2.4 analysis` if data missing

### Stage 3 Verdict

**If ANY sub-gate has an unchecked item → REVISE. No exceptions.**
Write `review-stage/STAGE3_PAPER_REVIEW.md` with every failed check
(sub-gate: item + evidence), fix_target for each, minimum changes before re-review.
Only ALL 5 PASS → Stage 3 complete.

---

## Cross-Stage Review Workflow

When invoked with scope `full` (or as part of the pipeline):

### Round Structure

```
For ROUND = 1, 2, ... until PASS or MAX_REVIEW_ROUNDS:

  1. Stage 1 Review (Idea)
     → If REVISE/BLOCKED: implement fixes, re-run idea-stage work, re-review
     → If PASS: proceed to Stage 2

  2. Stage 2 Review (Code & Experiment)
     → If REVISE/BLOCKED: fix code bugs, re-run experiments, regenerate figures, re-review
     → If PASS: proceed to Stage 3

  3. Stage 3 Review (Paper)
     → If REVISE/BLOCKED: fix paper, recompile, re-review
     → If PASS: paper is ready for submission

  After all three stages PASS → exit with FINAL_SUBMISSION_READY.md
```

### Gate Rollback Rules

When REVISE is returned, roll back to a SPECIFIC sub-phase. The reviewer MUST specify
BOTH `rollback_to` AND `fix_target`:

```
verdict: REVISE
rollback_to: Phase 2.2        # sub-phase granularity
fix_target: hyperparams       # what specifically to fix
reason: φ MAE 0.79 vs LM-NLS 0.07 (11× worse). Only 48 epochs (need ≥100).
```

| Issue Type | rollback_to | fix_target | What to Fix |
|-----------|------------|-----------|-------------|
| Idea fundamentally wrong | Phase 1 | idea | Re-run idea-discovery |
| Wrong baselines chosen | Phase 1 | baselines | Re-do literature search |
| Method hard-error (metric off by >10×, reproduce.sh fails) | Phase 2.1 | experiment_code | Rewrite model/loss/training code |
| Training insufficient (<100 epochs, <5 seeds) | Phase 2.2 | hyperparams | Increase epochs/seeds, tune |
| Baseline implementation bug | Phase 2.3 | baselines | Fix baseline code, re-evaluate |
| Analysis/claim wrong (p-values, metric interpretation) | Phase 2.4 | analysis | Re-run analysis, fix claims |
| Data pipeline error (SNR definition, noise model) | Phase 2.5 | data | Fix data generation |
| Missing figures, poor plot quality | Phase 2.6 | plotting | Re-generate figures |
| Writing structure, missing sections | Phase 3.1 | writing | Rewrite sections |
| Citations, formatting, LaTeX errors | Phase 3.2 | format | Fix bib, template, compile |
| Paper misrepresents results | Phase 3.3 | claims | Align claims with evidence |
| All three stages PASS → exit with SUBMISSION_READY |

The pipeline reads `rollback_to` and resumes from that sub-phase.
Details of each sub-phase are in deep-experiment-loop SKILL.md (Phase 2.x)
and paper-writing SKILL.md (Phase 3.x). Previously completed work that is
still valid can be reused — e.g., if only plotting needs fixing, don't re-train.

### REFINE vs REVISE

- **REVISE**: the hypothesis/approach is wrong. Roll back to Phase 1 or 2, change direction.
- **REFINE**: the hypothesis is correct, but experiment quality is insufficient.
  More seeds, larger test set, better hyperparameter tuning, additional ablation.
  Stay in Phase 2, run more rounds. Do NOT change the approach.

### Constraints

- **MAX_REVIEW_ROUNDS = 5** — Maximum complete review cycles before forcing final assessment.
- **BLOCKED items must be acknowledged.** If something cannot be fixed (e.g., no real experimental data,
  no access to a competitor's code), document it explicitly in the paper as a limitation.
- **Never fabricate.** If a reviewer requirement cannot be met, state this honestly.

---

## Integration with Pipeline

The research-pipeline should invoke this reviewer after each major stage:

```
/idea-discovery → STAGE1 REVIEW → /deep-experiment-loop → STAGE2 REVIEW → /paper-writing → STAGE3 REVIEW
                                     ↑                        ↑                        ↑
                                     └──── REVISE ────────────┴──── REVISE ────────────┘
```

When the reviewer returns REVISE for any stage, the pipeline loops back to that stage,
applies fixes, re-runs the stage's work, and re-invokes the reviewer.

Only when all three stages return PASS does the pipeline declare the paper submission-ready.

## Key Rules

1. **Read images.** If the paper has figures, read the PDF as an image to verify visual quality.
2. **Read code, not just results.** Bugs hide in code, not in numbers.
3. **Use domain knowledge.** Consult downloaded papers in research-wiki/ for field conventions.
4. **Be specific.** Every issue must cite a file:line, a specific number, or a specific claim.
5. **Prioritize science over style.** Stage 1 and Stage 2 issues block paper writing.
6. **Acknowledge unfixable issues.** Missing real data → document in limitations, don't pretend.
7. **PASS means genuinely ready.** Don't rubber-stamp. If a paper would be rejected by a real
   reviewer, return REVISE with the reasons.
