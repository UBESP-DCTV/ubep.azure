#' Read the request register's data dictionary
#'
#' The dictionary is the schema, and it lives as a file rather than as R code
#' because REDCap imports it as it is: one artefact, two consumers.
#'
#' @return A data frame with REDCap's eighteen data-dictionary columns.
#'
#' @keywords internal
register_dictionary <- function() {
  path <- system.file(
    "extdata", "request-register-dictionary.csv",
    package = "ubep.azure"
  )
  readr::read_csv(path, show_col_types = FALSE)
}


#' Split a REDCap choice string into codes and labels
#'
#' Choices travel as `"code, label | code, label"`, and only the **first** comma
#' separates the two: a label may carry commas of its own.
#'
#' @param text One cell of the dictionary's choices column.
#'
#' @return A data frame with `code` and `label`.
#'
#' @keywords internal
dictionary_choices <- function(text) {
  items <- trimws(strsplit(as.character(text), "|", fixed = TRUE)[[1]])
  items <- items[nzchar(items)]

  data.frame(
    code = trimws(sub("^([^,]*),.*$", "\\1", items)),
    label = trimws(sub("^[^,]*,\\s*", "", items)),
    stringsAsFactors = FALSE
  )
}


#' The register fields only the job writes
#'
#' Marked `@READONLY` in the dictionary, which governs the form and not the
#' API: the job keeps writing them while a requester cannot. Without the tag a
#' requester could type `applied` into the outcome, and the register would carry
#' a success nobody produced.
#'
#' @return A character vector of field names.
#'
#' @keywords internal
register_readonly_fields <- function() {
  c(
    "identity", "requested_by", "outcome", "outcome_detail",
    "outcome_at", "applied_as"
  )
}
