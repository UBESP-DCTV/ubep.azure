#' Build ps1 files
#'
#' From a correctly formatted file, `ps1` files for create the user and
#' to assign them to a group in bulk operation o AAD directly.
#'
#' @details
#' The Excel file must have 9 column, named exactly (case sensitive) as:
#' `Nome, Cognome, Email, Prj1_ID, Prj1_role, Prj1_DAG, Prj1_ID,
#'  Prj1_role, Prj1_DAG`.
#'
#' Moreover:
#'   - no more than 2 projects can be added at the creation time using
#'     this script.
#'   - At least information (all the three!) for one project must be
#'     provided for EDCxx servers
#'   - For students on MSTxx servers no information should be provided
#'     about projects (i.e. the first three column should contain data
#'     only!)
#'   - For template including a projects all the role and DAG for each
#'     of them must be provided!
#'
#' @param file (chr, default interactive selection windows) file path to
#'   the Excel file reporting the users to create (see details).
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   build_ps1_from_xlsx()
#' }
#'
build_ps1_from_xlsx <- function(file = file.choose()) {

  ps_name <- stringr::str_remove(basename(file), "\\.[^\\.]+$")

  out_dir <- dirname(file)
  server <- basename(out_dir)
  if (server == "toImport") {
    out_dir <- dirname(out_dir)
    usethis::ui_done(
      "{usethis::ui_field('out_dir')} moved to {usethis::ui_value(out_dir)}."
    )
    server <- basename(out_dir)
    usethis::ui_info("REDCap server is set to {usethis::ui_value(server)}")
  }

  stopifnot(
    `file must start with "<yyyymmdd>_importUtenti"` =
      stringr::str_detect(file, "importUtenti"),

    `file must be an excel or csv file` =
      stringr::str_detect(file, "\\.(csv|xlsx?)$"),

    `file must be located inside "mst01", "edc01", or "edc" folder` =
      server %in% c("mst01", "edc01", "edc")
  )

  if (stringr::str_detect(file, "\\.xlsx?$")) excel2csv(file, out_dir)

  ps1_create_bulk_users(ps_name, out_dir)

  usethis::ui_done("PS scripts created.")

  ps_file <- file.path(out_dir, paste0(ps_name, ".ps1"))

  ps1_create_bulk_group(ps_file, out_dir)
}
