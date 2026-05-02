# renv/activate.R — bootstrap stub for trading-systems-litreview
#
# This file is sourced automatically by .Rprofile when R starts inside
# the project. The proper, full-featured version of this file is the
# one written by renv::init(); we ship a minimal bootstrap so that a
# fresh checkout can run `renv::restore()` (or just install renv) and
# then re-init.
#
# Behaviour:
#   * If `renv` is installed, attach it and tell the user how to restore.
#   * If not, install it from CRAN and then attach it.

local({
  if (!requireNamespace("renv", quietly = TRUE)) {
    message("[renv] Bootstrapping renv from CRAN ...")
    install.packages("renv", repos = "https://cloud.r-project.org")
  }

  if (requireNamespace("renv", quietly = TRUE)) {
    # Activate this project under renv. After the first activate() call,
    # renv::init() (run interactively once) will replace this stub with
    # its own canonical activate.R.
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
  } else {
    warning("renv could not be installed; falling back to system libraries.")
  }
})
