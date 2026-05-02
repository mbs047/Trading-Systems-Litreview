# BANA 420 Project — Pure bibliometrix Analysis + biblioshiny GUI
#
# ============================================================================
# STATUS: experimental, NOT yet 100% ready.
# ============================================================================
# This is an ADDITIONAL entry point, not part of the required BANA 420
# deliverable. It runs a parallel analysis using only the `bibliometrix`
# package so we can compare its output against what `shiny_app.R` produces
# from the same Scopus inputs.
#
# Use the main Shiny dashboard (`src/shiny_app.R`) or the R Markdown
# notebook (`src/project_analysis.Rmd`) for the required deliverables.
#
# Known limitations:
#   - All parameters are hard-coded; there is no side-panel UI.
#   - Some plots fail silently on small corpora (thematic map,
#     conceptual structure).
#   - The biblioshiny auto-launch occasionally needs a manual
#     `biblioshiny()` call afterwards.
#   - Output filenames are not yet fully snake_case-aligned with
#     the rest of the repo.
# ============================================================================
#
# What it does:
#   1. Loads our Scopus exports through bibliometrix::convert2df().
#   2. Runs every standard biblioshiny analysis programmatically and saves
#      every table/figure under results/bibliometrix/.
#   3. Saves the cleaned data frame to results/bibliometrix/m_clean.rds.
#   4. Loads m_clean.rds and launches biblioshiny() (the GUI).
#
# Inputs we expect (Cookiecutter Data Science layout):
#   data/raw/search_results_renamed.zip   (required, our renamed Scopus exports)
#
# Outputs we produce (under results/bibliometrix/):
#   tables/            biblioAnalysis summary, sources, authors, countries,
#                      documents, keyword tables, lotka, bradford
#   figures/           every plot the package produces (PNG, 300 dpi)
#   network/           NetMatrix .rds objects for re-use
#   m_clean.rds        the cleaned bibliometric data frame
#   biblio_summary.txt the full text summary
#
# Run it (recommended — RStudio):
#   1. Open src/bibliometrix_app.R in RStudio.
#   2. Click 'Source' at the top-right of the editor pane
#      (or press Ctrl/Cmd + Shift + S).
#
# Alternative (R console):
#   source("src/bibliometrix_app.R")

# ---- Packages --------------------------------------------------------------

required_packages <- c("bibliometrix", "dplyr", "stringr", "ggplot2",
                       "wordcloud", "RColorBrewer", "igraph")

install_if_missing <- function(pkgs) {
  missing_pkgs <- pkgs[!pkgs %in% rownames(installed.packages())]
  if (length(missing_pkgs) > 0) {
    install.packages(missing_pkgs, dependencies = TRUE)
  }
}
install_if_missing(required_packages)
invisible(lapply(required_packages, library, character.only = TRUE))

# ---- Paths (Cookiecutter Data Science layout) -----------------------------

# This script lives under src/, so the project directory is its parent.
src_dir <- tryCatch(
  dirname(rstudioapi::getActiveDocumentContext()$path),
  error = function(e) getwd()
)
if (!nzchar(src_dir)) src_dir <- getwd()
setwd(src_dir)
project_dir <- normalizePath(file.path(src_dir, ".."))

raw_dir    <- file.path(project_dir, "data", "raw")
unzip_dir  <- file.path(raw_dir,     "search_results_unzipped")
output_dir <- file.path(project_dir, "results", "bibliometrix")
fig_dir    <- file.path(output_dir, "figures")
tab_dir    <- file.path(output_dir, "tables")
net_dir    <- file.path(output_dir, "network")

for (p in c(raw_dir, unzip_dir, output_dir, fig_dir, tab_dir, net_dir)) {
  dir.create(p, recursive = TRUE, showWarnings = FALSE)
}

zip_candidates <- list.files(raw_dir, pattern = "search_results.*\\.zip$",
                             full.names = TRUE, ignore.case = TRUE)
if (length(zip_candidates) == 0) {
  stop("Zip file not found in data/raw/. Place 'search_results_renamed.zip' there first.")
}
if (length(list.files(unzip_dir, recursive = TRUE)) == 0) {
  unzip(zip_candidates[1], exdir = unzip_dir)
}

