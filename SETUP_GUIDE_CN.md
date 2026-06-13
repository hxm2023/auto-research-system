# ARIS 安装指南（中文 · 新手友好）

本指南帮助你从零开始安装和使用 ARIS 自动科研系统。**不需要编程经验。** 按照步骤操作即可。

---

## 你需要什么

| 条件 | 说明 |
|------|------|
| **电脑** | Windows 10/11（推荐），macOS 或 Linux 也可以 |
| **GPU（可选）** | NVIDIA 显卡（跑深度学习实验用）。没有 GPU 也能跑，就是慢 |
| **网络** | 能访问 GitHub 和 arXiv |
| **Git** | 已安装（https://git-scm.com/downloads） |
| **Python** | 已安装 3.11 或更高版本 |
| **Claude Code** | 已安装（https://docs.anthropic.com/en/docs/claude-code） |
| **Codex MCP** | 可选——用于跨模型审稿。没有也能跑 |

---

## 第 1 步：安装 Claude Code

打开命令行（Windows 上打开 `cmd` 或 Git Bash），输入：

```bash
npm install -g @anthropic-ai/claude-code
```

安装完成后，输入 `claude` 回车，按照提示登录即可。

---

## 第 2 步：下载 ARIS

```bash
git clone https://github.com/hxm2023/auto-research-system.git aris_repo
```

下载完成后，你会在当前目录看到 `aris_repo` 文件夹。

---

## 第 3 步：创建你的科研项目文件夹

```bash
mkdir my-research
cd my-research
git init
```

`my-research` 是你的科研项目文件夹，你可以改成自己的项目名称。

---

## 第 4 步：安装 ARIS 技能

```bash
bash ../aris_repo/tools/install_aris.sh
```

### 这个命令做了什么？为什么需要它？

ARIS 由 **84 个技能（Skill）** 组成。每个技能是一个 Markdown 文件，Claude Code 读取后就知道该怎么工作了。`install_aris.sh` 的作用是：

1. **创建技能链接** — 在 `my-research/.claude/skills/` 目录下创建符号链接，指向 `aris_repo/skills/` 里的技能
2. **保留安装记录** — 生成 `my-research/.aris/installed-skills.txt`，记录安装了哪些技能
3. **自动更新 CLAUDE.md** — 如果你的项目已经有 `CLAUDE.md`，会自动添加 ARIS 配置块

运行后你会看到类似输出：
```
ARIS Project Install
  Project:    /c/Users/xxx/my-research
  ARIS repo:  /c/Users/xxx/aris_repo
  CREATE: 84
✓ Install complete
```

---

## 第 5 步：配置项目

在你的项目文件夹里创建 `CLAUDE.md`，写入项目专属配置。一个完整的例子：

```markdown
<!-- ARIS:BEGIN -->
## ARIS Skill Scope
ARIS skills installed in this project. 84 skills available.
Manifest: `.aris/installed-skills.txt`.
Update with: `bash /c/Users/xxx/aris_repo/tools/install_aris.sh`
<!-- ARIS:END -->

## Project: [你的项目名称]

**Goal**: [研究目标]
**Target venue**: [目标期刊]

## GPU
- GPU: NVIDIA GeForce RTX 5060 Laptop GPU (8 GB VRAM)
- CUDA: 12.9 | Driver: 577.05

## Python
- Python 3.12.10
- Package manager: uv
- Key deps: torch, numpy, scipy, matplotlib

## Key Commands
```bash
uv pip install <package>
uv run python src/train.py
bash reproduce.sh
```
```

---

## 第 6 步：发射

在你的项目文件夹里打开 Claude Code，输入：

```
/research-pipeline "你的研究方向" --deep_mode: true, auto_write: true, auto_proceed: true, venue: "你的目标期刊", arxiv_download: true
```

### 参数怎么设？

- `deep_mode: true` → 火力全开（30 轮实验 + 3 轮论文改进）。想速度快一点就设 `false`
- `auto_write: true` → 实验跑完自动写论文。想先看结果再写就设 `false`
- `auto_proceed: true` → 自动选 idea。想自己选就设 `false`
- `venue` → 目标期刊/会议名称。ARIS 会自动去网上搜这个期刊的 LaTeX 模板和投稿要求

---

## 常见问题

### Q: 提示 "python3: command not found"
A: 在 Windows 上 Python 叫 `python` 不是 `python3`。ARIS 已自动适配。

### Q: 提示权限不足
A: 关闭 Claude Code 的 dontAsk 模式：输入 `/permissions`，把 Bash 权限打开。

### Q: 实验跑太慢了
A: 设 `deep_mode: false`，实验轮次从 30 降到 8。或者给 Claude Code 配一个 GPU 服务器。

### Q: 管线跑着跑着停了
A: 正常。如果满足以下任一条件管线会停：
1. 跑了 30 轮实验（MAX_ROUNDS）
2. 通过了 Phase 4 跨阶段审稿（SUBMISSION_READY）
3. 出现无法修复的致命错误
你可以用 `--from-phase: 2` 从实验阶段恢复。

### Q: 怎么更新 ARIS？
A: 
```bash
cd aris_repo
git pull
cd ../my-research
bash ../aris_repo/tools/install_aris.sh
```

---

## 需要帮助？

- 原项目 GitHub: https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep
- 原始论文: arXiv:2605.03042
