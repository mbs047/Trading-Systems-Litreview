# Contributing

This is an academic group project for **BANA 420 — Final Project**. The notes below describe how the team works on the repository.

## Team

| Name | Student ID | Primary contribution |
|------|------------|----------------------|
| Mohammed Baobab | 202031137 | Pipeline (Rmd, Shiny app, bibliometrix app), data cleaning, text mining, document/term maps |
| Majid Tayfour | 202219094 | Final report |
| Hamed Alsaedi | 202008437 | Final report |
| Omero Moheyeldin | 700042090 | VOSviewer analysis (`vosviewer_analysis/`) |

The final report under `reports/` is a shared deliverable contributed to by all four members.

## Repository layout

This project follows the [Cookiecutter Data Science](https://drivendata.github.io/cookiecutter-data-science/) convention. The high-level rules are:

- `data/raw/` is **immutable**. Never edit files here. New raw data is added; nothing is overwritten or deleted.
- `data/interim/` and `data/processed/` are **regenerable**. They are produced by the scripts in `src/` and are gitignored.
- `results/` is **regenerable**. Everything in it can be reproduced by re-running the pipeline.
- `src/` holds **all code**. No code lives at the repo root.
- `vosviewer_analysis/` holds **manually-curated** VOSviewer maps. These are committed because they are produced by hand inside the VOSviewer GUI and are not regenerable from a script.
- `reports/` holds the **final knitted deliverables** (PDF and DOCX). These are committed because they are the human-readable artefacts of a specific run.
- `docs/` holds **human-written documentation** about the project (this file, the methodology, and any future design notes).
- `references/` is for **bibliography and external materials** (PDFs of cited papers, citation files, etc.).

## File-naming conventions

- All filenames use `snake_case`. No spaces, no parentheses, no upper-case acronyms in filenames (`ux` not `UX`, `ai` not `AI`).
- Subfolder analyses use a numeric prefix (`01_…`, `02_…`) to make ordering obvious.
- Generated CSVs and PNGs use descriptive long names (`top20_term_correlation_heatmap.png`, not `heatmap.png`) so they remain self-explanatory when copied into a report.

## R code conventions

- Path constants are defined once at the top of each script (`raw_dir`, `interim_dir`, `processed_dir`, `results_dir`, `fig_dir`, `table_dir`, `log_dir`, `biblio_dir`) and reused everywhere downstream — no hard-coded paths inside the body of the script.
- Every script is runnable from `src/` thanks to `setwd(dirname(rstudioapi::getActiveDocumentContext()$path))` and `project_dir <- normalizePath("..")`.
- Missing CRAN packages are installed automatically on first run.
- All write calls go through `file.path(<dir>, <filename>)` so paths work cross-platform.

## Branching & commits

- `main` is the integration branch. Knitted reports under `reports/` should always reflect the most recent successful run on `main`.
- One feature per branch. Suggested prefixes:
  - `feat/<short-name>` for new pipeline features.
  - `fix/<short-name>` for bug fixes.
  - `docs/<short-name>` for documentation changes.
  - `refactor/<short-name>` for non-behavioural code changes (e.g. the recent restructuring).
- Commit messages: imperative mood, present tense (`add Bradford-law plot`, not `added` or `adds`). Body lines wrap at ~72 characters.

## Re-running the pipeline

To produce a fresh `results/` from a clean checkout:

1. Make sure `data/raw/search_results_renamed.zip` is in place.
2. Open `src/project_analysis.Rmd` in RStudio and Knit, or `source("src/bibliometrix_app.R")` from the R console, or `shiny::runApp("src/shiny_app.R")` and click **Run full pipeline**.
3. Confirm `results/logs/run_info.csv` matches the **Reference run snapshot** in the README (raw rows = 588, Data A = 511, Data B = 511, manual review = 20).

If the snapshot drifts, that's a signal that either the inputs or the cleaning rules changed — investigate before committing.

## Updating the report

The deliverable PDF and DOCX in `reports/` are knitted from `src/project_analysis.Rmd`. To refresh them:

1. Knit the Rmd to PDF and Word from RStudio.
2. Copy the outputs into `reports/pdf/project_analysis.pdf` and `reports/docx/project_analysis.docx` respectively.
3. The `report_draft.{pdf,docx}` files are the team's editable narrative draft — they are *not* auto-generated and should be edited directly.
