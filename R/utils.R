generate_password <- function(length = 20L) {
  lower <- letters
  upper <- LETTERS
  digits <- as.character(0:9)
  # single quote deliberately excluded: passwords are embedded in a
  # single-quoted PowerShell string ('...') in the generated .ps1
  symbols <- strsplit("!@#$%^&*()-_=+[]{}", "")[[1]]

  guaranteed <- c(
    sample(lower, 1L),
    sample(upper, 1L),
    sample(digits, 1L),
    sample(symbols, 1L)
  )
  pool <- c(lower, upper, digits, symbols)
  rest <- sample(pool, length - length(guaranteed), replace = TRUE)

  paste(sample(c(guaranteed, rest)), collapse = "")
}


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