csv_files <- list.files(unzip_dir, pattern = "\\.csv$",
                        full.names = TRUE, recursive = TRUE)
if (length(csv_files) == 0) stop("No CSV files found after unzipping.")

# ---- Helper: save plots ---------------------------------------------------

save_plot <- function(plt, file, w = 12, h = 8) {
  if (inherits(plt, "ggplot")) {
    ggplot2::ggsave(filename = file.path(fig_dir, file),
                    plot = plt, width = w, height = h, dpi = 300, bg = "white")
  } else {
    grDevices::png(file.path(fig_dir, file),
                   width = w * 100, height = h * 100, res = 100, bg = "white")
    print(plt)
    grDevices::dev.off()
  }
}

# ============================================================================
# 1. Load and clean
# ============================================================================
message("\n[1/9] Loading and cleaning Scopus files via convert2df() ...")

M_list <- lapply(csv_files, function(f) {
  tryCatch(
    bibliometrix::convert2df(file = f, dbsource = "scopus", format = "csv"),
    error = function(e) {
      message("convert2df failed for ", basename(f), ": ", e$message); NULL
    }
  )
})
M_list <- M_list[!vapply(M_list, is.null, logical(1))]
M <- dplyr::bind_rows(M_list)

if ("TI" %in% names(M)) {
  M <- M |>
    dplyr::mutate(.ti_key = stringr::str_to_lower(stringr::str_squish(TI))) |>
    dplyr::distinct(.ti_key, .keep_all = TRUE) |>
    dplyr::select(-.ti_key)
}
if (!"DB" %in% names(M))     M$DB     <- "SCOPUS"
if (!"AU_CO" %in% names(M))  M$AU_CO  <- "Unknown"
if (!"AU1_CO" %in% names(M)) M$AU1_CO <- "Unknown"

saveRDS(M, file.path(output_dir, "m_clean.rds"))
message("    Loaded ", nrow(M), " unique documents from ",
        length(M_list), " CSVs.")

# ============================================================================
# 2. biblioAnalysis() summary
# ============================================================================
message("\n[2/9] Running biblioAnalysis() ...")

results <- bibliometrix::biblioAnalysis(M, sep = ";")
# Note: bibliometrix attaches an S3 method to summary() for objects of class
# "bibliometrixResults", but it does not export `summary` itself — so we have
# to call the generic, not bibliometrix::summary().
S <- summary(object = results, k = 20, pause = FALSE, verbose = FALSE)
utils::capture.output(S, file = file.path(output_dir, "biblio_summary.txt"))

write.csv(as.data.frame(results$Sources),      file.path(tab_dir, "sources.csv"),      row.names = FALSE)
write.csv(as.data.frame(results$Authors),      file.path(tab_dir, "authors.csv"),      row.names = FALSE)
write.csv(as.data.frame(results$Affiliations), file.path(tab_dir, "affiliations.csv"), row.names = FALSE)
write.csv(as.data.frame(results$Countries),    file.path(tab_dir, "countries.csv"),    row.names = FALSE)

# Five canonical biblioAnalysis plots
plots <- plot(results, k = 10, pause = FALSE)
plot_names <- c("annual_production.png", "avg_citations_per_year.png",
                "most_relevant_sources.png", "most_relevant_authors.png",
                "most_productive_countries.png")
for (i in seq_along(plots)) {
  save_plot(plots[[i]], plot_names[i], w = 11, h = 7)
}

# ============================================================================
# 3. Sources analyses
# ============================================================================
message("\n[3/9] Running source-level analyses (Bradford, h-index) ...")

bradford <- bibliometrix::bradford(M)
save_plot(bradford$graph, "bradford_law.png", w = 11, h = 7)
write.csv(bradford$table, file.path(tab_dir, "bradford_table.csv"), row.names = FALSE)

H_sources <- bibliometrix::Hindex(M, field = "source", elements = NULL,
                                  sep = ";", years = Inf)
