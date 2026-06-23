---
name: deep-experiment-loop
description: "Deep iterative experiment engineering loop. Orchestrates rounds of hypothesize→implement→execute→analyze→plot→decide, delegating heavy execution to /run-experiment, /analyze-results, /paper-figure, /figure-spec, /result-to-claim. Use when user wants deep experiment work, iterative improvement, or sustained autonomous research."
argument-hint: [research-topic-or-plan-path]
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Skill, mcp__codex__codex, mcp__codex__codex-reply
---

# Deep Experiment Loop: Decision Orchestrator

Drive sustained, deep experimental research: **$ARGUMENTS**

## Role

This skill orchestrates experiments. Heavy work is delegated:

| Step | Execute via |
|------|------------|
| HYPOTHESIZE, IMPLEMENT, SMOKE TEST, LOG TSV, DECIDE | deep-experiment-loop directly |
| EXECUTE | `/run-experiment` |
| ANALYZE | `/analyze-results` |
| CLAIM-CHECK | `/result-to-claim` |
| PLOT | `/paper-figure` + `/figure-spec` |

## CRITICAL: NEVER STOP — READ THIS BEFORE EVERY ROUND

**Once the loop begins, you are autonomous. You do NOT ask whether to continue.**
The human might be asleep, away from the computer, expecting you to work indefinitely.

**TASKS ARE FINE-GRAINED AND CONCRETE.** Every round targets ONE specific, small improvement.
Not "improve the model" but "increase T2* estimation accuracy by reducing patch length from 64 to 8."
Not "fix phase estimation" but "add circular phase loss to handle φ→φ+2π wrapping."
Each hypothesis.md must state exactly what will change, by how much, and how to verify it.

**MULTIPLE REWORK ROUNDS ARE EXPECTED AND ENCOURAGED.** The first implementation WILL be
imperfect. The second WILL have bugs. The third WILL need tuning. This is normal.
Quality comes from iteration, not from getting it right the first time.
Do NOT be discouraged by failed rounds — each failure teaches something.
Do NOT prematurely declare "approach infeasible" — debug, fix, re-run.
30 rounds exist for a reason: use them. 10+ hours exist for a reason: use them.

**THE GOAL IS IMMUTABLE: Our method MUST beat the best baseline on the primary metric.**
This is not a suggestion. This is the exit condition. The loop CANNOT exit with SYNTHESIZE
until our method's primary metric is numerically better than every single baseline.
- If our method is behind → CONTINUE or REFINE. Keep working. Train longer. Tune better.
- If our method is ahead on primary but behind on secondary → REFINE. Close the gap.
- If our method is ahead on ALL metrics → SYNTHESIZE. Now you may exit.
- The only permitted early exit is FALLBACK (30 rounds exhausted) or PIVOT-hard (2 complete
  re-idea cycles tried and failed). In either case, document honestly what was achieved.

**ANTI-CHEAT CHECK — Run this before every SYNTHESIZE or FALLBACK declaration:**
1. Extract the PRIMARY METRIC of our method: grep the latest metrics.json.
2. Extract the PRIMARY METRIC of the BEST BASELINE: grep baseline results.
3. Is our number BETTER than the baseline's number? Answer YES or NO.
4. If NO → you CANNOT declare SYNTHESIZE. Go back to IMPLEMENT. Fix the gap.
5. If YES but secondary metrics are behind → REFINE. Do NOT declare SYNTHESIZE.
6. "The core finding is robust" is NOT a substitute for beating baselines.
7. "The limitation is architectural" is NOT a reason to stop — FIX the architecture.
   (e.g., 64-pt patches destroy phase → try 4-pt patches. Simple. Try it.)
8. "This is computationally expensive" is NOT a reason to stop. Run the experiments.
9. If you catch yourself rationalizing "we've done enough" → STOP. You haven't.
   The goal is beating baselines. Until the numbers show it, keep working.

**This loop may run for 30 rounds. It may run for 10+ hours. That is normal. Keep going.**
After Round N completes and DECIDE says anything except SYNTHESIZE: immediately start
Round N+1. Do NOT pause. Do NOT ask. Do NOT summarize. Just go.

## CRITICAL: Execution Mandate — READ THIS BEFORE EVERY ROUND

**This skill is NOT a planning exercise. It is a CODE EXECUTION engine.**

### Every round MUST produce ALL of these files on disk. Zero tolerance for missing files:

```
ROUND_NN/
  hypothesis.md     ← MUST exist: specific falsifiable claim, success criterion (a number)
  code/*.py         ← MUST exist: at least config.py, run.py. Typically 6-10 .py files.
  results/          ← MUST exist: metrics.json with real numbers from execution
  analysis.md       ← MUST exist: numbers compared to targets, root cause, implications
  decision.md       ← MUST exist: CONTINUE | REFINE | PIVOT | SYNTHESIZE with reasoning
  plots/            ← MUST exist: ≥4 PDF figures generated from real data
```

