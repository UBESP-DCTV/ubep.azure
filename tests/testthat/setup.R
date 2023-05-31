library(checkmate)


example_ps <- paste(
  paste0(
    "$PasswordProfile = New-Object ",
    "-TypeName Microsoft.Open.AzureAD.Model.PasswordProfile"
  ),
  '$PasswordProfile.Password = "P@ssw0rd"',
  paste0(
    "New-AzureADUser -DisplayName \"GIOVANNI AGOSTINI\" ",
    "-PasswordProfile $PasswordProfile `"
  ),
  paste0(
    "-UserPrincipalName \"GIOVANNI.AGOSTINI@ubep.unipd.it\" ",
    "-AccountEnabled $true ",
    "-GivenName \"GIOVANNI\" ",
    "-Surname \"AGOSTINI\" ",
    "-MailNickName \"GIOVANNIAGOSTINI\" ",
    "-PhysicalDeliveryOfficeName ",
      "\"giovanni.agostini.2@studenti.unipd.it\""
  ),
  paste0(
    "New-AzureADUser -DisplayName \"JACOPOMARIA AGOSTINI\" ",
    "-PasswordProfile $PasswordProfile `"
  ),
  paste0(
    "-UserPrincipalName \"JACOPOMARIA.AGOSTINI@ubep.unipd.it\" ",
    "-AccountEnabled $true ",
    "-GivenName \"JACOPOMARIA\" ",
    "-Surname \"AGOSTINI\" ",
    "-MailNickName \"JACOPOMARIAAGOSTINI\" ",
    "-PhysicalDeliveryOfficeName ",
      "\"jacopomaria.agostini@studenti.unipd.it\""
  ),
sep = "\n"
)

example_tbl <- data.frame(
  Nome = c("Pinco", "Ciccio", "Mario", "", NA),
  Cognome = c("Pallino", "Pasticcio", "Rossi", "", NA),
  Email = c(
    "pinco.pallino.1@fobar.org", "ciccio.past@barfoo.com",
    "mr@example.boh", "", NA
  ),
  Prj1_ID = c(1, 2, NA, NA, NA),
  Prj1_role = c("user", "power", NA, "", NA),
  Prj1_DAG = c("a", "b", NA, "", NA),
  Prj2_ID = c(3, NA, 4, NA, NA),
  Prj2_role = c("user", NA, "boss", "", NA),
  Prj2_DAG = c("c", NA, "d", "", NA)
)
