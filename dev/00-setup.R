c(
  "devtools", "testthat", "checkmate", "tidyverse", "withr", "fs",
  "here", "glue", "rmarkdown", "knitr"
) |>
  install.packages()

renv::status()
renv::snapshot()

usethis::use_description()
usethis::use_readme_rmd()
usethis::use_news_md()
usethis::use_testthat()
usethis::use_roxygen_md()
usethis::use_r("foo") # delete foo.R file
usethis::use_package_doc()
usethis::use_code_of_conduct("corrado.lanera@ubep.unipd.it")
usethis::use_mit_license()

usethis::use_lifecycle_badge("experimental")
usethis::use_cran_badge()

usethis::use_tidy_github()