### After EACH round (after LOG TSV, before DECIDE), invoke the sentinel:

```bash
SENTINEL=".aris/tools/round_sentinel.sh"
[ -f "$SENTINEL" ] || SENTINEL="tools/round_sentinel.sh"
[ -f "$SENTINEL" ] || { [ -n "${ARIS_REPO:-}" ] && SENTINEL="$ARIS_REPO/tools/round_sentinel.sh"; }
bash "$SENTINEL" ROUND_NN
EXIT_CODE=$?
```

**exit 1 → gate failed. Fix missing files. Re-run sentinel. Do NOT proceed.**
**exit 0 → gate passed. Sentinel printed your next action. Follow it exactly.**
**exit 2 → SYNTHESIZE or FALLBACK. Sentinel printed handoff instructions. Follow them.**

The sentinel prints the EXACT next step. Do what it says. Do not interpret. Do not deviate.

### When delegating to sub-skills, INVOKE THEM — don't just mention them:

| Instead of saying | Do this |
|------------------|---------|
| "delegate EXECUTE to /run-experiment" | Actually call: `Skill("run-experiment")` |
| "delegate PLOT to /paper-figure" | Actually call: `Skill("paper-figure")` |
| "delegate ANALYZE to /analyze-results" | Actually call: `Skill("analyze-results")` |

If you mention a delegate but don't invoke it, the work doesn't happen.

## Context Management

This loop runs 30 rounds. Context window WILL fill. Every round writes its state to disk.
When starting a new round, READ from disk — don't rely on memory:

- Read `ROUND_NN/decision.md` (1 paragraph) for what happened last round — NOT the full analysis.
- Read `CLAUDE.md` for env/paths if you've forgotten them.
- Read `deep-experiment-logs/EXPERIMENT_HISTORY.tsv` for the trend across rounds.
- Read `deep-experiment-logs/CONTEXT_STATE.md` for current Phase state.

After each round's DECIDE, update `CONTEXT_STATE.md`:
```
Round N complete. Decision: [DECIDE]. Key finding: [one sentence]. Next round: N+1.
Primary metric: [our value] vs best baseline: [baseline value]. Gap: [delta].
```

## Smart GPU Scheduling (MANDATORY before every training run)

**Never launch GPU training without first checking what's available.**

```bash
# 1. Query GPU status
nvidia-smi --query-gpu=index,memory.used,memory.total,utilization.gpu --format=csv,noheader

# 2. Only use GPUs with < 5000 MiB used (truly idle)
# 3. Start from the highest GPU index and work DOWN (7→6→5→4→3→2→1→0)
#    This avoids conflicting with other projects that typically start from GPU 0.
# 4. If the project CLAUDE.md specifies a GPU preference, respect it.
# 5. If you need N GPUs but only M < N are free:
#    - Use M GPUs with gradient_accumulation to compensate for smaller batch
#    - Or wait 10 minutes and re-check
# 6. MAX GPUs: respect CLAUDE.md's limit. Default max = 3.
# 7. After selecting GPUs, export CUDA_VISIBLE_DEVICES before any python call.

# Example: Need 2 GPUs, GPUs 7,6,5 are free → use 7,6
export CUDA_VISIBLE_DEVICES=7,6
```

**If running on remote server via SSH**: run the nvidia-smi check on the server first.
**If running locally**: check local GPU. If VRAM < 4GB free, reduce batch size or use CPU.

## wandb Integration

**One rule**: Read `wandb_api.txt` in project root. If it exists → use wandb. If not → skip.

### wandb decision logic:

```python
import os
# Check if wandb_api.txt exists in project root
if os.path.exists("wandb_api.txt"):
    with open("wandb_api.txt") as f:
        wandb_key = f.read().strip()
    wandb.login(key=wandb_key)
    wandb.init(project=project_name)
    wandb.finish()
else:
    # No wandb_api.txt = no wandb. Skip silently. CSV+curves are enough.
    pass
```

- **`wandb_api.txt` exists → use wandb.** Simple.
- **No `wandb_api.txt` → skip wandb.** No warning. No question.
- **Never ask the user to create wandb_api.txt.** Check for it, act accordingly.
- **`wandb_api.txt` is in .gitignore** — never committed to GitHub.
- This applies to ALL projects. The file's existence is the decision.

## Network & Mirror Sites

