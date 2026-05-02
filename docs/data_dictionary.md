# Data dictionary

This document describes every column in the cleaned, analysis-ready datasets under `data/processed/`. Use it as the reference when joining tables, writing the report, or reviewing the manual-review queue.

All three processed files are linked by the `paper_id` key.

## `data_a_cleaned.xlsx` — master corpus

The full de-duplicated corpus, one row per unique paper, ~30 columns.

### Identifier and provenance columns (added by the pipeline)

| Column | Type | Description |
|--------|------|-------------|
| `paper_id` | string | Stable internal identifier of the form `P001`, `P002`, … assigned in row order after de-duplication. **Primary key.** Used to join Data A ↔ Data B ↔ document map ↔ manual-review file. |
| `topic_flag` | string | Either `"Likely related"` or `"Manual review"`. Set by a keyword-matching pass against the cleaned title + abstract — see the `keywords` vector in `src/shiny_app.R`. |
| `search_no` | integer | Which of the 20 Scopus queries returned this paper (1–20). When the same paper was returned by multiple queries, only the first is recorded — by which point the dedup step has already collapsed the duplicates. |
| `search_file` | string | Source CSV filename within `data/raw/search_results_renamed.zip`. Lets you trace any paper back to its query for reproducibility. |

### Bibliographic columns (from Scopus, harmonised)

The following columns are taken straight from Scopus and passed through `janitor::clean_names()` so they are snake_case throughout. The `first_existing()` helper handles cases where Scopus returned the field under an alias (e.g. `Author full names` vs `authors`).

| Column | Type | Description |
|--------|------|-------------|
| `authors` | string | Author list, semicolon-separated. May be `NA` when Scopus did not include it. |
| `author_full_names` | string | Author full names with Scopus author IDs in parentheses, semicolon-separated. |
| `author_s_id` | string | Semicolon-separated Scopus author IDs. |
| `title` | string | Paper title (verbatim). |
| `year` | integer | Publication year. Range in this corpus: 2015–2026. |
| `source_title` | string | Journal, proceedings, or book title — the publication venue. |
| `volume` | string | Volume number (string because Scopus mixes digits and roman numerals). |
| `issue` | string | Issue number. |
| `art_no` | string | Article number (used by some publishers in lieu of page numbers). |
| `page_start` | string | First page. |
| `page_end` | string | Last page. |
| `cited_by` | integer | Times the paper has been cited in Scopus as of the export date (2025-04). |
| `doi` | string | Digital Object Identifier — the canonical link to the paper. |
| `link` | string | Direct Scopus URL to the record. |
| `affiliations` | string | Affiliation list, semicolon-separated. |
| `authors_with_affiliations` | string | Authors paired with their affiliations. |
| `abstract` | string | Full abstract text. May be `NA` for some records. |
| `author_keywords` | string | Author-supplied keywords, semicolon-separated. Feeds VOSviewer analysis #02. |
| `index_keywords` | string | Scopus-curated keywords, semicolon-separated. Feeds VOSviewer analysis #03. |
| `document_type` | string | One of: `Conference paper`, `Article`, `Book chapter`, `Conference review`, `Review`, `Book`, `Erratum`, `Data paper`. |
| `publication_stage` | string | Usually `Final`; `Article in press` for unpublished accepted papers. |
| `open_access` | string | Open-access status string from Scopus (e.g. `All Open Access`, `Gold`, `Hybrid`, blank). |
| `source` | string | Always `Scopus` for this corpus. |
| `eid` | string | Scopus's own internal record identifier. |

### Derived helper columns (intermediate, not exported)

These exist inside the R session for the dedup step and are dropped before writing the xlsx — they are documented here only because they appear in code:

| Column | Type | Description |
|--------|------|-------------|
| `title_key` | string | Lower-cased, ASCII-only, whitespace-squished version of `title`. Dedup is applied on this column. Dropped before export. |
| `combined_text` | string | `title + abstract`, lower-cased and stripped of punctuation. Used by the keyword matcher to compute `topic_flag`. Dropped before export. |

## `data_b_abstracts.xlsx` — text-mining input

The slim two-column table that feeds tokenisation. One row per paper that has a non-empty abstract.

| Column | Type | Description |
|--------|------|-------------|
| `paper_id` | string | Same key as Data A. **Primary key.** |
| `abstract` | string | Cleaned abstract text. Guaranteed non-empty (rows with blank abstracts are filtered out). |

## `manual_review_candidates.xlsx` — triage queue

Subset of Data A whose `topic_flag` came back as `"Manual review"`. Same column set as Data A. Surface these to a human reviewer to confirm or reject.

## Derived tables under `results/tables/`

These are the outputs of the analysis, all keyed on `paper_id` or `term`.

| File | Key | Other columns |
|------|-----|---------------|
| `top20_terms.csv` / `.xlsx` | `word` | `frequency`, `rank` |
| `top20_term_correlations_long.csv` | `(item1, item2)` | `correlation` (phi-coefficient, –1 to 1) |
| `document_map_coordinates.csv` | `paper_id` | `x`, `y` (MDS dims), `topic_flag`, `year` |
| `term_map_coordinates.csv` | `term` | `Dim1`, `Dim2` (MDS dims) |
| `descriptive_summaries.xlsx` | sheet `year_summary` | `year`, `documents` |
| ↑ same file | sheet `top_sources` | `source_title`, `documents` |

## Run-metadata files under `results/logs/`

| File | What it contains |
|------|------------------|
| `run_info.csv` | Long-form metric snapshot. Items: `raw_rows`, `data_a_rows`, `data_b_rows`, `manual_review_rows`, `top_n_terms`, `unique_tokens`, `min_term_freq`, `max_term_freq`, `high_freq_terms_dropped`, `bibliometrix_available`. |
| `run_log.txt` | Free-text log of the most recent run — informational only, not parsed downstream. |

## Conventions

- All identifiers (`paper_id`, search numbers, year) are stored as the smallest faithful type — strings stay strings, integers stay integers.
- Empty values are `NA`, not the literal strings `""` or `NULL`.
- Every join in the analysis is on `paper_id` for paper-level tables and on `word` / `(item1, item2)` for term-level tables.
- All textual columns are UTF-8.
