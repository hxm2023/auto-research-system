#!/usr/bin/env bash
# ARIS Round Sentinel — forces per-round completion and continuation.
# Invoked at the end of each experiment round.
# Usage: bash round_sentinel.sh ROUND_NN
# Exit 0 = gate passed, proceed to DECIDE.
# Exit 1 = gate failed, fix and re-run this script.
# Exit 2 = gate passed AND SYNTHESIZE conditions met → print handoff instructions.
set -euo pipefail

ROUND="${1:-}"
[ -z "$ROUND" ] && { echo "Usage: bash round_sentinel.sh ROUND_NN"; exit 1; }

# Resolve gate_check script
GATE=".aris/tools/gate_check.sh"
[ -f "$GATE" ] || GATE="tools/gate_check.sh"
[ -f "$GATE" ] || { [ -n "${ARIS_REPO:-}" ] && GATE="$ARIS_REPO/tools/gate_check.sh"; }
[ -f "$GATE" ] || { echo "ERROR: gate_check.sh not found" >&2; exit 1; }

# ─── Step 1: Run per-round audit ──────────────────────────────────────────
echo "══════════════════════════════════════════════"
echo "  SENTINEL: Auditing $ROUND"
echo "══════════════════════════════════════════════"
bash "$GATE" 2-round "$ROUND" 2>&1
AUDIT_EXIT=$?

if [ $AUDIT_EXIT -ne 0 ]; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║  GATE FAILED — Round $ROUND is INCOMPLETE ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    echo "ACTION REQUIRED:"
    echo "  1. Read the [FAIL] lines above."
    echo "  2. Go back to the missing step."
    echo "  3. Produce the missing files."
    echo "  4. Re-run: bash round_sentinel.sh $ROUND"
    echo ""
    echo "DO NOT proceed to DECIDE. DO NOT start next round."
    echo "DO NOT declare SYNTHESIZE. DO NOT write FINAL_REPORT."
    exit 1
fi

# ─── Step 2: Append to TSV if not already logged ──────────────────────────
ROUND_NUM=$(echo "$ROUND" | grep -o '[0-9]*' | sed 's/^0*//')
TSV="deep-experiment-logs/EXPERIMENT_HISTORY.tsv"
if [ -f "$TSV" ] && ! grep -q "^${ROUND_NUM}[[:space:]]" "$TSV" 2>/dev/null; then
    # Extract primary metric from results/metrics.json if available
    METRIC="0.000"
    if [ -f "$ROUND/results/metrics.json" ]; then
        METRIC=$(python -c "
import json, sys
try:
    with open('$ROUND/results/metrics.json') as f:
        d = json.load(f)
    # Try common metric keys
    for k in ['primary_metric', 'rmse', 'omega_rmse', 'omega_mae', 'best_val']:
        if k in d: print(d[k]); break
        elif isinstance(d, dict):
            for v in d.values():
                if isinstance(v, (int,float)): print(v); break
except: print('0.000')
" 2>/dev/null || echo "0.000")
    fi
    # Get VRAM
    VRAM=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader 2>/dev/null | head -1 | sed 's/ MiB//' | awk '{printf "%.1f", $1/1024}' || echo "0.0")
    echo -e "${ROUND_NUM}\t${METRIC}\t${VRAM}\tkeep\tround $ROUND_NUM" >> "$TSV"
fi

# ─── Step 3: Decide next action ───────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  GATE PASSED — $ROUND complete             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Check SYNTHESIZE conditions crudely
BIB_COUNT=0; FIG_COUNT=0
[ -f "deep-experiment-logs/BIBLIOGRAPHY.bib" ] && BIB_COUNT=$(grep -c '^@' deep-experiment-logs/BIBLIOGRAPHY.bib 2>/dev/null || echo 0)
[ -d "deep-experiment-logs/FIGURES" ] && FIG_COUNT=$(ls deep-experiment-logs/FIGURES/*.pdf 2>/dev/null | wc -l)

if [ $ROUND_NUM -ge 30 ]; then
    echo "MAX_ROUNDS (30) reached — FALLBACK exit."
    echo "ACTION: write honest FINAL_REPORT.md documenting achievements and gaps."
    echo "Then hand off to pipeline Phase 3."
    exit 2
elif [ "$BIB_COUNT" -ge 25 ] && [ "$FIG_COUNT" -ge 8 ] && [ -f "deep-experiment-logs/FIGURES/fig_architecture.pdf" ]; then
    echo "File counts look good (bib:$BIB_COUNT, figs:$FIG_COUNT)."
    echo ""
    echo "══════════════════════════════════════════════"
    echo "  MANDATORY: Run /experiment-reviewer NOW."
    echo "  It checks whether our numbers beat baselines."
    echo "  File counts alone are NOT sufficient."
    echo "══════════════════════════════════════════════"
    echo ""
    echo "If experiment-reviewer returns PASS → write FINAL_REPORT, hand off to pipeline."
    echo "If experiment-reviewer returns FAIL → read its required actions, go back to IMPLEMENT."
    echo ""
    echo "DO NOT write FINAL_REPORT without /experiment-reviewer PASS."
    echo "File counts check is necessary but INSUFFICIENT for SYNTHESIZE."
    exit 2
else
    NEXT_ROUND=$((ROUND_NUM + 1))
    NEXT_DIR="deep-experiment-logs/ROUND_$(printf '%02d' $NEXT_ROUND)"
    echo "NEXT ROUND: ROUND_$(printf '%02d' $NEXT_ROUND)"
    echo ""
    echo "IMMEDIATE ACTION:"
    echo "  1. Run DECIDE: CONTINUE | REFINE | PIVOT-soft | PIVOT-hard"
    echo "  2. mkdir -p $NEXT_DIR/{code,results,plots}"
    echo "  3. Write $NEXT_DIR/hypothesis.md"
    echo "  4. Start IMPLEMENT for Round $NEXT_ROUND"
    echo ""
    echo "DO NOT ask the user. DO NOT pause. DO NOT summarize."
    echo "JUST GO TO ROUND $NEXT_ROUND NOW."
    exit 0
fi