If server cannot access HuggingFace / arXiv / GitHub / PyPI:
- **HuggingFace**: `export HF_ENDPOINT=https://hf-mirror.com` before any model loading
- **arXiv papers**: download PDFs locally and `scp` to server; or use `arxiv.org` mirror
- **GitHub**: `git clone https://ghproxy.com/https://github.com/...` mirror
- **PyPI**: `uv pip install --index-url https://mirrors.aliyun.com/pypi/simple/ <pkg>`
- **Test first**: `curl -s --max-time 5 <url>` before assuming service is available.
  If blocked, `WebSearch: "<service> mirror China"` for alternatives.

## Constants

- **MAX_ROUNDS = 30**
- **MIN_IMPROVEMENT = 0.05** (5% relative)
- **STAGNATION_LIMIT = 5** (rounds without improvement → force PIVOT)

## Inputs (priority order)

1. `refine-logs/EXPERIMENT_PLAN.md`
2. `idea-stage/IDEA_REPORT.md`
3. Project `CLAUDE.md`

## Output Structure

```
deep-experiment-logs/
  ROUND_00/hypothesis.md           ← targets and baselines
  ROUND_NN/{hypothesis.md, code/, results/, plots/, analysis.md, decision.md}
  FINAL_REPORT.md
  EXPERIMENT_HISTORY.tsv           ← round | metric | vram | status | desc
  reproduce.sh                     ← one-click reproduction
```

---

## Phase 1: Task Checklist Generation (Round 0)

### Pre-Step: Experimental Design (Fisher's 3 Principles)

Before generating the checklist, apply these principles (from K-Dense scientific-agent-skills):

1. **Randomization**: Train/val/test split MUST be random + seeded. No systematic assignment.
   Multiple measurements on the same unit ≠ independent replicates (pseudoreplication trap).
2. **Replication**: ≥5 seeds = independent training runs. ≥200 test samples (≥1000 preferred).
   What effect size can your test set detect? 200 samples → ~0.2σ at 80% power.
   Need to detect a 5% improvement? You need ≥1000 test samples.
3. **Blocking**: Stratify splits by condition. Per-SNR/noise-type reporting. Control for batch effects.

### Step 1: Generate Checklist from KB + IDEA_REPORT

After Phase 1 (Idea Discovery) completes, generate a DETAILED Phase 2 task checklist.
This checklist drives ALL subsequent rounds. It is NOT optional.

### Step 1: Generate Checklist from KB + IDEA_REPORT

Read `idea-stage/IDEA_REPORT.md` and `research-wiki/knowledge_base/`. Produce
`deep-experiment-logs/PHASE2_CHECKLIST.md` with TWO sections:

#### A. Program Results Checklist (incremental milestones)

Each milestone is a concrete, verifiable deliverable. Ordered from foundation to final goal:

```
## Milestone 1: Data Pipeline [SANITY]
- [ ] Generate/load dataset: [N] samples, [format], [splits]
- [ ] Verify data statistics: mean, std, class balance, SNR distribution
- [ ] Save to disk: data/[name].h5 or .npz
- [ ] Write data_pipeline.py with reproducible random seed
- GATE: python data_pipeline.py runs without error, produces expected shapes

## Milestone 2: Baseline Methods [BASELINE]
- [ ] Implement [Baseline 1] from [paper citation] — verify on clean data
- [ ] Implement [Baseline 2] from [paper citation] — verify on clean data
- [ ] ... (one milestone per baseline if complex)
- [ ] Run ALL baselines on SAME test split, record metrics
- GATE: every baseline produces numbers in expected range, no crashes

## Milestone 3: Our Method — Basic [MAIN]
- [ ] Implement our method (backbone loading, forward pass, loss)
- [ ] Smoke test: 2 epochs, loss decreases, no OOM
- [ ] Full training: [N] epochs, save checkpoints
- [ ] Evaluate on test set, compare to baselines
- GATE: our method runs without error, produces numbers

## Milestone 4: Our Method — Tuning [IMPROVE]
- [ ] Hyperparameter sweep: [params to tune]
- [ ] Train longer if loss hasn't plateaued
- [ ] Try alternative architectures: [variants]
- GATE: our method's primary metric improves over previous best

## Milestone 5: Full Comparison [COMPARE]
- [ ] Run ALL methods (baselines + ours) with ≥5 seeds each
- [ ] Compute paired t-test + Wilcoxon for our vs each baseline
- [ ] Per-SNR / per-condition stratified analysis
- [ ] Error distribution histograms
- GATE: our method beats ALL baselines on primary metric with p<0.01

## Milestone 6: Ablation + Robustness [ABLATION]
- [ ] Ablation: remove each component, measure impact
- [ ] Robustness: test on ≥3 distribution shifts
- [ ] Data scale experiment: train on 25%/50%/75%/100% data
- GATE: ablation table complete, robustness holds

## Milestone 7: Reproducibility [POLISH]
- [ ] All code in repo root, importable without ARIS paths
- [ ] pyproject.toml or requirements.txt with pinned versions
- [ ] .gitignore excludes venv, data, checkpoints
- [ ] README.md with quick-start
- [ ] reproduce.sh: one-command reproduction
- [ ] BENCHMARK_SOURCES.md with all baseline paper citations
- GATE: bash reproduce.sh runs end-to-end on a clean clone
```

