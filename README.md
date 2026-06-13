# ARIS — Autonomous Research Integration System

> **Chat an Idea. Get a Paper.** — Autonomous, Collaborative & Self-Evolving.

> 📖 [中文文档](README_CN.md) | [安装指南](SETUP_GUIDE.md) | [中文安装指南](SETUP_GUIDE_CN.md)

> ⚠️ **Forked & Heavily Modified from** [Auto-claude-code-research-in-sleep](https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep) by Wanshui Yin.
> Original paper: [arXiv:2605.03042](https://huggingface.co/papers/2605.03042).
> This version adds: cross-stage domain-reviewer, experiment-reviewer, phase/round sentinels,
> 58+ gate checks, unified src/ code repo, uv environment management, reproduce.sh,
> knowledge-builder, paper-download, contract-first plotting, and much more.

ARIS is an AI-driven end-to-end research pipeline for Claude Code. One research direction in, compiled paper PDF out. 84 skills orchestrate literature review, idea generation, deep experiment loops (up to 30 rounds), paper writing, and cross-model adversarial review - fully autonomous.

---

## Pipeline Architecture (v3)

```
Phase 0           Phase 1           Phase 2              Phase 3           Phase 4
Knowledge      -> Idea           -> Deep Experiment   -> Paper          -> Cross-Stage
Base Setup        Discovery         Loop                 Writing           Review (<=5 cycles)
    |                |                 |                    |                 |
    v                v                 v                    v                 v
/knowledge-      /idea-discovery  /deep-experiment-loop /paper-writing    /domain-reviewer
builder          (literature       (30 rounds:           (template->plan   (Codex MCP,
(domain context  ->creator          hypothesis->code      ->figure->write     reads PDF/images,
+ paper PDFs     ->novelty->review) ->run->plot->analyze  ->compile->improve) 5 criteria,
+ search index)                    ->decide)                                 rollback on REVISE)
                                      |
                           Delegates to:
                           /run-experiment /analyze-results
                           /paper-figure /figure-spec /result-to-claim
```

---

## Quick Start

```bash
# Clone ARIS
git clone https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep.git aris_repo

# Create your research project
mkdir my-research && cd my-research && git init

# Install ARIS skills
bash ../aris_repo/tools/install_aris.sh

# Add project config (CLAUDE.md with GPU specs, Python env, baseline requirements)

# Open Claude Code in this directory and run:
/research-pipeline "Your research direction" --deep_mode: true, auto_write: true, auto_proceed: true, venue: "Your Target Journal"
```

## Marathon Prompt

```
/research-pipeline "Use method X to solve task Y in domain Z" --deep_mode: true, auto_write: true, auto_proceed: true, venue: "Nature Communications", arxiv_download: true
```

### Domain-specific example (quantum sensing)
```
/research-pipeline "用TTM时间序列基础模型对NV色心Ramsey干涉实验做深度优化。data_lab/有真实实验数据。基线: FFT+Rife, LM-NLS, Bayesian MCMC, LSTM, NVRNet。>=150 epochs, >=5 seeds, p<0.01。全部源码src/, uv管理, bash reproduce.sh一键复现。产出Optics Letters论文。" --deep_mode: true, auto_write: true, auto_proceed: true, venue: "Optics Letters", arxiv_download: true
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `deep_mode` | false | true = 30 rounds + 3 paper improvement rounds |
| `auto_write` | false | Auto paper writing + cross-stage review |
| `auto_proceed` | true | Auto-select top idea |
| `venue` | ICLR | Any venue - ARIS auto-researches requirements |
| `arxiv_download` | false | Download arXiv PDFs |
| `base_repo` | false | GitHub URL for experiment codebase |
| `from-phase` | 0 | Resume from Phase N (0-4) |

## Pipeline Phases

**Phase 0: Knowledge Base** - Web-searches domain overview, standard metrics, field conventions. Downloads reference papers, extracts full text, builds searchable RAG index.

**Phase 1: Idea Discovery** - Literature survey, 8-12 ideas, novelty validation, ranked by quality. Auto-select top idea.

**Phase 2: Deep Experiment Loop (up to 30 rounds)** - Each round: hypothesize, implement, smoke test, execute, analyze, claim-check, plot, log, decide. Code goes to unified `src/` repo. Cannot exit until our method beats ALL baselines with statistical significance (p<0.01, >=5 seeds, >=1000 test samples, >=600 total epochs).

**Phase 3: Paper Writing** - Auto-detects venue LaTeX template. Writes paper, inserts figures, compiles PDF. 3 improvement rounds. Bidirectional citation verification.

**Phase 4: Cross-Stage Review (up to 5 cycles)** - Codex MCP (GPT-5.5) reviews idea + experiments + paper across 5 criteria (Originality, Scientific Importance, Interdisciplinary Readership, Technical Soundness, Readability). REVISE triggers auto-rollback to the relevant phase for rework and re-review until all PASS.

## Enforcement System

| Layer | Mechanism |
|-------|-----------|
| Per-round audit | `round_sentinel.sh` - 6 mandatory files, exit 1 blocks DECIDE |
| Phase transition | `phase_sentinel.sh` - 58+ binary checks, exit 1 blocks progression |
| Factual audit | `factual_audit.sh` - 7 automated checks (metrics, seeds, checkpoints, reproducibility) before Codex MCP review |
| Hard bottom lines | 4 non-negotiable rules: Technical Soundness<4, metric off >10x, statistical fraud, reproducibility failure |
| Sub-phase rollback | 12 granular rollback targets (Phase 2.1-2.6, 3.1-3.3) with fix_target tags |
| Skill-level | NEVER STOP mandate, ANTI-CHEAT check, experiment-reviewer gate |
| Hooks | PostToolUse + PreToolUse auto-triggers on Write/Skill |

## Code Output

```
project/
├── src/                    <-- ALL source code (self-contained)
├── reproduce.sh            <-- bash reproduce.sh runs everything
├── pyproject.toml .gitignore README.md
├── checkpoints/            <-- >=3 trained model weights
├── deep-experiment-logs/   <-- 30 rounds of experiment history
├── paper/                  <-- LaTeX + compiled PDF
└── review-stage/           <-- reviewer reports + SUBMISSION_READY
```

## Skills (84 total)

| Category | Skills |
|----------|--------|
| Pipeline | research-pipeline, deep-experiment-loop, domain-reviewer, experiment-reviewer |
| Knowledge | knowledge-builder, research-wiki, arxiv, semantic-scholar, deepxiv, openalex, exa-search |
| Idea | idea-discovery, idea-creator, novelty-check, research-lit, research-review |
| Experiment | run-experiment, analyze-results, paper-figure, figure-spec, result-to-claim |
| Paper | paper-writing, paper-plan, paper-write, paper-compile, auto-paper-improvement-loop |
| Review | experiment-audit, citation-audit, paper-claim-audit, proof-checker, kill-argument |
| Infrastructure | repo-clone, monitor-experiment, training-check, system-profile, overleaf-sync |

## Citation

```bibtex
@misc{ARIS2026,
  title={Auto-claude-code-research-in-sleep},
  author={Yin, Wanshui and the ARIS contributors},
  year={2026},
  howpublished={\url{https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep}},
}
```

Apache 2.0 License.
