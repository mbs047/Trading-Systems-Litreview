# BANA 420 Project — Shiny App (v3)
#
# Run: open in RStudio → Run App.
# Data folder must contain:
#   data/*.zip  — Scopus CSV export(s) zipped together  [required]
#   data/ALL SEARCH RESULTS - v01g (1).xlsx              [optional]

# ---- Packages ---------------------------------------------------------------
required_packages <- c(
  "shiny", "shinyjs", "shinyFiles",
  "DT", "dplyr", "readr", "readxl", "openxlsx",
  "stringr", "tidyr", "tibble", "janitor",
  "tidytext", "widyr",
  "ggplot2", "ggrepel",
  "Matrix", "wordcloud", "RColorBrewer",
  "officer", "flextable"
)

new_pkgs <- required_packages[!required_packages %in% rownames(installed.packages())]
if (length(new_pkgs)) install.packages(new_pkgs, dependencies = TRUE)
invisible(lapply(required_packages, library, character.only = TRUE))

bibliometrix_available <- requireNamespace("bibliometrix", quietly = TRUE)

# ---- Helpers ----------------------------------------------------------------
normalize_title <- function(x) {
  x |> stringr::str_to_lower() |>
    stringr::str_replace_all("[^a-z0-9 ]", " ") |>
    stringr::str_squish()
}

clean_text <- function(x) {
  tidyr::replace_na(x, "") |>
    stringr::str_to_lower() |>
    stringr::str_replace_all("[^a-z0-9 ]", " ") |>
    stringr::str_squish()
}

ensure_col <- function(df, col, default = NA_character_) {
  if (!col %in% names(df)) df[[col]] <- default
  df
}

first_existing <- function(df, candidates, new_name, default = NA_character_) {
  found <- candidates[candidates %in% names(df)]
  if (length(found) > 0) df[[new_name]] <- df[[found[1]]]
  else if (!new_name %in% names(df)) df[[new_name]] <- default
  df
}

# ---- Word report generator --------------------------------------------------
generate_word_report <- function(out_path, s, cfg) {
  # s   = named list snapshot of reactive state values
  # cfg = named list: project_dir, zip_file, n_top, min_freq, run_time, keywords

  doc <- officer::read_docx()

  # ---- tiny wrappers --------------------------------------------------------
  h <- function(doc, txt, lvl = 1) {
    style <- paste("heading", lvl)
    officer::body_add_par(doc, txt, style = style)
  }
  p <- function(doc, txt = "") officer::body_add_par(doc, txt, style = "Normal")

  add_plot <- function(doc, gg, w = 6.5, h = 4.5) {
    tmp <- tempfile(fileext = ".png")
    on.exit(unlink(tmp), add = TRUE)
    ggplot2::ggsave(tmp, plot = gg, width = w, height = h, dpi = 180, bg = "white")
    officer::body_add_img(doc, src = tmp, width = w, height = h)
  }

  add_ft <- function(doc, df, n = 30) {
    df <- head(df, n)
    # Truncate character columns that are very long so the table is readable
    df <- dplyr::mutate(df, dplyr::across(
      where(is.character),
      ~ifelse(nchar(.x) > 120, paste0(substr(.x, 1, 117), "..."), .x)
    ))
    ft <- flextable::flextable(df) |>
      flextable::theme_booktabs() |>
      flextable::bg(bg = "#1F3864", part = "header") |>
      flextable::color(color = "white", part = "header") |>
      flextable::bold(bold = TRUE, part = "header") |>
      flextable::fontsize(size = 9, part = "all") |>
      flextable::autofit()
    officer::body_add_flextable(doc, ft)
  }

  sep <- function(doc) p(doc, "")   # blank line between sections

  # ---- Cover ----------------------------------------------------------------
  doc <- officer::body_add_par(doc, "BANA 420 — Text-mining Pipeline", style = "Title")
  doc <- h(doc, "Systematic Literature Review Report", lvl = 2)
  doc <- p(doc, paste("Generated:", format(Sys.time(), "%A, %d %B %Y at %H:%M:%S")))
  doc <- sep(doc)

  # ---- 1. Configuration -------------------------------------------------------
  doc <- h(doc, "1. Pipeline Configuration")
  doc <- p(doc, paste(
    "The table below records every setting that was active when the pipeline ran.",
    "Re-running with the same settings on the same zip file will reproduce all outputs exactly."
  ))
  cfg_df <- tibble::tibble(
    Setting = c(
      "Project directory", "Zip file used",
      "Top N terms", "Minimum term frequency",
      "Run date / time", "Topic-filter keywords"
    ),
    Value = c(
      cfg$project_dir, cfg$zip_file,
      as.character(cfg$n_top), as.character(cfg$min_freq),
      cfg$run_time, cfg$keywords
    )
  )
  doc <- add_ft(doc, cfg_df, n = 10)
  doc <- sep(doc)

  # ---- 2. Pipeline overview ---------------------------------------------------
  doc <- h(doc, "2. Pipeline Overview")
  doc <- p(doc, "Key record counts produced by this pipeline run:")
  if (!is.null(s$run_info)) doc <- add_ft(doc, s$run_info)
  doc <- sep(doc)

  # ---- 3. Data A --------------------------------------------------------------
  doc <- h(doc, "3. Data A — Cleaned, De-duplicated Records")
  doc <- p(doc, paste(
    "All CSVs inside the zip were merged and de-duplicated on the normalised title",
    "(lower-cased, punctuation removed). A stable PaperID (P0001, P0002 …) was assigned",
    "to each surviving record. Scopus field aliases were reconciled into standard column names."
  ))

  if (!is.null(s$data_a_export)) {
    # Topic flag breakdown
    doc <- h(doc, "Topic flag breakdown", lvl = 2)
    flag_tbl <- s$data_a_export |>
      dplyr::count(topic_flag, name = "count") |>
      dplyr::mutate(percent = paste0(round(count / sum(count) * 100, 1), " %"))
    doc <- add_ft(doc, flag_tbl)

    # Sample rows
    doc <- h(doc, "First 20 records (key columns)", lvl = 2)
    preview <- s$data_a_export |>
      dplyr::select(dplyr::any_of(c(
        "paper_id", "topic_flag", "title", "year", "source_title"
      ))) |>
      head(20)
    doc <- add_ft(doc, preview, n = 20)
  }
  doc <- sep(doc)

  # ---- 4. Top Terms -----------------------------------------------------------
  doc <- h(doc, "4. Top Terms Analysis")
  doc <- p(doc, paste(
    "Abstracts were tokenised into single words (unigrams). English stop-words and",
    "domain noise terms were removed. The", cfg$n_top,
    "most frequent remaining terms are shown below.",
    "Frequency = total occurrences across all", nrow(s$data_b), "abstracts."
  ))
  if (!is.null(s$bar_plot))    doc <- add_plot(doc, s$bar_plot, w = 6.5, h = 5)
  doc <- h(doc, "Term frequency table", lvl = 2)
  if (!is.null(s$top20_table)) doc <- add_ft(doc, s$top20_table, n = 50)

  doc <- h(doc, "Word cloud", lvl = 2)
  doc <- p(doc, "Word size encodes frequency. Spatial layout is fixed with set.seed(42).")
  if (!is.null(s$top20)) {
    tmp_wc <- tempfile(fileext = ".png")
    set.seed(42)
    grDevices::png(tmp_wc, width = 1800, height = 1200, res = 180, bg = "white")
    wordcloud::wordcloud(
      words = s$top20$word, freq = s$top20$frequency,
      min.freq = min(s$top20$frequency), max.words = cfg$n_top,
      random.order = FALSE, rot.per = 0.10, scale = c(5, 1.5),
      colors = RColorBrewer::brewer.pal(8, "Dark2")
    )
    grDevices::dev.off()
    doc <- officer::body_add_img(doc, src = tmp_wc, width = 6.5, height = 4.3)
    unlink(tmp_wc)
  }
  doc <- sep(doc)

  # ---- 5. Correlation heatmap -------------------------------------------------
  doc <- h(doc, "5. Term Correlation Heatmap")
  doc <- p(doc, paste(
    "Each cell shows the phi (\u03c6) coefficient between two terms:",
    "how much more often they co-occur in the same abstract than chance predicts.",
    "+1 = always together, 0 = independent, negative = rarely together.",
    "Only the top", cfg$n_top, "terms are included; the diagonal is always 1."
  ))
  if (!is.null(s$heatmap_plot)) doc <- add_plot(doc, s$heatmap_plot, w = 7, h = 6)
  doc <- h(doc, "Top 15 term pairs by |correlation|", lvl = 2)
  if (!is.null(s$term_cor_full)) {
    top_pairs <- s$term_cor_full |>
      dplyr::filter(item1 != item2) |>
      dplyr::arrange(dplyr::desc(abs(correlation))) |>
      dplyr::mutate(correlation = round(correlation, 4)) |>
      head(15)
    doc <- add_ft(doc, top_pairs)
  }
  doc <- sep(doc)

  # ---- 6. Document map --------------------------------------------------------
  doc <- h(doc, "6. Document Map (2D MDS of TF-IDF)")
  doc <- p(doc, paste(
    "Step 1: Build a TF-IDF matrix (rows = papers, columns = terms with frequency",
    paste0("\u2265 ", cfg$min_freq), ").",
    "Step 2: Compute Euclidean distances between paper vectors.",
    "Step 3: Project onto 2D with classical Multidimensional Scaling (MDS).",
    "Blue = Likely related (keyword match). Red = Manual review."
  ))
  if (!is.null(s$doc_map_plot)) doc <- add_plot(doc, s$doc_map_plot, w = 7, h = 5.5)
  if (!is.null(s$doc_map_df)) {
    doc <- h(doc, "Document MDS coordinates (first 20 rows)", lvl = 2)
    coords <- s$doc_map_df |>
      dplyr::mutate(dplyr::across(where(is.numeric), ~round(., 4))) |>
      head(20)
    doc <- add_ft(doc, coords)
  }
  doc <- sep(doc)

  # ---- 7. Term map ------------------------------------------------------------
  doc <- h(doc, "7. Term Map (2D MDS of Correlation Distances)")
  doc <- p(doc, paste(
    "Distance between terms = 1 \u2212 \u03c6. Perfectly correlated terms would overlap;",
    "uncorrelated terms sit at distance 1. MDS projects these distances to 2D.",
    "Clusters of terms = coherent research sub-themes."
  ))
  if (!is.null(s$term_map_plot)) doc <- add_plot(doc, s$term_map_plot, w = 7, h = 5.5)
  if (!is.null(s$term_map_df)) {
    doc <- h(doc, "Term MDS coordinates", lvl = 2)
    doc <- add_ft(doc,
      s$term_map_df |> dplyr::mutate(dplyr::across(where(is.numeric), ~round(., 4))))
  }
  doc <- sep(doc)

  # ---- 8. Descriptive summaries -----------------------------------------------
  doc <- h(doc, "8. Descriptive Summaries")

  doc <- h(doc, "Publications per Year", lvl = 2)
  doc <- p(doc, "Based on the 'Year' field in the Scopus export (all de-duplicated papers).")
  if (!is.null(s$year_summary)) {
    yp <- ggplot2::ggplot(s$year_summary, ggplot2::aes(x = year, y = documents)) +
      ggplot2::geom_col(fill = "#1F3864", width = 0.7) +
      ggplot2::geom_text(ggplot2::aes(label = documents), vjust = -0.4, size = 3.2) +
      ggplot2::labs(title = "Publications per Year", x = NULL, y = "Documents") +
      ggplot2::theme_minimal(base_size = 11)
    doc <- add_plot(doc, yp, w = 6.5, h = 3.8)
    doc <- add_ft(doc, s$year_summary)
  }
  doc <- sep(doc)

  doc <- h(doc, "Top 20 Sources", lvl = 2)
  doc <- p(doc, "Journals, conference proceedings, or book series with the most records.")
  if (!is.null(s$source_summary)) {
    sp <- ggplot2::ggplot(s$source_summary,
        ggplot2::aes(x = reorder(source_title, documents), y = documents)) +
      ggplot2::geom_col(fill = "#1F3864") +
      ggplot2::geom_text(ggplot2::aes(label = documents), hjust = -0.1, size = 2.8) +
      ggplot2::coord_flip(clip = "off") +
      ggplot2::expand_limits(y = max(s$source_summary$documents) * 1.12) +
      ggplot2::labs(title = "Top 20 Sources", x = NULL, y = "Documents") +
      ggplot2::theme_minimal(base_size = 10)
    doc <- add_plot(doc, sp, w = 7, h = 5)
    doc <- add_ft(doc, s$source_summary)
  }

  # ---- Save -----------------------------------------------------------------
  print(doc, target = out_path)
  invisible(out_path)
}

