#' Build the distributable REDCap module archive
#'
#' Packs `inst/redcap-module/` into the archive REDCap expects, naming the top
#' level directory `ubep_provisioning_v<version>`. REDCap derives both the
#' module prefix and its version from that directory name, so the name is part
#' of the contract rather than a convention.
#'
#' The module and its R client share a single version number, the one in
#' `DESCRIPTION`: the endpoint contract has two ends, and keeping them in one
#' repository with one version is what stops their compatibility from becoming
#' a matrix to remember. The `VERSION` file is rewritten from `DESCRIPTION`
#' while staging rather than copied, so the two cannot drift unnoticed.
#'
#' The `tests/` directory is left out. It is the module's own test suite, run
#' in CI and never needed on a server.
#'
#' @param out_dir Directory the archive is written to.
#'
#' @return The path of the archive, invisibly.
#'
#' @export
build_redcap_module <- function(out_dir = ".") {
  stopifnot(dir.exists(out_dir))

  version <- as.character(utils::packageVersion("ubep.azure"))
  source_dir <- system.file("redcap-module", package = "ubep.azure")
  if (source_dir == "") {
    stop("redcap-module not found in the installed package")
  }

  module_dir <- paste0("ubep_provisioning_v", version)
  staging <- file.path(tempfile("ubep-module-"), module_dir)
  dir.create(staging, recursive = TRUE)
  on.exit(unlink(dirname(staging), recursive = TRUE), add = TRUE)

  to_copy <- setdiff(list.files(source_dir), "tests")
  file.copy(file.path(source_dir, to_copy), staging, recursive = TRUE)
  readr::write_file(version, file.path(staging, "VERSION"))

  zip_path <- normalizePath(
    file.path(out_dir, paste0(module_dir, ".zip")),
    mustWork = FALSE
  )
  withr::with_dir(
    dirname(staging),
    utils::zip(zip_path, module_dir, flags = "-rq")
  )

  invisible(zip_path)
}
