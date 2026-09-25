test_that("a reachable instance reports version, fingerprint and counts", {
  state <- list(
    ok = TRUE, errors = character(), gate = "collaudata",
    payload = list(
      redcap_version = "17.3.3", redcap_major = 17L,
      version_gate = "collaudata", surface_fingerprint = "16faf46d5ab1",
      allowlist_fingerprint = "aabbccddeeff",
      results = list(
        list(username = "a", project_id = 9001L, expiration = "2020-01-01"),
        list(username = "b", project_id = 9001L, expiration = NULL),
        list(username = "c", project_id = 9002L, expiration = "2099-01-01")
      )
    )
  )

  row <- observe_instance("edcNN", state, today = as.Date("2026-08-07"))

  expect_true(row[["raggiungibile"]])
  expect_equal(row[["redcap_version"]], "17.3.3")
  expect_equal(row[["redcap_major"]], 17L)
  expect_equal(row[["surface_fingerprint"]], "16faf46d5ab1")
  expect_equal(row[["allowlist_fingerprint"]], "aabbccddeeff")
  expect_equal(row[["coppie"]], 3L)
  expect_equal(row[["scadute"]], 1L)
  expect_equal(row[["senza_scadenza"]], 1L)
})


test_that("the expiration boundary is inclusive, as REDCap applies it", {
  # REDCap denies when `expiration <= TODAY`, so a pair expiring *today* is
  # already refused and must be counted. The date is injected rather than read
  # from the clock: a literal `today` in a fixture turns green into red on a
  # calendar date, for a reason that has nothing to do with the code.
  state <- list(
    ok = TRUE, errors = character(), gate = "collaudata",
    payload = list(
      redcap_version = "17.3.3", redcap_major = 17L,
      surface_fingerprint = "16faf46d5ab1",
      results = list(
        list(username = "a", project_id = 9001L, expiration = "2026-08-07"),
        list(username = "b", project_id = 9001L, expiration = "2026-08-08")
      )
    )
  )

  row <- observe_instance("edcNN", state, today = as.Date("2026-08-07"))

  expect_equal(row[["scadute"]], 1L)
})


test_that("an unreachable instance becomes a row, not an exception", {
  state <- list(
    ok = FALSE, errors = "TRASPORTO_MODULO_ASSENTE",
    payload = NULL, gate = NA_character_
  )

  row <- observe_instance("edcNN", state, today = as.Date("2026-08-07"))

  expect_false(row[["raggiungibile"]])
  expect_equal(row[["errori"]], "TRASPORTO_MODULO_ASSENTE")
  expect_true(is.na(row[["redcap_major"]]))
  expect_true(is.na(row[["coppie"]]))
})


test_that("a module that predates the allowlist fingerprint stays readable", {
  # Instances still on an older release answer without the field. Refusing
  # them would blind the audit on exactly the instances a rollout is behind on.
  state <- list(
    ok = TRUE, errors = character(), gate = "collaudata",
    payload = list(
      redcap_version = "17.3.3", redcap_major = 17L,
      surface_fingerprint = "16faf46d5ab1",
      results = list()
    )
  )

  row <- observe_instance("edcNN", state, today = as.Date("2026-08-07"))

  expect_true(row[["raggiungibile"]])
  expect_true(is.na(row[["allowlist_fingerprint"]]))
  expect_equal(row[["coppie"]], 0L)
})


test_that("the run record counts successful reads, not attempted instances", {
  observations <- rbind(
    observe_instance("a", list(
      ok = TRUE, gate = "collaudata",
      payload = list(
        redcap_major = 17L, redcap_version = "17.3.3",
        surface_fingerprint = "16faf46d5ab1", results = list()
      )
    )),
    observe_instance("b", list(
      ok = FALSE, errors = "TRASPORTO_MODULO_ASSENTE", payload = NULL
    ))
  )

  record <- run_record(observations, at = "2026-08-07 03:00")

  expect_equal(record[["istanze"]], 2L)
  expect_equal(record[["letture_riuscite"]], 1L)
  expect_equal(record[["irraggiungibili"]], 1L)
  expect_equal(record[["major_fra_lette"]], 17L)
  # one instance could not be read, so the fleet claim cannot be made
  expect_false(record[["copertura_completa"]])
  expect_false(record[["flotta_a_una_major"]])
})


test_that("the fleet claim is false whenever coverage is partial", {
  # The clause that retires a compatibility branch fires when the set of majors
  # in the fleet is a singleton. A flag computed over the instances that happen
  # to answer would report a singleton while instances on an older major sit
  # unread — and would retire a branch that is still needed. So the flag is
  # false whenever it cannot know.
  observations <- observe_instance("a", list(
    ok = TRUE, gate = "collaudata",
    payload = list(
      redcap_major = 17L, redcap_version = "17.3.3",
      surface_fingerprint = "16faf46d5ab1", results = list()
    )
  ))

  tutte <- run_record(observations, at = "2026-08-07 03:00")
  expect_true(tutte[["copertura_completa"]])
  expect_true(tutte[["flotta_a_una_major"]])

  parziale <- run_record(
    observations,
    at = "2026-08-07 03:00",
    non_osservate = c("edc01", "mst01")
  )
  expect_equal(parziale[["major_fra_lette"]], 17L)
  expect_false(parziale[["copertura_completa"]])
  expect_false(parziale[["flotta_a_una_major"]])
  expect_equal(parziale[["non_osservate"]], c("edc01", "mst01"))
})