#### B. Plotting Checklist (incremental milestones)

```
## Plot Milestone 1: Architecture Diagram
- [ ] /figure-spec: full method architecture with tensor dimensions
- [ ] Save: FIGURES/fig_architecture.pdf + .png
- GATE: diagram is self-contained, readable at column width

## Plot Milestone 2: Our Method's Results
- [ ] Plot predictions vs ground truth (scatter + correlation)
- [ ] Plot error distribution (histogram + fit)
- [ ] Plot per-SNR or per-condition breakdown
- [ ] Plot training curves (loss, metrics over epochs)
- [ ] Save all to ROUND_NN/plots/, best to FIGURES/
- GATE: ≥4 PDF plots, all axes labeled with units, error bars present

## Plot Milestone 3: Comparison vs Baselines
- [ ] Main comparison plot: our method vs ALL baselines on primary metric
- [ ] Secondary comparison plots: each secondary metric
- [ ] Error bars, p-value annotations, sample sizes on every plot
- [ ] Paper citations in legend
- GATE: comparison plot clearly shows our advantage, field-appropriate style

## Plot Milestone 4: Domain-Specific + Polish
- [ ] Generate any additional plots the field expects (study KB papers)
- [ ] 2-4 variations per plot type (different metric/SNR subset/style)
- [ ] All figures: ≥300 DPI, PDF vector, colorblind-friendly palette
- [ ] All axes labeled with units, legends complete
- GATE: would this figure be accepted at [VENUE]?
```

### Step 2: Codex MCP Review of Checklist

Send the checklist to Codex MCP for adversarial review:

```
mcp__codex__codex with xhigh reasoning:
"You are a senior researcher in this field. Review this Phase 2 task checklist.
Is anything MISSING that reviewers would expect? Are the milestones ordered correctly?
Are the GATE conditions strict enough? Are the plotting requirements sufficient
for a top venue in this field? Be specific and critical."
```

Incorporate Codex feedback. Finalize `PHASE2_CHECKLIST.md`.

### Step 3: Track Progress

At the end of EVERY round, update the checklist:
- [x] for completed items (with round number where evidence exists)
- [ ] for remaining items

This checklist is the SINGLE SOURCE OF TRUTH for Phase 2 completion.
**Phase 2 CANNOT exit until EVERY item is checked.** The checklist is reviewed
by Codex MCP at least once (at Milestone 5 or 6) to verify completion quality.

Write baseline definitions and numerical targets to `ROUND_00/hypothesis.md`.

---

## Phase 2: Iterative Loop

Each round = 9 lightweight steps. Heavy work delegated to sub-skills.

### 2A. HYPOTHESIZE

Write `hypothesis.md` with fine-grained, verifiable specificity:

```
## Round N Hypothesis
**We will change**: [ONE specific thing. Not a list. One.]
  Example: "Reduce TTM patch_length from 64 to 8 to preserve phase information."
  NOT: "Improve the model." NOT: "Try different architectures."

**We expect**: [ONE numerical prediction]
  Example: "φ MAE will drop from ~1.5 to <0.5 rad at SNR>20dB."

**We will verify by**: [ONE concrete test]
  Example: "Run evaluate.py on test set, compare φ MAE to Round N-1."

**Success criterion**: [ONE number]
  Example: "φ MAE < 1.0 rad (any improvement below random chance of 1.57 rad)."

**Failure means**: "If φ MAE ≥ 1.5 rad after 100 epochs → patch size is not the bottleneck.
  Next round will try attention-based phase pooling instead."
```

Each round changes ONE thing and measures ONE outcome. Stacking multiple changes in one
round makes it impossible to know what worked. Fine-grained, single-variable experiments
accumulate into major improvements over 30 rounds.

### The 5-Question Pre-Code Checklist (universal — answer BEFORE writing code)

Don't open VSCode until you can answer all five. Write them in `hypothesis.md`:

1. **What SPECIFIC problem are you solving?** The more specific, the better.
   Good: "In long-context settings, the model under-uses information beyond position 4000."
   Bad: "The model isn't good at long contexts."

2. **What exactly are you changing?** Data? Loss? Inference strategy? Training pipeline?
   Change only 1-2 components. Not everything at once.
   "I'm adding 500 examples of long-distance dependency patterns to the training set."

