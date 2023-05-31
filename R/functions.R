clean_string <- function(string) {
  stringr::str_to_lower(string) |>
    stringr::str_squish() |>
    stringr::str_replace_all("\\s+", ".") |>
    stringr::str_replace_all("\\.+", ".") |>
    stringr::str_replace_all("[^\\w\\d\\.]", "") |>
    stringi::stri_trans_general("Latin-ASCII")
}




compose_jobtitle <- function(users, i) {

  stopifnot(
    names(users) == c(
      "Nome", "Cognome", "Email",
      "Prj1_ID", "Prj1_role", "Prj1_DAG",
      "Prj2_ID", "Prj2_role", "Prj2_DAG"
    )
  )

  usr <- users[i, , drop = FALSE]
  p1 <- if (!is.na(usr[["Prj1_ID"]]) && (usr[["Prj1_ID"]] != "")) {
    glue::glue(
      "Prj,{usr[['Prj1_ID']]}|role,{usr[['Prj1_role']]}|DAG,{usr[['Prj1_DAG']]}"
    )
  }
  p2 <- if (!is.na(usr[["Prj2_ID"]]) && (usr[["Prj2_ID"]] != "")) {
    glue::glue(
      "Prj,{usr[['Prj2_ID']]}|role,{usr[['Prj2_role']]}|DAG,{usr[['Prj2_DAG']]}"
    )
  }

  p12 <- stringr::str_c(p1, p2, sep = ";")

  job_title <- if ((length(p12) > 0) && !is.na(p12) && (p12 != "")) {
    paste0(" -JobTitle \"", p12, "\" ")
  } else {
    ""
  }

  invisible(job_title)
}




create_user_powershell_script <- function(domain, file_name_no_extension) {

  file_input <- paste0("bulkUsers/", file_name_no_extension, ".csv")
  file_output <- paste0("bulkUsers/", file_name_no_extension, ".ps1")
  file_delete_users <- paste0(
    "bulkUsers/",
    file_name_no_extension, "_deleteUsers.ps1"
  )
  file_log <- paste0("bulkUsers/", "logImportUsers.csv")

  users <- readr::read_csv(here::here(file_input))
  output <- sink(here::here(file_output))
  log <- here::here(file_log)


  paste(
    paste0(
      "$PasswordProfile = New-Object ",
      "-TypeName Microsoft.Open.AzureAD.Model.PasswordProfile"
    ),
    "$PasswordProfile.Password = 'P@ssw0rd'\r",
    sep = "\r"
  ) |>
    cat(output)

  user_principal_name_col <- vector()
  name_col <- vector()
  surname_col <- vector()
  email_col <- vector()

  for (i in seq_len(nrow(users))) {
    name <- clean_string(users[i, "Nome"])
    surname <- clean_string(users[i, "Cognome"])
    job_title <- compose_jobtitle(users, i)
    user_principal_name <- paste0(name, ".", surname, "@", domain)

    sntx <- paste0(
      "New-AzureADUser -DisplayName \"", name, " ", surname,
      "\" -PasswordProfile $PasswordProfile `", "\r",
      "-UserPrincipalName \"", user_principal_name,
      "\" -AccountEnabled $true -GivenName \"",
      name, "\" -Surname \"", surname,
      "\" -MailNickName \"", name, surname, "\"", job_title,
      " -PhysicalDeliveryOfficeName \"", users[i, "Email"], "\"\r"
    )
    cat(sntx, output, append = TRUE)

    user_principal_name_col <- append(
      user_principal_name_col,
      user_principal_name
    )
    name_col <- append(name_col, users[i, "Nome"])
    surname_col <- append(surname_col, users[i, "Cognome"])
    email_col <- append(email_col, users[i, "Email"])
  }

  sink()

  utils::write.table(
    data.frame(
      user_principal_name_col, name_col, surname_col, email_col, Sys.Date()
    ),
    log,
    sep = ",",
    row.names = TRUE,
    col.names = FALSE,
    append = TRUE
  )

  output <- sink(here::here(file_delete_users))

  for (i in seq_len(nrow(users))) {
    name <- clean_string(users[i, "Nome"])
    surname <- clean_string(users[i, "Cognome"])
    user_principal_name <- paste0(name, ".", surname, "@", domain)

    sntx <- paste0(
      "Remove-AzureADUser -ObjectId \"", user_principal_name, "\"\r"
    )

    cat(sntx, output, append = TRUE)
  }

  sink()
}




setup_import_files <- function(file = file.choose()) {

  ps_name <- stringr::str_remove(basename(file), "\\.[^\\.]+$")

  out_dir <- dirname(file)
  server <- basename(out_dir)
  if (server == "toImport") {
    out_dir <- dirname(out_dir)
    usethis::ui_done(
      "{usethis::ui_field('out_dir')} moved to {usethis::ui_value(out_dir)}."
    )
    server <- basename(out_dir)
    usethis::ui_info("REDCap server is set to {usethis::ui_value(server)}")
  }

  stopifnot(
    `file must start with "<yyyymmdd>_importUtenti"` =
      stringr::str_detect(file, "importUtenti"),

    `file must be an excel or csv file` =
      stringr::str_detect(file, "\\.(csv|xlsx?)$"),

    `file must be located inside "mst01", "edc01", or "edc" folder` =
      server %in% c("mst01", "edc01", "edc")
  )

  if (stringr::str_detect(file, "\\.xlsx?$")) excel2csv(file, out_dir)

  create_user_powershell_script(
    "ubep.unipd.it", paste(server, ps_name, sep = "/")
  )
  usethis::ui_done("PS scripts created.")

  ps_file <- file.path(out_dir, paste0(ps_name, ".ps1"))

  create_group_import_member(ps_file, out_dir)
}




create_group_import_member <- function(file, out_dir) {
  stopifnot(
    `file must be a PS1 file` = stringr::str_detect(file, "\\.ps1$")
  )
  out_name <- basename(file) |>
    stringr::str_replace("importUtenti", "GroupImportMembers") |>
    stringr::str_replace("\\.ps1$", ".csv")
  out_path <- file.path(out_dir, out_name)

  get_usrs_principalname(file, out_path)
  usethis::ui_done("GroupImportMember CSV file created.")
}




excel2csv <- function(file, out_dir) {
  out_name <- basename(file) |>
    stringr::str_replace("\\.xlsx?$", ".csv")
  out_path <- file.path(out_dir, out_name)
  server <- basename(out_dir)

  read_data(file) |>
    readr::write_csv(out_path, na = "")
  usethis::ui_done(
    "Excel file converted to CSV inside the {server} folder."
  )
  invisible(out_path)
}




read_data <- function(file, csv = FALSE) {
  db <- if (csv) {
    readr::read_csv(file)
  } else {
    readxl::read_excel(file)
  }

  dplyr::filter(db, dplyr::if_any(dplyr::everything(), ~ !is.na(.)))
}




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
