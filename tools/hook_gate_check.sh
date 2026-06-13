#!/usr/bin/env bash
# ARIS Hook Gate Check — triggered by PostToolUse hooks.
# Reads CLAUDE_TOOL_INPUT to determine what file was just written,
# then runs the appropriate gate_check.sh phase.
# Silent on success, logs to deep-experiment-logs/gate_hooks.log on failure.
set -euo pipefail

LOG_DIR="${ARIS_LOG_DIR:-deep-experiment-logs}"
mkdir -p "$LOG_DIR"
HOOK_LOG="$LOG_DIR/gate_hooks.log"

GATE_SCRIPT=""
for p in ".aris/tools/gate_check.sh" "tools/gate_check.sh"; do
    [ -f "$p" ] && { GATE_SCRIPT="$p"; break; }
done
[ -z "$GATE_SCRIPT" ] && [ -n "${ARIS_REPO:-}" ] && GATE_SCRIPT="$ARIS_REPO/tools/gate_check.sh"
[ -z "$GATE_SCRIPT" ] && exit 0  # gate_check.sh not found, skip silently

# Parse the file that was just written from CLAUDE_TOOL_INPUT
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
FILE_PATH=$(echo "$TOOL_INPUT" | python -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null || echo "")

PHASE=""
ROUND_NN=""

# Detect what to check based on the file that was just written
case "$FILE_PATH" in
    *decision.md)
        # A round's decision was written → audit that round
        ROUND_NN=$(echo "$FILE_PATH" | grep -o 'ROUND_[0-9][0-9]*' | head -1)
        [ -n "$ROUND_NN" ] && PHASE="2-round"
        ;;
    *FINAL_REPORT.md)
        PHASE="2"
        ;;
    *main.pdf|*main.tex)
        PHASE="3"
        ;;
    *SUBMISSION_READY.md)
        PHASE="4"
        ;;
esac

if [ -z "$PHASE" ]; then
    exit 0  # Not a gate-relevant file, skip silently
fi

# Run the check
if [ "$PHASE" = "2-round" ]; then
    bash "$GATE_SCRIPT" 2-round "$ROUND_NN" 2>&1 || {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] GATE FAIL: $PHASE $ROUND_NN after writing $FILE_PATH" >> "$HOOK_LOG"
    }
else
    bash "$GATE_SCRIPT" "$PHASE" 2>&1 || {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] GATE FAIL: phase $PHASE after writing $FILE_PATH" >> "$HOOK_LOG"
    }
fi