3. **Why do you think this will help?** State your mechanism hypothesis.
   "Exposing the model to more long-distance patterns during training should increase
   its utilization of distant tokens, because the model currently sees mostly local patterns."
   If you can't write this, you're just guessing randomly.

4. **What is the minimum viable experiment?** Small model, small dataset, quick run.
   "Test on Qwen2.5-0.5B with 200 synthetic long-context examples. Should take <10 min."
   Don't start with the full 7B model on 50K data.

5. **Even if it doesn't improve, what will you learn?**
   "At minimum, I'll know whether data augmentation for long-distance dependency helps
   at all, or whether the bottleneck is architectural (attention pattern) rather than data."
   Every negative result with a clear lesson is a seed for the next round.

### 2B. IMPLEMENT

**Code goes to a UNIFIED project repository, NOT scattered across ROUND_NN/code/.**

The project root must contain a clean, self-contained codebase that anyone can
clone, configure, and run. This is the code that will be published with the paper.

#### Repository Structure (MANDATORY)

```
project/
├── reproduce.sh            ← ONE command: bash reproduce.sh runs everything
├── pyproject.toml          ← uv-managed dependencies with pinned versions
├── .gitignore              ← excludes .venv/ data/ checkpoints/ __pycache__/ *.pyc
├── README.md               ← title, abstract, quick-start, hardware, output, citation,
│                              server transfer guide (see below)
├── BASELINE_SOURCES.md     ← every baseline with paper citation + performance numbers
├── src/
│   ├── data_pipeline.py    ← data generation/loading (uses data_lab/ if exists)
│   ├── baselines/
│   │   ├── fft_rife.py     ← each baseline in its own file with paper citation
│   │   ├── lm_nls.py
│   │   └── ...
│   ├── models/
│   │   ├── backbone.py     ← pretrained model loading (frozen + fine-tuning)
│   │   ├── head.py         ← task-specific prediction heads
│   │   └── loss.py         ← loss functions (MUST use optimizer + loss-based tuning)
│   ├── train.py            ← training loop with optimizer (AdamW), LR scheduler,
│   │                          checkpoint save/resume, early stopping
│   ├── evaluate.py         ← evaluation on test set + real data (if data_lab/ exists)
│   ├── plot.py             ← generates ALL paper figures (results + comparison + fitting)
│   └── run_all.sh          ← alternative one-click launcher (calls reproduce.sh logic)
├── deep-experiment-logs/   ← per-round analysis/decision/plots (NOT source code)
└── paper/                  ← LaTeX source + compiled PDF
```

**Source code lives in `src/`, NOT in `deep-experiment-logs/ROUND_NN/code/`.**
Each round IMPROVES the code in `src/`, making it better. `deep-experiment-logs/ROUND_NN/`
stores only analysis.md, decision.md, hypothesis.md, and result artifacts.

#### README.md Requirements

Must contain these sections:
```markdown
# [Paper Title]
[One-paragraph abstract]

## Quick Start
git clone <repo-url> && cd <project> && bash reproduce.sh

## Requirements
- Python 3.11+, uv, NVIDIA GPU (8GB+ VRAM)
- Or CPU-only (slower): set DEVICE=cpu in config.py

## Server Transfer Guide
Transfer the ENTIRE repo directory. Then:
  scp -r project/ user@server:/path/to/
  ssh user@server
  cd /path/to/project
  bash reproduce.sh
  
Required files to transfer: ALL. The repo is self-contained.
No external dependencies beyond Python + uv + GPU drivers.

## Output
- results/ — evaluation metrics
- figures/ — publication-quality plots
- checkpoints/ — trained model weights

## Citation
[Paper citation, once published]
```

#### Step 0: Benchmark Baselines from Published Papers (AUTOMATIC)

Every baseline MUST cite a specific paper and faithfully reproduce its method.

1. **Identify the canonical paper for each baseline method** — search for:
   ```
   WebSearch: "<method_name> paper original proposed by"
   WebSearch: "github <method_name> implementation benchmark <field>"
   ```
2. **Record paper metadata**: title, authors, year, venue, arXiv ID or DOI.
   This goes into `ROUND_NN/BENCHMARK_SOURCES.md`:
   ```
   | Baseline | Paper | Authors | Year | Venue | Code Source |
   |----------|-------|---------|------|-------|-------------|
   | LM-NLS   | "Solving Nonlinear Least Squares..." | Marquardt | 1963 | SIAM | scipy.optimize |
   | ...
   ```
3. **Clone and verify**: `/repo-clone` if public code exists. Read the paper's method section.
   Implement faithfully — same algorithm, same hyperparameters, same evaluation protocol.
   If adapting the method to our data, document exactly what changed and why.
4. **Run on OUR data**: every baseline evaluated on the SAME train/val/test split as our method.
   Same metrics, same seeds. This is non-negotiable — an unfair comparison is worthless.

