# renv/activate.R — bootstrap stub for trading-systems-litreview
#
# This file is sourced automatically by .Rprofile when R starts inside
# the project. The proper, full-featured version is the one written by
# renv::init(); we ship a minimal bootstrap so that a fresh checkout can
# install renv and then run `renv::restore()`.
#
# Behaviour:
#   * If `renv` is installed, attach it and tell the user how to restore.
#   * Otherwise, in an *interactive* session, install it from CRAN.
#   * In a non-interactive session (Rscript, knit, RStudio addin), do NOT
#     auto-install — print a hint and continue. This avoids surprise
#     network calls during knit/source and avoids breaking when CRAN is
#     unreachable.
#
# Implementation note: .Rprofile runs *before* default packages are
# attached, so `install.packages` etc. are not on the search path yet.
# All functions from `utils` are called fully-qualified as `utils::fn()`.

local({
  ok_namespace <- requireNamespace("renv", quietly = TRUE)

  if (!ok_namespace) {
    if (interactive()) {
      message("[renv] renv is not installed.")
      message("[renv] To bootstrap, run in the R console:")
      message('[renv]     install.packages("renv", repos = "https://cloud.r-project.org")')
      message('[renv]     renv::restore()')

      # Offer to install on the spot, but only when we have a real prompt.
      ans <- tryCatch(
        readline("Install renv now from CRAN? [y/N]: "),
        error = function(e) ""
      )
      if (tolower(trimws(ans)) %in% c("y", "yes")) {
        tryCatch(
          utils::install.packages("renv", repos = "https://cloud.r-project.org"),
          error = function(e) message("[renv] install failed: ", conditionMessage(e))
        )
        ok_namespace <- requireNamespace("renv", quietly = TRUE)
      }
    } else {
      # Non-interactive: do not auto-install. The script we're running
      # (Knit, Rscript, …) will fall back to whatever packages are
      # already installed on the system.
      message("[renv] renv not installed; skipping activation in non-interactive mode.")
      message("[renv] To enable renv, run interactively:")
      message('[renv]     install.packages("renv"); renv::restore()')
    }
  }

  if (ok_namespace) {
    tryCatch(
      renv::activate(),
      error = function(e) {
        message("[renv] activate() failed: ", conditionMessage(e))
        message("[renv] Run renv::init() to set the project up.")
      }
    )

    if (interactive()) {
      lock <- file.path(getwd(), "renv.lock")
      if (file.exists(lock)) {
        message("[renv] Project lockfile detected.")
        message("[renv] To install the pinned packages, run:  renv::restore()")
      }
    }
  }
})
