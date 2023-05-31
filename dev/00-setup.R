c(
  "devtools", "testthat", "checkmate", "tidyverse", "withr", "fs",
  "here", "glue", "rmarkdown", "knitr", "lintr"
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

usethis::use_spell_check()
spelling::spell_check_package()
spelling::update_wordlist()



usethis::use_tidy_github()

lintr::use_lintr()
lintr::lint_package()


usethis::use_github_action_check_release("R-CMD-check-develop.yaml")
usethis::use_github_action_check_standard("R-CMD-check-main.yaml")
usethis::use_coverage()

usethis::use_github_action("lint")
usethis::use_github_action("test-coverage")
usethis::use_github_actions_badge("lint.yaml")

usethis::git_vaccinate()

usethis::use_pkgdown_github_pages()


renv::upgrade()
renv::update()
