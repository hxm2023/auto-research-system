# ARIS：一套能自动跑完从 Idea 到论文 PDF 全流程的 AI 科研系统

> **输入一个研究方向，睡一觉醒来看到论文 PDF。** 这不是科幻。这是我们魔改的 ARIS（Autonomous Research Integration System）能做到的事情。

---

## 它是什么

ARIS 是一套基于 Claude Code 的 AI 驱动全自动科研管线。它把整个科研流程——从文献调研、idea 生成、实验循环、论文写作到跨模型审稿——全部编排成 5 个自动执行的 Phase，每个 Phase 之间有强制关口检查，任何一个产出不达标就退回重做。

**87 个技能**（Skills）像乐高积木一样组装在一起，每个技能是一份 Markdown 文件，Claude Code 读取后就知道该怎么工作。

如果你正在投 NeurIPS/ICML/ACL/物理期刊、做毕业设计、或者想在一夜之间把一个想法变成可投稿的论文初稿，ARIS 就是为你准备的。

---

## 管线架构

```
研究方向 输入
    │
Phase 0: 知识库构建（10-30min）
    │  自动搜索领域知识，下载参考论文，建立搜索索引
    ▼
Phase 1: Idea 发现（30-60min）
    │  文献调研→生成 8-12 个 idea→验证新颖性→排名推荐
    ▼
Phase 2: 深度实验循环（4-48h，≤30轮）
    │  每轮：假设→写代码→跑实验→画图→分析→决定
    │  不打败所有基线不准停
    ▼
Phase 3: 论文写作（45-90min）
    │  自动找期刊模板→写 LaTeX→插入真实图片→编译 PDF
    ▼
Phase 4: 跨阶段审稿（≤5 轮迭代）
    │  GPT-5.5 独立审稿→不通过就退回重做
    ▼
可投稿论文 PDF
```

---

## 它和原版 ARIS 有什么不同

ARIS 最初来自 [Wanshui Yin 的 Auto-claude-code-research-in-sleep](https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep)。我们在其基础上做了大量魔改：

### 管线升级：Workflow 1/2/3 → Phase 0-4

原版管线是"实验桥接→自动审稿→论文写作"的线性流程。我们重写为 5 个 Phase，增加了：
- **Phase 0（知识库构建）**：在文献调研前先搜索领域 overview、标准指标和基线、绘图规范，下载参考论文全文提取
- **Phase 4（跨阶段审稿）**：替换了原版的 auto-review-loop，用 GPT-5.5（Codex MCP）做独立跨模型审稿

### 深度实验循环：从"跑一次就结束"到"30 轮迭代"

原版的 experiment-bridge + auto-review-loop 基本是"实现→跑→审→结束"。我们重写为 `deep-experiment-loop`：
- 每轮包含 8 个步骤：假设→实现→烟雾测试→委托执行→委托分析→声明检查→委托绘图→日志→决定
- 4 态决策：CONTINUE / REFINE / PIVOT / SYNTHESIZE
- 11 条硬性退出条件（不打败基线不准停、≥100 epochs、≥5 seeds、p<0.01……）

### 强制关口系统：58+ 二进制检查

这是原版完全没有的。我们创建了 4 个 sentinel 脚本：
- `gate_check.sh`：58+ 项检查，覆盖 5 个 Phase 的所有产出。Pass = 继续，Fail = 停
- `round_sentinel.sh`：每轮实验后自动审计，缺文件不准 DECIDE
- `phase_sentinel.sh`：Phase 过渡关口，二进制阻断
- `factual_audit.sh`：Codex MCP 审稿前 8 项自动事实核查

### 代码工程：统一仓库而非散落 ROUND_NN/

原版实验代码散落在各轮目录中。我们要求所有代码写入统一的 `src/` 仓库，用 uv 管理环境，`bash reproduce.sh` 一键复现全流程。

### 领域感知：不只是 AI 会议的 matplotlib 默认图

我们给 paper-figure 技能加入了：
- 7 种图表类型（bar/heatmap/scatter/line/box/forest/violin）
- 4 种期刊主题（Nature/Lancet/conservative/publication）
- Contract-First 方法（先定义"这张图证明什么"，再画）
- 禁止默认 matplotlib tab10（必须色盲友好）
- 从知识库读取该领域的绘图规范

### 跨模型审稿：不是自己审自己

Phase 4 的 domain-reviewer 用 GPT-5.5（Codex MCP）做独立审稿。Claude 组装审稿 prompt + 领域知识库，GPT-5.5 给出评分和判决。审稿结果带 `rollback_to: Phase N` 和 `fix_target`，管线自动回滚到指定子阶段修复。

---

## 如何使用

### 安装（3 步）

```bash
# 1. 克隆 ARIS
git clone https://github.com/hxm2023/auto-research-system.git aris_repo

# 2. 创建你的项目文件夹
mkdir my-research && cd my-research && git init

# 3. 安装技能
bash ../aris_repo/tools/install_aris.sh
```

