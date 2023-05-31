get_usrs_principalname <- function(path2ps, out_file = NULL) {
  res <- readr::read_lines(path2ps) |>
    stringr::str_subset("UserPrincipalName") |>
    stringr::str_extract("(?<=UserPrincipalName \")[^\\s\"]+")

  if (!is.null(out_file)) {
    res_ps <- c(
      "version:v1.0",
      "Member object ID or user principal name [memberObjectIdOrUpn] Required",
      res
    )

    readr::write_lines(res_ps, out_file)
  }

  invisible(res)
}
