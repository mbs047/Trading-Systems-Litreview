# src/helpers.R
#
# Shared helper functions for trading-systems-litreview.
#
# These are sourced by:
#   * src/project_analysis.Rmd  (the main R Markdown notebook)
#   * src/shiny_app.R           (the Shiny dashboard, indirectly)
#   * tests/testthat/test-helpers.R   (the test suite)
#
# Keep this file dependency-light: stringr and tidyr only. No pipeline
# state, no global side-effects.

#' Normalise a title for de-duplication.
#'
#' Lower-cases, strips everything that is not ASCII alphanumeric or a
#' space, and squishes whitespace. Used as the dedup key in Data A.
#'
#' @param x character vector of titles.
#' @return character vector of the same length, normalised.
normalize_title <- function(x) {
  x |>
    stringr::str_to_lower() |>
    stringr::str_replace_all("[^a-z0-9 ]", " ") |>
    stringr::str_squish()
}

#' Clean a text field before keyword matching for topic_flag.
#'
#' Differs from `normalize_title()` only in that it converts NA to ""
#' first, so the result is safe to feed into `str_detect()`.
#'
#' @param x character vector (may include NA).
#' @return character vector of the same length, NA-free.
clean_text_for_topic_flag <- function(x) {
  x |>
    tidyr::replace_na("") |>
    stringr::str_to_lower() |>
    stringr::str_replace_all("[^a-z0-9 ]", " ") |>
    stringr::str_squish()
}

#' Ensure a column exists in a data frame.
#'
#' If `col_name` is missing, adds it filled with `default`. If present,
#' returns the data frame unchanged. Used to guarantee a stable schema
#' before joins / writes.
#'
#' @param df data frame.
#' @param col_name name of the column that must exist.
#' @param default fill value if the column has to be created.
#' @return data frame with `col_name` guaranteed present.
ensure_column <- function(df, col_name, default = NA_character_) {
  if (!col_name %in% names(df)) {
    df[[col_name]] <- default
  }
  df
}

#' Coalesce alias columns into a canonical column.
#'
#' Different Scopus exports return the same field under different names
#' (e.g. `authors` vs `author_full_names`). This helper writes the value
#' of the first matching `candidate` into `new_name`. If none of the
#' candidates exist and `new_name` doesn't exist either, it is created
#' with `default`.
#'
#' @param df data frame.
#' @param candidates character vector of column names to look for, in
#'   priority order.
#' @param new_name canonical name to write to.
#' @param default fill value when no candidate is found.
#' @return data frame with `new_name` guaranteed present.
first_existing <- function(df, candidates, new_name,
                           default = NA_character_) {
  existing <- candidates[candidates %in% names(df)]
  if (length(existing) > 0) {
    df[[new_name]] <- df[[existing[1]]]
  } else if (!new_name %in% names(df)) {
    df[[new_name]] <- default
  }
  df
}
