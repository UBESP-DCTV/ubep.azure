ps1_create_bulk_users <- function(domain, file_name_no_extension) {

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




ps1_create_bulk_group <- function(file, out_dir) {
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
