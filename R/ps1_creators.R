ps1_create_bulk_users <- function(
    file_name_no_extension,
    out_dir,
    domain = "ubep.unipd.it"
) {

  file_input <- file.path(
    out_dir,
    paste0(file_name_no_extension, ".csv")
  )

  file_output <- file_input |>
    stringr::str_replace("\\.csv$", ".ps1")

  file_delete_users <- file_input |>
    stringr::str_replace("\\.csv$", "_deleteUsers.ps1")

  file_log <- file.path(out_dir, "logImportUsers.csv")

  users <- readr::read_csv(file_input, show_col_types = FALSE)
  output <- sink(file_output)
  log <- file_log

  # --- MODIFICA 1: Nuova sintassi per il profilo password (Hashtable) ---
  paste(
    "$PasswordProfile = @{",
    "    Password = 'P@ssw0rd'",
    "    ForceChangePasswordNextSignIn = $true",
    "}\r",
    sep = "\r"
  ) |>
    cat(output)
  # ----------------------------------------------------------------------

  user_principal_name_col <- vector()
  name_col <- vector()
  surname_col <- vector()
  email_col <- vector()

  for (i in seq_len(nrow(users))) {
    name <- clean_string(users[i, "Nome"])
    surname <- clean_string(users[i, "Cognome"])
    job_title <- compose_jobtitle(users, i)
    user_principal_name <- paste0(name, ".", surname, "@", domain)

    # --- MODIFICA 2: New-MgUser invece di New-AzureADUser ---
    # Nota: PhysicalDeliveryOfficeName diventa OfficeLocation
    sntx <- paste0(
      "New-MgUser -DisplayName \"", name, " ", surname,
      "\" -PasswordProfile $PasswordProfile `", "\r",  # <--- NOTA L'ACCENTO GRAVE QUI
      "-UserPrincipalName \"", user_principal_name,
      "\" -AccountEnabled:$true -GivenName \"",
      name, "\" -Surname \"", surname,
      "\" -MailNickName \"", name, surname, "\"", job_title,
      " -OfficeLocation \"", users[i, "Email"], "\"\r"
    )
    cat(sntx, output, append = TRUE)
    # --------------------------------------------------------

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
      user_principal_name_col,
      name_col,
      surname_col,
      email_col,
      Sys.Date()
    ),
    log,
    sep = ",",
    row.names = TRUE,
    col.names = FALSE,
    append = TRUE
  )

  output <- sink(file_delete_users)

  for (i in seq_len(nrow(users))) {
    name <- clean_string(users[i, "Nome"])
    surname <- clean_string(users[i, "Cognome"])
    user_principal_name <- paste0(name, ".", surname, "@", domain)

    # --- MODIFICA 3: Remove-MgUser invece di Remove-AzureADUser ---
    # Nota: ObjectId diventa UserId. Aggiunto ErrorAction per sicurezza.
    sntx <- paste0(
      "Remove-MgUser -UserId \"", user_principal_name, "\" -ErrorAction SilentlyContinue\r"
    )

    cat(sntx, output, append = TRUE)
    # --------------------------------------------------------------
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
