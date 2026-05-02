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

A more detailed methodological walkthrough is in [`docs/methodology.md`](docs/methodology.md), the search strategy in [`docs/search_protocol.md`](docs/search_protocol.md), and the cleaned-data column reference in [`docs/data_dictionary.md`](docs/data_dictionary.md). The PRISMA 2020 flow diagram for the corpus construction is at [`results/figures/prisma_flow.png`](results/figures/prisma_flow.png).

## Repository layout

```
trading-systems-litreview/
├── README.md
├── LICENSE
├── .gitignore
├── .gitattributes
│
├── src/                                  # all source code
│   ├── project_analysis.Rmd              # main R Markdown notebook
│   ├── shiny_app.R                       # interactive Shiny app
│   ├── bibliometrix_app.R                # standalone bibliometrix app
│   ├── helpers.R                         # shared cleaning helpers (used by tests)
│   └── build_prisma_flow.py              # regenerates the PRISMA diagram
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
│   ├── methodology.md                    # pipeline-stage walkthrough + PRISMA
│   ├── search_protocol.md                # Scopus queries, dates, filters, criteria
│   ├── data_dictionary.md                # every column in data/processed/ explained
│   └── contributing.md                   # team, layout rules, branch / commit style
│
├── references/                           # bibliography / external materials
│   └── references.bib
│
├── tests/                                # unit tests for src/helpers.R
│   ├── run_tests.R
│   └── testthat/
│       └── test-helpers.R
│
├── renv.lock                             # pinned package versions for reproducibility
├── .Rprofile                             # auto-activates renv on R startup
└── CITATION.cff                          # machine-readable citation metadata
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

## How to use & run

The repository ships three R entry points plus the external VOSviewer tool. They all read the same Scopus zip under `data/raw/` and write to `data/{interim,processed}/` and `results/`. Pick the one that matches what you want to do.

### 0. Prerequisites & get the repo

The three R entry points are all designed to run inside **RStudio Desktop** — that's the most user-friendly way and the path we recommend for everyone on the team. Install once and forget:

- **R** (>= 4.2) — <https://cran.r-project.org/>
- **RStudio Desktop** (free) — <https://posit.co/download/rstudio-desktop/>

Then clone the repo:

```bash
git clone https://github.com/<your-username>/trading-systems-litreview.git
cd trading-systems-litreview
```

Open the project in RStudio (**File → Open Project…** and pick the repo folder, or just double-click any `.R` / `.Rmd` file inside it). Confirm `data/raw/search_results_renamed.zip` is in place. Missing CRAN packages are installed automatically on first run of any of the three scripts.

### 1. `src/project_analysis.Rmd` — main R Markdown notebook

The canonical, knit-to-report version of the pipeline. Use this when you want a polished PDF / Word / HTML deliverable and the prose narration that explains every step.

**Run it (recommended — RStudio)**

1. Open `src/project_analysis.Rmd` in RStudio (just double-click the file).
2. Click the **Knit** button at the top of the editor — or press **Ctrl/Cmd + Shift + K**.
3. Pick the output format from the **Knit** dropdown — **PDF**, **Word**, or **HTML**.
4. The knitted document opens automatically when it's done; the R Markdown tab in the bottom-left pane shows the build log if anything goes wrong.

**Alternative (R console / headless)**

```r
rmarkdown::render("src/project_analysis.Rmd", output_format = "pdf_document")
```

**What it produces**

Cleaned datasets under `data/processed/`, all five required figures + tables under `results/figures/` and `results/tables/`, descriptive summaries, the `bibliometrix_converted_data.csv` cross-check, and `results/logs/run_log.txt` + `run_info.csv`. The knitted PDF/DOCX should be copied into `reports/pdf/project_analysis.pdf` / `reports/docx/project_analysis.docx`.

### 2. `src/shiny_app.R` — interactive Shiny dashboard

The **primary interactive entry point**. Use this when you want to explore the corpus, tweak parameters, and download artefacts on demand.

**Run it (recommended — RStudio)**

1. Open `src/shiny_app.R` in RStudio.
2. Click the green **▶ Run App** button at the top of the editor pane (it appears automatically when RStudio detects a Shiny file). The app launches in RStudio's built-in viewer; click the **Open in Browser** button if you want a full browser window instead.

**Alternative (R console)**

```r
shiny::runApp("src/shiny_app.R")
```

**Workflow inside the app**

1. Confirm the project directory in the sidebar (defaults to the repo root).
2. Adjust the side-panel sliders if needed:
   - **Top N terms** — how many top-frequency terms feed the bar chart, word cloud, heatmap, and term map (default 20).
   - **Min term frequency** — minimum per-term count for inclusion in the document map (default 3).
   - **Max term frequency** — drops over-dominant terms above this cap (default 180); useful when generic words like "data", "trading", or "system" swamp the analysis.
3. Click **Run full pipeline**.
4. Browse each tab — Data A, Data B, manual review, top-20 terms (table + bar chart + word cloud), correlation heatmap, document map, term map, descriptive summaries, run metadata.
5. Download any deliverable (cleaned XLSX, top-terms CSV, correlation table, map coordinates, run info, full Word report) from the sidebar buttons.

**What it produces**

Same artefact set as the Rmd, written to the same paths, plus an on-demand Word report (`BANA420_Report_<timestamp>.docx`) generated via `officer` + `flextable`.

### 3. `src/bibliometrix_app.R` — bibliometrix add-on (work in progress)

> **Status: experimental, not yet 100% ready.** This script is an **additional** entry point that runs a parallel analysis using only the [`bibliometrix`](https://www.bibliometrix.org/) package, so we can compare its results against what the Shiny dashboard produces from the same Scopus inputs. It is **not part of the required deliverable** — the main Shiny app and the Rmd are. Some sections still need work (parameter exposure, error handling on small corpora, polishing the biblioshiny launch flow), so expect rough edges.

**Why it exists**

`bibliometrix` is the field-standard R package for bibliometric analysis. Running it side-by-side with our hand-rolled pipeline lets us:

- Cross-check our Data A / Data B against `convert2df()` ingest.
- Add bibliometric outputs the main pipeline doesn't provide (Bradford / Lotka laws, h-index per author and source, thematic map, trend topics, country collaboration, historiograph, etc.).
- Launch `biblioshiny()` — bibliometrix's official GUI — on the same cleaned dataset for interactive exploration outside our app.

**Run it (recommended — RStudio)**

1. Open `src/bibliometrix_app.R` in RStudio.
2. Click **Source** at the top-right of the editor pane (or press **Ctrl/Cmd + Shift + S**) to execute the whole script.
3. Watch the R console for progress messages; once it finishes, `biblioshiny()` opens in a new browser tab automatically.

**Alternative (R console)**

```r
source("src/bibliometrix_app.R")
```

The script unzips the Scopus archive, runs every standard `bibliometrix` analysis, writes outputs under `results/bibliometrix/{figures,tables,network}/`, persists the cleaned data frame as `results/bibliometrix/m_clean.rds`, and finally launches `biblioshiny()`. Inside the GUI choose: **Load data → RData (.rds) → results/bibliometrix/m_clean.rds → Start**.

**Known limitations**

- No side-panel UI — all parameters are hard-coded in the script.
- Some plots fail silently if the corpus is too small for the chosen analysis (e.g. thematic map, conceptual structure).
- The biblioshiny auto-launch sometimes needs a manual `biblioshiny()` call afterwards.
- Output filenames are not yet fully snake_case-aligned with the rest of the repo.

If you only need the required BANA 420 deliverables, **stick with `project_analysis.Rmd` or `shiny_app.R`**.

### 4. VOSviewer — the external mapping tool

VOSviewer produces the five saved maps under `vosviewer_analysis/`. It is a separate Java application, not an R script.

**Install**

Download from <https://www.vosviewer.com/download> and unzip / install. Java is required.

**Run a saved map**

1. Launch VOSviewer.
2. **File → Open…** → select `vosviewer_map.txt` and `vosviewer_network.txt` from the relevant `vosviewer_analysis/<analysis>/` subfolder.
3. The saved layout, clusters, and labels load exactly as committed.

Or drag the matching `vosviewer_map.json` onto **VOSviewer Online** at <https://app.vosviewer.com> to view it in the browser without installing anything.

**Rebuild a map**

See [`vosviewer_analysis/HOW_TO_USE.md`](vosviewer_analysis/HOW_TO_USE.md) for the full walkthrough — different procedure for the text-based abstract analysis (`01_…`) versus the network-based ones (`02_…`–`05_…`), plus the load parameters used for each.

When done, save back into the same subfolder so the screenshot, map, network, and JSON stay consistent.

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
- CRAN packages: `dplyr`, `readr`, `readxl`, `openxlsx`, `stringr`, `tidyr`, `purrr`, `tibble`, `janitor`, `tidytext`, `widyr`, `ggplot2`, `ggrepel`, `Matrix`, `wordcloud`, `RColorBrewer`, `shiny`, `shinyjs`, `shinyFiles`, `DT`, `officer`, `flextable`, `bibliometrix`, `igraph`, `renv`, `testthat`.
- Python 3 + `matplotlib` (only needed if you want to regenerate the PRISMA diagram).
- External: [VOSviewer](https://www.vosviewer.com/download) for opening the CSVs and producing the maps stored under `vosviewer_analysis/`. See [`vosviewer_analysis/HOW_TO_USE.md`](vosviewer_analysis/HOW_TO_USE.md).

All required CRAN packages are installed automatically on first run, but the recommended path is `renv::restore()` from the project root (see *Reproducibility* below).

Bibliography for the report lives at [`references/references.bib`](references/references.bib).

## Reproducibility

The notebook is designed to be re-runnable. On a clean build the only files that need to be preserved are:

- `src/project_analysis.Rmd`, `src/shiny_app.R`, `src/bibliometrix_app.R`, `src/helpers.R`, `src/build_prisma_flow.py`
- `data/raw/search_results_renamed.zip`
- `data/raw/ALL SEARCH RESULTS - v01g (1).xlsx` *(optional)*
- `renv.lock`, `.Rprofile`, `renv/activate.R`

Every other folder (`data/interim/`, `data/processed/`, `results/`, `data/raw/search_results_unzipped/`) is regenerated automatically on the next run and is safe to delete.

### Pinned package versions with `renv`

The project ships an [`renv`](https://rstudio.github.io/renv/) lockfile so a fresh checkout gets the same package versions we ran with. On first open in RStudio, `renv` will bootstrap itself; then run:

```r
renv::restore()
```

This installs the versions listed in `renv.lock` into a project-local library under `renv/library/` (gitignored). After your first successful pipeline run, `renv::snapshot()` will refine the lockfile with hashes captured from your machine.

If you don't want to use `renv`, every script also auto-installs missing CRAN packages on first run — `renv` is the more robust path but not strictly required.

### Regenerating the PRISMA flow diagram

`results/figures/prisma_flow.png` is regenerated from `results/logs/run_info.csv` by:

```bash
python3 src/build_prisma_flow.py
```

Re-run after every pipeline run if the corpus counts have shifted.

### Running the test suite

The pure helpers in `src/helpers.R` (used for de-duplication and schema reconciliation) are covered by unit tests under `tests/testthat/`. Run them with:

```bash
Rscript tests/run_tests.R
```

Or from inside R:

```r
source("tests/run_tests.R")
```

## Project context

This project was built for **BANA 420 — Final Project**. It implements the five required text-mining results (top-20 terms, word cloud, correlation heatmap, document map, term map) over a Scopus-derived corpus on trading systems, decision support, and trading-platform usability, and extends them with a full `bibliometrix` analysis and five VOSviewer maps.

## Team & contributions

| Name | Student ID | Email |
|------|------------|-------|
| Mohammed Baobaid | 202031137 | 202031137@uaeu.ac.ae |
| Majid Tayfour | 202219094 | 202219094@uaeu.ac.ae |
| Hamed Alsaedi | 202008437 | 202008437@uaeu.ac.ae |
| Omero Moheyeldin | 700042090 | 700042090@uaeu.ac.ae |

**Contributions**

- **VOSviewer analysis** (`vosviewer_analysis/` and all five maps inside it) — produced by **Omero Moheyeldin**.
- **Pipeline** (R Markdown notebook, Shiny app, bibliometrix application, data cleaning, text mining, document/term maps, the rest of `results/`) — built by **Mohammed Baobaid**.
- **Final report** (deliverables under `reports/`) — shared group task contributed to by all four members.

See [`docs/contributing.md`](docs/contributing.md) for branch / commit conventions.

## How to cite

If you reuse this pipeline or its outputs, please cite it. The repository ships a [`CITATION.cff`](CITATION.cff) file in the root, which GitHub renders as a "Cite this repository" button and which most reference managers (Zotero, EndNote, Mendeley) understand directly.

## License

Released under the [MIT License](LICENSE).
