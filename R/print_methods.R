# Computation never prints. These methods only format ordinary lists/tables.
round_table <- function(x, digits) {
  numeric <- vapply(x, is.numeric, logical(1))
  x[numeric] <- lapply(x[numeric], round, digits)
  x
}

#' @export
print.voi_partition <- function(x, digits = 4, ...) {
  cat("Preferred option:", x$d_star, "\n")
  fields <- intersect(c("A", "B", "C", "D", "EVPI", "VoH_static", "EVPI_sub", "VoH_dyn"), names(x))
  print(round(unlist(x[fields]), digits))
  if (isTRUE(x$differentiated)) print(x$planner_profile)
  invisible(x)
}

#' @export
print.fairness_screen <- function(x, digits = 4, ...) {
  print(round_table(x$table, digits), row.names = FALSE)
  invisible(x)
}

#' @export
print.baseline_pair <- function(x, digits = 4, ...) {
  print(round_table(x$rules, digits), row.names = FALSE)
  invisible(x)
}

#' @export
print.marginalisation_count <- function(x, digits = 4, ...) {
  cat("Hidden-loss share for", x$d_star, ":", round(x$share, digits), "\n")
  print(round_table(x$by_group, digits), row.names = FALSE)
  invisible(x)
}

#' @export
print.fidelity_threshold <- function(x, digits = 4, ...) {
  table <- x
  class(table) <- "data.frame"
  print(round_table(table, digits), row.names = FALSE)
  invisible(x)
}
