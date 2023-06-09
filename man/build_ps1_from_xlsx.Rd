% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/bild_ps1_from_xlsx.R
\name{build_ps1_from_xlsx}
\alias{build_ps1_from_xlsx}
\title{Build ps1 files}
\usage{
build_ps1_from_xlsx(file = file.choose())
}
\arguments{
\item{file}{(chr, default interactive selection windows) file path to
the Excel file reporting the users to create (see details).}
}
\description{
From a correctly formatted file, \code{ps1} files for create the user and
to assign them to a group in bulk operation o AAD directly.
}
\details{
The Excel file must have 9 column, named exactly (case sensitive) as:
\verb{Nome, Cognome, Email, Prj1_ID, Prj1_role, Prj1_DAG, Prj1_ID, Prj1_role, Prj1_DAG}.

Moreover:
\itemize{
\item no more than 2 projects can be added at the creation time using
this script.
\item At least information (all the three!) for one project must be
provided for EDCxx servers
\item For students on MSTxx servers no information should be provided
about projects (i.e. the first three column should contain data
only!)
\item For template including a projects all the role and DAG for each
of them must be provided!
}
}
\examples{
\dontrun{
  build_ps1_from_xlsx()
}

}