**Comparison plots**: before generating any results figure, check the field's papers for
how they present method comparisons. `WebSearch: "<field> benchmark comparison figure style"`.
Draw the SAME type of comparison plot used in the field — not a generic bar chart.
Include all baselines + our method in every comparison plot, with paper citations in the legend.

#### Implementation standards

- Inspect model source for return types, import paths, deprecated APIs before writing wrappers.
- Not done until smoke test passes: 2 epochs, 10% data, loss decreasing, no OOM.
- Train ≥100 epochs MINIMUM (150+ required, 200+ preferred). Use ReduceLROnPlateau or cosine
  annealing. If loss still decreasing → keep training. Overnight training is normal.
  **Early stopping is FORBIDDEN before epoch 100.** A model that "converges" at epoch 40
  with loss still decreasing is UNDERFIT, not converged. Set patience ≥30 epochs.
  Train until validation loss plateaus for 30+ epochs, not until it stops dropping quickly.
  6 GPU-minutes total is INSUFFICIENT. Target 30+ GPU-minutes per round.
- **MUST save model checkpoints — at least 3 files.** This is non-negotiable:
  ```python
  # Save on every val_loss improvement
  torch.save(model.state_dict(), f'checkpoints/best_round{N}.pt')
  # Save optimizer state for resume
  torch.save({'epoch': epoch, 'model_state': model.state_dict(),
              'optimizer_state': optimizer.state_dict(), 'val_loss': val_loss,
              'metrics': {'omega_mae': ..., 'phi_mae': ..., 't2_mae': ..., 'c_mae': ...}},
             f'checkpoints/ckpt_round{N}_epoch{epoch}.pt')
  # Save final model
  torch.save(model.state_dict(), f'checkpoints/final_round{N}.pt')
  ```
  Minimum: `best.pt` + `final.pt` + at least one intermediate checkpoint = ≥3 .pt files.
  Do NOT train without saving. Untrained weights are worthless.
  `reproduce.sh` must load from saved checkpoint for evaluation, not re-train.
  `gate_check.sh` Phase 2 verifies: `checkpoints/*.pt` ≥ 3 files.
- **MUST use optimizer + loss-based fine-tuning.** No frozen-backbone-only approaches.
  Use AdamW optimizer, compute loss on the task objective, backprop through the full model.
  Fine-tune at minimum the top layers, preferably the full backbone. This is non-negotiable.
- **MUST log training metrics every epoch.** Save to `ROUND_NN/results/training_log.csv`:
  ```csv
  epoch,train_loss,val_loss,lr,train_acc,val_acc,...
  1,2.345,2.456,0.001,0.65,0.63,...
  ```
  Also generate `ROUND_NN/results/training_curves.pdf`: matplotlib plot with train+val loss
  curves, annotated with best epoch and convergence point. These logs enable:
  - Debugging: is loss diverging? Plateauing? Overfitting (val_loss >> train_loss)?
  - Optimization: which epoch to load for best checkpoint?
  - Paper: training curve goes into the paper as a diagnostic figure.
  `gate_check.sh` verifies: training_log.csv exists with ≥100 rows.
- **If `data_lab/` exists**: evaluate() MUST run on real data and produce results.
  plot.py MUST generate figures from real data, not only synthetic data.
  The paper's results section must report both synthetic and real data performance.
- **BASELINE_SOURCES.md MUST exist before SYNTHESIZE**: every baseline method with:
  paper citation (title/authors/year/venue/DOI), method description, performance on our data
  (primary metric ± std), code source (our implementation / repo-clone from URL).
- If our method doesn't beat baselines → study their optimized code, apply insights,
  train longer. Do NOT declare infeasible. Only exit via SYNTHESIZE or FALLBACK (30 rounds).

### 2C. SMOKE TEST

Two-part check before full execution. Fix errors (up to 5 attempts total).

#### Part 1: Code Validation (AST + Security)

```bash
# AST syntax check (all .py files in code/)
python -c "
import ast, sys, os
errors = []
for root, dirs, files in os.walk('code/'):
    for f in files:
        if f.endswith('.py'):
            path = os.path.join(root, f)
            try:
                with open(path) as fp:
                    ast.parse(fp.read())
            except SyntaxError as e:
                errors.append(f'{path}:{e.lineno}: {e.msg}')
if errors:
    print('SYNTAX ERRORS:'); [print(e) for e in errors]; sys.exit(1)
print('AST OK')
"

# Dangerous import scan
grep -rn "os\.system\|subprocess\.call\|eval\|exec\|__import__\|importlib\.import_module" code/ \
  && echo 'WARNING: dangerous calls found — review before running' \
  || echo 'Security scan clean'

# Dependency check (verify all imports resolve)
python -c "
import importlib, sys
# Quick check: can we import key modules?
for mod in ['torch', 'numpy', 'scipy', 'matplotlib']:
    try: importlib.import_module(mod)
    except ImportError: print(f'MISSING: {mod}'); sys.exit(1)
print('Core deps OK')
"
```

