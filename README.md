# trading-systems-litreview

A reproducible literature-review pipeline for trading-system research, built for the BANA 420 final project. We collect Scopus search exports, clean and de-duplicate them into a single corpus, mine the abstracts for the dominant vocabulary, project both documents and terms onto 2D maps, run a parallel `bibliometrix` analysis, and export co-occurrence networks for VOSviewer so the conceptual structure of the field becomes visible at a glance.

The repository follows the [Cookiecutter Data Science](https://drivendata.github.io/cookiecutter-data-science/) layout: source code in `src/`, immutable raw data in `data/raw/`, intermediate products in `data/interim/`, the cleaned analysis-ready datasets in `data/processed/`, and every generated artefact (figures, tables, logs, bibliometrix output) in `results/`. The whole analysis is available in three interchangeable forms — an R Markdown notebook (`src/project_analysis.Rmd`), an interactive Shiny app (`src/shiny_app.R`), and a standalone bibliometrix application (`src/bibliometrix_app.R`).

## What this project does

The pipeline takes a folder of Scopus per-search CSV exports (zipped) and runs them end-to-end:

1. **Read & combine** — unzip the archive, read every CSV, tag each row with its search number and source file.
2. **Build Data A** — standardise field names, reconcile Scopus aliases, drop title-less rows, de-duplicate on a normalised title key, assign a stable `PaperID` (P001, P002, …).
3. **Build Data B** — keep only `PaperID` and the cleaned abstract; this is the table that feeds the text mining.
4. **Tokenise & rank** — split abstracts into words, drop stop-words, publisher noise, and pure numbers, then compute the top-20 most frequent terms.
5. **Required Result A** — bar chart of the top-20 terms.
6. **Required Result B** — word cloud of the same top-20 vocabulary.
7. **Required Result C** — pairwise phi-correlation heatmap of the top-20 terms.
8. **Required Result D** — document map: TF-IDF document-term matrix → Euclidean distance → classical MDS → 2D projection of every paper.
9. **Required Result E** — term map: top-20 correlation matrix → `1 - correlation` distance → classical MDS → 2D projection of the top-20 terms.
10. **Descriptive summaries** — documents per year and top-20 publishing sources.
11. **bibliometrix analysis** — annual production, author productivity, source ranking, Bradford / Lotka laws, keyword growth, thematic map, trend topics, and conceptual structure.
12. **VOSviewer exports** — co-occurrence and co-authorship tables ready to drop into VOSviewer (the saved maps and screenshots from five completed analyses live under `vosviewer_analysis/`).
13. **Run metadata & log** — every run writes a `run_info.csv` snapshot and a free-text `run_log.txt`.

A more detailed methodological walkthrough is in [`docs/methodology.md`](docs/methodology.md).

## Repository layout

```
trading-systems-litreview/
├── README.md
├── LICENSE
├── .gitignore
├── .gitattributes
│
├── src/                                  # all R source code
│   ├── project_analysis.Rmd              # main R Markdown notebook
│   ├── shiny_app.R                       # interactive Shiny app
│   └── bibliometrix_app.R                # standalone bibliometrix app
│
├── data/
│   ├── raw/                              # immutable inputs
│   │   ├── search_results_renamed.zip            # required: Scopus CSV exports
│   │   └── search_results_unzipped/              # auto-extracted on first run (gitignored)
│   ├── interim/                          # generated intermediate tables (gitignored)
│   │   └── raw_combined_from_zip.csv
│   └── processed/                        # cleaned, analysis-ready datasets (gitignored)
│       ├── data_a_cleaned.xlsx
│       ├── data_b_abstracts.xlsx
│       └── manual_review_candidates.xlsx
│
├── results/                              # generated artefacts (gitignored)
│   ├── figures/
│   │   ├── top20_terms_barplot.png
│   │   ├── wordcloud_top20_terms.png
│   │   ├── top20_term_correlation_heatmap.png
│   │   ├── document_map_2d.png
│   │   └── term_map_2d.png
│   ├── tables/
│   │   ├── top20_terms.csv  /  .xlsx
│   │   ├── top20_term_correlations_long.csv
│   │   ├── document_map_coordinates.csv
│   │   ├── term_map_coordinates.csv
│   │   └── descriptive_summaries.xlsx
│   ├── bibliometrix/                     # full bibliometrix output
│   │   ├── m_clean.rds
│   │   ├── biblio_summary.txt
│   │   ├── bibliometrix_converted_data.csv
│   │   ├── figures/                      # annual production, author/source rankings,
│   │   │                                 # Bradford, keyword growth, thematic map, …
│   │   ├── tables/                       # affiliations, authors, h-index, sources,
│   │   │                                 # most-cited (global/local), thematic clusters, …
│   │   └── network/
│   │       └── co_occurrence_keywords.rds
│   └── logs/
│       ├── run_log.txt
│       └── run_info.csv
│
├── vosviewer_analysis/                   # Omero's saved VOSviewer maps + screenshots
│   ├── HOW_TO_USE.md
│   ├── 01_abstract_term_cooccurrence/
│   ├── 02_author_keyword_cooccurrence/
│   ├── 03_index_keyword_cooccurrence/
│   ├── 04_country_collaboration/
│   └── 05_source_keyword_similarity/
│
├── reports/                              # final knitted deliverables
│   ├── docx/
│   │   ├── project_analysis.docx
│   │   └── report_draft.docx
│   └── pdf/
│       ├── project_analysis.pdf
│       └── report_draft.pdf
│
├── docs/                                 # human-written documentation
│   ├── methodology.md
│   └── contributing.md
│
└── references/                           # bibliography / external materials
```

## Inputs

| File | Required | Purpose |
|------|----------|---------|
| `data/raw/search_results_renamed.zip` | Yes | Renamed per-search Scopus CSV exports. Unzipped on first run into `data/raw/search_results_unzipped/`. |
| `data/raw/ALL SEARCH RESULTS - v01g (1).xlsx` | No | Pre-combined workbook used only as an optional sanity-check against our rebuilt Data A. |

## Outputs

Every run writes its artefacts under `data/{interim,processed}/` and `results/`:

| Location | What it contains |
|----------|------------------|
| `data/interim/` | `raw_combined_from_zip.csv` — unmodified concatenation of every per-search CSV |
| `data/processed/` | `data_a_cleaned.xlsx`, `data_b_abstracts.xlsx`, `manual_review_candidates.xlsx` |
| `results/tables/` | `top20_terms.{csv,xlsx}`, `top20_term_correlations_long.csv`, `document_map_coordinates.csv`, `term_map_coordinates.csv`, `descriptive_summaries.xlsx` |
| `results/figures/` | `top20_terms_barplot.png`, `wordcloud_top20_terms.png`, `top20_term_correlation_heatmap.png`, `document_map_2d.png`, `term_map_2d.png` |
| `results/bibliometrix/` | `m_clean.rds`, `biblio_summary.txt`, `bibliometrix_converted_data.csv`, plus `figures/`, `tables/`, and `network/` subfolders |
| `results/logs/` | `run_log.txt`, `run_info.csv` |

Final knitted reports (PDF and Word) are kept under `reports/pdf/` and `reports/docx/`. The VOSviewer-ready CSVs that feed `vosviewer_analysis/` are produced inside the bibliometrix run and saved under `results/bibliometrix/`.

## Quick start — R Markdown notebook

```bash
git clone https://github.com/<your-username>/trading-systems-litreview.git
cd trading-systems-litreview
```

Then in RStudio:

1. Open `src/project_analysis.Rmd`.
2. Confirm `data/raw/search_results_renamed.zip` is in place.
3. Click **Knit** (or `Ctrl/Cmd + Shift + K`) and choose PDF, HTML, or Word.

Missing CRAN packages are installed automatically on first knit.

## Quick start — Shiny app

```r
shiny::runApp("src/shiny_app.R")
```

In the app:

1. Confirm the project directory in the sidebar (defaults to the repo root).
2. Click **Run full pipeline**.
3. Browse each tab — Data A, Data B, manual review, top-20 terms (table + bar chart + word cloud), correlation heatmap, document map, term map, descriptive summaries, run metadata.
4. Download any deliverable from the sidebar buttons.

## Quick start — bibliometrix application

```r
shiny::runApp("src/bibliometrix_app.R")
```

A standalone app focused on the bibliometric side of the pipeline — annual production, author productivity, source ranking, Bradford / Lotka laws, keyword growth, thematic map, trend topics, and conceptual structure. It writes its outputs under `results/bibliometrix/`.

## VOSviewer workflow

1. Install VOSviewer from <https://www.vosviewer.com/download>.
2. Run the main pipeline so the bibliometrix CSVs are up to date.
3. Open VOSviewer → **Create a map based on network data** → load the relevant CSV.
4. See [`vosviewer_analysis/HOW_TO_USE.md`](vosviewer_analysis/HOW_TO_USE.md) for the full walkthrough on re-opening or rebuilding the saved maps.
5. Save the resulting map / network files into the matching `vosviewer_analysis/<analysis>/` folder alongside a `vosviewer_screenshot.png`.

## Reference run snapshot

| Metric | Value |
|--------|------:|
| `raw_combined_rows` | 588 |
| `data_a_rows_after_dedup` | 511 |
| `data_b_rows_with_abstracts` | 511 |
| `manual_review_rows` | 20 |
| `top20_terms_generated` | 20 |
| `bibliometrix_available` | 1 |

Top-5 terms by frequency: **data** (915), **trading** (839), **system** (523), **market** (492), **financial** (425).
Strongest term-pair correlations: **market – stock** (0.348), **analysis – data** (0.300), **platform – user** (0.285), **analysis – financial** (0.252).

## Requirements

- R >= 4.2 and RStudio.
- CRAN packages: `dplyr`, `readr`, `readxl`, `openxlsx`, `stringr`, `tidyr`, `purrr`, `tibble`, `janitor`, `tidytext`, `widyr`, `ggplot2`, `ggrepel`, `Matrix`, `wordcloud`, `RColorBrewer`, `shiny`, `shinyjs`, `shinyFiles`, `DT`, `officer`, `flextable`, `bibliometrix`, `igraph`.
- External: [VOSviewer](https://www.vosviewer.com/download) for opening the CSVs and producing the maps stored under `vosviewer_analysis/`. See [`vosviewer_analysis/HOW_TO_USE.md`](vosviewer_analysis/HOW_TO_USE.md).

All required CRAN packages are installed automatically on first run.

## Reproducibility

The notebook is designed to be re-runnable. On a clean build the only files that need to be preserved are:

- `src/project_analysis.Rmd`
- `src/shiny_app.R`
- `src/bibliometrix_app.R`
- `data/raw/search_results_renamed.zip`
- `data/raw/ALL SEARCH RESULTS - v01g (1).xlsx` *(optional)*

Every other folder (`data/interim/`, `data/processed/`, `results/`, `data/raw/search_results_unzipped/`) is regenerated automatically on the next run and is safe to delete.

## Project context

This project was built for **BANA 420 — Final Project**. It implements the five required text-mining results (top-20 terms, word cloud, correlation heatmap, document map, term map) over a Scopus-derived corpus on trading systems, decision support, and trading-platform usability, and extends them with a full `bibliometrix` analysis and five VOSviewer maps.

## Team & contributions

| Name | Student ID |
|------|------------|
| Mohammed Baobab | 202031137 |
| Majid Tayfour | 202219094 |
| Hamed Alsaedi | 202008437 |
| Omero Moheyeldin | 700042090 |

**Contributions**

- **VOSviewer analysis** (`vosviewer_analysis/` and all five maps inside it) — produced by **Omero Moheyeldin**.
- **Pipeline** (R Markdown notebook, Shiny app, bibliometrix application, data cleaning, text mining, document/term maps, the rest of `results/`) — built by **Mohammed Baobab**.
- **Final report** (deliverables under `reports/`) — shared group task contributed to by all four members.

See [`docs/contributing.md`](docs/contributing.md) for branch / commit conventions.

## License

Released under the [MIT License](LICENSE).
