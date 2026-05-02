# Search protocol

This document records exactly how the corpus underlying this review was assembled. It is the methodological cornerstone of the project — without it the analysis is not reproducible — so any future re-run should follow this protocol verbatim or, if it deviates, document the deviation.

## 1. Database and access

| Item | Value |
|------|-------|
| Database | Scopus (Elsevier) |
| Access | UAEU library subscription |
| Search interface | Scopus advanced search |
| Export format | CSV with all available bibliographic + abstract fields |

Scopus was chosen over Web of Science and Google Scholar because (a) UAEU has institutional access, (b) it carries the conference proceedings that are central to HCI / trading-platform usability research, and (c) it produces a clean, citation-grade export that the `bibliometrix` R package can ingest natively via `convert2df()`.

## 2. Search execution

| Item | Value |
|------|-------|
| Search dates | 2025-04 (most recent runs in April 2025) |
| Year filter | 2015–2026 (publication year, all available years; `PUBYEAR > 2014`) |
| Language filter | English only (`LANGUAGE("English")`) |
| Document types kept | Articles, conference papers, conference reviews, reviews, book chapters, books, data papers |
| Document types excluded | Erratum, Note, Editorial, Letter (when present) |
| Search field | TITLE-ABS-KEY (title, abstract, author keywords, index keywords) |

## 3. Search queries

The corpus was built from twenty paired Scopus queries, each capturing a distinct facet of trading-system / trading-platform usability research. Each query was exported as its own CSV so we can trace any paper back to the search that found it. Provenance is preserved through the `search_no` and `search_file` columns added at ingest time.

The renamed query files live inside `data/raw/search_results_renamed.zip`:

| # | Filename slug | Topic angle |
|--:|---------------|-------------|
| 01 | `01_financial_trading_platform_usability` | General platform usability |
| 02 | `02_trading_software_usability_evaluation` | Software-evaluation framing |
| 03 | `03_electronic_trading_interface_design` | UI design |
| 04 | `04_trading_platform_user_experience_ux` | UX framing |
| 05 | `05_human_computer_interaction_in_financial_trading` | HCI angle |
| 06 | `06_usability_heuristics_for_trading_systems` | Heuristic evaluation |
| 07 | `07_requirements_engineering_for_trading_systems` | RE / specification |
| 08 | `08_user_centered_design_of_trading_platforms` | UCD / participatory design |
| 09 | `09_interaction_design_for_electronic_trading` | Interaction design |
| 10 | `10_information_visualization_for_financial_trading` | InfoVis |
| 11 | `11_financial_market_data_visualization_interface` | Market-data visualisation |
| 12 | `12_decision_support_systems_for_traders_interface` | DSS for traders |
| 13a | `13_cognitive_workload_in_trading_interfaces` | Cognitive load (no results) |
| 13b | `13_usability_survey_financial_trading` | Usability surveys |
| 14 | `14_situation_awareness_in_financial_trading_systems` | Situation awareness |
| 15 | `15_algorithmic_trading_interfaces` | Algorithmic trading UI |
| 16 | `16_explainable_ai_for_trading_decision_interfaces` | XAI |
| 17 | `17_mobile_trading_app_usability` | Mobile apps |
| 18 | `18_feature_requirements_for_trading_platforms` | Feature requirements |
| 19 | `19_workflow_design_electronic_trading` | Workflow design |
| 20 | `20_usability_financial_trading_platform` | Cross-validation duplicate of #01 |

The literal Scopus query strings used are reproduced verbatim from the filename slug — for example query #04 was:

```
TITLE-ABS-KEY ( "trading platform" AND ( "user experience" OR "UX" ) )
AND PUBYEAR > 2014
AND ( LIMIT-TO ( LANGUAGE , "English" ) )
```

Search 13a returned zero hits and is preserved as `13_cognitive_workload_in_trading_interfaces_no_results.txt` for completeness; it does not contribute rows but documents that the angle was searched.

## 4. Identification — yields per search

The following counts are from the run captured in `results/logs/run_info.csv`. Total identified = **588 raw records** before any deduplication.