test_that("a run that read nothing reports zero reads", {
  # The alarm on absence fires on the lack of a record with at least one
  # successful read. If the record said only "the process started", a job that
  # started, failed against every instance and exited would satisfy it — a
  # detector the fault can meet.
  observations <- observe_instance("a", list(
    ok = FALSE, errors = "TRASPORTO_MODULO_ASSENTE", payload = NULL
  ))

  record <- run_record(observations, at = "2026-08-07 03:00")

  expect_equal(record[["letture_riuscite"]], 0L)
  expect_equal(length(record[["major_fra_lette"]]), 0L)
  expect_false(record[["flotta_a_una_major"]])
})


test_that("two majors in the fleet are not a singleton", {
  # The condition the two clauses on retiring compatibility branches rest on.
  observations <- rbind(
    observe_instance("a", list(ok = TRUE, gate = "collaudata", payload = list(
      redcap_major = 17L, redcap_version = "17.3.3",
      surface_fingerprint = "16faf46d5ab1", results = list()
    ))),
    observe_instance("b", list(ok = TRUE, gate = "collaudata", payload = list(
      redcap_major = 15L, redcap_version = "15.8.4",
      surface_fingerprint = "ffffffffffff", results = list()
    )))
  )

  record <- run_record(observations, at = "2026-08-07 03:00")

  expect_equal(record[["major_fra_lette"]], c(15L, 17L))
  expect_false(record[["flotta_a_una_major"]])
  expect_equal(length(record[["impronte_superficie"]]), 2L)
})


test_that("list fields serialize as arrays even when holding one item", {
  # The length-one array trap, on the emission side this time. `auto_unbox`
  # turns a one-element vector into a scalar, so a fleet with a single instance
  # would emit a string where the alert query expects an array — and the fault
  # stays hidden until the day only one instance answers.
  observations <- observe_instance("a", list(
    ok = TRUE, gate = "collaudata",
    payload = list(
      redcap_major = 17L, redcap_version = "17.3.3",
      surface_fingerprint = "16faf46d5ab1", results = list()
    )
  ))

  json <- run_record_json(run_record(observations, at = "2026-08-07 03:00"))
  back <- jsonlite::fromJSON(json, simplifyVector = FALSE)

  expect_true(is.list(back[["impronte_superficie"]]))
  expect_length(back[["impronte_superficie"]], 1L)
  expect_true(is.list(back[["major_fra_lette"]]))

  # scalars must stay scalars: a run with one reading is not a list of one
  expect_true(is.numeric(back[["letture_riuscite"]]))
  expect_true(is.logical(back[["flotta_a_una_major"]]))
})


test_that("an empty list-valued field stays an empty array, not null", {
  observations <- observe_instance("a", list(
    ok = FALSE, errors = "TRASPORTO_MODULO_ASSENTE", payload = NULL
  ))

  json <- run_record_json(run_record(observations, at = "2026-08-07 03:00"))
  back <- jsonlite::fromJSON(json, simplifyVector = FALSE)

  expect_true(is.list(back[["major_fra_lette"]]))
  expect_length(back[["major_fra_lette"]], 0L)
})


test_that("the record carries the gates, so an alarm can see a bad one", {
  # The alarm on outcome fires on a gate other than `collaudata`. Without the
  # gates in the record the rule would have nothing to read, and the run would
  # look healthy while an instance refused every write.
  observations <- rbind(
    observe_instance("a", list(ok = TRUE, gate = "collaudata", payload = list(
      redcap_major = 17L, redcap_version = "17.3.3",
      surface_fingerprint = "16faf46d5ab1", results = list()
    ))),
    observe_instance("b", list(
      ok = TRUE, gate = "non_collaudata", payload = list(
        redcap_major = 17L, redcap_version = "17.9.9",
        surface_fingerprint = "ffffffffffff", results = list()
      )
    ))
  )

  record <- run_record(observations, at = "2026-08-07 03:00")

  expect_equal(record[["cancelli"]], c("collaudata", "non_collaudata"))
  expect_false(record[["tutti_collaudati"]])
})


test_that("all gates collaudata is only true when every read said so", {
  observations <- observe_instance("a", list(
    ok = TRUE, gate = "collaudata",
    payload = list(
      redcap_major = 17L, redcap_version = "17.3.3",
      surface_fingerprint = "16faf46d5ab1", results = list()
    )
  ))
  expect_true(run_record(observations, at = "x")[["tutti_collaudati"]])

  # a run that read nothing has not seen a good gate, so the claim is false
  niente <- observe_instance("a", list(
    ok = FALSE, errors = "TRASPORTO_MODULO_ASSENTE", payload = NULL
  ))
  expect_false(run_record(niente, at = "x")[["tutti_collaudati"]])
})


