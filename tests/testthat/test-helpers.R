# tests/testthat/test-helpers.R
#
# Unit tests for the pure helpers in src/helpers.R.
#
# Run from the project root:
#   testthat::test_dir("tests/testthat")
# or, more robustly via the test runner script:
#   Rscript tests/run_tests.R

# Resolve project root robustly. testthat::test_dir() runs each file with
# its own working directory inside tests/testthat/; falling back to that
# location keeps the test runnable from anywhere.
this_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
test_dir  <- if (!is.null(this_file) && nzchar(this_file)) {
  dirname(normalizePath(this_file, mustWork = FALSE))
} else {
  getwd()
}
proj_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
helpers   <- file.path(proj_root, "src", "helpers.R")
source(helpers, local = TRUE)

library(testthat)


# ---------------------------------------------------------------------------
# normalize_title()
# ---------------------------------------------------------------------------

test_that("normalize_title lowercases", {
  expect_equal(normalize_title("Hello World"), "hello world")
})

test_that("normalize_title strips punctuation and squishes whitespace", {
  expect_equal(
    normalize_title("Trading: A User-Centred  Approach!"),
    "trading a user centred approach"
  )
})

test_that("normalize_title is idempotent", {
  once  <- normalize_title("Re-run  the   pipeline.")
  twice <- normalize_title(once)
  expect_equal(once, twice)
})

test_that("normalize_title is vectorised", {
  expect_equal(
    normalize_title(c("FOO bar.", "  baz  QUUX  ")),
    c("foo bar", "baz quux")
  )
})

test_that("normalize_title preserves digits", {
  expect_equal(normalize_title("R 4.4 release notes"), "r 4 4 release notes")
})

test_that("normalize_title returns NA for NA input", {
  # stringr passes NA through; we just confirm we don't accidentally coerce.
  expect_true(is.na(normalize_title(NA_character_)))
})


# ---------------------------------------------------------------------------
# clean_text_for_topic_flag()
# ---------------------------------------------------------------------------

test_that("clean_text_for_topic_flag converts NA to empty string", {
  expect_equal(clean_text_for_topic_flag(NA_character_), "")
})

test_that("clean_text_for_topic_flag keeps NA-safety while normalising", {
  expect_equal(
    clean_text_for_topic_flag(c("Hello!", NA, "  Trading-Platform  ")),
    c("hello", "", "trading platform")
  )
})

test_that("clean_text_for_topic_flag is idempotent", {
  once  <- clean_text_for_topic_flag("Some, mixed-CASE text!!")
  twice <- clean_text_for_topic_flag(once)
  expect_equal(once, twice)
})


# ---------------------------------------------------------------------------
# ensure_column()
# ---------------------------------------------------------------------------

test_that("ensure_column adds missing columns with the default value", {
  df <- data.frame(a = 1:3)
  out <- ensure_column(df, "b")
  expect_true("b" %in% names(out))
  expect_true(all(is.na(out$b)))
  expect_length(out$b, 3L)
})

test_that("ensure_column leaves existing columns untouched", {
  df <- data.frame(a = 1:3, b = letters[1:3])
  out <- ensure_column(df, "b", default = "x")
  expect_equal(out$b, letters[1:3])
})

test_that("ensure_column accepts a custom default", {
  df <- data.frame(a = 1:3)
  out <- ensure_column(df, "flag", default = FALSE)
  expect_equal(out$flag, c(FALSE, FALSE, FALSE))
})


# ---------------------------------------------------------------------------
# first_existing()
# ---------------------------------------------------------------------------

test_that("first_existing copies the first matching candidate", {
  df  <- data.frame(authors = c("Alice", "Bob"),
                    au      = c("A", "B"))
  out <- first_existing(df, c("author_names", "authors", "au"), "authors_canon")
  expect_equal(out$authors_canon, c("Alice", "Bob"))
})

test_that("first_existing falls back to default when no candidate exists", {
  df  <- data.frame(x = 1:3)
  out <- first_existing(df, c("nope", "still_no"), "year",
                        default = NA_integer_)
  expect_true("year" %in% names(out))
  expect_true(all(is.na(out$year)))
})

test_that("first_existing leaves new_name alone when present and no candidate matches", {
  df  <- data.frame(year = c(2024L, 2025L))
  out <- first_existing(df, c("py"), "year", default = 0L)
  expect_equal(out$year, c(2024L, 2025L))
})

test_that("first_existing prefers the earliest candidate in the list", {
  df  <- data.frame(authors = c("first"),
                    au      = c("second"))
  out <- first_existing(df, c("authors", "au"), "name")
  expect_equal(out$name, "first")
})
