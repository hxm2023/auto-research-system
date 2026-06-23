---
name: twitter-search
description: "Search Twitter/X for cutting-edge AI/ML research discussions via Nitter (free, no API key). Best for LLM, CV, robotics, RL, and AI fields where researchers actively share new papers, ideas, and pre-prints on Twitter. Use when user says '搜推特', 'twitter search', 'what's trending on ML twitter', 'X上有什么新论文', or wants pre-arXiv research signals."
argument-hint: "[topic-or-keyword]"
allowed-tools: Bash(*), Read, Write, WebFetch, WebSearch
---

# Twitter/X Search via Nitter

Search research discussions on Twitter: **$ARGUMENTS**

## When to Use (AI/ML/CV/RL/Robotics only)

Twitter is a primary research communication channel for:
- LLM/NLP: new training techniques, benchmark results, model releases
- Computer Vision: architecture innovations, dataset releases
- Reinforcement Learning: GRPO/PPO/RLHF advances, training tips
- Embodied AI/Robotics: sim-to-real, manipulation breakthroughs
- General ML: conference decisions, paper discussions, hiring trends

**Do NOT use for**: physics, chemistry, biology, quantum sensing, or other non-CS fields.
Twitter is not a primary research channel for those — use arXiv/Semantic Scholar instead.

## Nitter Instances (try in order)

Nitter is a free, privacy-respecting Twitter frontend. No API key needed.

| Instance | Status |
|----------|--------|
| `https://nitter.net` | Primary (confirmed working) |
| `https://nitter.privacydev.net` | Fallback 1 |
| `https://nitter.poast.org` | Fallback 2 |

## Workflow

### Step 1: Search Twitter

```bash
# Primary method: WebFetch Nitter search results
KEYWORD="GRPO training"  # from $ARGUMENTS
QUERY=$(echo "$KEYWORD" | sed 's/ /+/g')
WebFetch: "https://nitter.net/search?f=tweets&q=$QUERY"
```

### Step 2: Parse Results

Nitter returns HTML with tweets in `<div class="tweet-content">`. Extract tweet text, author, date, and engagement (likes/retweets/replies). Summarize the top 10 most-engaged tweets.

### Step 3: Follow Threads

If a tweet links to a paper or GitHub repo, follow the link. Read the paper abstract or repo README. This often surfaces pre-arXiv work.

### Step 4: Search for Trending Topics

```bash
# Trending AI/ML discussions (last 24h)
WebFetch: "https://nitter.net/search?f=tweets&q=GRPO+OR+RLHF+OR+LLM+training&since=2026-06-01"
```

### Step 5: Ingest Notable Findings

If a tweet reveals a new paper (with arXiv link), method breakthrough, or benchmark result, ingest into research-wiki:

```
/research-wiki ingest "<paper title>" — arxiv: <id>
```

## Key Rules

1. **Only search AI/ML/CV/RL/Robotics topics.** Twitter is not useful for other fields.
2. **Nitter is free, no API key.** If an instance is down, try the next one.
3. **Twitter signals arrive DAYS before arXiv.** A paper announcement tweet often appears 1-3 days before the arXiv listing.
4. **Engagement is a quality signal.** Prioritize tweets with 20+ likes or replies from known researchers.
5. **Thread replies contain pre-publication peer review.** Academic debates in replies are gold for understanding paper weaknesses.
6. **Be respectful of rate limits.** Space searches by 2+ seconds.