| Search | Records |
|-------:|--------:|
| 04 | 146 |
| 07 | 89 |
| 09 | 77 |
| 10 | 51 |
| 03 | 38 |
| 18 | 38 |
| 05 | 31 |
| 11 | 31 |
| 15 | 21 |
| 01 | 8 |
| 08 | 8 |
| 12 | 8 |
| 20 | 8 |
| 17 | 7 |
| 14 | 6 |
| 19 | 6 |
| 13b | 5 |
| 16 | 5 |
| 02 | 4 |
| 06 | 1 |
| 13a | 0 |
| **Total** | **588** |

The wide spread (1–146 records per query) is expected: narrow queries (`usability heuristics for trading systems`) hit a tiny literature, while broad ones (`user experience`) hit a much larger one. The narrow queries still earn their place because they surface papers the broad queries miss.

## 5. Screening (de-duplication)

After identification we apply automated de-duplication on a normalised title key (lower-cased, ASCII-only, whitespace-squished — see `normalize_title()` in `src/project_analysis.Rmd`). This is necessary because the 20 queries deliberately overlap — the same paper can be returned by multiple searches.

- Rows removed by title-key dedup: **77** (588 → 511).
- Rows removed for missing or blank `Title`: **0** (Scopus exports always carry a title).

## 6. Eligibility (text-mining feasibility)

To enter the text-mining pipeline a paper must have a non-empty `Abstract` field.

- Records lost to blank abstracts: **0** (511 → 511 — every deduplicated record had an abstract this run).

## 7. Inclusion (manual review)

A keyword-based topic flag classifies each surviving record as **Likely related** or **Manual review**. The keyword list is configured in `src/shiny_app.R` and `src/project_analysis.Rmd` and currently includes: *trading*, *stock*, *broker*, *market data*, *decision support*, *electronic trading*, *user interface*, *user experience*, *usability*, etc.

- Likely related: **491**
- Manual review needed: **20**

The 20 manual-review candidates are exported to `data/processed/manual_review_candidates.xlsx` for human triage and are surfaced separately on the document map (red points).

## 8. Document-type composition (raw 588)

| Document type | Count |
|---------------|------:|
| Conference paper | 283 |
| Article | 242 |
| Book chapter | 27 |
| Conference review | 15 |
| Review | 10 |
| Book | 8 |
| Erratum | 2 |
| Data paper | 1 |

Conference papers dominate the corpus, which is consistent with the field's publishing patterns (HCI / interaction design publishes heavily at CHI, INTERACT, IUI, IEEE conferences).

## 9. Inclusion / exclusion criteria

**Inclusion**

- Indexed in Scopus.
- Published 2015 or later.
- English-language.
- Has a non-empty title.
- Subject to text-mining: has a non-empty abstract.
- Topic-relevant by keyword flag, OR escalated to manual review.

**Exclusion**

- Records with no abstract are dropped from the text-mining pipeline (still kept in Data A for record-keeping).
- Errata, notes, and editorials are kept if Scopus returns them but their absence of substantive content means they typically end up in the manual-review bucket.
- Languages other than English are filtered at the Scopus query level.

## 10. Deviations and limitations

- **Single-database**. Scopus only — no Web of Science, IEEE Xplore, ACM DL, or Google Scholar cross-check. This is a known limitation for systematic reviews; we accept it because UAEU access constraints made multi-database harvesting impractical and because Scopus subsumes most IEEE / ACM proceedings indirectly.
- **Single-language**. English-only filter excludes potentially-relevant non-English work, particularly in Asian markets where electronic trading research is active.
- **Snapshot date**. The 2025-04 snapshot will drift; any re-run after that date will produce different counts. The exact zip used is committed at `data/raw/search_results_renamed.zip` so the *original* run remains reproducible regardless of how Scopus changes.
- **Manual-review keyword list**. The keyword list is editorial and may exclude relevant papers whose abstracts use different terminology. We mitigate this by sending borderline cases to manual review rather than silently dropping them.

## 11. Re-running this protocol

To re-execute the search exactly as documented:

1. Sign in to Scopus through your institutional access.
2. For each of the 20 queries, paste the corresponding query string (reproduced from the filename slug), apply the filters listed in §2, and export the results as CSV with **all** available fields.
3. Save the 20 CSVs into a folder named `search results - renamed/`, naming each file with its search number prefix.
4. Zip the folder as `search_results_renamed.zip` and place it at `data/raw/`.
5. Run `src/project_analysis.Rmd` (Knit) or `src/shiny_app.R` (Run App) to ingest.

Counts will differ from §4 if Scopus has indexed new papers since 2025-04.
