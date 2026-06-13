---
name: experiment-reviewer
description: "Adversarial experiment quality gate. Reads experiment results, compares our method against ALL baselines on primary and secondary metrics, returns binary PASS/FAIL verdict. If FAIL, specifies exactly which metrics are behind and forces rework. Invoked before any SYNTHESIZE or FALLBACK declaration in the deep experiment loop. Use when the loop considers exiting, or when user wants an honest assessment of whether results are publication-ready."
argument-hint: "[experiment-results-path]"
allowed-tools: Bash(*), Read, Grep, Glob, Write, mcp__codex__codex, mcp__codex__codex-reply
---

# Experiment Reviewer: Binary Quality Gate

Review experiment results for: **$ARGUMENTS**

## Purpose

This skill is the **final gatekeeper** of the deep experiment loop. It provides an
independent, binary assessment of whether our method has actually beaten the baselines.
It has ONE job: compare numbers and say PASS or FAIL.

**This reviewer does NOT accept excuses.** "The core finding is robust," "the limitation
is architectural," "this is computationally expensive" — none of these are valid reasons
to declare success. Only NUMBERS matter.

## When It Runs

- Before every SYNTHESIZE or FALLBACK declaration in `/deep-experiment-loop`
- Can be invoked standalone: `/experiment-reviewer "deep-experiment-logs/"`
- The deep-experiment-loop MUST invoke this before writing FINAL_REPORT.md

## Workflow

### Step 1: Find the Best Numbers

Read all `ROUND_NN/results/metrics.json` files. For EACH method (ours + every baseline):

```bash
# Find the best primary metric achieved by each method across all rounds
for round in deep-experiment-logs/ROUND_*/; do
  if [ -f "$round/results/metrics.json" ]; then
    python -c "
import json, sys
with open('$round/results/metrics.json') as f:
    data = json.load(f)
# Extract our method's primary metric and baselines
print(json.dumps(data, indent=2))
"
  fi
done
```

Extract:
- **Our method**: name, primary metric value, secondary metric values
- **Best baseline**: name, primary metric value, secondary metric values
- For each baseline: name, primary metric value

### Step 2: Compare — REJECT if ANY metric is worse

**Our method must beat baselines on the primary metric, and not be substantially worse on any secondary metric.** If our method is 11× worse on phase while claiming "突破", that's NOT a pass.

Rules:
- Primary metric: our value MUST be < best baseline (lower is better) OR > best baseline (higher is better)
- Secondary metrics: our value must be within 2× of best baseline. If >2× worse → FAIL
- If φ MAE is 0.79 vs baseline 0.07 (11× worse) → FAIL. "But T2* is better" does not excuse it.
- Common bugs to flag: unit errors (rad/s vs rad/ns), seed count=1, epochs<100, data_lab unused, baseline underestimated

### Step 2B: Compare (THE ONLY THING THAT MATTERS)

Extract numerical values from metrics.json. Then **MUST call Codex MCP** for adversarial review:

```
mcp__codex__codex with config: {"model_reasoning_effort": "xhigh"}
prompt: "You are an adversarial experiment reviewer. Here are the numerical results:
  - Our method ([name]): primary metric = [value], secondary = [values]
  - Best baseline ([name]): primary metric = [value], secondary = [values]
  Compare them. Is our method actually better? Are the numbers realistic?
  Are there any signs of bugs, overfitting, or cherry-picking?
  Give a binary verdict: PASS (ready for paper) or FAIL (must fix).
  If FAIL: list specific required actions."
```

**Do NOT make the PASS/FAIL decision yourself.** Send it to Codex MCP. Read the verdict.

### Step 3: Verdict (binary — no gray area)

**PASS** — Our method beats EVERY baseline on the primary metric. All secondary
metrics show our method is competitive (within 10% of best) or better.

Write `deep-experiment-logs/EXPERIMENT_REVIEW.md`:
```markdown
# Experiment Review — PASS

## Primary metric: [metric_name]
- Our method ([name]): [value]
- Best baseline ([name]): [value]
- Delta: [improvement]× better
- Verdict: BEATS ALL BASELINES

## Secondary metrics
| Metric | Our Method | Best Baseline | Verdict |
|--------|-----------|---------------|---------|
| [metric] | [value] | [value] | PASS/BEHIND |
...

## Statistical significance
- p-value (our vs best baseline): [value] — [SIGNIFICANT / NOT SIGNIFICANT]
- Test set size: N
- Seeds: K

## OVERALL: PASS — Ready for paper writing.
```

**FAIL** — Our method does NOT beat the best baseline on the primary metric,
OR primary is ahead but ≥2 secondary metrics are significantly behind.

Write `deep-experiment-logs/EXPERIMENT_REVIEW.md`:
```markdown
# Experiment Review — FAIL

## Primary metric: [metric_name]
- Our method ([name]): [value]
- Best baseline ([name]): [value]
- Gap: our method is [X]× WORSE than baseline
- **MUST FIX before proceeding.**

## Failed metrics
| Metric | Our Value | Baseline Value | Gap | Required Action |
|--------|----------|---------------|-----|----------------|
| [metric] | [value] | [value] | [X]× worse | [specific fix] |
...

## Required Actions Before Re-review
1. [Action 1 — specific, not generic]
2. [Action 2 — specific, not generic]
...

## OVERALL: FAIL — Return to IMPLEMENT. Do NOT proceed to paper writing.
```

### Step 4: Block Pipeline if FAIL

If FAIL:
- **Do NOT allow SYNTHESIZE.** The loop MUST continue.
- **Do NOT allow FALLBACK** unless MAX_ROUNDS (30) is reached.
- If MAX_ROUNDS is reached with FAIL: write honest assessment of what was achieved
  and what could not be achieved. Document limitations. Then allow handoff.

## Key Rules

1. **Only numbers matter.** "Robust finding," "architectural limitation," "the approach
   is sound" — irrelevant. Show the numbers.
2. **Every baseline must be compared.** If a baseline listed in CLAUDE.md or the
   experiment plan has no results, that's also a FAIL.
3. **Statistical significance required.** If p > 0.05 on the primary comparison,
   this is a FAIL (insufficient evidence).
4. **Test set must be ≥200 samples.** Smaller = FAIL.
5. **≥5 seeds required.** Fewer = FAIL.
6. **No excuses accepted.** If the reviewer is invoked and returns FAIL, the loop
   MUST continue. There is no appeal.