If AST fails → fix syntax errors, re-check.
If dangerous imports found → review each, remove or justify.
If deps missing → `uv pip install` them.

#### Part 2: Runtime Smoke Test

2 epochs on 10% of data. Loss must decrease. No OOM.
Pass → proceed to full execution.

### 2D. EXECUTE → `/run-experiment`
```
/run-experiment "ROUND_NN experiment: [one-line description]"
```
Handles GPU deployment, OOM recovery, checkpoint saving. Results → `ROUND_NN/results/`.

**ALL Bash output must be logged to disk.** Every significant command must use `tee`:
```bash
python code/run.py 2>&1 | tee ROUND_NN/results/run_log.txt
nvidia-smi > ROUND_NN/results/gpu_profile.txt
bash .aris/tools/gate_check.sh 2-round ROUND_NN 2>&1 | tee ROUND_NN/gate_check.log
```
Never discard stdout/stderr that could be useful for debugging. The run log, GPU profile,
and gate check output are mandatory artifacts saved in `ROUND_NN/results/`.

### 2E. ANALYZE → `/analyze-results`
```
/analyze-results "ROUND_NN/results/"
```
Computes statistics, comparison tables, insights. Then write brief `analysis.md`:
raw numbers, comparison to targets (gap), what worked/didn't (root cause), next-round implications.

If the result is negative (our method did NOT improve), follow this protocol BEFORE declaring failure:

1. **Rule out low-level bugs**: Can the baseline be reproduced within ~5% of published numbers?
   Does turning OFF our change restore baseline performance? Try 2-3 random seeds — is this just noise?

2. **Per-category analysis**: Split the data by difficulty / length / category / SNR. Is there
   ONE subgroup where our method actually helped? Many ideas start as "only works on hard cases"
   and evolve into conditional methods that become general.

3. **Sample the output**: Look at actual model predictions for 5-10 examples. Any pattern?
   Is the model making a consistent type of error? A pattern is the seed of the next round.

4. **Write the one-sentence lesson**: "I thought X would improve Y, but [what actually happened].
   This means [revised understanding of the problem]." This sentence is the input to the next
   round's hypothesis. Many impactful findings grow from honest post-mortems.

### 2F. CLAIM-CHECK → `/result-to-claim`
```
/result-to-claim "[description and results path]"
```
Judges whether results support intended claims. Use verdict to inform DECIDE step.

### 2G. PLOT → `/paper-figure` + `/figure-spec`
```
/paper-figure "ROUND_NN/results/ — field conventions from research-wiki/knowledge_base/"
```

**ALL figures MUST be saved to BOTH `ROUND_NN/plots/` AND `paper/figures/`.**
The `paper/figures/` directory feeds `\includegraphics` in the LaTeX paper.
If `paper/figures/` is empty or contains only placeholders, the paper has no figures.

Generates publication-quality figures. **These types are MANDATORY, plus any others
that fit this specific project:**

#### Mandatory (must exist for SYNTHESIZE)
1. **Architecture Diagram** — `/figure-spec`. Full method overview.
2. **Our Method's Execution Results** — `/paper-figure`. Includes: fitting curves (model
   predictions overlaid on data), prediction vs ground truth scatter, error distribution
   histogram. Must show concrete output of our method on the task. Use real data if `data_lab/` exists.
3. **Comparison vs All Baselines** — `/paper-figure`. All methods on same data split.
   Primary metric + secondary metrics. Error bars, p-values, sample sizes on every plot.
4. **Ablation & Robustness** — `/paper-figure`. Component removal impact, per-condition breakdown.
5. **Domain-Specific Plots** — Study KB papers and `data_lab/illustration.md` for what
   this field expects. Physical consistency? Per-SNR? Allan variance? Draw whatever strengthens
   the paper's argument.

#### Multiple variations per type
For EACH figure type, generate **2-4 variations** with different content, style, or focus:
- Different metric being plotted (e.g., RMSE vs MAE, one SNR range vs another)
- Different visual style (e.g., bar chart vs line plot vs box plot for the same data)
- Different data subsets (e.g., all SNR vs low-SNR only, all noise types vs worst type)
- Different level of detail (e.g., summary figure for main text, detailed breakdown for appendix)
Save all to `ROUND_NN/plots/`. The best ones go to `FIGURES/`. The rest are backup.