# Two fixtures for the tests on benches below: what matters there is only
# whether an instance answered and what it is called, so the payload is written
# once rather than restated in every test.
acceso <- function(nome) {
  observe_instance(nome, list(
    ok = TRUE, gate = "collaudata",
    payload = list(
      redcap_major = 17L, redcap_version = "17.3.3",
      surface_fingerprint = "16faf46d5ab1", results = list()
    )
  ))
}

spento <- function(nome) {
  observe_instance(nome, list(
    ok = FALSE, errors = "TRASPORTO_MODULO_ASSENTE", payload = NULL
  ))
}


test_that("without benches, every unreachable instance is a production one", {
  observations <- rbind(acceso("prod-a"), spento("prod-b"), spento("prod-c"))

  record <- run_record(observations, at = "2026-08-07 03:00")

  expect_equal(record[["irraggiungibili"]], 2L)
  expect_equal(
    record[["irraggiungibili_produzione"]], record[["irraggiungibili"]]
  )
  expect_equal(record[["irraggiungibili_nomi"]], c("prod-b", "prod-c"))
})


test_that("a bench switched off does not count against production", {
  # Benches are off by default and switched on when needed. Counted with the
  # rest, they would keep the alarm on unreachable instances red for good, and
  # an alarm that is always red is an alarm nobody reads.
  observations <- rbind(acceso("prod-a"), spento("banco-a"))

  record <- run_record(
    observations,
    at = "2026-08-07 03:00", banchi = "banco-a"
  )

  expect_equal(record[["irraggiungibili_produzione"]], 0L)
  expect_equal(record[["irraggiungibili_nomi"]], "banco-a")
  # The old counter is untouched: the table and whoever reads it keep the
  # meaning they had.
  expect_equal(record[["irraggiungibili"]], 1L)
  # And a bench that was not read is still a gap in coverage: it may sit on
  # another major, so the fleet claim cannot be made over it.
  expect_false(record[["copertura_completa"]])
  expect_false(record[["flotta_a_una_major"]])
})


test_that("a production instance switched off still counts", {
  observations <- rbind(
    spento("prod-a"), spento("banco-a"), acceso("banco-b")
  )

  record <- run_record(
    observations,
    at = "2026-08-07 03:00", banchi = c("banco-a", "banco-b")
  )

  expect_equal(record[["irraggiungibili"]], 2L)
  expect_equal(record[["irraggiungibili_produzione"]], 1L)
  expect_equal(record[["irraggiungibili_nomi"]], c("prod-a", "banco-a"))
})


test_that("a bench named but not observed changes nothing", {
  # The inventory and the observations can disagree for a run: a name that
  # marks nothing must neither fail nor be counted.
  observations <- rbind(acceso("prod-a"), spento("prod-b"))

  con <- run_record(
    observations,
    at = "2026-08-07 03:00", banchi = "banco-assente"
  )
  senza <- run_record(observations, at = "2026-08-07 03:00")

  expect_equal(con[["irraggiungibili_produzione"]], 1L)
  expect_identical(con, senza)
})


test_that("the unreachable names stay an array, with one item or none", {
  # The same length-one trap as the other list fields: one bench off would
  # emit a bare string where the column is `dynamic`, and a query reading it as
  # an array would fail on that run only.
  uno <- run_record_json(run_record(
    rbind(acceso("prod-a"), spento("banco-a")),
    at = "2026-08-07 03:00", banchi = "banco-a"
  ))
  expect_match(uno, '"irraggiungibili_nomi":["banco-a"]', fixed = TRUE)
  # a counter stays a counter
  expect_match(uno, '"irraggiungibili_produzione":0', fixed = TRUE)

  nessuno <- run_record_json(
    run_record(acceso("prod-a"), at = "2026-08-07 03:00")
  )
  expect_match(nessuno, '"irraggiungibili_nomi":[]', fixed = TRUE)
})


test_that("the record's fields are exactly the collection rule's columns", {
  # The columns of the observer's table, minus `TimeGenerated`, which the
  # runner adds at emission time.
  #
  # Written out by hand, like its twin for the channel's record, because the
  # ingestion API drops in silence every column the collection rule does not
  # know: a field added here before the rule has learned it does not fail, it
  # arrives empty. This test is what turns that silence into a red, and the
  # order it asks for is the rule first, the package after.
  colonne <- c(
    "at", "istanze", "letture_riuscite", "irraggiungibili",
    "irraggiungibili_produzione", "irraggiungibili_nomi", "non_osservate",
    "copertura_completa", "major_fra_lette", "flotta_a_una_major", "cancelli",
    "tutti_collaudati", "impronte_superficie", "impronte_allowlist",
    "coppie_scadute", "coppie_totali"
  )

  record <- run_record(acceso("prod-a"), at = "2026-08-07 03:00")

  expect_setequal(names(record), colonne)
})
