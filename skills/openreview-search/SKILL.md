---
name: openreview-search
description: "Search OpenReview for conference submissions (NeurIPS, ICML, ICLR, etc.) — including papers under review, accepted papers, and reviewer discussions. Accesses papers 3-6 months before arXiv publication. Use when user says 'openreview', 'conference submissions', 'under review', 'peer review discussion', or wants pre-publication papers from top ML venues."
argument-hint: "[topic-or-venue]"
allowed-tools: Bash(*), Read, Write, WebFetch, WebSearch
---

# OpenReview Search

Search conference submissions on OpenReview: **$ARGUMENTS**

## Overview

OpenReview hosts papers from NeurIPS, ICML, ICLR, AAAI, and other top venues — including
papers currently under review. This is the earliest access point for cutting-edge research:
papers appear here 3-6 months before they hit arXiv. Reviewer discussions are also visible,
providing pre-publication peer review signals.

## Venue Mapping

| Venue | OpenReview ID |
|-------|-------------|
| NeurIPS 2026 | NeurIPS.cc/2026/Conference |
| ICML 2026 | ICML.cc/2026/Conference |
| ICLR 2026 | ICLR.cc/2026/Conference |
| AAAI 2026 | AAAI.org/2026/Conference |
| ACL 2026 | ACLWeb.org/2026/Conference |
| EMNLP 2026 | EMNLP/2026/Conference |
| CVPR 2026 | thecvf.com/CVPR/2026/Conference |

If `$ARGUMENTS` specifies a venue, use its OpenReview ID. Otherwise search broadly.

## Workflow

### Step 1: Search by Venue + Keyword (primary: WebSearch + WebFetch)

OpenReview's API may be unstable. Use WebSearch + WebFetch as the primary method:

```
WebSearch: "site:openreview.net <keyword> <venue> 2026"
```

Then WebFetch the result pages. This always works and needs no API key.

### Step 2: API Search (fallback, if WebSearch returns nothing)

```bash
python -c "
import json, urllib.request

# OpenReview API v2 — note: may require specific header format
body = json.dumps({'query': {'term': '$ARGUMENTS'}})
try:
    req = urllib.request.Request(
        'https://api2.openreview.net/notes/search',
        data=body.encode(),
        headers={'Content-Type': 'application/json'}
    )
    data = json.loads(urllib.request.urlopen(req, timeout=15).read())
    for n in data.get('notes', [])[:10]:
        t = n.get('content', {}).get('title', {}).get('value', '')
        print(f'  {t}')
except Exception as e:
    print(f'API unavailable ({e}), use WebSearch instead')
"
```

### Step 2: Get Paper with Reviews

To fetch a specific paper with its reviews:

```python
note_id = "PAPER_ID"
url = f'https://api2.openreview.net/notes?id={note_id}'
req = urllib.request.Request(url, headers={'User-Agent': 'ARIS/1.0'})
data = json.loads(urllib.request.urlopen(req).read())
# data['notes'][0] contains the paper with all metadata
# Reviews can be fetched via: https://api2.openreview.net/notes?forum={forum_id}
```

### Step 3: Get Decision + Meta-Review

```python
forum_id = "FORUM_ID"
url = f'https://api2.openreview.net/notes?forum={forum_id}&invitation={venue}/-/Decision'
req = urllib.request.Request(url, headers={'User-Agent': 'ARIS/1.0'})
data = json.loads(urllib.request.urlopen(req).read())
# Shows accept/reject decision and meta-review summary
```

### Step 4: Ingest into Research Wiki

For accepted papers (decision = Accept), ingest into the research wiki:

```
/research-wiki ingest "<title>" — openreview: <note_id>
```

## Key Rules

1. OpenReview API v2 is free, no API key needed. Rate limit: ~100 requests/minute.
2. Papers under review are NOT public on arXiv yet — this is the earliest access point.
3. Reviewer discussions and meta-reviews are gold for understanding what reviewers value.
4. For venue-specific searches, use the OpenReview ID from the venue mapping table.
5. If a venue is not in the mapping, search: `WebSearch: "<venue> OpenReview 2026"`.
