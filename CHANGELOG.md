# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2025-05-02

First tagged release. The full pipeline — corpus build, text mining,
bibliometric analysis, and VOSviewer maps — is complete and reproducible
end-to-end from `data/raw/search_results_renamed.zip`.

### Added

#### Pipeline (`src/`)

- **`project_analysis.Rmd`** — main R Markdown notebook implementing the
  five required text-mining results (top-20 terms, word cloud, phi-correlation
  heatmap, document map via classical MDS over TF-IDF, term map via classical
  MDS over `1 − correlation`), plus descriptive summaries and a parallel
  `bibliometrix::convert2df()` cross-check.
- **`shiny_app.R`** — interactive Shiny dashboard with side-panel sliders
  for `Top N terms` (default 20), `Min term frequency` (default 3), and
  `Max term frequency` (default 180; drops over-dominant terms before
  ranking). On-demand Word report via `officer` + `flextable`. All maps
  display coordinates to 6 significant digits via `DT::formatRound()`.
- **`bibliometrix_app.R`** — additional standalone bibliometrix runner
  (annual production, author productivity, source ranking, Bradford / Lotka
  laws, keyword growth, thematic map, trend topics, conceptual structure,
  historiograph, country / author collaboration). Marked **experimental**;
  not part of the required deliverable.
- **`helpers.R`** — pure cleaning helpers (`normalize_title`,
  `clean_text_for_topic_flag`, `ensure_column`, `first_existing`) extracted
  for reuse and unit testing.
- **`build_prisma_flow.py`** — regenerates the PRISMA 2020 flow diagram
  from `results/logs/run_info.csv`.

#### Documentation (`docs/`)

- **`methodology.md`** — pipeline-stage walkthrough with PRISMA 2020 flow
  embedded and the per-stage corpus counts in a table.
- **`search_protocol.md`** — Scopus search strategy: database, dates,
  filters, the 20 query slugs, per-search yields (1–146 records each),
  inclusion/exclusion criteria, document-type breakdown, and known
  deviations / limitations.
- **`data_dictionary.md`** — every column in `data/processed/` documented
  (identifiers, provenance, Scopus bibliographic fields, derived helpers),
  plus the keys for `results/tables/` and run-metadata files.
- **`contributing.md`** — team list with UAEU emails, layout rules,
  branch / commit conventions.

#### VOSviewer (`vosviewer_analysis/`)

- Five completed VOSviewer analyses (abstract terms, author keywords,
  index keywords, country collaboration, source-keyword similarity), each
  with input network/map files, the VOSviewer map/network/JSON, and a
  PNG screenshot.
- **`HOW_TO_USE.md`** — load and rebuild walkthrough with the
  text-based vs. network-based distinction documented.

#### Reports (`reports/`)

- `pdf/project_analysis.pdf`, `pdf/report_draft.pdf`,
  `docx/project_analysis.docx`, `docx/report_draft.docx`.

#### Reproducibility

- **`renv.lock`** + **`.Rprofile`** + **`renv/activate.R`** pinning every
  package the pipeline uses. Bootstrap is interactive-only and uses
  `utils::install.packages()` so it survives R's startup-order trap.
- **`tests/testthat/test-helpers.R`** — 14 unit tests for the cleaning
  helpers (lowercasing, punctuation stripping, NA handling, vectorisation,
  idempotence, default-value insertion, candidate priority, no-match
  fallback). Both the test file and `tests/run_tests.R` resolve their
  own location via `commandArgs()` / frame-walking / `rstudioapi`, so they
  work regardless of cwd.
- **`results/figures/prisma_flow.{png,svg}`** committed to the repo as a
  deliverable (everything else under `results/` is gitignored and
  regenerable).

#### Project metadata

- **`CITATION.cff`** — machine-readable citation metadata; GitHub renders
  a "Cite this repository" button automatically.
- **`references/references.bib`** — bibliography stub with the standard
  methodological references (PRISMA, bibliometrix, VOSviewer, tidytext,
  classical MDS, Cookiecutter Data Science, R, Shiny).
- **`LICENSE`** — MIT.

### Repository structure

The project follows the [Cookiecutter Data Science](https://drivendata.github.io/cookiecutter-data-science/)
layout:

```
src/                  all source code
data/raw/             immutable Scopus inputs
data/interim/         derived intermediate (gitignored)
data/processed/       cleaned analysis-ready datasets (gitignored)
results/              generated artefacts (gitignored, except prisma_flow)
vosviewer_analysis/   committed VOSviewer maps
reports/              final knitted PDF / DOCX
docs/                 human-written documentation
references/           bibliography
tests/                unit tests
```

### Reference run snapshot

| Metric | Value |
|--------|------:|
| Records identified (raw) | 588 |
| After de-duplication | 511 |
| With non-empty abstract | 511 |
| Likely related (auto-include) | 491 |
| Manual review queue | 20 |

Top-5 terms by frequency: **data** (915), **trading** (839), **system**
(523), **market** (492), **financial** (425). Strongest term-pair
correlations: market–stock (0.348), analysis–data (0.300), platform–user
(0.285), analysis–financial (0.252).

### Team

- Mohammed Baobaid (202031137@uaeu.ac.ae) — pipeline (Rmd, Shiny app,
  bibliometrix app), data cleaning, text mining, document/term maps.
- Omero Moheyeldin (700042090@uaeu.ac.ae) — VOSviewer analyses.
- Majid Tayfour (202219094@uaeu.ac.ae) — final report.
- Hamed Alsaedi (202008437@uaeu.ac.ae) — final report.
