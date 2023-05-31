
# Project packages (TO BE UPDATED EVERY NEW PACKAGE USED) ----------
meta_pkgs <- c()  # e.g., tidyverse, tidymodels, ...
renv::install(meta_pkgs)

prj_pkgs <- c(
  "dplyr", "glue", "readr", "readxl", "stringi", "stringr",
  "usethis", "utils"
)
renv::install(prj_pkgs)
purrr::walk(prj_pkgs, usethis::use_package)

gh_prj_pkgs <- c()  # e.g. CorradoLanera/autotestthat
renv::install(gh_prj_pkgs)
purrr::walk(gh_prj_pkgs, ~{
  package_name <- stringr::str_extract(.x, "[\\w\\.]+$")
  usethis::use_dev_package(package_name, remote = .x)
})

dev_pkgs <- c(
  "devtools", "testthat", "checkmate", "tidyverse", "withr", "fs",
  "glue", "rmarkdown", "knitr", "lintr", "spelling", "covr"
)
renv::install(dev_pkgs)
purrr::walk(dev_pkgs, usethis::use_package, type = "Suggests")

usethis::use_tidy_description()
devtools::document()
renv::status()
# renv::snapshot()

# Functions definitions -------------------------------------------

## if you need more structure respect to include your functions inside
## `R/functions.R`, you can create other couple of test/function-script
## by running the following lines of code as needed.



.use_r_with_test("utils")
.use_r_with_test("getters")
.use_r_with_test("composers")
.use_r_with_test("ps1_creators")
.use_r_with_test("bild_ps1_from_xlsx")




