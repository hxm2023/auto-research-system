# ARIS Setup Guide (Beginner-Friendly)

This guide helps you install and run ARIS from scratch. No programming experience needed.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| **OS** | Windows 10/11, macOS, or Linux |
| **Git** | https://git-scm.com/downloads |
| **Python** | 3.11+ installed |
| **Claude Code** | https://docs.anthropic.com/en/docs/claude-code |
| **GPU** (optional) | NVIDIA GPU for deep learning experiments. CPU fallback works but slower. |
| **Codex MCP** (optional) | For cross-model review. Pipeline works without it. |

---

## Step 1: Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
claude  # follow login prompts
```

---

## Step 2: Download ARIS

```bash
git clone https://github.com/hxm2023/auto-research-system.git aris_repo
```

---

## Step 3: Create Your Research Project

```bash
mkdir my-research
cd my-research
git init
```

---

## Step 4: Install ARIS Skills

```bash
bash ../aris_repo/tools/install_aris.sh
```

### What does `install_aris.sh` do?

1. **Creates skill links** — symlinks (or Windows junctions) from `my-research/.claude/skills/` to `aris_repo/skills/`
2. **Records the install** — writes `my-research/.aris/installed-skills.txt` manifest
3. **Updates CLAUDE.md** — if your project already has a `CLAUDE.md`, adds the ARIS managed block

Expected output:
```
ARIS Project Install
  Project:    /path/to/my-research
  ARIS repo:  /path/to/aris_repo
  CREATE: 84
✓ Install complete
```

---

## Step 5: Configure Your Project

Create a `CLAUDE.md` in your project directory. Example:

```markdown
<!-- ARIS:BEGIN -->
## ARIS Skill Scope
ARIS skills installed in this project. Update with: `bash <path>/aris_repo/tools/install_aris.sh`
<!-- ARIS:END -->

## Project: [Your Project Name]
**Goal**: [research goal]
**Target venue**: [journal name]

## GPU
- GPU: NVIDIA GeForce RTX 5060 (8 GB VRAM)

## Python
- Python 3.12 | uv package manager

## Key Commands
uv pip install <pkg>
uv run python src/train.py
bash reproduce.sh
```

---

## Step 6: Launch

Open Claude Code in your project directory and paste:

```
/research-pipeline "Your research direction" --deep_mode: true, auto_write: true, auto_proceed: true, venue: "Your Target Journal", arxiv_download: true
```

### Parameters

| Param | Default | What it does |
|-------|---------|-------------|
| `deep_mode` | false | true = 30 experiment rounds + 3 paper improvement rounds |
| `auto_write` | false | Auto paper writing + review after experiments |
| `auto_proceed` | true | Auto-pick top idea |
| `venue` | ICLR | Target journal — any name works |
| `arxiv_download` | false | Download arXiv PDFs |
| `base_repo` | false | GitHub repo for experiment codebase |
| `from-phase` | 0 | Resume from Phase N (0-4) |

---

## FAQ

### Q: "python3: command not found"
A: ARIS auto-detects `python` vs `python3`. If you see this, install Python 3.

### Q: Permission denied errors
A: Open Claude Code permissions: type `/permissions` and enable Bash access.

### Q: Pipeline stopped unexpectedly
A: The pipeline stops only when: (1) 30 rounds exhausted, (2) Phase 4 cross-stage review passes all stages, or (3) an unrecoverable error occurs. Resume with `--from-phase: N`.

### Q: How do I update ARIS?
```bash
cd aris_repo && git pull
cd ../my-research && bash ../aris_repo/tools/install_aris.sh
```

## Support

- Original project: https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep
- Original paper: arXiv:2605.03042
