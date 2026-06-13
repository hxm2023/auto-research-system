---
name: knowledge-builder
description: "Build a comprehensive domain RAG knowledge base: gathers field overview, standard methods, key metrics, and common baselines via web search, then downloads and extracts reference papers. Produces a structured, searchable knowledge base for domain-aware work agents and reviewer agents. Use when user says 'build knowledge base', 'RAG', '知识库', 'domain knowledge', or before running the research pipeline."
argument-hint: "[research-topic]"
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, WebSearch, WebFetch
---

# Knowledge Builder: Comprehensive Domain RAG

Build a domain knowledge base for: **$ARGUMENTS**

## Overview

This skill builds a structured, searchable knowledge base in `research-wiki/knowledge_base/`
that contains BOTH:

1. **Domain Context**: field overview, standard methods, key metrics, common baselines,
   evaluation protocols, and field-specific conventions (from web search)
2. **Paper Content**: full text and extracted figures from downloaded reference papers
   (from arXiv / open-access sources)

The knowledge base is consumed by:
- **Work agents** (`/deep-experiment-loop`): for field-appropriate plotting, baseline selection
- **Reviewer agents** (`/domain-reviewer`): for domain-aware claim verification
- **Paper writing**: for citation context accuracy

## When to Use

- Before starting a new research project (build domain knowledge first)
- Before running the domain-reviewer (needs field context to evaluate claims)
- When the user says "build knowledge base", "RAG", "下载论文建知识库", "领域知识准备"
- Automatically as Phase 0 of `/research-pipeline`

## Output Structure

```
research-wiki/knowledge_base/
├── domain_overview.md        # field overview, key concepts, standard methods
├── metrics_and_baselines.md  # standard metrics, SOTA baselines, evaluation protocols
├── field_conventions.md      # plot types, notation, terminology specific to this field
├── papers/                   # one JSON per paper (full text + sections + figures)
│   ├── author2025_title.json
│   └── ...
├── figures/                  # extracted figures from papers (for plot convention reference)
├── index.json                # combined search index
├── search.py                 # simple keyword search script
└── README.md                 # KB status and usage
```

---

## Phase 1: Domain Context Gathering

**Purpose**: Build field-level knowledge BEFORE diving into specific papers.

### 1A. Field Overview

Search the web for the research topic and capture the big picture:

```
WebSearch: "<research topic> overview survey"
WebSearch: "<research topic> key methods comparison"
WebSearch: "<research topic> standard evaluation protocol"
```

Compile findings into `research-wiki/knowledge_base/domain_overview.md`:

```markdown
# Domain Overview: [Research Topic]

## What is this field?
[2-3 paragraph summary of the research area, its importance, and current state]

## Key Concepts
- [Concept 1]: [definition and significance]
- [Concept 2]: [definition and significance]
...

## Standard Methods
1. [Method A]: [how it works, when it's used, typical performance]
2. [Method B]: [how it works, when it's used, typical performance]
...

## Active Research Directions
- [Direction 1]
- [Direction 2]
...

## Key Venues
- [Venue 1]: [what they publish, acceptance criteria]
- [Venue 2]: [what they publish, acceptance criteria]
```

### 1B. Metrics and Baselines

```
WebSearch: "<research topic> benchmark metrics"
WebSearch: "<research topic> state of the art baseline methods"
```

Compile into `research-wiki/knowledge_base/metrics_and_baselines.md`:

```markdown
# Metrics and Baselines: [Research Topic]

## Standard Evaluation Metrics
| Metric | Definition | Typical Range | What It Measures |
|--------|-----------|---------------|-----------------|
| [Metric 1] | [formula or description] | [typical values] | [what it captures] |
...

## SOTA Baselines (ranked by relevance)
| Method | Paper | Year | Key Performance | Code Available? |
|--------|-------|------|-----------------|-----------------|
| [Method 1] | [citation] | 2024 | [metric=value] | Yes/No (URL) |
...

## Classical Methods (pre-neural)
| Method | When to Use | Expected Performance | Limitations |
|--------|-------------|---------------------|-------------|
| [Method A] | [scenario] | [typical error] | [when it fails] |
...
```

### 1C. Field Conventions

```
WebSearch: "<research topic> paper figures typical plots"
WebSearch: "<research topic> notation conventions"
```

Compile into `research-wiki/knowledge_base/field_conventions.md`:

```markdown
# Field Conventions: [Research Topic]

## Plot Types
- [Plot Type 1]: used for [purpose]. Example: [description].
  Typical: [log-log / linear / polar / ...]
- [Plot Type 2]: used for [purpose].
...

## Notation Conventions
- [symbol]: typically means [definition]
- [symbol]: typically means [definition]
...

## Paper Structure
- Typical sections: [list]
- Typical length: [pages]
- Figure count: typically [N-M]
...
```

---

## Phase 2: Paper Download and Extraction

### 2A. Identify Papers

Check `research-wiki/papers/` for ingested stubs with arXiv IDs or DOIs.
If empty, search for key papers:

```
WebSearch: "arxiv <research topic> <year>"
```

For each identified paper, ingest into research-wiki first (via `/research-wiki ingest`),
then proceed to download.

### 2B. Download PDFs

For each paper with an arXiv ID:

