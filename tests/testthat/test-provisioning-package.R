test_that("build_redcap_module produces an installable archive", {
  # eval
  out_dir <- withr::local_tempdir()
  zip_path <- build_redcap_module(out_dir)
  version <- as.character(utils::packageVersion("ubep.azure"))
  entries <- utils::unzip(zip_path, list = TRUE)[["Name"]]
  top_level <- unique(sub("/.*$", "", entries))

  # test
  expect_true(file.exists(zip_path))
  expect_equal(
    basename(zip_path), paste0("ubep_provisioning_v", version, ".zip")
  )
  expect_equal(top_level, paste0("ubep_provisioning_v", version))
  expect_true(
    paste0("ubep_provisioning_v", version, "/config.json") %in% entries
  )
  expect_true(
    paste0("ubep_provisioning_v", version, "/api.php") %in% entries
  )
  expect_true(
    paste0("ubep_provisioning_v", version, "/lib/VersionGate.php") %in% entries
  )
})


test_that("the VERSION file inside the archive matches DESCRIPTION", {
  # eval
  out_dir <- withr::local_tempdir()
  zip_path <- build_redcap_module(out_dir)
  version <- as.character(utils::packageVersion("ubep.azure"))
  utils::unzip(zip_path, exdir = out_dir)
  version_file <- file.path(
    out_dir, paste0("ubep_provisioning_v", version), "VERSION"
  )

  # test
  expect_true(file.exists(version_file))
  expect_equal(trimws(readr::read_file(version_file)), version)
})


test_that("the test directory is not shipped to servers", {
  # eval
  out_dir <- withr::local_tempdir()
  zip_path <- build_redcap_module(out_dir)
  entries <- utils::unzip(zip_path, list = TRUE)[["Name"]]

  # test
  expect_false(any(grepl("/tests/", entries, fixed = TRUE)))
})


test_that("the shipped manifest keeps the page free of both auth and csrf", {
  # eval
  out_dir <- withr::local_tempdir()
  zip_path <- build_redcap_module(out_dir)
  version <- as.character(utils::packageVersion("ubep.azure"))
  utils::unzip(zip_path, exdir = out_dir)
  manifest <- jsonlite::fromJSON(file.path(
    out_dir, paste0("ubep_provisioning_v", version), "config.json"
  ))

  # test
  # Without `no-csrf-pages` the endpoint answers every POST with an error that
  # names the token API instead of the CSRF check, so a manifest that lost the
  # entry would look like a routing problem rather than a packaging one.
  expect_equal(manifest[["no-auth-pages"]], "api")
  expect_equal(manifest[["no-csrf-pages"]], "api")
  expect_true("test-project-ids" %in% manifest[["system-settings"]][["key"]])
})
