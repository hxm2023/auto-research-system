---
name: repo-clone
description: "Clone GitHub repositories for baseline reproduction, competitor comparison, or reference implementation. Supports cloning into baselines/ directory, installing dependencies, and making the code importable for downstream experiment phases. Use when user says 'clone repo', 'download github', 'get baseline code', '复现代码', '下载参考实现', or when the pipeline needs a competitor's source code."
argument-hint: "[github-url] [— target: <dir>] [— install: true|false] [— branch: <name>]"
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob
---

# Repo Clone: Download and Integrate External Code

Clone and prepare: **$ARGUMENTS**

## Overview

This skill clones a GitHub repository and prepares it for use in the research pipeline.
It handles:
1. Cloning to a specified directory (default: `baselines/<repo-name>`)
2. Installing dependencies (auto-detect pip/conda/uv/poetry)
3. Verifying the clone is importable
4. Documenting the baseline for reproducibility

## When It Triggers (automatic in pipeline)

This skill is called automatically when:
- **Phase 1 (Idea Discovery)**: `/research-lit` finds a baseline paper whose code should be compared.
  The research-lit output lists "Code Available: yes (URL)". Pipeline auto-clones.
- **Phase 2 (Deep Experiment Loop)**: IMPLEMENT needs to compare against a competitor's code.
  If CLAUDE.md lists baselines with GitHub URLs, auto-clone before starting experiments.
- **Phase 4 (Domain Reviewer)**: reviewer identifies a missing baseline with available code.
  Auto-clone and add to comparison.

Can also be invoked manually:
```
/repo-clone "https://github.com/xxx/baseline-method" — target: baselines/nvrnet — install: true
```

## Constants

- **DEFAULT_TARGET = `baselines/`** — Clone destination under project root.
- **AUTO_INSTALL = true** — Auto-detect and install dependencies after clone.
- **SHALLOW = true** — Use `--depth 1` for faster clone (no full history needed).
- **VERIFY_IMPORT = true** — Test that the cloned code can be imported.

## Workflow

### Step 1: Parse the URL

Extract from the GitHub URL:
- `repo_name` = last segment of URL (strip `.git` if present)
- `target_dir` = `$TARGET/$repo_name` (or `$TARGET` if explicitly specified)

```bash
URL="$ARGUMENTS"
REPO_NAME=$(echo "$URL" | sed 's|.*/||; s|\.git$||')
TARGET_DIR="${TARGET:-baselines}/$REPO_NAME"
```

### Step 2: Clone

```bash
mkdir -p "$(dirname "$TARGET_DIR")"

if [ -d "$TARGET_DIR" ]; then
    echo "Repo already cloned at $TARGET_DIR"
    cd "$TARGET_DIR" && git pull --depth 1 2>/dev/null || echo "Pull failed, using existing clone"
else
    git clone --depth 1 "$URL" "$TARGET_DIR"
    echo "Cloned $URL → $TARGET_DIR"
fi
```

If a specific branch or tag is needed, use `— branch: <name>` to checkout after clone.

### Step 3: Read the Repo

After cloning, read the repo's README and key files to understand:
- What does this code do? What's the entry point?
- What are the dependencies?
- What's the license? (important for attribution)
- Are there pretrained weights to download?

Write a brief summary to `$TARGET_DIR/REPO_README_SCAN.md`.

### Step 4: Install Dependencies (if AUTO_INSTALL)

Auto-detect package manager and install:

```bash
cd "$TARGET_DIR"

# Prefer uv for all Python package management
if [ -f "uv.lock" ] || [ -f "pyproject.toml" ]; then
    uv sync 2>&1 || uv pip install -e . 2>&1
elif [ -f "requirements.txt" ]; then
    uv pip install -r requirements.txt 2>&1
elif [ -f "environment.yml" ]; then
    conda env create -f environment.yml 2>&1 || echo "Conda env creation skipped (may need manual setup)"
elif [ -f "setup.py" ]; then
    uv pip install -e . 2>&1
else
    echo "No dependency file found. Manual inspection needed."
fi
```

If install fails: document the failure, don't block the pipeline. The baseline can still be read/analyzed.

### Step 5: Verify Import

Test that the cloned code can be imported:

```bash
cd "$TARGET_DIR"
python -c "import $(echo $REPO_NAME | tr '-' '_')" 2>&1 && echo "Import OK" || echo "Import failed — may need PYTHONPATH"
```

If import fails, document how to add it to PYTHONPATH:
```bash
export PYTHONPATH="$TARGET_DIR:$PYTHONPATH"
```

### Step 6: Document

Write `$TARGET_DIR/BASELINE_INFO.md`:
```markdown
# Baseline: [Repo Name]
- **Source**: [URL]
- **Clone date**: [today]
- **License**: [detected license]
- **Description**: [what this code does, from README]
- **Entry point**: [main script or module]
- **Dependencies**: [list]
- **Install status**: [OK / partial / failed]
- **Usage in this project**: [what we're using it for]

## How to Run
[command to run the baseline on our data]
```

### Step 7: Return Path

The skill outputs the absolute path to the cloned repo, so downstream code can:
```python
import sys
sys.path.insert(0, "baselines/<repo-name>")
from their_module import their_method
```

## Integration with Pipeline

When called from the pipeline, the path is automatically recorded in:
- `deep-experiment-logs/BASELINES.md` — list of all cloned baselines
- Experiment code can `import` from `baselines/` directory
- Phase 4 reviewer verifies baselines were actually used in comparison

## Key Rules

1. Always shallow clone (`--depth 1`) unless a specific commit is needed.
2. Always document the clone in `BASELINE_INFO.md` for reproducibility.
3. If install fails, don't block — the code can still be read and manually integrated.
4. Respect licenses. If a repo has a restrictive license, note it and don't copy code directly.
5. Clean up failed clones. If a repo is empty or 404, remove the target directory.
