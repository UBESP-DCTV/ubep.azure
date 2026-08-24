#' Say an outcome in both languages
#'
#' The vocabulary of outcomes is closed and counts five words. This function
#' names all five, and a test walks `outcome_vocabulary()` to say so: adding a
#' sixth outcome without a translation stops the suite instead of shipping a
#' message with an English gap in the middle of an Italian sentence.
#'
#' @param outcome One word of `outcome_vocabulary()`.
#'
#' @return A character vector named `it` and `en`.
#'
#' @keywords internal
mail_outcome_words <- function(outcome) {
  stopifnot(is.character(outcome), length(outcome) == 1L, !is.na(outcome))

  said <- list(
    pending         = c(it = "in lavorazione",      en = "in progress"),
    applied         = c(it = "eseguita",            en = "applied"),
    simulated       = c(it = "simulata",            en = "simulated"),
    data_error      = c(it = "errore di dato",      en = "data error"),
    transport_error = c(it = "errore di trasporto", en = "transport error")
  )

  if (!outcome %in% names(said)) {
    stop(
      "mail_outcome_words(): esito fuori vocabolario: ", outcome,
      call. = FALSE
    )
  }

  said[[outcome]]
}


#' Turn the register's UTC stamp into the hour a person in Rome reads
#'
#' The register keeps UTC, which is the machine's truth and the one value the
#' comparison in `round_changed()` ignores by design. A person reading a mail
#' does not hold that convention, and the collaudo measured the cost: two hours
#' counted three times as latency before somebody read the code.
#'
#' The conversion belongs here, in the text a person reads, and not in the
#' field the code compares.
#'
#' @param at The register's `outcome_at`, `"%Y-%m-%d %H:%M"` in UTC.
#'
#' @return The same moment in Italian civil time, or `NA_character_` if `at`
#'   does not parse -- a wrong hour is worse than a missing one.
#'
#' @keywords internal
mail_local_time <- function(at) {
  stopifnot(is.character(at), length(at) == 1L)

  moment <- as.POSIXct(at, tz = "UTC", format = "%Y-%m-%d %H:%M")
  if (is.na(moment)) {
    return(NA_character_)
  }

  format(moment, "%Y-%m-%d %H:%M", tz = "Europe/Rome")
}
