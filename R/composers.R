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
