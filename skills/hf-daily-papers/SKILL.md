---
name: hf-daily-papers
description: "Browse and search HuggingFace Daily Papers — the community-curated feed of trending ML/AI papers updated daily. Use when user says 'HF daily', 'huggingface papers today', 'trending papers', 'latest ML papers', or wants the freshest research before arXiv indexing."
argument-hint: "[topic-or-date]"
allowed-tools: Bash(*), Read, Write, WebFetch, WebSearch
---

# HuggingFace Daily Papers

Search or browse the HF Daily Papers feed: **$ARGUMENTS**

## Overview

HuggingFace Daily Papers (huggingface.co/papers) is the go-to source for LLM researchers.
Papers appear here 1-3 days before arXiv indexing, with community upvotes and discussions.
This skill fetches and summarizes trending papers.

## Workflow

### Step 1: Fetch the Feed

```bash
# Fetch today's trending papers
python -c "
import json, urllib.request
url = 'https://huggingface.co/api/daily_papers'
req = urllib.request.Request(url, headers={'User-Agent': 'ARIS/1.0'})
data = json.loads(urllib.request.urlopen(req).read())
for i, p in enumerate(data[:10]):
    print(f'{i+1}. [{p[\"paper\"][\"upvotes\"]}↑] {p[\"paper\"][\"title\"]}')
    print(f'   {p[\"paper\"][\"id\"]} | {p[\"paper\"][\"publishedAt\"][:10]}')
    print()
"
```

### Step 2: Search Specific Topic

If `$ARGUMENTS` specifies a topic, filter papers:

```python
import json, urllib.request, sys
topic = sys.argv[1].lower() if len(sys.argv) > 1 else ''
url = 'https://huggingface.co/api/daily_papers'
req = urllib.request.Request(url, headers={'User-Agent': 'ARIS/1.0'})
data = json.loads(urllib.request.urlopen(req).read())
for p in data:
    title = p['paper']['title'].lower()
    abstract = p.get('paper', {}).get('abstract', '').lower()
    if topic in title or topic in abstract:
        print(f'[{p[\"paper\"][\"upvotes\"]}↑] {p[\"paper\"][\"title\"]}')
        print(f'  ID: {p[\"paper\"][\"id\"]} | {p[\"paper\"][\"publishedAt\"][:10]}')
```

### Step 3: Read a Paper's Discussion

To read the community discussion and paper details:

```python
paper_id = "PAPER_ID"  # e.g., "2606.xxxxx"
url = f'https://huggingface.co/api/daily_papers/{paper_id}'
req = urllib.request.Request(url, headers={'User-Agent': 'ARIS/1.0'})
data = json.loads(urllib.request.urlopen(req).read())
# Print discussion summary and paper metadata
```

### Step 4: Ingest into Research Wiki

If the research wiki exists, ingest high-upvote papers (≥10 upvotes):

```
/research-wiki ingest "<paper title>" — arxiv: <id>
```

## Key Rules

1. HF Daily Papers updates every ~12 hours. Fetch on each invocation.
2. Upvote count is a proxy for community interest — prioritize papers with ≥10 upvotes.
3. Papers here often predate arXiv indexing by 1-3 days.
4. Community discussion threads contain early peer review-like commentary.
