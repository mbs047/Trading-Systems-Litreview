# BANA 420 Project — VOSviewer Data Preparation
#
# We use this script to prepare our Scopus search exports for five
# VOSviewer analyses. We do NOT run VOSviewer from R — we let VOSviewer
# read the Scopus-CSV files we produce here.
#
# We produce five VOSviewer-ready Scopus CSVs under output/vosviewer/,
# one per analysis, plus a short README-style guide on how to load each
# one in the VOSviewer GUI and which clustering settings we used.
#
# Inputs we expect:
#   data/search results - renamed.zip   (required)
#
# Outputs we produce:
#   output/vosviewer/01_co_occurrence_author_keywords.csv
#   output/vosviewer/02_co_occurrence_all_keywords.csv
#   output/vosviewer/03_co_occurrence_title_abstract.csv
#   output/vosviewer/04_co_authorship_authors.csv
#   output/vosviewer/05_co_citation_references.csv
#   output/vosviewer/VOSviewer_how_to_load.txt

# ---- Packages ---------------------------------------------------------------

required_packages <- c(
  "dplyr", "readr", "stringr", "tidyr", "purrr", "tibble", "janitor"
)

install_if_missing <- function(pkgs) {
  missing_pkgs <- pkgs[!pkgs %in% rownames(installed.packages())]
  if (length(missing_pkgs) > 0) {
    install.packages(missing_pkgs, dependencies = TRUE)
  }
}
install_if_missing(required_packages)
invisible(lapply(required_packages, library, character.only = TRUE))

# ---- Paths ------------------------------------------------------------------

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
project_dir <- getwd()
input_dir   <- file.path(project_dir, "data")
unzip_dir   <- file.path(input_dir, "search_results_unzipped")
output_dir  <- file.path(project_dir, "output")
vos_dir     <- file.path(output_dir, "vosviewer")