### 发射（1 条命令）

打开 Claude Code，粘贴：

```
/research-pipeline "你的研究方向" --deep_mode: true, auto_write: true, auto_proceed: true, venue: "你的目标期刊", arxiv_download: true
```

然后去睡觉。醒来看论文 PDF。

### 真实案例（量子传感领域）

```
/research-pipeline "用IBM Granite TTM时间序列基础模型对NV色心Ramsey干涉实验做深度优化。data_lab/有真实实验数据。基线: FFT+Rife, LM-NLS, Bayesian MCMC, LSTM, NVRNet。>=150 epochs, >=5 seeds, p<0.01。全部源码src/, uv管理, bash reproduce.sh一键复现。产出Optics Letters论文。" --deep_mode: true, auto_write: true, auto_proceed: true, venue: "Optics Letters", arxiv_download: true
```

### 中断恢复

```bash
/research-pipeline "..." --from-phase: 2  # 从实验阶段恢复
```

### 参数说明

| 参数 | 默认 | 说明 |
|------|------|------|
| `deep_mode` | false | true=30轮实验+3轮论文改进 |
| `auto_write` | false | 实验后自动写论文+审稿 |
| `auto_proceed` | true | 自动选最佳 idea |
| `venue` | ICLR | 目标期刊，任意名字均可（自动调研） |
| `arxiv_download` | false | 下载 arXiv 论文 PDF |
| `from-phase` | 0 | 从 Phase N 恢复（0-4） |

---

## 87 个技能一览

### 管线核心
| 技能 | 角色 |
|------|------|
| `research-pipeline` | 总调度，串联 5 个 Phase |
| `deep-experiment-loop` | 实验决策编排，委托重活给子技能 |
| `domain-reviewer` | 三阶段跨模型审稿 |
| `experiment-reviewer` | 二进制 PASS/FAIL 数值审查 |

### 知识库
| 技能 | 角色 |
|------|------|
| `knowledge-builder` | WebSearch 建领域 RAG + 下载论文 |
| `research-wiki` | 论文/idea/实验知识图谱 |
| `arxiv` `semantic-scholar` `deepxiv` `openalex` `exa-search` | 多渠道文献搜索 |

### Idea
| 技能 | 角色 |
|------|------|
| `idea-discovery` | 文献调研→idea 生成→查新→评审全流程 |
| `research-lit` | 搜索分析论文 |
| `idea-creator` | 生成 8-12 个可发表 idea（5 维框架） |
| `novelty-check` | 验证 idea 新颖性 |
| `research-review` | Codex MCP 外部评审 idea |

### 实验
| 技能 | 角色 |
|------|------|
| `run-experiment` | 部署跑实验（本地/远程 GPU） |
| `analyze-results` | 统计分析+对比表 |
| `paper-figure` | 论文级图和表（7 种类型，4 种主题） |
| `figure-spec` | 确定性架构图（JSON→SVG） |
| `result-to-claim` | 判断实验结果是否支撑论文声明 |

### 论文
| 技能 | 角色 |
|------|------|
| `paper-writing` | 模板→规划→写→编→改进全流程 |
| `paper-plan` | 论文大纲规划 |
| `paper-write` | 逐节写 LaTeX（9 条写作质量标准） |
| `paper-compile` | 编译 LaTeX→PDF |
| `auto-paper-improvement-loop` | Codex 审→修→再编 ×3 轮 |

### 审稿
| 技能 | 角色 |
|------|------|
| `citation-audit` | 引用真实性审计 |
| `paper-claim-audit` | 论文数字与实验数据一致性 |
| `proof-checker` | 数学证明验证 |
| `kill-argument` | 对抗性评审 |

### 基础设施
| 技能 | 角色 |
|------|------|
| `repo-clone` | 自动下载基线代码仓库 |
| `overleaf-sync` | 与 Overleaf 双向同步 |
| `system-profile` | 系统性能分析 |
| `meta-optimize` | ARIS 自身使用日志优化 |

---

## 强制执行体系

这是 ARIS 区别于其他 AI 科研工具最核心的地方——不是"建议"你做什么，而是"强制"你做到。

### 三层防御

1. **技能内嵌要求**：每个 Phase 过渡处写着 `🚦 GATE 0→1 (BLOCKING)`、`exit 1 = STOP`
2. **PostToolUse Hook**：每次 Write 工具写文件后自动触发 sentinel 检查
3. **PreToolUse Hook**：调用 paper-writing 前自动检查 Phase 2 是否完成

### 审稿强化（来自 Supervisor-Skills 和 scientific-agent-skills）

我们整合了两个外部科研方法论的精华：
- **Supervisor-Skills**（骆昱宇，港科大广州）：9 条写作质量标准、10 项绘图自查清单、5 维 Idea 框架、审稿人四喜四恶
- **scientific-agent-skills**（K-Dense）：Fisher 实验设计三原则、统计功效分析、伪重复陷阱、MDE 计算

