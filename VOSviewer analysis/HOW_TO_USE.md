# How to use the files in `VOSviewer analysis/`

This folder holds the five VOSviewer analyses that go with the Scopus corpus produced by the rest of the pipeline. Each subfolder is a self-contained map you can re-open, re-style, or re-export from VOSviewer without rerunning anything in R.

## 1. Install VOSviewer

We used VOSviewer (free, Java-based). Download it from the official site:

- Project page / download: <https://www.vosviewer.com/download>

Install Java if you don't already have it, then launch VOSviewer.

## 2. What's in each subfolder

Every analysis folder contains the same set of files (with one exception — see `01_abstract_term_cooccurrence/`):

| File | What it is |
|------|------------|
| `vosviewer_map.txt` | The **map file** — one row per item (term/keyword/author/country/source) with cluster, weights, and 2D coordinates. |
| `vosviewer_network.txt` | The **network file** — pairwise links between items with link strengths. |
| `vosviewer_map.json` | The same map in JSON form (handy for VOSviewer Online and for diffing in git). |
| `vosviewer_screenshot.png` | A PNG export of the saved view, so you can preview the map without opening VOSviewer. |
| `input_map.txt` / `input_network.txt` | The raw input files originally fed into VOSviewer to build this analysis. |
| `input_item_summary.tsv` | Per-item summary (occurrences, total link strength) used to pick thresholds. |

Folder `01_abstract_term_cooccurrence/` is built from text rather than a precomputed network, so it has a different input set:

| File | What it is |
|------|------------|
| `corpus.txt` | The cleaned abstracts fed into VOSviewer's text-mining mode. |
| `thesaurus_terms.txt` | Thesaurus mapping VOSviewer applied (merge / ignore terms). |
| `scores.txt` | Optional per-document score column. |

## 3. Re-opening a saved map

1. Launch VOSviewer.
2. **File → Open…** (or the **Open** button on the start screen).
3. In the dialog, set **Map file** to `vosviewer_map.txt` and **Network file** to `vosviewer_network.txt` from the subfolder you want to view.
4. Click **OK** — the saved map loads with its existing clusters and coordinates.

You can also drag `vosviewer_map.json` onto VOSviewer Online (<https://app.vosviewer.com>) to view it in the browser without installing anything.

## 4. Rebuilding a map from scratch

If you want to regenerate one of the analyses (e.g. after the corpus changes):

1. **Network-based analyses** (`02_…` through `05_…`):
   - **File → Create…** → **Create a map based on network data**.
   - Point it at `input_network.txt` (and `input_map.txt` if you want to reuse the labels).
   - Pick the same counting / normalisation method noted in the original `vosviewer_map.txt` header.
2. **Abstract term co-occurrence** (`01_abstract_term_cooccurrence/`):
   - **File → Create…** → **Create a map based on text data**.
   - Choose **Read data from VOSviewer files** → load `corpus.txt` (and `scores.txt` if relevant).
   - In the next step, load `thesaurus_terms.txt` as the thesaurus.
   - Use the binary counting method and the same minimum-occurrences threshold listed in the original map.

When you're happy with the result, save back into the same folder so the screenshot, map, and network files stay consistent:

- **File → Save…** → save `vosviewer_map.txt` + `vosviewer_network.txt` (overwrite).
- **File → Save as JSON…** → overwrite `vosviewer_map.json`.
- **File → Screenshot → Save…** → overwrite `vosviewer_screenshot.png`.

## 5. Where the input files come from

The `input_*.txt` and `input_item_summary.tsv` files in folders 02–05 are the VOSviewer-ready CSVs produced by the R pipeline, copied here for traceability. The originals live under:

```
output/vosviewer/
├── 01_co_occurrence_author_keywords.csv
├── 02_co_occurrence_all_keywords.csv
├── 03_co_occurrence_title_abstract.csv
├── 04_co_authorship_authors.csv
└── 05_co_citation_references.csv
```

See `output/vosviewer/VOSviewer_how_to_load.txt` for the loading parameters used for each CSV.

## 6. Credits

The five analyses in this folder were produced by **Omero Moheyeldin** as part of the BANA 420 final project. Tool: VOSviewer (<https://www.vosviewer.com/download>).
