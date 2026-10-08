#' Express group outcomes in explicitly chosen reporting units
#' @param nb_list List of numeric draws x options matrices or draws x options x
#'   outcomes arrays, one per group.
#' @param units Named list of named coefficient vectors, one per reporting unit.
#'   Coefficients are NOT normalised: c(a=1,b=1) is a sum, c(a=.5,b=.5) a mean.
#' @return List with the same numeric shapes, named by reporting unit.
#' @examples
#' nb <- list(a = cbind(sq = 0, x = c(8, 2)), b = cbind(sq = 0, x = c(-2, 4)))
#' reporting_units(nb, list(total = c(a = 1, b = 1)))
#' @export
reporting_units <- function(nb_list, units) {
  if (missing(units)) stop_missing("units", "state the reporting coefficients.")
  nb_list <- check_nb(nb_list, multiple = TRUE)
  if (!is.list(units) || !length(units)) stop("`units` must be a non-empty named list.", call. = FALSE)
  check_names(names(units), "`units` must be named; names")
  # If any group has several outcomes, promote the remaining 1-outcome matrices.
  if (any(!vapply(nb_list, is.matrix, logical(1)))) nb_list <- as_outcome_arrays(nb_list)
  lapply(units, function(coefficients) {
    if (!is.numeric(coefficients) || !length(coefficients) || any(!is.finite(coefficients)))
      stop("Reporting coefficients must be finite numbers.", call. = FALSE)
    check_names(names(coefficients), "Coefficients must be named by group; names")
    if (!all(names(coefficients) %in% names(nb_list)))
      stop("Reporting unit refers to an unknown group.", call. = FALSE)
    # NB_u[s,d,k] = sum_g c_ug * NB_g[s,d,k]. Array arithmetic keeps outcomes
    # separate: kg is never added to money. Reduce('+') sums over groups only.
    terms <- Map(function(x, coefficient) coefficient * x,
                  nb_list[names(coefficients)], coefficients)
    Reduce(`+`, terms)
  })
}

#' Stack separately measured outcomes for reporting
#' @param ... Named matrices, or one named list of matrices, with matching dimensions.
#' @return A draws x options x outcomes array; no valuation or weighting occurs.
#' @examples
#' nb_array(money = cbind(sq = 0, x = c(5, 8)), hours = cbind(sq = 0, x = c(2, 3)))
#' @export
nb_array <- function(...) {
  matrices <- list(...)
  if (length(matrices) == 1L && is.list(matrices[[1L]])) matrices <- matrices[[1L]]
  check_names(names(matrices), "Outcome names")
  if (!all(vapply(matrices, is.matrix, logical(1))))
    stop("Every outcome must be a numeric matrix.", call. = FALSE)
  matrices <- check_nb(matrices)
  array(unlist(matrices, use.names = FALSE),
        dim = c(dim(matrices[[1L]]), length(matrices)),
        dimnames = list(NULL, colnames(matrices[[1L]]), names(matrices)))
}

# Used only by multiple-outcome reporting, not by the one-outcome valuation core.
as_outcome_arrays <- function(nb_list) {
  arrays <- Filter(function(x) length(dim(x)) == 3L, nb_list)
  outcomes <- if (length(arrays)) dimnames(arrays[[1L]])[[3L]] else "nb"
  lapply(nb_list, function(x) if (is.matrix(x))
    array(x, c(dim(x), 1L), dimnames = list(NULL, colnames(x), outcomes)) else x)
}

#' Summarise each group and option without a collective valuation
#' @param nb_list List of draws x options matrices, one outcome per call.
#' @return Data frame: unit, option, mean, p_gain, p_loss, preferred, EVPI.
#'   EVPI and preferred refer to each unit's OWN expected outcome. Repeated EVPI
#'   values within a unit are the same decision statistic, not additive amounts.
#' @examples
#' nb_summary(list(a = cbind(sq = 0, x = c(8, -2))))
#' @export
nb_summary <- function(nb_list) {
  nb_list <- check_nb(nb_list)
  rows <- lapply(names(nb_list), function(g) {
    x <- nb_list[[g]]
    means <- colMeans(x)                   # E_theta NB_g(d,theta), each group separately
    data.frame(unit = g, option = colnames(x), mean = as.numeric(means),
      p_gain = colMeans(x > 0), p_loss = colMeans(x < 0),
      preferred = colnames(x)[which.max(means)],
      EVPI = mean(apply(x, 1L, max)) - max(means), row.names = NULL)
  })
  do.call(rbind, rows)
}
