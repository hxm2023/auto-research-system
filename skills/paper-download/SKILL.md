---
name: paper-download
description: "Download reference papers from research-wiki, extract text and figures, build a searchable RAG knowledge base for domain-aware work agents and reviewer agents. Use when user says 'download papers', 'build knowledge base', 'RAG', 'paper library', or wants to populate research-wiki with actual paper content."
argument-hint: "[scope: all|arxiv-ids|keyword]"
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, WebSearch, WebFetch
---

# Paper Download & Knowledge Base Builder

Download and index papers for: **$ARGUMENTS**

## Overview

This skill populates `research-wiki/papers/` with downloaded PDFs, extracts text and key figures,
and builds a searchable knowledge base that domain-aware agents (work agents, reviewer agents)
can reference for field-specific knowledge.

## When to Use

- After literature survey (`/research-lit`, `/arxiv`, etc.) when papers are ingested but not downloaded
- Before running the domain-reviewer (needs paper content for domain knowledge)
- Before generating figures (needs field-specific plot conventions)
- Whenever the user says "下载论文", "build knowledge base", "RAG"

## Workflow

### Phase 1: Identify Papers to Download

Check `research-wiki/papers/` for ingested paper stubs. Each `.md` file has YAML frontmatter
with `external_ids.arxiv` or `external_ids.doi`.

```bash
# List papers that have arXiv IDs but no PDF
for f in research-wiki/papers/*.md; do
  arxiv_id=$(grep "arxiv:" "$f" | head -1 | sed 's/.*arxiv: *"\([^"]*\)".*/\1/')
  slug=$(basename "$f" .md)
  if [ -n "$arxiv_id" ] && [ ! -f "research-wiki/papers/$slug.pdf" ]; then
    echo "$slug -> $arxiv_id"
  fi
done
```

Also check `research-wiki/knowledge_base/` exists; create if not.

### Phase 2: Download PDFs

For each paper with an arXiv ID:

```bash
arxiv_id="XXXX.XXXXX"
slug="author2025_title"
# Download from arXiv
python -c "
import urllib.request
url = f'https://arxiv.org/pdf/{arxiv_id}.pdf'
urllib.request.urlretrieve(url, f'research-wiki/papers/{slug}.pdf')
print(f'Downloaded {arxiv_id} -> {slug}.pdf')
"
```

If arXiv download fails (some papers are behind paywalls), try:
- Semantic Scholar API for open-access PDF links
- Unpaywall API for legal open-access versions
- Author homepage / institutional repository

### Phase 3: Extract Text

Extract full text from PDFs for the knowledge base:

```python
# Using pymupdf (pip install pymupdf)
import fitz  # pymupdf
import json, os

pdf_dir = "research-wiki/papers"
kb_dir = "research-wiki/knowledge_base"
os.makedirs(kb_dir, exist_ok=True)

documents = []

for pdf_file in os.listdir(pdf_dir):
    if not pdf_file.endswith('.pdf'):
        continue

    slug = pdf_file.replace('.pdf', '')
    doc = fitz.open(os.path.join(pdf_dir, pdf_file))

    full_text = ""
    sections = []

    for page_num, page in enumerate(doc):
        text = page.get_text()
        full_text += text + "\n"

        # Extract sections by font size heuristics
        blocks = page.get_text("dict")["blocks"]
        for block in blocks:
            if "lines" in block:
                for line in block["lines"]:
                    for span in line["spans"]:
                        if span["size"] > 11:  # heading-level font
                            sections.append({
                                "page": page_num + 1,
                                "text": span["text"].strip(),
                                "font_size": span["size"],
                                "bbox": list(span["bbox"]),
                            })

    # Save per-paper JSON
    paper_data = {
        "slug": slug,
        "full_text": full_text,
        "sections": sections,
        "num_pages": len(doc),
    }
    with open(os.path.join(kb_dir, f"{slug}.json"), "w", encoding="utf-8") as f:
        json.dump(paper_data, f, ensure_ascii=False, indent=2)

    documents.append(paper_data)
    doc.close()

# Save combined index
with open(os.path.join(kb_dir, "index.json"), "w", encoding="utf-8") as f:
    json.dump({"papers": [d["slug"] for d in documents], "count": len(documents)}, f)

print(f"Extracted {len(documents)} papers to {kb_dir}/")
```

### Phase 4: Extract Key Figures

Extract figures from papers for plot convention reference:

```python
import fitz, os

pdf_dir = "research-wiki/papers"
fig_dir = "research-wiki/knowledge_base/figures"
os.makedirs(fig_dir, exist_ok=True)

for pdf_file in os.listdir(pdf_dir):
    if not pdf_file.endswith('.pdf'):
        continue

    slug = pdf_file.replace('.pdf', '')
    doc = fitz.open(os.path.join(pdf_dir, pdf_file))

    for page_num in range(len(doc)):
        page = doc[page_num]
        images = page.get_images(full=True)
        for img_idx, img in enumerate(images):
            xref = img[0]
            base_image = doc.extract_image(xref)
            image_bytes = base_image["image"]
            ext = base_image["ext"]
            img_path = os.path.join(fig_dir, f"{slug}_p{page_num+1}_f{img_idx+1}.{ext}")
            with open(img_path, "wb") as f:
                f.write(image_bytes)

    doc.close()

print(f"Extracted figures to {fig_dir}/")
```

### Phase 5: Build Searchable Index

Create a simple search script for the knowledge base:

```python
# Save as research-wiki/knowledge_base/search.py
import json, os, sys

kb_dir = os.path.dirname(os.path.abspath(__file__))

def search(query, top_k=5):
    """Simple keyword search over paper texts."""
    results = []
    query_terms = query.lower().split()

    for f in os.listdir(kb_dir):
        if not f.endswith('.json') or f == 'index.json':
            continue
        with open(os.path.join(kb_dir, f), encoding='utf-8') as fp:
            data = json.load(fp)

        text_lower = data['full_text'].lower()
        score = sum(text_lower.count(term) for term in query_terms)
        if score > 0:
            # Extract relevant snippets
            snippets = []
            for term in query_terms:
                idx = text_lower.find(term)
                if idx >= 0:
                    start = max(0, idx - 200)
                    end = min(len(text_lower), idx + 200)
                    snippets.append(data['full_text'][start:end])

            results.append({
                'slug': data['slug'],
                'score': score,
                'snippets': snippets[:3],
            })

    results.sort(key=lambda x: x['score'], reverse=True)
    return results[:top_k]

if __name__ == '__main__':
    query = ' '.join(sys.argv[1:])
    for r in search(query):
        print(f"\n## {r['slug']} (score: {r['score']})")
        for s in r['snippets']:
            print(f"  ...{s[:300]}...")
```

### Final Phase: Report

Write `research-wiki/knowledge_base/README.md`:
```
# Knowledge Base Status
- Papers downloaded: N
- Papers with full text: M
- Figures extracted: F
- Last updated: YYYY-MM-DD

## Search Usage
python research-wiki/knowledge_base/search.py "quantum sensing NV center phase estimation"
```

## Integration

After building the knowledge base:
- **Work agents** (deep-experiment-loop) can search for field-specific plot conventions
- **Reviewer agents** (domain-reviewer) can verify claims against published results
- **Paper writing** can check citation context accuracy

## Key Rules

1. Only download papers that are in research-wiki/papers/ (already ingested and validated)
2. Respect copyright: only download from legitimate open-access sources (arXiv, author pages)
3. Store everything in `research-wiki/knowledge_base/` — this is .gitignored (large files)
4. Re-run to update when new papers are ingested