write.csv(H_sources$H, file.path(tab_dir, "sources_hindex.csv"), row.names = FALSE)

# ============================================================================
# 4. Authors analyses
# ============================================================================
message("\n[4/9] Running author-level analyses (h-index, Lotka, productivity) ...")

H_authors <- bibliometrix::Hindex(M, field = "author", elements = NULL,
                                  sep = ";", years = Inf)
write.csv(H_authors$H, file.path(tab_dir, "authors_hindex.csv"), row.names = FALSE)

L <- bibliometrix::lotka(results)
# bibliometrix's lotka() return shape varies by version: older releases put
# Beta/C/R2/p.value at the top level of a list, newer ones nest them under
# L$Results / L$Fitted, and some return them as a single-row data frame or
# matrix. We pull each field defensively so the script works regardless.
pull_lotka <- function(L, name) {
  # Safe accessor: only use $ on actual lists, never on atomic vectors/matrices.
  safe_pluck <- function(obj, key) {
    if (is.list(obj) && key %in% names(obj)) obj[[key]] else NULL
  }
  # Helper that searches a candidate object (list, data.frame, matrix, vector)
  # for `name` and returns the first numeric scalar it finds.
  search_obj <- function(obj) {
    if (is.null(obj)) return(NULL)
    nms <- names(obj)
    if (is.null(nms) && !is.null(dim(obj))) {
      nms <- if (!is.null(colnames(obj))) colnames(obj) else rownames(obj)
    }
    if (is.null(nms) || !(name %in% nms)) return(NULL)
    v <- tryCatch({
      if (is.data.frame(obj)) {
        obj[[name]]
      } else if (is.list(obj)) {
        obj[[name]]
      } else if (!is.null(dim(obj))) {
        if (!is.null(colnames(obj)) && name %in% colnames(obj)) {
          obj[, name]
        } else {
          obj[name, ]
        }
      } else {
        obj[name]
      }
    }, error = function(e) NULL)
    if (is.null(v)) return(NULL)
    v <- suppressWarnings(as.numeric(v))
    v <- v[!is.na(v)]
    if (length(v) == 0) NULL else v[1]
  }

  candidates <- list(
    L,
    safe_pluck(L, "Results"),
    safe_pluck(L, "Fitted"),
    safe_pluck(L, "fit")
  )
  for (cand in candidates) {
    val <- search_obj(cand)
    if (!is.null(val)) return(val)
  }
  NA_real_
}
beta_val <- pull_lotka(L, "Beta")
c_val    <- pull_lotka(L, "C")
r2_val   <- pull_lotka(L, "R2")
p_val    <- pull_lotka(L, "p.value")

writeLines(c(
  paste("Beta:",    if (is.na(beta_val)) "NA" else round(beta_val, 3)),
  paste("C:",       if (is.na(c_val))    "NA" else round(c_val, 3)),
  paste("R^2:",     if (is.na(r2_val))   "NA" else round(r2_val, 3)),
  paste("p-value:", if (is.na(p_val))    "NA" else signif(p_val, 3))
), file.path(tab_dir, "lotka_fit.txt"))

# AuthorProd may sit at L$AuthorProd in some versions or be absent entirely.
ap <- if (is.list(L) && "AuthorProd" %in% names(L)) L[["AuthorProd"]] else NULL
if (!is.null(ap)) {
  write.csv(ap, file.path(tab_dir, "lotka_author_prod.csv"), row.names = FALSE)
}

topAU <- bibliometrix::authorProdOverTime(M, k = 10, graph = FALSE)
save_plot(topAU$graph, "authors_production_over_time.png", w = 12, h = 7)
write.csv(topAU$dfAU, file.path(tab_dir, "authors_prod_over_time.csv"), row.names = FALSE)

# ============================================================================
# 5. Documents and citations
# ============================================================================
message("\n[5/9] Running document-level citation analyses ...")

cit_global <- bibliometrix::citations(M, field = "article", sep = ";")
write.csv(as.data.frame(cit_global$Cited),
          file.path(tab_dir, "most_cited_global.csv"), row.names = FALSE)