### 审稿子关口（Stage 2 和 Stage 3 共 11 项）

Stage 2（实验审核）：6 个子关口——实验设计、代码质量、训练量、结果质量、图片质量、可复现性。**任一个 FAIL = 退回重做。**

Stage 3（论文审核）：5 个子关口——格式与模板、图表审计、引用审计、内容质量、声明-证据对齐。**任一个 FAIL = 退回重做。** 无免责条款。

---

## 来自三次失败运行的经验

ARIS 不是在真空中设计的。我们跑了三遍完整的管线，每次都中途停下。每次停下都暴露了一个系统性问题：

### 第一次：代码太浅（6 轮就停，TTM 只跑 frozen backbone）

**根因**：deep-experiment-loop 只是"建议"跑更多轮，没有强制。Claude 跑了 6 轮基线后就声明"完成"了。
**修复**：创建 `round_sentinel.sh`——每轮后强制审计，缺 hypothesis/code/results/analysis/decision/plots 中任何一个不准进入 DECIDE。

### 第二次：Codex MCP 从未被调用

**根因**：domain-reviewer 技能里写了"调用 Codex MCP"，但 Claude 理解成了"应该调用"而非"必须调用"。
**修复**：在所有审稿技能中写入 `MUST call mcp__codex__codex`、`Do NOT simulate`、`Do NOT make the PASS/FAIL decision yourself`。

### 第三次：论文编译从未完成，Phase 4 从未触发

**根因**：Phase 3 结束后没有显式跳转到 Phase 4 的指令。
**修复**：在每个 Phase 出口添加 `🚦 AFTER PHASE N → Immediately proceed to Phase N+1. Do NOT stop.`，且用 `phase_sentinel.sh` 强制关口。

---

## 系统设计理念

### 1. 委托而非重写

deep-experiment-loop 不亲自跑实验、不亲自画图、不亲自分析。它只是一个决策编排器。重活委托给专门技能：`/run-experiment`、`/analyze-results`、`/paper-figure`。

### 2. 文件即证据

每轮实验必须产出 6 个文件到磁盘，不存在"心里分析过了"。gate_check.sh 逐项检查文件存在性和内容实质性。

### 3. 跨模型约束

同一件事不能自己审自己。DeepSeek V4 Pro 写代码写论文 → GPT-5.5 独立审稿 → Claude 路由决策。

### 4. 域感知

绘图、写作、基线选择都从知识库读取该领域的规范。量子物理论文不应该画得像 CVPR 论文。

---

## 最新功能（v3.2）

### 信息搜集渠道（11 个）
ARIS 现在可以搜到审稿中的论文（比 arXiv 早 3-6 个月）和推上刚发布的研究：
- **OpenReview**：NeurIPS/ICML/ICLR 审稿中的投稿
- **Twitter/X**（via Nitter，免费）：LLM/CV/RL/AI 领域研究者发布的 pre-arXiv 成果
- **HF Daily Papers**：HuggingFace 社区每日精选，比 arXiv 快 1-3 天
- **arXiv、Semantic Scholar、DeepXiv、OpenAlex、Exa、Gemini**：全学科覆盖

### 科研方法论整合
- **来自 Supervisor-Skills（港科大）**：9 条写作标准、10 项绘图清单、5 维 Idea 框架
- **来自 scientific-agent-skills（K-Dense）**：Fisher 实验设计三原则、统计功效分析
- **来自知乎研0教程**：3 种 Idea 模板（跨域迁移/挑战默认/系统对比）、5 问预检清单、失败复盘协议
- 实验前必须回答"改什么/为什么/最小实验/即使失败学到什么"——不答完不准写代码

### 工程增强
- **wandb 集成**：`wandb_api.txt` 放项目根目录，自动读取。不存在就跳过。gitignored
- **智能 GPU 调度**：每次训练前自动 `nvidia-smi`，从高 index GPU 往下找空闲的
- **代码可复现**：`src/` 统一仓库 + `reproduce.sh` + `pyproject.toml` + `.gitignore` + `README.md`

## 未来方向

- **多 MCP 审稿**：接入 Gemini、Qwen 等更多模型做独立审稿
- **Meta-optimize**：记录每次管线运行的 EXPERIMENT_HISTORY.tsv，学习哪些策略有效
- **向量数据库 RAG**：当前是关键词检索，升级到 embedding-based 语义检索

---

## 引用

如果你在研究中使用了 ARIS，请引用原版：

```bibtex
@misc{ARIS2026,
  title={Auto-claude-code-research-in-sleep},
  author={Yin, Wanshui and the ARIS contributors},
  year={2026},
  howpublished={\url{https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep}},
}
```

魔改版：[https://github.com/hxm2023/auto-research-system](https://github.com/hxm2023/auto-research-system)

---

*文档更新时间：2026-06-19 · 作者：ARIS 贡献者 · Apache 2.0 License*
