# ARIS — 自动科研系统

> **输入一个研究方向，输出一篇可投稿论文 PDF。** — 全自动、协作式、自我进化。

> 📖 [English](README.md) | [安装指南](SETUP_GUIDE_CN.md)

> ⚠️ **魔改自** [Auto-claude-code-research-in-sleep](https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep) (原作者: Wanshui Yin)。
> 原始论文: [arXiv:2605.03042](https://huggingface.co/papers/2605.03042)。
> 本版本新增：跨阶段领域审稿、实验数值审查、Phase/Round Sentinel、58+ 关口检查、
> 统一 src/ 代码仓库、uv 环境管理、reproduce.sh、知识库构建、论文下载、
> Contract-First 绘图等。

---

## 是什么

ARIS 是一个基于 Claude Code 的 **AI 驱动全自动科研管线**。你只需要给一个研究方向，系统自动完成：

1. **知识库构建** — 网络搜索领域知识 + 下载参考论文 + 建立 RAG 索引
2. **Idea 发现** — 文献调研 → 生成 8-12 个 idea → 验证新颖性 → 排序推荐
3. **深度实验循环**（最多 30 轮）— 写代码 → 跑实验 → 画图 → 分析 → 迭代
4. **论文写作** — 自动查找期刊模板 → 写 LaTeX → 插入图片 → 编译 PDF → 改进 ×3 轮
5. **跨阶段审稿**（最多 5 轮）— Codex MCP (GPT-5.5) 独立审稿 → 不通过就回炉重做

全程不需要人工干预。夜间启动，早上看论文。

## 安装（新手友好）

### 第 1 步：装好 Claude Code

去 https://docs.anthropic.com/en/docs/claude-code 安装 Claude Code。

### 第 2 步：下载 ARIS

```bash
git clone https://github.com/hxm2023/auto-research-system.git aris_repo
```

### 第 3 步：创建项目文件夹并连接 ARIS

```bash
mkdir my-research && cd my-research && git init
```

然后对 Claude Code 说：**"给这个文件夹连接aris系统"**（Claude 会自动运行 `install_aris.sh`）

### 每个项目需要准备什么

**必要（2 项）**：

| # | 项目 | 怎么做 |
|---|------|--------|
| 1 | **连接 ARIS** | 对 Claude 说：`"给这个文件夹连接aris系统"` |
| 2 | **Marathon prompt** | 以 `/research-pipeline "方向" --deep_mode: true, ...` 开头 |

**可选但推荐（5 项）**：

| # | 项目 | 写在 CLAUDE.md | 示例 |
|---|------|---------------|------|
| 3 | **项目配置** | GPU 型号、Python 版本、基线方法、质量要求 | 见下方模板 |
| 4 | **真实数据** | `data_lab/` 文件夹 + `data_lab/illustration.md` 说明数据 | `.xls`, `.csv`, `.png` |
| 5 | **远程服务器** | CLAUDE.md 末尾加 SSH + GPU 配置（修改工作目录路径） | 见下方模板 |
| 6 | **相关源码** | 放进项目文件夹 | `granite-tsfm-main/` |
| 7 | **wandb API key** | 仅DL项目。把key写入 `wandb_api.txt`（不要在 CLAUDE.md 里写！） | `wandb_api.txt`（gitignored） |

### wandb 设置

深度学习项目（PyTorch/RL/transformers）需要训练监控时：

```bash
echo "你的wandb_api_key" > wandb_api.txt
```

ARIS 运行时自动读取这个文件。文件存在 → 启用 wandb 日志。不存在 → 静默跳过。
该文件已被 gitignore，永远不会提交到 GitHub。CLAUDE.md 里不需要任何 wandb 配置。

### CLAUDE.md 模板

```markdown
<!-- ARIS:BEGIN -->
## ARIS Skill Scope
ARIS skills installed in this project.
<!-- ARIS:END -->

## Project: [项目名称]
**Goal**: [一句话目标]
**Target venue**: [目标期刊]

## GPU
- GPU: [型号, 显存]
- Python: [版本] | 包管理: uv

## 基线方法
- [基线1]: [论文引用 + 实现说明]
- [基线2]: ...

## 实验要求
- ≥150 epochs, ≥5 seeds, ≥1000 测试样本, p<0.01
- 代码在 src/, uv 管理, bash reproduce.sh 一键复现

## 远程服务器（仅在用服务器时写）
- SSH: `ssh myserver`
- GPU: [规格]。从高 GPU index 往低用。
- 代码目录: `/path/to/project`
- HF 镜像: `export HF_ENDPOINT=https://hf-mirror.com`（HF 被墙时用）
- 所有代码在服务器运行。除代码目录外不修改任何文件。
- tmux: `tmux new -d -s exp 'bash -c "..."'`
```

### 第 4 步：启动 Claude Code，发射

```
/research-pipeline "你的研究方向" --deep_mode: true, auto_write: true, auto_proceed: true, venue: "你的目标期刊", arxiv_download: true
```

## 马拉松 Prompt 示例

通用：
```
/research-pipeline "用方法X在场景Y上解决任务Z，在指标上超越基线A、B、C" --deep_mode: true, auto_write: true, auto_proceed: true, venue: "Nature Communications", arxiv_download: true
```

领域示例（量子传感）：
```
/research-pipeline "用TTM时间序列基础模型对NV色心Ramsey干涉实验做深度优化。data_lab/有真实实验数据。基线: FFT+Rife, LM-NLS, Bayesian MCMC, LSTM, NVRNet。>=150 epochs, >=5 seeds, p<0.01。全部源码src/, uv管理, bash reproduce.sh一键复现。产出Optics Letters论文。" --deep_mode: true, auto_write: true, auto_proceed: true, venue: "Optics Letters", arxiv_download: true
```

## 参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `deep_mode` | false | true=30轮实验+3轮论文改进 |
| `auto_write` | false | 实验完成后自动写论文+审稿 |
| `auto_proceed` | true | 自动选最佳idea |
| `venue` | ICLR | 目标期刊/会议，任意名字都可以 |
| `arxiv_download` | false | 下载arXiv论文PDF |
| `base_repo` | false | 基于哪个GitHub仓库做实验 |
| `from-phase` | 0 | 从Phase N恢复（0-4） |

## 管线架构（v3）

```
Phase 0          Phase 1          Phase 2             Phase 3         Phase 4
知识库构建   →   Idea发现     →   深度实验循环    →   论文写作    →   跨阶段审稿
(自动)          (自动)            (≤30轮)            (自动)           (≤5轮迭代)
    │               │                 │                  │                │
    ▼               ▼                 ▼                  ▼                ▼
/knowledge-     /idea-discovery  /deep-experiment-loop /paper-writing  /domain-reviewer
builder         (调研→创意→查新)  (假设→代码→跑→画→析) (模板→写→编→改) (Codex MCP审稿)
```

## 强制执行机制

| 层级 | 机制 |
|------|------|
| 每轮审计 | `round_sentinel.sh` — 6个文件不全不准DECIDE |
| Phase过渡 | `phase_sentinel.sh` — 58+项检查，fail不准推进 |
| 技能内嵌 | NEVER STOP指令、ANTI-CHEAT检查、experiment-reviewer |
| Hooks | PostToolUse + PreToolUse自动触发 |

## 代码产物（跑完管线后）

```
project/
├── src/                    ← 全部源码（自包含，不依赖ARIS）
├── reproduce.sh            ← 一键复现 bash reproduce.sh
├── pyproject.toml .gitignore README.md
├── checkpoints/            ← >=3个模型权重
├── deep-experiment-logs/   ← 30轮实验历史
├── paper/                  ← LaTeX + 编译PDF
└── review-stage/           ← 审稿报告 + SUBMISSION_READY
```

## 84 个技能

| 类别 | 技能 |
|------|------|
| 管线核心 | research-pipeline, deep-experiment-loop, domain-reviewer, experiment-reviewer |
| 知识库 | knowledge-builder, research-wiki, arxiv, semantic-scholar, deepxiv, openalex |
| Idea | idea-discovery, idea-creator, novelty-check, research-lit, research-review |
| 实验 | run-experiment, analyze-results, paper-figure, figure-spec, result-to-claim |
| 论文 | paper-writing, paper-plan, paper-write, paper-compile, auto-paper-improvement-loop |
| 审稿 | experiment-audit, citation-audit, paper-claim-audit, proof-checker |
| 基础设施 | repo-clone, monitor-experiment, training-check, system-profile, overleaf-sync |

## 引用

```bibtex
@misc{ARIS2026,
  title={Auto-claude-code-research-in-sleep},
  author={Yin, Wanshui and the ARIS contributors},
  year={2026},
  howpublished={\url{https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep}},
}
```

Apache 2.0 License.
