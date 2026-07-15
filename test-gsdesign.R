.libPaths(c(
  Sys.getenv("GSDESIGN_LIB"),
  Sys.getenv("BISECTRUNK_ENV"),
  .libPaths()
))
Sys.setenv(NOT_CRAN = "true")

tests <- data.frame(
  file = c(
    "test-independent-test-plot.gsDesign.R",
    "test-independent-test-plot.gsProbability.R"
  ),
  desc = c(
    paste(
      "plot.gsDesign: plots are correctly rendered for",
      "plottype = power and base set to FALSE"
    ),
    paste(
      "plot.gsProbability: plots are correctly rendered for",
      "plottype power and base set to FALSE"
    )
  )
)

test_dir <- file.path(Sys.getenv("BISECTRUNK_OUT"), "testthat")
snapshot_dir <- file.path(test_dir, "_snaps")
dir.create(snapshot_dir, recursive = TRUE, showWarnings = FALSE)

source_dir <- file.path(Sys.getenv("BISECTRUNK_PROJECT"), "tests/testthat")
copied <- c(
  file.copy(
    file.path(source_dir, tests$file),
    test_dir,
    overwrite = TRUE
  ),
  vapply(
    sub("^test-(.*)[.]R$", "\\1", tests$file),
    function(context) {
      destination <- file.path(snapshot_dir, context)
      dir.create(destination, showWarnings = FALSE)
      file.copy(
        file.path(
          source_dir,
          "_snaps",
          context,
          "plottype-power-base-false.svg"
        ),
        destination,
        overwrite = TRUE
      )
    },
    logical(1)
  )
)

if (!all(copied)) {
  stop("Failed to stage the focused tests in BISECTRUNK_OUT.")
}

failed <- Map(
  function(file, desc) {
    tryCatch(
      {
        testthat::test_file(
          file.path(test_dir, file),
          desc = desc,
          package = "gsDesign",
          load_package = "installed",
          load_helpers = FALSE,
          stop_on_failure = TRUE
        )
        FALSE
      },
      error = function(cnd) {
        message(conditionMessage(cnd))
        TRUE
      }
    )
  },
  tests$file,
  tests$desc
)

quit(status = if (any(unlist(failed))) 1L else 0L)
