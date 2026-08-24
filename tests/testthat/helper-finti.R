# I valori finti dei test, in un posto solo.
#
# Nominarli qui invece che come letterali accanto a un argomento che si chiama
# `api_key` o `credential` non e' pignoleria: un valore finto scritto in quella
# forma e' indistinguibile, per chi legge o per un guardiano automatico, da un
# segreto vero lasciato in chiaro. E tre file di test hanno bisogno degli
# stessi valori, che e' la ragione ordinaria per cui un helper esiste.

finti <- list(
  chiave  = "chiave-di-prova",
  parola  = "Zx9-qWer-7Tuv",
  gettone = "gettone-di-prova"
)


# Una riga del registro come il giro la maneggia: i diciassette campi del
# dizionario, con i valori che il banco di collaudo ha reso familiari. Gli
# argomenti sostituiscono i campi che il singolo test vuole diversi, cosi' ogni
# test dichiara la sola cosa che sta esercitando.
riga_di_prova <- function(...) {
  utils::modifyList(
    list(
      record_id = "16", server = "edc10", project_id = "29",
      username = "sara.collaudozeta@ubep.unipd.it",
      first_name = "Sara", last_name = "Collaudozeta",
      contact_email = "sara.esterna@example.org", identity = "existing",
      role_name = "collaudo-canale", dag_name = "", expiration = "",
      requested_by = "cinzia@ubep.unipd.it", request_status = "active",
      outcome = "data_error", outcome_detail = "DATO_RUOLO_INESISTENTE",
      outcome_at = "2026-08-24 12:04", applied_as = ""
    ),
    list(...)
  )
}