This gives the paper-writing phase choices — pick the strongest versions for the venue's
page/Figure limits rather than being forced to use whatever single version was generated.

**Visual quality**: colorblind-friendly, ≥300 DPI, labeled axes with units, error bars
everywhere, legend with method names + citations. Visually striking. Each figure should
look like it belongs in the field's top journal.

### 2H. LOG TO TSV
Append to `deep-experiment-logs/EXPERIMENT_HISTORY.tsv`:
```
round	primary_metric	peak_vram_gb	status	description
```
Status: `keep` (improved) | `discard` (equal/worse) | `crash` (failed).

### 2I. DECIDE

**After EVERY decision, immediately execute the next action. Do NOT pause. Do NOT ask.**

**CONTINUE** → START ROUND N+1 NOW. Do not ask. Do not summarize. Just go.
**REFINE** → START ROUND N+1 NOW with better execution. Do not ask. Just go.
**PIVOT-soft** → START ROUND N+1 NOW with new approach. Do not ask. Just go.
**PIVOT-hard** → SIGNAL rollback_to: Phase 1 NOW. Do not ask. Just go.
**SYNTHESIZE** → Invoke `/experiment-reviewer` first. If PASS → exit loop. If FAIL → back to IMPLEMENT.
**FALLBACK** → MAX_ROUNDS (30) reached. Invoke `/experiment-reviewer`. If PASS → exit.
  If FAIL → write honest FALLBACK_REPORT.md documenting what couldn't be achieved and why.
  Then hand off to pipeline with explicit caveats.

The only exit options are SYNTHESIZE and FALLBACK. Everything else = NEXT ROUND NOW.
There is no "ask the user" option. The user is not available to answer.

## SYNTHESIZE Conditions (all must hold — gated by gate_check.sh 2)

0. **PHASE2_CHECKLIST.md: ALL items checked. Zero `[ ]` remaining.**
   This is the master checklist. If any item is unchecked, Phase 2 is NOT done.
1. Primary metric beats ALL baselines with statistical significance
2. ≥2 secondary metrics show p<0.05 improvement
3. Ablation complete with error bars
4. ≥3 distribution shifts / noise mismatch types tested
5. p<0.01 primary, p<0.05 secondary, ≥200 test samples, ≥5 seeds
6. ≥8 distinct PDF figures + 1 architecture diagram (via plotting checklist)
7. ≥25 verified references in BIBLIOGRAPHY.bib
8. Self-contained reproducible code (via program checklist milestone 7)
9. Baselines maximally competitive (tuned, not weak defaults)
10. EXPERIMENT_REVIEW.md with PASS verdict
11. `reproduce.sh` generated and verified
12. Codex MCP review of checklist confirms completion quality (Milestone 5-6)

### reproduce.sh (generated at SYNTHESIZE)

```bash
#!/usr/bin/env bash
# Reproduce all experiments for [paper title].
# Usage: git clone <repo> && cd <repo> && bash reproduce.sh
set -euo pipefail
uv sync
source .venv/bin/activate  # or .venv/Scripts/activate on Windows

# 1. Data
python src/data_pipeline.py --n_traces 5000 --output_dir data/

# 2. Baselines
python src/baselines/fft_rife.py --data_dir data/ --output results/
python src/baselines/lm_nls.py --data_dir data/ --output results/
# ... (one per baseline)

# 3. Train our method
python src/train.py --epochs 150 --batch_size 48 --data_dir data/ --checkpoint_dir checkpoints/

# 4. Evaluate
python src/evaluate.py --checkpoint checkpoints/best.pt --data_dir data/ --output results/
# If data_lab/ exists: python src/evaluate.py --checkpoint checkpoints/best.pt --real_data data_lab/ --output results/

# 5. Generate ALL paper figures
python src/plot.py --results results/ --output paper/figures/

echo "Reproduction complete. Results in results/, Figures in paper/figures/, Paper in paper/main.pdf"
```

The code repository must be **fully self-contained and run outside ARIS**. Required:
- `reproduce.sh`: one-command reproduction (above). Must ACTUALLY run. Test it.
- `pyproject.toml`: dependencies with pinned versions, managed by uv
- `.gitignore`: excludes .venv/ data/ checkpoints/ __pycache__/ *.pyc
- `README.md`: title, abstract, quick-start, server transfer guide, hardware, output, citation

## Exit: SYNTHESIZE or FALLBACK

When exiting: generate `reproduce.sh`, `FINAL_REPORT.md`, `BIBLIOGRAPHY.bib` (≥25 refs),
`README.md`, `.gitignore`. Copy best plots to `FIGURES/`. Hand off to pipeline.

Key rules: delegate don't re-implement. Numbers over narrative. Never skip smoke test.
Don't exit after negative first round. Negative results with thorough analysis ARE publishable.
