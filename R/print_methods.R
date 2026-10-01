# print() methods for the S3 classes returned by layer-1 functions.
# Kept apart from the computations so that those stay free of side effects
# (FUNCTIONS.md, design rule 5).

round_df <- function(df, digits) {
  num <- vapply(df, is.numeric, logical(1))
  df[num] <- lapply(df[num], round, digits)
  df
}

#' @export
print.voi_partition <- function(x, digits = 4, ...) {
  cat("Value of information\n")
  cat(sprintf("  %d draws | %d options | %d groups\n",
              x$n_draws, x$n_options, x$n_groups))
  cat("  recommended option: ", x$d_star,
      sprintf(" (best in %.1f %% of draws)\n", 100 * x$p_ahead), sep = "")
  print(round(c(EVPI = x$EVPI, A = x$A, C = x$C), digits))
  if (isTRUE(x$differentiated)) {
    cat("\nDecision per group (planner",
        if (isTRUE(x$restricted)) sprintf(", %d allowed profiles", x$n_profiles),
        "):\n", sep = "")
    print(round(c(B = x$B, D = x$D, VoH_static = x$VoH_static,
                  EVPI_sub = x$EVPI_sub, VoH_dyn = x$VoH_dyn), digits))
    if (!is.null(x$planner_profile))
      cat("Planner profile: ",
          paste(names(x$planner_profile), x$planner_profile, sep = " -> ",
                collapse = " | "), "\n", sep = "")
  }
  invisible(x)
}

#' @export
print.fairness_screen <- function(x, digits = 4, ...) {
  cat("Fairness screen: ", nrow(x$table), " rules, ", length(x$options),
      " options, ", length(x$groups), " groups\n\n", sep = "")
  print(round_df(x$table, digits), row.names = FALSE)
  cat("\nSmallest rank correlation between the rules (Spearman): ",
      round(x$rank_correlation, 3), "\n", sep = "")
  invisible(x)
}

#' @export
print.marginalisation_count <- function(x, digits = 3, ...) {
  cat("Hidden loss under option '", x$d_star, "' (", x$n_draws, " draws): ",
      round(x$share, digits), "\n", sep = "")
  print(round_df(x$by_group, digits), row.names = FALSE)
  invisible(x)
}

#' @export
print.baseline_pair <- function(x, digits = 4, ...) {
  cat("Reference-state pair: ", paste(x$references, collapse = " vs "), "\n\n",
      sep = "")
  print(round_df(x$rules, digits), row.names = FALSE)
  flips <- unique(x$outcomes[x$outcomes$flip, c("unit", "outcome")])
  if (nrow(flips))
    cat("\nHighest mean changes for: ",
        paste(flips$unit, flips$outcome, sep = "/", collapse = ", "), "\n", sep = "")
  invisible(x)
}

#' @export
print.fidelity_threshold <- function(x, digits = 3, ...) {
  cat("Fidelity threshold: the share f* of an option's effect that must arrive\n",
      "for it to stay (or become) recommended; NA = not ahead at any f <= 1\n\n", sep = "")
  print(round_df(as.data.frame(unclass(x), stringsAsFactors = FALSE), digits),
        row.names = FALSE)
  invisible(x)
}
