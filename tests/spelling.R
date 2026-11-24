# Sotto covr il pacchetto è installato senza sorgenti, e spell_check_test()
# non trova la cartella da controllare: covr imposta R_COVR a "true".
in_covr <- identical(Sys.getenv("R_COVR"), "true")
if (requireNamespace("spelling", quietly = TRUE) && !in_covr) {
  spelling::spell_check_test(
    vignettes = TRUE,
    error = FALSE,
    skip_on_cran = TRUE
  )
}
