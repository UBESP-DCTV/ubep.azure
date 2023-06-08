clean_string <- function(string) {
  stringr::str_to_lower(string) |>
    stringr::str_squish() |>
    stringr::str_replace_all("\\s+", ".") |>
    stringr::str_replace_all("\\.+", ".") |>
    stringr::str_replace_all("[^\\w\\d\\.]", "") |>
    stringi::stri_trans_general("Latin-ASCII")
}


excel2csv <- function(file, out_dir) {
  out_name <- basename(file) |>
    stringr::str_replace("\\.xlsx?$", ".csv")
  out_path <- file.path(out_dir, out_name)
  server <- basename(out_dir) # nolint

  read_data(file) |>
    readr::write_csv(out_path, na = "")
  usethis::ui_done(
    "Excel file converted to CSV inside the {server} folder."
  )
  invisible(out_path)
}


read_data <- function(file, csv = FALSE) {
  db <- if (csv) {
    readr::read_csv(file, show_col_types = FALSE)
  } else {
    readxl::read_excel(file)
  }

  dplyr::filter(db, dplyr::if_any(dplyr::everything(), ~ !is.na(.)))
}
