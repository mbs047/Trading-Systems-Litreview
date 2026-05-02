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
  install.packages("testthat", repos = "https://cloud.r-project.org")
}

this_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
runner_dir <- if (!is.null(this_file) && nzchar(this_file)) {
  dirname(normalizePath(this_file, mustWork = FALSE))
} else {
  file.path(getwd(), "tests")
}

result <- testthat::test_dir(
  file.path(runner_dir, "testthat"),
  reporter = testthat::SummaryReporter$new()
)

# Exit with non-zero if any test failed (useful for CI).
df <- as.data.frame(result)
if (any(df$failed > 0) || any(df$error)) {
  if (!interactive()) quit(status = 1)
}