# ---- UI helpers -------------------------------------------------------------

# Styled info box with two optional sections: "About the data" and "How to read"
insight_box <- function(about = NULL, how_to = NULL) {
  sections <- tagList()

  if (!is.null(about)) {
    sections <- tagAppendChild(sections,
      div(style = "margin-bottom:10px;",
        tags$strong(style = "color:#1F3864;", "About this data"),
        tags$ul(style = "margin-top:5px; padding-left:18px; color:#333;",
          lapply(about, tags$li)
        )
      )
    )
  }

  if (!is.null(how_to)) {
    sections <- tagAppendChild(sections,
      div(
        tags$strong(style = "color:#1F3864;", "How to analyse"),
        tags$ul(style = "margin-top:5px; padding-left:18px; color:#333;",
          lapply(how_to, tags$li)
        )
      )
    )
  }

  div(
    style = paste(
      "background:#f0f4ff; border-left:4px solid #1F3864;",
      "border-radius:4px; padding:12px 16px;",
      "margin-bottom:16px; font-size:0.88em; line-height:1.6;"
    ),
    sections
  )
}

# ---- UI ---------------------------------------------------------------------
ui <- fluidPage(
  shinyjs::useShinyjs(),

  tags$head(tags$style(HTML("
    body { font-family: 'Segoe UI', sans-serif; }
    .metric-card {
      background: #1F3864; color: white; border-radius: 8px;
      padding: 14px 10px; text-align: center; margin: 4px;
    }
    .metric-card .num  { font-size: 2.2em; font-weight: 700; line-height: 1.1; }
    .metric-card .lbl  { font-size: 0.78em; opacity: 0.82; margin-top: 2px; }
    .status-box {
      background: #f8f9fa; border: 1px solid #dee2e6; border-radius: 4px;
      padding: 7px 10px; min-height: 34px; font-size: 0.83em; word-break: break-word;
    }
    .sidebar-label { font-weight: 600; margin-bottom: 4px; font-size: 0.9em; }
    .dl-btn { width: 100%; margin-bottom: 6px; }
    .tab-content { padding-top: 10px; }
    .cell-expand {
      cursor: pointer; color: inherit;
      display: -webkit-box; -webkit-line-clamp: 3;
      -webkit-box-orient: vertical; overflow: hidden;
      max-height: 4.5em; line-height: 1.5em;
    }
    .cell-expand:hover { color: #1F3864; text-decoration: underline dotted; }
    .modal-body p { white-space: pre-wrap; word-break: break-word; font-size: 0.93em; }
    .modal-header { background: #1F3864; color: white; }
    .modal-header .close { color: white; opacity: 0.8; }
  "))),

  titlePanel("BANA 420 — Text-mining Pipeline"),

  sidebarLayout(
    sidebarPanel(
      width = 3,

      # Step 1 — folder
      p(class = "sidebar-label", "1. Project folder"),
      shinyFiles::shinyDirButton(
        "pick_dir", label = "Browse\u2026", title = "Select project folder",
        class = "btn-default btn-sm btn-block"
      ),
      br(),
      div(class = "status-box", style = "margin-top:4px; margin-bottom:8px;",
          textOutput("chosen_dir_text")),
      helpText(style = "margin-top:0;",
        "Folder must have a data/ subfolder with a Scopus zip file."),

      tags$hr(),

      # Step 2 — settings
      p(class = "sidebar-label", "2. Analysis settings"),
      sliderInput("n_top_terms",    "Top N terms",       min = 10, max = 50, value = 20, step = 5),
      sliderInput("min_token_freq", "Min term frequency", min = 1,  max = 15, value = 3,  step = 1),

      tags$hr(),

      # Step 3 — run
      p(class = "sidebar-label", "3. Run"),
      actionButton("run_pipeline", "Run full pipeline",
                   class = "btn-primary btn-block", icon = icon("play")),
      br(), br(),
      div(class = "status-box", textOutput("status")),

      tags$hr(),

      # Report
      p(class = "sidebar-label", "Report"),
      downloadButton("dl_report", "Word Report (.docx)",
                     class = "btn-success dl-btn", icon = icon("file-word")),
      helpText(style = "margin-top:2px;",
               "Full report with all charts, tables, and configuration."),

      tags$hr(),

      # Downloads
      p(class = "sidebar-label", "Raw downloads"),
      downloadButton("dl_data_a",    "Data A (xlsx)",        class = "btn-default dl-btn"),
      downloadButton("dl_data_b",    "Data B (xlsx)",        class = "btn-default dl-btn"),
      downloadButton("dl_manual",    "Manual review (xlsx)", class = "btn-default dl-btn"),
      downloadButton("dl_top20_csv", "Top terms (csv)",      class = "btn-default dl-btn"),
      downloadButton("dl_corr_csv",  "Correlations (csv)",   class = "btn-default dl-btn"),
      downloadButton("dl_doc_map",   "Doc map (csv)",        class = "btn-default dl-btn"),
      downloadButton("dl_term_map",  "Term map (csv)",       class = "btn-default dl-btn"),
      downloadButton("dl_run_info",  "Run info (csv)",       class = "btn-default dl-btn")
    ),

    mainPanel(
      width = 9,
      tabsetPanel(
        id = "main_tabs",

        # Overview -----------------------------------------------------------
        tabPanel("Overview",
          br(),
          fluidRow(
            column(3, div(class = "metric-card",
              div(class = "num", textOutput("m_raw")),
              div(class = "lbl", "Raw records"))),
            column(3, div(class = "metric-card",
              div(class = "num", textOutput("m_dedup")),
              div(class = "lbl", "After de-dup"))),
            column(3, div(class = "metric-card",
              div(class = "num", textOutput("m_abstracts")),
              div(class = "lbl", "With abstracts"))),
            column(3, div(class = "metric-card",
              div(class = "num", textOutput("m_manual")),
              div(class = "lbl", "Manual review")))
          ),
          br(),
          insight_box(
            about = list(
              "Raw records — total rows across all CSV files in the zip, including duplicates from overlapping searches.",
              "After de-dup — unique papers remaining after removing duplicates on the normalised title (lower-cased, punctuation stripped).",
              "With abstracts — papers that have a non-empty Abstract field; only these feed the text-mining steps.",
              "Manual review — papers the keyword filter could not confidently classify as relevant; these need a human decision."
            ),
            how_to = list(
              "A large drop from Raw to After de-dup is expected and healthy — it means your searches overlapped, which is good for coverage.",
              "If With abstracts is much lower than After de-dup, many Scopus records lack abstracts; consider retrieving them from the publisher or accepting reduced text-mining coverage.",
              "If Manual review is very high (> 40 % of After de-dup), your keyword list may be too narrow — expand it in the pipeline settings.",
              "Run the pipeline again after changing the Top N terms or Min frequency sliders to see how the results shift."
            )
          ),
          h4("How to use"),
          tags$ol(
            tags$li("Select the project folder (must contain ", tags$code("data/"), " with a Scopus zip)."),
            tags$li("Adjust ", tags$b("Top N terms"), " and ", tags$b("Min frequency"), " if needed."),
            tags$li(tags$b("Click Run full pipeline.")),
            tags$li("Browse each tab — all charts and tables update automatically."),
            tags$li("Download any output from the sidebar.")
          ),
          h4("Expected inputs"),
          tags$ul(
            tags$li(tags$b("data/*.zip"), " — zip of Scopus CSV exports (required)."),
            tags$li(tags$b("data/ALL SEARCH RESULTS - v01g (1).xlsx"), " — optional cross-check.")
          )
        ),

        # Data A -------------------------------------------------------------
        tabPanel("Data A",
          h4("Data A — cleaned, de-duplicated master table"),
          insight_box(
            about = list(
              "One row per unique paper — every CSV from the zip is merged and de-duplicated on the normalised title.",
              HTML("<b>paper_id</b> — stable identifier (P0001, P0002 …) assigned after de-duplication; used to link rows across all outputs."),
              HTML("<b>topic_flag</b> — 'Likely related' if the title or abstract matched any pipeline keyword; 'Manual review' otherwise."),
              HTML("<b>search_no / search_file</b> — which CSV file the paper came from (useful for tracing back to your original search query).")
            ),
            how_to = list(
              "Use the column filter row (top of the table) to isolate papers by year, source, or topic_flag.",
              "Click 'Show / hide columns' to remove noisy columns like affiliations before exporting.",
              "Filter topic_flag = 'Manual review' here to quickly see which papers need a human decision.",
              "Click any truncated cell (abstract, affiliations) to read its full content in a popup."
            )
          ),
          DT::dataTableOutput("data_a_table")
        ),

        # Data B -------------------------------------------------------------
        tabPanel("Data B",
          h4("Data B — PaperID + abstract (text-mining input)"),
          insight_box(
            about = list(
              "Data B is a strict subset of Data A: only rows where the Abstract column is non-empty.",
              "It contains exactly two columns: paper_id (the link back to Data A) and abstract (the raw text).",
              "Every downstream analysis — tokenisation, top terms, correlations, document map — is computed from this table."
            ),
            how_to = list(
              "If this table is much smaller than Data A, your Scopus export is missing many abstracts — that reduces text-mining quality.",
              "Use the search box to find a specific paper_id and verify its abstract text looks correct before trusting the analysis.",
              "Click a truncated abstract cell to read the full text and sanity-check what the tokeniser will see."
            )
          ),
          DT::dataTableOutput("data_b_table")
        ),

        # Manual review ------------------------------------------------------
        tabPanel("Manual review",
          h4("Manual-review candidates"),
          insight_box(
            about = list(
              "These papers matched none of the pipeline keywords in either the title or the abstract.",
              "They are not automatically excluded — that decision belongs to a human reviewer.",
              "The table shows paper_id, title, year, source, abstract, and topic_flag for quick triage."
            ),
            how_to = list(
              "Read each title first — if clearly off-topic (e.g. a chemistry paper in a fintech search), mark it for exclusion.",
              "If the title looks relevant but the abstract did not match, read the abstract — the paper may use different terminology (e.g. 'algorithmic trading' vs 'trading').",
              "Papers using relevant but unlisted synonyms are good candidates for expanding the keyword list in the pipeline.",
              "Papers that sit inside blue clusters on the Document Map tab are likely relevant even if the keyword filter missed them.",
              "Record your inclusion / exclusion decisions in a separate column in the downloaded Excel file."
            )
          ),
          DT::dataTableOutput("manual_table")
        ),

        # Top terms ----------------------------------------------------------
        tabPanel("Top terms",
          h4(textOutput("top_n_heading")),
          insight_box(
            about = list(
              "Terms are extracted by tokenising every abstract in Data B, then removing English stop-words (the, is, of …) and domain noise words (elsevier, copyright …).",
              "Frequency = number of times the term appears across all abstracts (not the number of papers it appears in).",
              "The slider 'Top N terms' controls how many terms are shown; 'Min frequency' controls which terms are considered informative for the document map."
            ),
            how_to = list(
              "Bar chart — the longer the bar, the more central that concept is to the literature; the top 5 terms typically define the core research theme.",
              "Look for surprising absences: if a term you expect to dominate is missing, it may be a synonym the data uses instead.",
              "A very steep drop-off between rank 1 and rank 10 means the literature is tightly focused; a gradual slope means it is broad and multi-theme.",
              "Word cloud — size encodes frequency (same as the bar chart); spatial position is random. Use it as a visual summary, not for precise comparison.",
              "Increase Top N to 30-50 to reveal secondary vocabulary that might represent emerging sub-topics."
            )
          ),
          fluidRow(
            column(4, DT::dataTableOutput("top20_table")),
            column(8, plotOutput("top20_plot", height = "460px"))
          ),
          tags$hr(),
          h4("Word cloud"),
          plotOutput("wordcloud_plot", height = "480px")
        ),

        # Correlation heatmap ------------------------------------------------
        tabPanel("Correlation heatmap",
          h4("Pairwise term correlations (\u03c6 coefficient)"),
          insight_box(
            about = list(
              "Each cell shows the phi (\u03c6) correlation between two terms — how much more (or less) often they appear in the same abstract than chance alone would predict.",
              "Scale: +1.0 = always appear together; 0 = independent (no relationship); \u22120.3 or lower = rarely co-occur (unusual in text mining).",
              "The matrix is symmetric: the value for (term A, term B) is identical to (term B, term A).",
              "Only the top-N terms (set by the slider) are included; the diagonal (a term with itself) is always 1."
            ),
            how_to = list(
              "Look for dark-red blocks (clusters of terms with high phi) — each block represents a coherent sub-theme in the literature.",
              "A phi \u2265 0.20 between two terms is noteworthy; \u2265 0.35 is a strong relationship.",
              "Terms that show near-zero correlation with all others are standalone concepts — they appear across many different papers.",
              "Use the correlation table below the heatmap to sort by |phi| and find the strongest term pairs quickly.",
              "Name each red cluster — those names become your research sub-theme labels for the final report."
            )
          ),
          plotOutput("heatmap_plot", height = "620px"),
          tags$hr(),
          h4("Correlation table — sorted by absolute correlation, self-pairs excluded"),
          DT::dataTableOutput("corr_table")
        ),

        # Document map -------------------------------------------------------
        tabPanel("Document map",
          h4("Document map — 2D MDS of TF-IDF"),
          insight_box(
            about = list(
              "Each point is one paper from Data B. Its position is computed in three steps: (1) build a TF-IDF matrix (rows = papers, columns = informative terms); (2) compute Euclidean distances between paper vectors; (3) project those distances onto 2D using classical Multidimensional Scaling (MDS).",
              "TF-IDF down-weights common words and up-weights words that are distinctive to a specific paper, so proximity in this map means 'similar distinctive vocabulary'.",
              "Colour: blue = 'Likely related' (keyword-matched); red = 'Manual review' (not matched by keyword filter).",
              "The 'Min frequency' slider controls which terms count as informative — lower values include rarer terms and spread the map out more."
            ),
            how_to = list(
              "Tight clusters of blue points = a focused sub-field sharing a common vocabulary; label each cluster as a sub-theme.",
              "Red points (Manual review) inside a blue cluster are strong candidates for inclusion — they use the same vocabulary as confirmed relevant papers.",
              "Red points far from any blue cluster are likely off-topic and safe to exclude.",
              "Outlier blue points far from all clusters are papers with highly distinctive vocabulary — could be pioneering or interdisciplinary work worth reading.",
              "If the entire map looks like one dense blob, increase Min frequency to filter out very common terms and reveal more structure."
            )
          ),
          plotOutput("doc_map_plot", height = "680px"),
          tags$hr(),
          h4("Paper coordinates (Dim1, Dim2 = MDS axes)"),
          DT::dataTableOutput("doc_map_table")
        ),

        # Term map -----------------------------------------------------------
        tabPanel("Term map",
          h4("Term map — 2D MDS of correlation distances"),
          insight_box(
            about = list(
              "Each point is one of the top-N terms. Proximity = high phi correlation (they co-occur often).",
              "Distance is computed as 1 \u2212 \u03c6, so perfectly correlated terms (phi = 1) would sit on top of each other, and uncorrelated terms (phi = 0) would be at distance 1.",
              "Classical MDS projects these distances onto 2D while preserving relative distances as faithfully as possible.",
              "This map is the term-level complement to the Document map: where the document map shows paper clusters, this map shows concept clusters."
            ),
            how_to = list(
              "Terms that cluster together form a coherent concept group — give each cluster a theme name.",
              "The number of visible clusters roughly equals the number of distinct sub-themes in your literature.",
              "Terms sitting between two clusters are bridging concepts — they connect different research streams.",
              "Isolated terms far from all others are niche or unique concepts that do not belong to any dominant theme.",
              "Cross-reference with the heatmap: a cluster here should correspond to a red block there."
            )
          ),
          plotOutput("term_map_plot", height = "580px"),
          tags$hr(),
          h4("Term coordinates (Dim1, Dim2 = MDS axes)"),
          DT::dataTableOutput("term_map_table")
        ),

        # Descriptive summaries ----------------------------------------------
        tabPanel("Descriptive summaries",
          insight_box(
            about = list(
              "These charts summarise the bibliographic metadata of Data A (all de-duplicated papers, not just those with abstracts).",
              "Publications per year tracks how many papers were published each calendar year according to the Scopus 'Year' field.",
              "Top 20 sources lists the journals, conference proceedings, or book series that contribute the most papers to the dataset."
            ),
            how_to = list(
              "Year chart — a rising trend confirms growing academic interest in your topic; a peak followed by a plateau may indicate the field is maturing.",
              "Year chart — if the earliest years have very few papers, check whether your Scopus query limited the date range, or whether the topic truly emerged recently.",
              "Year chart — missing years in the middle of the range are worth investigating (possibly a coverage gap in the database).",
              "Sources chart — a single dominant journal or conference with a very tall bar indicates an established publication venue for this research area.",
              "Sources chart — if the top 20 sources all have 1-2 papers, the literature is fragmented with no clear home venue; this is common in emerging or interdisciplinary fields.",
              "Sources chart — a mix of journals and conference proceedings suggests the field publishes in both, which is typical of applied computer science and information systems research."
            )
          ),
          fluidRow(
            column(6,
              h4("Publications per year"),
              plotOutput("year_plot", height = "360px"),
              br(),
              DT::dataTableOutput("year_table")
            ),
            column(6,
              h4("Top 20 sources"),
              plotOutput("source_plot", height = "360px"),
              br(),
              DT::dataTableOutput("source_table")
            )
          )
        ),

        # Run log ------------------------------------------------------------
        tabPanel("Run log",
          h4("Run summary"),
          insight_box(
            about = list(
              "A compact record of what the pipeline produced in the most recent run.",
              "raw_rows = total rows read from all CSVs; data_a_rows = after de-dup; data_b_rows = after filtering for non-empty abstracts.",
              "unique_tokens = number of distinct words remaining after stop-word and noise removal across all abstracts."
            ),
            how_to = list(
              "If data_b_rows is zero, the pipeline found no abstracts — check that your Scopus CSVs include the Abstract column.",
              "If unique_tokens is very low (< 200), the abstracts may be too short or the noise list too aggressive — reduce Min frequency or shorten the noise word list.",
              "Use the full log below to trace exactly where the pipeline spent time and what counts it produced at each step."
            )
          ),
          DT::dataTableOutput("run_info_table"),
          tags$hr(),
          h4("Full log"),
          verbatimTextOutput("run_log_text")
        )
      )
    )
  )
)

# ---- Server -----------------------------------------------------------------
server <- function(input, output, session) {

  # ---- Shared JS for expandable long-text cells ------------------------------
  # Any cell whose text exceeds TRUNC chars is rendered as a clamped snippet.
  # Clicking it fires input$expand_cell so the server can show a modal.
  TRUNC <- 160L

  cell_render_js <- DT::JS(paste0("
    function(data, type, row, meta) {
      if (type !== 'display' || typeof data !== 'string' || data.length <= ", TRUNC, ") {
        return data == null ? '' : data;
      }
      var esc = data.replace(/&/g,'&amp;').replace(/</g,'&lt;')
                    .replace(/>/g,'&gt;').replace(/\"/g,'&quot;');
      return '<span class=\"cell-expand\" title=\"Click to read full text\" ' +
             'data-full=\"' + esc + '\">' + data + '</span>';
    }
  "))

  cell_click_cb <- DT::JS("
    table.on('click', '.cell-expand', function() {
      var full = $(this).data('full');
      Shiny.setInputValue('expand_cell', {col: $(this).closest('td').index(),
        text: full, ts: Date.now()}, {priority: 'event'});
    });
  ")

  # Modal shown when user clicks an expandable cell
  observeEvent(input$expand_cell, {
    showModal(modalDialog(
      title = "Full cell content",
      p(input$expand_cell$text),
      footer = modalButton("Close"),
      easyClose = TRUE,
      size = "l"
    ))
  })

  # Helper: build a datatable with truncated cells + col-visibility button
  make_dt <- function(df, page = 10L, filter = "none") {
    DT::datatable(
      df,
      filter     = filter,
      extensions = "Buttons",
      escape     = FALSE,          # allow our HTML spans through
      options    = list(
        scrollX     = TRUE,
        pageLength  = page,
        dom         = "Bfrtip",
        buttons     = list(list(extend = "colvis", text = "Show / hide columns")),
        columnDefs  = list(list(targets = "_all", render = cell_render_js))
      ),
      callback = cell_click_cb
    )
  }

  # ---- Directory picker -----------------------------------------------------
  fs_roots <- c(Home = path.expand("~"), `Working dir` = getwd())

  shinyFiles::shinyDirChoose(input, "pick_dir", roots = fs_roots)

  chosen_dir <- reactive({
    if (is.integer(input$pick_dir)) return(getwd())
    d <- shinyFiles::parseDirPath(roots = fs_roots, selection = input$pick_dir)
    if (length(d) == 0 || identical(d, "")) getwd() else as.character(d)
  })

  output$chosen_dir_text <- renderText({
    d <- chosen_dir()
    if (dir.exists(d)) d else paste(d, "[not found]")
  })

  # ---- Shared state ---------------------------------------------------------
  state <- reactiveValues(
    status       = "Idle — select a folder and click Run.",
    log_lines    = character(0),
    ready        = FALSE,
    # pipeline outputs (all NULL until a successful run)
    data_a_export  = NULL,
    data_b         = NULL,
    manual_review  = NULL,
    top20          = NULL,
    top20_table    = NULL,
    term_cor_full  = NULL,
    heatmap_plot   = NULL,
    bar_plot       = NULL,
    doc_map_df     = NULL,
    doc_map_plot   = NULL,
    term_map_df    = NULL,
    term_map_plot  = NULL,
    year_summary   = NULL,
    source_summary = NULL,
    run_info       = NULL,
    # metrics for overview cards
    n_raw      = 0L,
    n_dedup    = 0L,
    n_abstract = 0L,
    n_manual   = 0L,
    # config snapshot (populated on successful run — used by report generator)
    cfg_project_dir = "",
    cfg_zip_file    = "",
    cfg_n_top       = 20L,
    cfg_min_freq    = 3L,
    cfg_run_time    = "",
    cfg_keywords    = ""
  )

  log_msg <- function(...) {
    msg <- paste0(...)
    state$log_lines <- c(state$log_lines, msg)
    state$status    <- msg
  }

  # ---- Pipeline -------------------------------------------------------------
  observeEvent(input$run_pipeline, {

    project_dir <- chosen_dir()
    if (!dir.exists(project_dir)) {
      showNotification("Select a valid project directory first.", type = "error")
      return()
    }

    shinyjs::disable("run_pipeline")
    state$log_lines <- character(0)
    state$ready     <- FALSE

    withProgress(message = "Running pipeline\u2026", value = 0, {

      # tryCatch: use stop() for user-facing errors so they are caught here.
      # All state$xxx assignments happen ONLY after the full pipeline succeeds.
      ok <- tryCatch({

        # ---- Paths ----------------------------------------------------------
        input_dir  <- file.path(project_dir, "data")
        output_dir <- file.path(project_dir, "output")
        fig_dir    <- file.path(output_dir, "figures")
        table_dir  <- file.path(output_dir, "tables")
        data_dir   <- file.path(output_dir, "data")
        log_dir    <- file.path(output_dir, "logs")
        raw_dir    <- file.path(output_dir, "raw_scopus_files")
        unzip_dir  <- file.path(input_dir,  "search_results_unzipped")

        for (p in c(output_dir, fig_dir, table_dir, data_dir, log_dir, raw_dir))
          dir.create(p, recursive = TRUE, showWarnings = FALSE)

        log_msg("Run started: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
        incProgress(0.04, detail = "Locating zip file\u2026")

        # ---- Find zip -------------------------------------------------------
        zip_files <- list.files(input_dir, pattern = "\\.zip$",
                                full.names = TRUE, ignore.case = TRUE)
        if (length(zip_files) == 0)
          stop("No .zip file found in data/. Add the Scopus zip and try again.")

        zip_path <- zip_files[1]
        log_msg("Using zip: ", basename(zip_path))
        incProgress(0.04, detail = "Unzipping\u2026")

        # Always re-unzip so stale files never cause silent failures
        if (dir.exists(unzip_dir)) unlink(unzip_dir, recursive = TRUE)
        dir.create(unzip_dir, recursive = TRUE)
        unzip(zip_path, exdir = unzip_dir)

        csv_files <- list.files(unzip_dir, pattern = "\\.csv$",
                                full.names = TRUE, recursive = TRUE)
        if (length(csv_files) == 0)
          stop("No CSV files found inside the zip. Check the zip contents.")

        # ---- Read CSVs ------------------------------------------------------
        incProgress(0.05, detail = paste("Reading", length(csv_files), "CSV files\u2026"))

        raw_list <- lapply(seq_along(csv_files), function(i) {
          df <- readr::read_csv(csv_files[i],
                                col_types = readr::cols(.default = "c"),
                                show_col_types = FALSE, progress = FALSE)
          df$search_no   <- i
          df$search_file <- basename(csv_files[i])
          df
        })
        raw_combined <- dplyr::bind_rows(raw_list)
        readr::write_csv(raw_combined, file.path(raw_dir, "raw_combined.csv"))
        log_msg("Loaded ", length(csv_files), " CSV files — ",
                nrow(raw_combined), " rows total")
        incProgress(0.06, detail = "Building Data A\u2026")

        # ---- Build Data A ---------------------------------------------------
        data_a_raw <- raw_combined |> janitor::clean_names()

        if (!"title" %in% names(data_a_raw))
          stop("No 'Title' column found. Are these Scopus CSV exports?")

        keywords <- c(
          "trading", "stock", "broker", "market data", "decision support",
          "electronic trading", "user interface", "user experience", "usability",
          "human.computer interaction", "hci", "visualization", "dashboard",
          "financial", "fintech", "investment", "portfolio"
        )

        data_a_raw <- data_a_raw |>
          first_existing(c("abstract", "ab"),                          "abstract")     |>
          first_existing(c("authors", "author_names", "au"),           "authors")      |>
          first_existing(c("year", "py"),                              "year")         |>
          first_existing(c("source_title", "so", "source", "journal"), "source_title") |>
          ensure_col("abstract") |> ensure_col("authors") |>
          ensure_col("year")     |> ensure_col("source_title") |>
          ensure_col("search_no") |> ensure_col("search_file")

        data_a_clean <- data_a_raw |>
          dplyr::filter(!is.na(title), stringr::str_squish(title) != "") |>
          dplyr::mutate(
            title_key     = normalize_title(title),
            combined_text = clean_text(paste(title, dplyr::coalesce(abstract, ""))),
            topic_flag    = dplyr::if_else(
              stringr::str_detect(combined_text, paste(keywords, collapse = "|")),
              "Likely related", "Manual review"
            )
          ) |>
          dplyr::arrange(title) |>
          dplyr::distinct(title_key, .keep_all = TRUE) |>
          dplyr::mutate(paper_id = sprintf("P%04d", dplyr::row_number())) |>
          dplyr::relocate(
            dplyr::any_of(c("paper_id", "topic_flag", "search_no", "search_file")),
            .before = 1
          )

        data_a_export <- data_a_clean |> dplyr::select(-title_key, -combined_text)

        manual_review <- data_a_clean |>
          dplyr::filter(topic_flag == "Manual review") |>
          dplyr::select(dplyr::any_of(c(
            "paper_id", "search_no", "search_file",
            "title", "year", "source_title", "abstract", "topic_flag"
          )))

        log_msg("Data A: ", nrow(data_a_export),
                " rows after de-dup from ", nrow(raw_combined), " raw")

        # ---- Data B ---------------------------------------------------------
        data_b_export <- data_a_export |>
          dplyr::select(paper_id, abstract) |>
          dplyr::filter(!is.na(abstract), stringr::str_squish(abstract) != "")

        if (nrow(data_b_export) == 0)
          stop("No abstracts found. Check that the Abstract column is populated in your CSVs.")

        log_msg("Data B: ", nrow(data_b_export), " rows with abstracts")

        # ---- Write xlsx -----------------------------------------------------
        incProgress(0.05, detail = "Saving Data A / B\u2026")
        openxlsx::write.xlsx(data_a_export,
          file.path(data_dir, "Data_A_cleaned.xlsx"), asTable = TRUE, overwrite = TRUE)
        openxlsx::write.xlsx(data_b_export,
          file.path(data_dir, "Data_B_abstracts.xlsx"), asTable = TRUE, overwrite = TRUE)
        if (nrow(manual_review) > 0)
          openxlsx::write.xlsx(manual_review,
            file.path(data_dir, "Manual_review.xlsx"), asTable = TRUE, overwrite = TRUE)

        # ---- Tokenise -------------------------------------------------------
        incProgress(0.07, detail = "Tokenising abstracts\u2026")

        n_top    <- input$n_top_terms
        min_freq <- input$min_token_freq

        noise_terms <- tibble::tibble(word = c(
          "elsevier", "ltd", "rights", "reserved", "author", "authors",
          "copyright", "copyrights", "study", "paper", "results", "result",
          "method", "methods", "approach", "based", "using", "used",
          "proposed", "present", "provide", "provides"
        ))

        abstract_tokens <- data_b_export |>
          tidytext::unnest_tokens(word, abstract) |>
          dplyr::filter(
            stringr::str_detect(word, "[a-z]"),
            !stringr::str_detect(word, "^\\d+$")
          ) |>
          dplyr::anti_join(tidytext::stop_words, by = "word") |>
          dplyr::anti_join(noise_terms,          by = "word")

        if (nrow(abstract_tokens) == 0)
          stop("No tokens remain after stop-word removal. Abstracts may be empty or all noise.")

        term_counts <- abstract_tokens |>
          dplyr::count(word, sort = TRUE, name = "frequency")

        top_n_terms <- term_counts |> dplyr::slice_head(n = n_top)
        top_words   <- top_n_terms$word
        top_n_table <- top_n_terms |>
          dplyr::mutate(rank = dplyr::row_number()) |>
          dplyr::select(rank, word, frequency)

        readr::write_csv(top_n_terms, file.path(table_dir, "top_terms.csv"))
        openxlsx::write.xlsx(top_n_table, file.path(table_dir, "top_terms.xlsx"),
                             asTable = TRUE, overwrite = TRUE)
        log_msg("Top ", n_top, " terms extracted (", nrow(term_counts), " unique tokens)")

        # ---- Bar chart ------------------------------------------------------
        incProgress(0.05, detail = "Bar chart\u2026")

        bar_plot <- ggplot2::ggplot(
          top_n_terms,
          ggplot2::aes(x = reorder(word, frequency), y = frequency)
        ) +
          ggplot2::geom_col(fill = "#1F3864") +
          ggplot2::geom_text(ggplot2::aes(label = frequency),
                             hjust = -0.15, size = 3.2) +
          ggplot2::coord_flip(clip = "off") +
          ggplot2::expand_limits(y = max(top_n_terms$frequency) * 1.08) +
          ggplot2::labs(title = paste("Top", n_top, "Most Frequent Terms"),
                        x = NULL, y = "Frequency") +
          ggplot2::theme_minimal(base_size = 13) +
          ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())

        ggplot2::ggsave(file.path(fig_dir, "top_terms_barplot.png"),
                        plot = bar_plot, width = 11, height = 8, dpi = 300, bg = "white")

        # ---- Correlation heatmap --------------------------------------------
        incProgress(0.07, detail = "Computing correlations\u2026")

        word_counts_by_doc <- abstract_tokens |>
          dplyr::count(paper_id, word, name = "n")

        term_cor_pairs <- word_counts_by_doc |>
          dplyr::filter(word %in% top_words) |>
          widyr::pairwise_cor(item = word, feature = paper_id, value = n,
                              sort = TRUE, upper = FALSE)

        all_pairs <- tidyr::expand_grid(item1 = top_words, item2 = top_words)

        term_cor_full <- dplyr::bind_rows(
          term_cor_pairs,
          term_cor_pairs |>
            dplyr::transmute(item1 = item2, item2 = item1, correlation)
        ) |>
          dplyr::right_join(all_pairs, by = c("item1", "item2")) |>
          dplyr::mutate(
            correlation = dplyr::case_when(
              item1 == item2 ~ 1,
              TRUE           ~ tidyr::replace_na(correlation, 0)
            )
          )

        readr::write_csv(term_cor_full, file.path(table_dir, "term_correlations.csv"))

        heatmap_plot <- ggplot2::ggplot(
          term_cor_full,
          ggplot2::aes(x = item1, y = item2, fill = correlation)
        ) +
          ggplot2::geom_tile(color = "white", linewidth = 0.4) +
          ggplot2::scale_fill_gradient2(
            low = "#2166ac", mid = "white", high = "#d6604d",
            midpoint = 0, limits = c(-1, 1)
          ) +
          ggplot2::geom_text(
            ggplot2::aes(label = ifelse(abs(correlation) >= 0.05,
                                        sprintf("%.2f", correlation), "")),
            size = 2.5, color = "black"
          ) +
          ggplot2::labs(
            title = paste("Correlation Heatmap —", n_top, "Terms"),
            x = NULL, y = NULL, fill = "\u03c6"
          ) +
          ggplot2::theme_minimal(base_size = 11) +
          ggplot2::theme(
            axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
            panel.grid  = ggplot2::element_blank()
          )

        ggplot2::ggsave(file.path(fig_dir, "heatmap.png"),
                        plot = heatmap_plot, width = 13, height = 11, dpi = 300, bg = "white")
        log_msg("Heatmap done.")

        # ---- Document map ---------------------------------------------------
        incProgress(0.08, detail = "Document map\u2026")

        doc_term_tfidf <- abstract_tokens |>
          dplyr::count(paper_id, word, sort = TRUE, name = "n") |>
          tidytext::bind_tf_idf(term = word, document = paper_id, n = n)

        informative <- term_counts |>
          dplyr::filter(frequency >= min_freq) |>
          dplyr::pull(word)

        doc_map_df   <- NULL
        doc_map_plot <- NULL

        if (length(informative) >= 2) {
          doc_sparse <- doc_term_tfidf |>
            dplyr::filter(word %in% informative) |>
            tidytext::cast_sparse(row = paper_id, column = word, value = tf_idf)

          doc_mat <- as.matrix(doc_sparse)
          doc_mat <- doc_mat[rowSums(doc_mat) > 0, , drop = FALSE]

          if (nrow(doc_mat) >= 3) {
            doc_dist   <- stats::dist(doc_mat, method = "euclidean")
            doc_coords <- stats::cmdscale(doc_dist, k = 2)

            doc_map_df <- tibble::tibble(
              paper_id = rownames(doc_coords),
              x = doc_coords[, 1],
              y = doc_coords[, 2]
            ) |>
              dplyr::left_join(
                data_a_export |> dplyr::select(paper_id, topic_flag, year),
                by = "paper_id"
              )

            readr::write_csv(doc_map_df, file.path(table_dir, "doc_map.csv"))

            doc_map_plot <- ggplot2::ggplot(
              doc_map_df,
              ggplot2::aes(x = x, y = y, color = topic_flag)
            ) +
              ggplot2::geom_point(shape = 1, size = 2.5, stroke = 0.8, alpha = 0.8) +
              ggrepel::geom_text_repel(
                ggplot2::aes(label = paper_id),
                size = 2.3, max.overlaps = 45, segment.color = "grey70"
              ) +
              ggplot2::scale_color_manual(
                values = c("Likely related" = "#1F3864", "Manual review" = "#d6604d"),
                na.value = "grey60"
              ) +
              ggplot2::labs(
                title    = "Document Map — 2D MDS of TF-IDF",
                subtitle = paste("Terms with frequency \u2265", min_freq),
                x = "Dimension 1", y = "Dimension 2", color = "Topic flag"
              ) +
              ggplot2::theme_minimal(base_size = 12) +
              ggplot2::theme(legend.position = "bottom")

            ggplot2::ggsave(file.path(fig_dir, "doc_map.png"),
                            plot = doc_map_plot, width = 14, height = 11,
                            dpi = 300, bg = "white")
          }
        }
        log_msg("Document map done. (", nrow(doc_map_df), " documents plotted)")

        # ---- Term map -------------------------------------------------------
        incProgress(0.07, detail = "Term map\u2026")

        tcp_map <- term_cor_full |>
          dplyr::filter(item1 %in% top_words, item2 %in% top_words) |>
          dplyr::group_by(item1, item2) |>
          dplyr::summarise(correlation = mean(correlation, na.rm = TRUE), .groups = "drop")

        tcm <- matrix(0, nrow = length(top_words), ncol = length(top_words),
                      dimnames = list(top_words, top_words))
        ri    <- match(tcp_map$item1, top_words)
        ci    <- match(tcp_map$item2, top_words)
        valid <- !is.na(ri) & !is.na(ci)
        tcm[cbind(ri[valid], ci[valid])] <- tcp_map$correlation[valid]
        tcm[cbind(ci[valid], ri[valid])] <- tcp_map$correlation[valid]
        diag(tcm) <- 1

        term_map_df   <- NULL
        term_map_plot <- NULL

        term_coords <- stats::cmdscale(as.dist(1 - tcm), k = 2)
        term_map_df <- tibble::tibble(
          term = rownames(term_coords),
          Dim1 = term_coords[, 1],
          Dim2 = term_coords[, 2]
        )
        readr::write_csv(term_map_df, file.path(table_dir, "term_map.csv"))

        term_map_plot <- ggplot2::ggplot(
          term_map_df,
          ggplot2::aes(x = Dim1, y = Dim2, label = term)
        ) +
          ggplot2::geom_point(color = "#1F3864", size = 3.5) +
          ggrepel::geom_text_repel(
            fontface = "bold", size = 3.5, color = "#1F3864",
            segment.color = "grey70", max.overlaps = 50
          ) +
          ggplot2::labs(
            title = paste("Term Map —", n_top, "top terms"),
            x = "Dimension 1", y = "Dimension 2"
          ) +
          ggplot2::theme_minimal(base_size = 12)

        ggplot2::ggsave(file.path(fig_dir, "term_map.png"),
                        plot = term_map_plot, width = 13, height = 10,
                        dpi = 300, bg = "white")
        log_msg("Term map done.")

        # ---- Descriptive summaries ------------------------------------------
        incProgress(0.05, detail = "Descriptive summaries\u2026")

        year_summary <- data_a_export |>
          dplyr::filter(!is.na(year), stringr::str_squish(as.character(year)) != "") |>
          dplyr::mutate(year = suppressWarnings(as.integer(year))) |>
          dplyr::filter(!is.na(year)) |>
          dplyr::count(year, sort = FALSE, name = "documents") |>
          dplyr::arrange(year)

        source_summary <- data_a_export |>
          dplyr::filter(!is.na(source_title),
                        stringr::str_squish(source_title) != "") |>
          dplyr::count(source_title, sort = TRUE, name = "documents") |>
          dplyr::slice_head(n = 20)

        openxlsx::write.xlsx(
          list(year_summary = year_summary, top_sources = source_summary),
          file.path(table_dir, "descriptive_summaries.xlsx"), overwrite = TRUE
        )

        # ---- Word cloud (saved to disk) -------------------------------------
        incProgress(0.04, detail = "Word cloud\u2026")
        set.seed(42)
        png(file.path(fig_dir, "wordcloud.png"),
            width = 2200, height = 1600, res = 220, bg = "white")
        wordcloud::wordcloud(
          words = top_n_terms$word, freq = top_n_terms$frequency,
          min.freq = min(top_n_terms$frequency), max.words = n_top,
          random.order = FALSE, rot.per = 0.10, scale = c(6, 1.5),
          colors = RColorBrewer::brewer.pal(8, "Dark2")
        )
        dev.off()

        # ---- Run info -------------------------------------------------------
        run_info <- tibble::tibble(
          item  = c("raw_rows", "data_a_rows", "data_b_rows",
                    "manual_review_rows", "top_n_terms", "unique_tokens",
                    "bibliometrix_available"),
          value = c(nrow(raw_combined), nrow(data_a_export), nrow(data_b_export),
                    nrow(manual_review), n_top, nrow(term_counts),
                    as.integer(bibliometrix_available))
        )
        readr::write_csv(run_info, file.path(log_dir, "run_info.csv"))

        log_msg("Run completed at ", format(Sys.time(), "%H:%M:%S"))
        writeLines(state$log_lines, file.path(log_dir, "run_log.txt"))

        # ---- Commit everything to state ONLY on full success ----------------
        state$data_a_export  <- data_a_export
        state$data_b         <- data_b_export
        state$manual_review  <- manual_review
        state$top20          <- top_n_terms
        state$top20_table    <- top_n_table
        state$term_cor_full  <- term_cor_full
        state$heatmap_plot   <- heatmap_plot
        state$bar_plot       <- bar_plot
        state$doc_map_df     <- doc_map_df
        state$doc_map_plot   <- doc_map_plot
        state$term_map_df    <- term_map_df
        state$term_map_plot  <- term_map_plot
        state$year_summary   <- year_summary
        state$source_summary <- source_summary
        state$run_info       <- run_info
        state$n_raw      <- nrow(raw_combined)
        state$n_dedup    <- nrow(data_a_export)
        state$n_abstract <- nrow(data_b_export)
        state$n_manual   <- nrow(manual_review)
        # Config snapshot for the Word report
        state$cfg_project_dir <- project_dir
        state$cfg_zip_file    <- basename(zip_path)
        state$cfg_n_top       <- n_top
        state$cfg_min_freq    <- min_freq
        state$cfg_run_time    <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
        state$cfg_keywords    <- paste(keywords, collapse = ", ")
        state$ready      <- TRUE

        incProgress(0.02, detail = "Done.")
        "ok"

      }, error = function(e) {
        msg <- conditionMessage(e)
        log_msg("ERROR: ", msg)
        showNotification(
          paste("Pipeline failed:", msg),
          type = "error", duration = NULL
        )
        "error"
      })

      if (!identical(ok, "ok"))
        log_msg("Pipeline did not complete. Check the error notification above.")
    })

    shinyjs::enable("run_pipeline")
  })

  # ---- Overview metrics -------------------------------------------------------
  fmt <- function(n) if (n > 0) format(n, big.mark = ",") else "\u2014"
  output$m_raw      <- renderText({ fmt(state$n_raw)      })
  output$m_dedup    <- renderText({ fmt(state$n_dedup)    })
  output$m_abstracts <- renderText({ fmt(state$n_abstract) })
  output$m_manual   <- renderText({ fmt(state$n_manual)   })

  # ---- Status / log -----------------------------------------------------------
  output$status       <- renderText({ state$status })
  output$run_log_text <- renderText({ paste(state$log_lines, collapse = "\n") })

  # ---- Data tables ------------------------------------------------------------
  output$data_a_table <- DT::renderDataTable({
    req(state$data_a_export)
    make_dt(state$data_a_export, page = 10L, filter = "top")
  })

  output$data_b_table <- DT::renderDataTable({
    req(state$data_b)
    make_dt(state$data_b, page = 10L)
  })

  output$manual_table <- DT::renderDataTable({
    req(state$manual_review)
    make_dt(state$manual_review, page = 10L, filter = "top")
  })

  # ---- Top terms tab ----------------------------------------------------------
  output$top_n_heading <- renderText({
    paste("Top", input$n_top_terms, "most frequent terms")
  })

  output$top20_table <- DT::renderDataTable({
    req(state$top20_table)
    DT::datatable(state$top20_table, options = list(pageLength = 25, dom = "t"))
  })

  output$top20_plot <- renderPlot({
    req(state$bar_plot)
    state$bar_plot
  })

  output$wordcloud_plot <- renderPlot({
    req(state$top20)
    set.seed(42)
    wordcloud::wordcloud(
      words = state$top20$word, freq = state$top20$frequency,
      min.freq = min(state$top20$frequency),
      max.words = input$n_top_terms,
      random.order = FALSE, rot.per = 0.10, scale = c(6, 1.5),
      colors = RColorBrewer::brewer.pal(8, "Dark2")
    )
  })

  # ---- Heatmap ----------------------------------------------------------------
  output$heatmap_plot <- renderPlot({ req(state$heatmap_plot); state$heatmap_plot })

  output$corr_table <- DT::renderDataTable({
    req(state$term_cor_full)
    DT::datatable(
      state$term_cor_full |>
        dplyr::filter(item1 != item2) |>
        dplyr::arrange(dplyr::desc(abs(correlation))) |>
        dplyr::mutate(correlation = round(correlation, 4)),
      options = list(pageLength = 10)
    )
  })

  # ---- Document map -----------------------------------------------------------
  output$doc_map_plot  <- renderPlot({ req(state$doc_map_plot);  state$doc_map_plot  })
  output$doc_map_table <- DT::renderDataTable({
    req(state$doc_map_df)
    DT::datatable(state$doc_map_df, options = list(pageLength = 10, scrollX = TRUE))
  })

  # ---- Term map ---------------------------------------------------------------
  output$term_map_plot  <- renderPlot({ req(state$term_map_plot); state$term_map_plot })
  output$term_map_table <- DT::renderDataTable({
    req(state$term_map_df)
    DT::datatable(state$term_map_df, options = list(pageLength = 25))
  })

  # ---- Descriptive summaries --------------------------------------------------
  output$year_plot <- renderPlot({
    req(state$year_summary)
    ggplot2::ggplot(state$year_summary,
      ggplot2::aes(x = year, y = documents)) +
      ggplot2::geom_col(fill = "#1F3864", width = 0.7) +
      ggplot2::geom_text(ggplot2::aes(label = documents),
                         vjust = -0.4, size = 3.2) +
      ggplot2::labs(title = "Publications per Year", x = NULL, y = "Documents") +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(panel.grid.major.x = ggplot2::element_blank())
  })

  output$source_plot <- renderPlot({
    req(state$source_summary)
    ggplot2::ggplot(state$source_summary,
      ggplot2::aes(x = reorder(source_title, documents), y = documents)) +
      ggplot2::geom_col(fill = "#1F3864") +
      ggplot2::geom_text(ggplot2::aes(label = documents), hjust = -0.15, size = 3.0) +
      ggplot2::coord_flip(clip = "off") +
      ggplot2::expand_limits(y = max(state$source_summary$documents) * 1.1) +
      ggplot2::labs(title = "Top 20 Sources", x = NULL, y = "Documents") +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())
  })

  output$year_table <- DT::renderDataTable({
    req(state$year_summary)
    DT::datatable(state$year_summary, options = list(pageLength = 20, dom = "t"))
  })

  output$source_table <- DT::renderDataTable({
    req(state$source_summary)
    DT::datatable(state$source_summary,
      options = list(pageLength = 20, scrollX = TRUE, dom = "t"))
  })

  output$run_info_table <- DT::renderDataTable({
    req(state$run_info)
    DT::datatable(state$run_info, options = list(pageLength = 15, dom = "t"))
  })

  # ---- Downloads --------------------------------------------------------------
  mk_xlsx <- function(get_data, fname) {
    downloadHandler(
      filename = function() fname,
      content  = function(file) {
        d <- get_data(); req(d)
        openxlsx::write.xlsx(d, file, asTable = TRUE, overwrite = TRUE)
      }
    )
  }
  mk_csv <- function(get_data, fname) {
    downloadHandler(
      filename = function() fname,
      content  = function(file) { d <- get_data(); req(d); readr::write_csv(d, file) }
    )
  }

  output$dl_report <- downloadHandler(
    filename = function() {
      paste0("BANA420_Report_", format(Sys.time(), "%Y%m%d_%H%M"), ".docx")
    },
    content = function(file) {
      req(state$ready)
      showNotification("Building Word report — please wait...",
                       id = "report_notif", duration = NULL, type = "message")
      on.exit(removeNotification("report_notif"), add = TRUE)

      # Snapshot of all state needed by the report
      s <- list(
        run_info       = state$run_info,
        data_a_export  = state$data_a_export,
        data_b         = state$data_b,
        top20          = state$top20,
        top20_table    = state$top20_table,
        bar_plot       = state$bar_plot,
        heatmap_plot   = state$heatmap_plot,
        term_cor_full  = state$term_cor_full,
        doc_map_plot   = state$doc_map_plot,
        doc_map_df     = state$doc_map_df,
        term_map_plot  = state$term_map_plot,
        term_map_df    = state$term_map_df,
        year_summary   = state$year_summary,
        source_summary = state$source_summary
      )
      cfg <- list(
        project_dir = state$cfg_project_dir,
        zip_file    = state$cfg_zip_file,
        n_top       = state$cfg_n_top,
        min_freq    = state$cfg_min_freq,
        run_time    = state$cfg_run_time,
        keywords    = state$cfg_keywords
      )
      generate_word_report(file, s, cfg)
    }
  )

  output$dl_data_a    <- mk_xlsx(function() state$data_a_export, "Data_A.xlsx")
  output$dl_data_b    <- mk_xlsx(function() state$data_b,        "Data_B.xlsx")
  output$dl_manual    <- mk_xlsx(function() state$manual_review, "Manual_review.xlsx")
  output$dl_top20_csv <- mk_csv(function() state$top20,          "top_terms.csv")
  output$dl_corr_csv  <- mk_csv(function() state$term_cor_full,  "term_correlations.csv")
  output$dl_doc_map   <- mk_csv(function() state$doc_map_df,     "doc_map.csv")
  output$dl_term_map  <- mk_csv(function() state$term_map_df,    "term_map.csv")
  output$dl_run_info  <- mk_csv(function() state$run_info,       "run_info.csv")
}

# ---- Run --------------------------------------------------------------------
shinyApp(ui = ui, server = server)
