# tests/run_tests.R
#
# Run all unit tests under tests/testthat/.
#
# Usage from the project root:
#   Rscript tests/run_tests.R
#
# Or from inside R / RStudio:
#   source("tests/run_tests.R")

if (!requireNamespace("testthat", quietly = TRUE)) {
  utils::install.packages("testthat", repos = "https://cloud.r-project.org")
}

# Locate the testthat directory by probing common cwd anchors. This works
# whether the script is invoked from the project root, from tests/, or
# sourced interactively.
locate_testthat_dir <- function() {
  candidates <- c(
    "tests/testthat",
    "testthat",
    file.path(getwd(), "tests", "testthat")
  )
  for (p in candidates) {
    if (dir.exists(p)) return(normalizePath(p))
  }
  stop("Could not locate tests/testthat/. Run from the project root or from tests/.")
}

result <- testthat::test_dir(
  locate_testthat_dir(),
  reporter = testthat::SummaryReporter$new()
)

# Exit with non-zero if any test failed (useful for CI).
df <- as.data.frame(result)
if (any(df$failed > 0) || any(df$error)) {
  if (!interactive()) quit(status = 1)
}
