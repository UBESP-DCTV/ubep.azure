bild_ps1_from_xlsx <- function(file = file.choose()) {

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

  ps1_create_bulk_users(
    "ubep.unipd.it", paste(server, ps_name, sep = "/")
  )
  usethis::ui_done("PS scripts created.")

  ps_file <- file.path(out_dir, paste0(ps_name, ".ps1"))

  ps1_create_bulk_group(ps_file, out_dir)
}
