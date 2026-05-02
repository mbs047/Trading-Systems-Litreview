# tests/run_tests.R
#
# Run all unit tests under tests/testthat/.
#
# Usage:
#   * From RStudio: open this file and click 'Source' (the recommended path).
#   * From the project root in a terminal:  Rscript tests/run_tests.R
#   * From inside an R session:             source("tests/run_tests.R")
#
# This script does not depend on the current working directory — it
# locates tests/testthat/ via several fallback strategies.

if (!requireNamespace("testthat", quietly = TRUE)) {
  utils::install.packages("testthat", repos = "https://cloud.r-project.org")
}

# ---------------------------------------------------------------------------
# Locate this script's directory, regardless of how R was launched.
# ---------------------------------------------------------------------------
script_dir <- function() {
  # 1) Rscript / Rterm: --file=...
  args <- commandArgs(trailingOnly = FALSE)
  hit  <- grep("^--file=", args, value = TRUE)
  if (length(hit) > 0) {
    p <- sub("^--file=", "", hit[1])
    if (nzchar(p) && file.exists(p)) return(dirname(normalizePath(p)))
  }
  # 2) Sourced from R / RStudio: sys.frame()$ofile is set by source().
  for (i in seq_len(sys.nframe())) {
    of <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(of) && nzchar(of)) {
      return(dirname(normalizePath(of, mustWork = FALSE)))
    }
  }
  # 3) RStudio API: the active document path.
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
      tryCatch(rstudioapi::isAvailable(), error = function(e) FALSE)) {
    p <- tryCatch(rstudioapi::getActiveDocumentContext()$path,
                  error = function(e) "")
    if (nzchar(p) && file.exists(p)) return(dirname(normalizePath(p)))
  }
  NA_character_
}

# ---------------------------------------------------------------------------
# Locate tests/testthat/ — try script-relative first, then cwd-relative.
# ---------------------------------------------------------------------------
locate_testthat_dir <- function() {
  sd <- script_dir()
  candidates <- c(
    if (!is.na(sd)) file.path(sd, "testthat"),
    "tests/testthat",
    "testthat",
    file.path(getwd(), "tests", "testthat"),
    file.path(getwd(), "testthat")
  )
  for (p in candidates) {
    if (!is.null(p) && !is.na(p) && dir.exists(p)) {
      return(normalizePath(p))
    }
  }
  stop(
    "Could not locate tests/testthat/. Tried:\n  ",
    paste(candidates, collapse = "\n  "),
    "\n\nFix: either set the working directory to the project root\n",
    "(setwd('/path/to/trading-systems-litreview')) and re-run, or open\n",
    "this script in RStudio and click Source."
  )
}

testthat_dir <- locate_testthat_dir()
message("[run_tests] Using testthat dir: ", testthat_dir)

result <- testthat::test_dir(
  testthat_dir,
  reporter = testthat::SummaryReporter$new()
)

# Exit with non-zero if any test failed (useful for CI).
df <- as.data.frame(result)
if (any(df$failed > 0) || any(df$error)) {
  if (!interactive()) quit(status = 1)
}
