#!/usr/bin/env bash
# ARIS Phase Sentinel — blocks incorrect Phase transitions.
# Usage: bash phase_sentinel.sh <from_phase> <to_phase>
# Exit 0 = gate passed, proceed to next Phase.
# Exit 1 = gate failed, fix before proceeding.
set -euo pipefail

FROM="${1:-}"; TO="${2:-}"
[ -z "$FROM" ] || [ -z "$TO" ] && { echo "Usage: bash phase_sentinel.sh <from> <to>"; exit 1; }

GATE=".aris/tools/gate_check.sh"
[ -f "$GATE" ] || GATE="tools/gate_check.sh"
[ -f "$GATE" ] || { [ -n "${ARIS_REPO:-}" ] && GATE="$ARIS_REPO/tools/gate_check.sh"; }
[ -f "$GATE" ] || { echo "ERROR: gate_check.sh not found" >&2; exit 1; }

echo "══════════════════════════════════════════════"
echo "  PHASE SENTINEL: Phase $FROM → Phase $TO"
echo "══════════════════════════════════════════════"

bash "$GATE" "$FROM" 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║  GATE FAILED — cannot proceed to Phase $TO  ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    echo "Phase $FROM outputs are incomplete or insufficient."
    echo "Read the [FAIL] lines above. Fix each one."
    echo "Then re-run: bash phase_sentinel.sh $FROM $TO"
    echo ""
    echo "DO NOT invoke Phase $TO skills. DO NOT proceed."
    echo "Return to Phase $FROM and complete it first."

    # Write CONTEXT_STATE
    mkdir -p deep-experiment-logs
    cat > deep-experiment-logs/CONTEXT_STATE.md << EOF
# Pipeline State — BLOCKED at Phase $FROM → $TO
$(date)
Gate check failed. Phase $FROM outputs incomplete.
Must fix before proceeding to Phase $TO.
EOF

    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  GATE PASSED — proceed to Phase $TO         ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Print the exact next invocation based on the transition
case "$FROM→$TO" in
    "0→1")
        echo "NEXT: Invoke /idea-discovery \"\$ARGUMENTS\""
        ;;
    "1→2")
        echo "NEXT: Invoke /deep-experiment-loop \"\$CHOSEN_IDEA_TITLE\""
        ;;
    "2→3")
        echo "NEXT: Write NARRATIVE_REPORT.md, then invoke /paper-writing \"NARRATIVE_REPORT.md\" — venue: \$VENUE"
        ;;
    "3→4")
        echo "NEXT: Invoke /domain-reviewer \"full\""
        ;;
esac

echo ""
echo "DO NOT pause. DO NOT summarize. DO NOT ask the user. Just execute the NEXT command above."

# Write CONTEXT_STATE
mkdir -p deep-experiment-logs
cat > deep-experiment-logs/CONTEXT_STATE.md << EOF
# Pipeline State — Phase $FROM complete, entering Phase $TO
$(date)
Phase $FROM gate check: PASS
Proceeding to Phase $TO.
EOF

exit 0