cit_local <- tryCatch(
  bibliometrix::localCitations(M, sep = ";"),
  error = function(e) NULL
)
if (!is.null(cit_local)) {
  write.csv(as.data.frame(cit_local$Papers),
            file.path(tab_dir, "most_cited_local.csv"), row.names = FALSE)
}

# ============================================================================
# 6. Keywords / words
# ============================================================================
message("\n[6/9] Running keyword and word-frequency analyses ...")

# Title words via termExtraction
M_terms <- bibliometrix::termExtraction(M, Field = "TI", remove.numbers = TRUE,
                                        verbose = FALSE)
ti_counts <- bibliometrix::tableTag(M_terms, Tag = "TI_TM", sep = ";")
write.csv(data.frame(word = names(ti_counts), frequency = as.integer(ti_counts)),
          file.path(tab_dir, "title_word_frequencies.csv"), row.names = FALSE)

# Word cloud (top 50 title words)
top50 <- utils::head(ti_counts, 50)
grDevices::png(file.path(fig_dir, "title_wordcloud.png"),
               width = 2200, height = 1600, res = 220, bg = "white")
wordcloud::wordcloud(words = names(top50), freq = as.integer(top50),
                     max.words = 50, random.order = FALSE,
                     colors = RColorBrewer::brewer.pal(8, "Dark2"))
grDevices::dev.off()

# Keyword growth (cumulative)
KG <- tryCatch(
  bibliometrix::KeywordGrowth(M, Tag = "ID", sep = ";", top = 10, cdf = TRUE),
  error = function(e) NULL
)
if (!is.null(KG)) {
  write.csv(KG, file.path(tab_dir, "keyword_growth.csv"), row.names = FALSE)
  grDevices::png(file.path(fig_dir, "keyword_growth.png"),
                 width = 2400, height = 1500, res = 220, bg = "white")
  matplot(KG[, -1], type = "l", lty = 1, lwd = 2,
          xlab = "Year index", ylab = "Cumulative occurrences",
          main = "Top keywords' cumulative growth")
  legend("topleft", legend = colnames(KG)[-1],
         col = seq_len(ncol(KG) - 1), lty = 1, lwd = 2, cex = 0.8)
  grDevices::dev.off()
}

# Trend topics
trend <- tryCatch(
  bibliometrix::fieldByYear(M, field = "ID", min.freq = 5, n.items = 5,
                            graph = FALSE),
  error = function(e) NULL
)
if (!is.null(trend)) {
  save_plot(trend$graph, "trend_topics.png", w = 12, h = 7)
  write.csv(trend$df, file.path(tab_dir, "trend_topics.csv"), row.names = FALSE)
}

# ============================================================================
# 7. Conceptual structure
# ============================================================================
message("\n[7/9] Building conceptual-structure networks ...")

# Keyword co-occurrence network
NM_cooc <- bibliometrix::biblioNetwork(M, analysis = "co-occurrences",
                                       network = "keywords", sep = ";")
saveRDS(NM_cooc, file.path(net_dir, "co_occurrence_keywords.rds"))
grDevices::png(file.path(fig_dir, "co_occurrence_keywords.png"),
               width = 2400, height = 1800, res = 220, bg = "white")
bibliometrix::networkPlot(NM_cooc, normalize = "association", n = 50,
                          type = "fruchterman", size.cex = TRUE, size = 15,
                          remove.multiple = FALSE, edgesize = 5,
                          labelsize = 0.7, label.cex = TRUE, label.n = 30)
grDevices::dev.off()

# Thematic map
th <- tryCatch(
  bibliometrix::thematicMap(M, field = "ID", n = 250, minfreq = 5,
                            stemming = FALSE, size = 0.5,
                            n.labels = 1, repel = TRUE),
  error = function(e) NULL
)
if (!is.null(th)) {
  save_plot(th$map, "thematic_map.png", w = 12, h = 9)
  write.csv(th$clusters, file.path(tab_dir, "thematic_clusters.csv"),
            row.names = FALSE)
}