```python
import urllib.request, os
arxiv_id = "XXXX.XXXXX"
slug = "author2025_title"
url = f"https://arxiv.org/pdf/{arxiv_id}.pdf"
os.makedirs("research-wiki/papers", exist_ok=True)
urllib.request.urlretrieve(url, f"research-wiki/papers/{slug}.pdf")
print(f"Downloaded {arxiv_id}")
```

### 2C. Extract Text

```python
import fitz, json, os  # pymupdf

pdf_dir = "research-wiki/papers"
kb_dir = "research-wiki/knowledge_base/papers"
os.makedirs(kb_dir, exist_ok=True)

for pdf_file in os.listdir(pdf_dir):
    if not pdf_file.endswith('.pdf'): continue
    slug = pdf_file.replace('.pdf', '')
    doc = fitz.open(os.path.join(pdf_dir, pdf_file))
    full_text = ""
    for page in doc:
        full_text += page.get_text() + "\n"
    with open(os.path.join(kb_dir, f"{slug}.json"), "w", encoding="utf-8") as f:
        json.dump({"slug": slug, "full_text": full_text, "num_pages": len(doc)}, f, ensure_ascii=False)
    doc.close()

print(f"Extracted {len(os.listdir(kb_dir))} papers")
```

### 2D. Extract Figures

```python
import fitz, os

fig_dir = "research-wiki/knowledge_base/figures"
os.makedirs(fig_dir, exist_ok=True)

for pdf_file in os.listdir(pdf_dir):
    if not pdf_file.endswith('.pdf'): continue
    slug = pdf_file.replace('.pdf', '')
    doc = fitz.open(os.path.join(pdf_dir, pdf_file))
    for pg in range(len(doc)):
        for img in doc[pg].get_images(full=True):
            xref = img[0]
            base = doc.extract_image(xref)
            with open(f"{fig_dir}/{slug}_p{pg+1}_{img[0]}.{base['ext']}", "wb") as f:
                f.write(base["image"])
    doc.close()
```

---

## Phase 3: Build Search Index

```python
import json, os

kb_dir = "research-wiki/knowledge_base"
papers_dir = os.path.join(kb_dir, "papers")

# Build combined index
index = {
    "domain_files": ["domain_overview.md", "metrics_and_baselines.md", "field_conventions.md"],
    "papers": [],
    "total_papers": 0,
}

for f in os.listdir(papers_dir):
    if f.endswith('.json') and f != 'index.json':
        index["papers"].append(f.replace('.json', ''))
        index["total_papers"] += 1

with open(os.path.join(kb_dir, "index.json"), "w") as f:
    json.dump(index, f, indent=2)

# Simple search script
search_code = '''
import json, os, sys
kb_dir = os.path.dirname(os.path.abspath(__file__))
papers_dir = os.path.join(kb_dir, "papers")

def search(query, top_k=10):
    results = []
    query_terms = query.lower().split()
    # Search domain files
    for fname in ["domain_overview.md", "metrics_and_baselines.md", "field_conventions.md"]:
        fpath = os.path.join(kb_dir, fname)
        if os.path.exists(fpath):
            with open(fpath, encoding="utf-8") as f:
                text = f.read().lower()
            score = sum(text.count(t) for t in query_terms)
            if score > 0:
                results.append({"source": fname, "score": score, "type": "domain"})
    # Search papers
    for fname in os.listdir(papers_dir):
        if not fname.endswith('.json'): continue
        with open(os.path.join(papers_dir, fname), encoding="utf-8") as f:
            data = json.load(f)
        text = data["full_text"].lower()
        score = sum(text.count(t) for t in query_terms)
        if score > 0:
            idx = text.find(query_terms[0]) if query_terms else 0
            snippet = data["full_text"][max(0,idx-150):idx+150]
            results.append({"source": data["slug"], "score": score, "snippet": snippet, "type": "paper"})
    results.sort(key=lambda x: x["score"], reverse=True)
    return results[:top_k]

if __name__ == "__main__":
    for r in search(" ".join(sys.argv[1:])):
        print(f"\\n[{r['type']}] {r['source']} (score={r['score']})")
        if r['type'] == 'paper':
            print(f"  ...{r['snippet'][:300]}...")
'''

with open(os.path.join(kb_dir, "search.py"), "w") as f:
    f.write(search_code)

print(f"Knowledge base built at {kb_dir}/")
print(f"  Domain files: 3")
print(f"  Papers: {index['total_papers']}")
print(f"  Search: python {kb_dir}/search.py '<query>'")
```

---

## Final Phase: Report

Write `research-wiki/knowledge_base/README.md` with status and usage.

## Integration with Pipeline

The knowledge base is consumed by:

1. **Phase 1 (Idea Discovery)**: `/research-lit` searches KB before external APIs
2. **Phase 2 (Deep Experiment Loop)**: PLOT step reads `field_conventions.md` for plot types
3. **Phase 4 (Domain Reviewer)**: searches KB to verify claims against published results

## Key Rules

1. Build domain knowledge BEFORE downloading papers — understand the field first
2. Only download from legitimate sources (arXiv, open-access, author pages)
3. Store everything in `research-wiki/knowledge_base/` (gitignore large files)
4. Re-run to update when new papers are ingested or when the research direction changes
5. The KB is supplementary — it does not replace real literature review