dir.create(unzip_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(vos_dir,   recursive = TRUE, showWarnings = FALSE)

zip_candidates <- list.files(
  input_dir,
  pattern = "search results.*\\.zip$",
  full.names = TRUE,
  ignore.case = TRUE
)
if (length(zip_candidates) == 0) {
  stop("Zip file not found in data/. Place 'search results - renamed.zip' there first.")
}
zip_path <- zip_candidates[1]

# ---- Read every per-search CSV and combine ---------------------------------

if (length(list.files(unzip_dir, recursive = TRUE)) == 0) {
  unzip(zip_path, exdir = unzip_dir)
}

csv_files <- list.files(unzip_dir, pattern = "\\.csv$",
                        full.names = TRUE, recursive = TRUE)
if (length(csv_files) == 0) {
  stop("No CSV files found after unzipping.")
}

raw_list <- lapply(seq_along(csv_files), function(i) {
  f <- csv_files[i]
  df <- readr::read_csv(f, col_types = readr::cols(.default = "c"),
                        show_col_types = FALSE)
  df$search_no   <- i
  df$search_file <- basename(f)
  df
})
raw_combined <- dplyr::bind_rows(raw_list)
message("Loaded ", length(csv_files), " CSV files | ",
        nrow(raw_combined), " combined rows.")

# ---- De-duplicate on title and produce a clean Scopus-style table ----------

normalize_title <- function(x) {
  x |> stringr::str_to_lower() |>
    stringr::str_replace_all("[^a-z0-9 ]", " ") |>
    stringr::str_squish()
}

scopus <- raw_combined |>
  dplyr::filter(!is.na(Title), stringr::str_squish(Title) != "") |>
  dplyr::mutate(title_key = normalize_title(Title)) |>
  dplyr::distinct(title_key, .keep_all = TRUE) |>
  dplyr::select(-title_key)

message("After title de-duplication: ", nrow(scopus), " unique papers.")

# We make sure the standard Scopus column names VOSviewer looks for exist.
# VOSviewer's Scopus reader expects, at minimum:
#   Authors, Title, Year, Source title, Abstract, Author Keywords,
#   Index Keywords, References, Affiliations, EID, DOI, Cited by,
#   Document Type, Source.
ensure_col <- function(df, col_name, default = NA_character_) {
  if (!col_name %in% names(df)) df[[col_name]] <- default
  df
}

required_cols <- c(
  "Authors", "Author full names", "Author(s) ID", "Title", "Year",
  "Source title", "Volume", "Issue", "Art. No.", "Page start", "Page end",
  "Cited by", "DOI", "Link", "Affiliations", "Authors with affiliations",
  "Abstract", "Author Keywords", "Index Keywords", "References",
  "Document Type", "Publication Stage", "Open Access", "Source", "EID"
)
for (col in required_cols) scopus <- ensure_col(scopus, col)

# ---- Helper: write a Scopus-style CSV that VOSviewer can read --------------

write_vos_csv <- function(df, path) {
  # We export only the columns VOSviewer's Scopus reader uses, in the order
  # it expects, to avoid any column-mapping surprises.
  df_out <- df |>
    dplyr::select(dplyr::all_of(required_cols))
  readr::write_csv(df_out, path, na = "")
}

# ===========================================================================
# Analysis 1 — Co-occurrence of author keywords
# ---------------------------------------------------------------------------
# We keep every paper that has at least one author keyword and we drop the
# rest, since VOSviewer can only build the network from records that carry
# the keyword field.
# ===========================================================================

scopus_kw_author <- scopus |>
  dplyr::filter(!is.na(`Author Keywords`),
                stringr::str_squish(`Author Keywords`) != "")

write_vos_csv(
  scopus_kw_author,
  file.path(vos_dir, "01_co_occurrence_author_keywords.csv")
)
message("Analysis 1 — author-keyword co-occurrence: ",
        nrow(scopus_kw_author), " papers exported.")

# ===========================================================================
# Analysis 2 — Co-occurrence of all keywords (author + index keywords)
# ---------------------------------------------------------------------------
# We keep papers that have either an Author Keywords field or an Index
# Keywords field. In VOSviewer we then choose "All keywords" so it merges
# both fields into a single co-occurrence map.
# ===========================================================================

scopus_kw_all <- scopus |>
  dplyr::filter(
    (!is.na(`Author Keywords`) & stringr::str_squish(`Author Keywords`) != "") |
    (!is.na(`Index Keywords`)  & stringr::str_squish(`Index Keywords`)  != "")
  )

write_vos_csv(
  scopus_kw_all,
  file.path(vos_dir, "02_co_occurrence_all_keywords.csv")
)
message("Analysis 2 — all-keyword co-occurrence: ",
        nrow(scopus_kw_all), " papers exported.")

# ===========================================================================
# Analysis 3 — Co-occurrence of title-and-abstract terms
# ---------------------------------------------------------------------------
# We keep every paper that has a non-empty Title and a non-empty Abstract.
# In VOSviewer we then run the "text data" workflow and let its built-in
# linguistic filter pick the noun phrases.
# ===========================================================================

scopus_text <- scopus |>
  dplyr::filter(!is.na(Title), stringr::str_squish(Title) != "",
                !is.na(Abstract), stringr::str_squish(Abstract) != "")

write_vos_csv(
  scopus_text,
  file.path(vos_dir, "03_co_occurrence_title_abstract.csv")
)
message("Analysis 3 — title+abstract co-occurrence: ",
        nrow(scopus_text), " papers exported.")

# ===========================================================================
# Analysis 4 — Co-authorship (authors)
# ---------------------------------------------------------------------------
# We keep every paper that has at least one author. VOSviewer uses the
# Authors field to build the co-authorship network.
# ===========================================================================

scopus_authors <- scopus |>
  dplyr::filter(!is.na(Authors), stringr::str_squish(Authors) != "")

write_vos_csv(
  scopus_authors,
  file.path(vos_dir, "04_co_authorship_authors.csv")
)
message("Analysis 4 — co-authorship of authors: ",
        nrow(scopus_authors), " papers exported.")

# ===========================================================================
# Analysis 5 — Co-citation of cited references
# ---------------------------------------------------------------------------
# We keep every paper that has a non-empty References field. Co-citation
# only works on records that ship the reference list.
# ===========================================================================

scopus_refs <- scopus |>
  dplyr::filter(!is.na(References), stringr::str_squish(References) != "")

write_vos_csv(
  scopus_refs,
  file.path(vos_dir, "05_co_citation_references.csv")
)
message("Analysis 5 — co-citation of references: ",
        nrow(scopus_refs), " papers exported.")