# Conceptual structure (MCA)
CS <- tryCatch(
  bibliometrix::conceptualStructure(M, field = "ID", method = "MCA",
                                    minDegree = 5, clust = "auto",
                                    stemming = FALSE, labelsize = 10,
                                    documents = 10, graph = FALSE),
  error = function(e) NULL
)
if (!is.null(CS)) {
  save_plot(CS$graph_terms,    "conceptual_structure_terms.png",    w = 12, h = 9)
  save_plot(CS$graph_dendogram, "conceptual_structure_dendogram.png", w = 12, h = 7)
  save_plot(CS$graph_documents_Contrib,
            "conceptual_structure_docs_contrib.png", w = 12, h = 9)
}

# ============================================================================
# 8. Intellectual structure (co-citation, historiograph)
# ============================================================================
message("\n[8/9] Building intellectual-structure networks ...")

NM_cocit <- bibliometrix::biblioNetwork(M, analysis = "co-citation",
                                        network = "references", sep = ";")
saveRDS(NM_cocit, file.path(net_dir, "co_citation_references.rds"))
grDevices::png(file.path(fig_dir, "co_citation_references.png"),
               width = 2400, height = 1800, res = 220, bg = "white")
bibliometrix::networkPlot(NM_cocit, normalize = "association", n = 30,
                          type = "fruchterman", size.cex = TRUE, size = 20,
                          remove.multiple = FALSE, edgesize = 5,
                          labelsize = 0.7, label.n = 20)
grDevices::dev.off()

hist_net <- tryCatch(
  bibliometrix::histNetwork(M, sep = ";", network = TRUE, verbose = FALSE),
  error = function(e) NULL
)
if (!is.null(hist_net)) {
  grDevices::png(file.path(fig_dir, "historiograph.png"),
                 width = 2600, height = 1800, res = 220, bg = "white")
  hp <- bibliometrix::histPlot(hist_net, n = 15, size = 5, labelsize = 4,
                               verbose = FALSE)
  print(hp$g)
  grDevices::dev.off()
}

# ============================================================================
# 9. Social structure (collaboration networks)
# ============================================================================
message("\n[9/9] Building social-structure networks ...")

NM_collab_au <- bibliometrix::biblioNetwork(M, analysis = "collaboration",
                                            network = "authors", sep = ";")
saveRDS(NM_collab_au, file.path(net_dir, "collab_authors.rds"))
grDevices::png(file.path(fig_dir, "collab_authors.png"),
               width = 2400, height = 1800, res = 220, bg = "white")
bibliometrix::networkPlot(NM_collab_au, n = 30, type = "auto",
                          size.cex = TRUE, size = 20, remove.multiple = TRUE,
                          labelsize = 0.7, cluster = "louvain")
grDevices::dev.off()

M_co <- bibliometrix::metaTagExtraction(M, Field = "AU_CO", sep = ";")
NM_collab_co <- bibliometrix::biblioNetwork(M_co, analysis = "collaboration",
                                            network = "countries", sep = ";")
saveRDS(NM_collab_co, file.path(net_dir, "collab_countries.rds"))
grDevices::png(file.path(fig_dir, "collab_countries.png"),
               width = 2400, height = 1800, res = 220, bg = "white")
bibliometrix::networkPlot(NM_collab_co, n = 30, type = "circle",
                          size.cex = TRUE, size = 20, remove.multiple = TRUE,
                          labelsize = 0.8, cluster = "louvain")
grDevices::dev.off()

message("\nAll outputs written under: ", output_dir)

# ============================================================================
# 10. Launch the official biblioshiny GUI on this same M
# ============================================================================
# bibliometrix ships its own GUI called biblioshiny(). We launch it here so
# we can browse the exact same cleaned dataset (m_clean.rds) we just built.
#
# Inside biblioshiny we pick:
#   Load data -> RData (.rds) file -> results/bibliometrix/m_clean.rds -> Start.

library(bibliometrix)
M <- readRDS(file.path(output_dir, "m_clean.rds"))
message("\nLaunching biblioshiny GUI ...")
message("Inside the GUI, choose: Load data -> RData (.rds) -> ",
        file.path(output_dir, "m_clean.rds"), " -> Start")
biblioshiny()
