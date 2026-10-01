# Several outcomes and reporting units. Base R only -- see FUNCTIONS.md.
#
# A net benefit need not be one number: in a scaling decision it is typically
# a vector of outcomes -- income, labour time, consumption. Layer 1 never
# combines them: voi_partition(), fairness_screen() and marginalisation_count()
# value one outcome per call, and baseline_pair() reports every outcome side
# by side. Rules that combine outcomes (a weighted sum, a floor on one outcome,
# the order of aggregation) are not part of these functions.

#' Stack outcome matrices into one net-benefit array for one group
#'
#' Stacks one `S x D` matrix per outcome into the `S x D x K` array that
#' [baseline_pair()] and [reporting_units()] accept as an element of
#' `nb_list`.
#'
#' @param ... Named `S x D` numeric matrices, one per outcome, all with the
#'   same dimensions and column names. Alternatively a single named list of
#'   such matrices.
#' @return A numeric array with dimensions draws x options x outcomes.
#' @examples
#' S <- 100
#' money <- cbind(sq = 0, scale = rnorm(S, 50, 20))
#' hours <- cbind(sq = 0, scale = rnorm(S, -2, 1))
#' str(nb_array(money = money, hours = hours))
#' @export
nb_array <- function(...) {
  mats <- list(...)
  if (length(mats) == 1L && is.list(mats[[1L]]) && !is.array(mats[[1L]]))
    mats <- mats[[1L]]
  if (length(mats) == 0L) stop("No matrices supplied.", call. = FALSE)
  nm <- names(mats)
  if (is.null(nm) || any(!nzchar(nm)) || anyDuplicated(nm))
    stop("Every outcome matrix must be named, uniquely.", call. = FALSE)
  if (!all(vapply(mats, function(m) is.matrix(m) && is.numeric(m), logical(1))))
    stop("Every outcome must be a numeric draws x options matrix.",
         call. = FALSE)
  d1 <- dim(mats[[1L]])
  if (!all(vapply(mats, function(m) identical(dim(m), d1), logical(1))))
    stop("All outcome matrices must have the same dimensions.", call. = FALSE)
  cn <- colnames(mats[[1L]])
  if (!all(vapply(mats, function(m) identical(colnames(m), cn), logical(1))))
    stop("All outcome matrices must have the same column names (options).",
         call. = FALSE)
  array(unlist(mats, use.names = FALSE), dim = c(d1, length(mats)),
        dimnames = list(NULL, cn, nm))
}

#' Re-express net benefits in different reporting units
#'
#' Axis 3: the unit in which a result is reported is chosen, not given. The
#' same group-level model can be reported per commune, per gender, or per
#' household. `reporting_units()` builds each new unit as an explicit linear
#' combination of the groups in `nb_list`, outcome by outcome.
#'
#' Net benefits are additive quantities, so a linear combination covers the
#' cases that matter:
#' \itemize{
#'   \item a *share-weighted mean* (e.g. "women" from two commune-level groups,
#'     coefficients proportional to group size, summing to 1);
#'   \item a *sum* (e.g. a household from its members, coefficients 1 and 1).
#' }
#' The coefficients are the valuation and have no default.
#'
#' @param nb_list Named list of `S x D` matrices or `S x D x K` arrays.
#' @param units Named list. Each element is a named numeric vector of
#'   coefficients whose names are groups in `nb_list`.
#' @return An `nb_list` with one element per unit, in the shape of the input
#'   (matrices if every input element was a matrix, arrays otherwise).
#' @examples
#' S <- 200
#' nb <- list(a = cbind(sq = 0, x = rnorm(S, 5)),
#'            b = cbind(sq = 0, x = rnorm(S, 1)))
#' reporting_units(nb, list(both = c(a = 1, b = 1)))
#' @export
reporting_units <- function(nb_list, units) {
  st <- nb_structure(nb_list)
  if (missing(units))
    stop_missing("units", "a named list of named coefficient vectors.")
  if (!is.list(units) || length(units) == 0L)
    stop("`units` must be a non-empty named list.", call. = FALSE)
  un <- names(units)
  if (is.null(un) || any(!nzchar(un)) || anyDuplicated(un))
    stop("`units` must be named, uniquely.", call. = FALSE)

  out <- lapply(un, function(u) {
    coef <- units[[u]]
    if (!is.numeric(coef) || length(coef) == 0L || any(!is.finite(coef)))
      stop("Unit '", u, "': coefficients must be finite numbers.", call. = FALSE)
    cg <- names(coef)
    if (is.null(cg) || any(!nzchar(cg)) || anyDuplicated(cg))
      stop("Unit '", u, "': coefficients must be named by group, uniquely.",
           call. = FALSE)
    unknown <- setdiff(cg, st$groups)
    if (length(unknown))
      stop("Unit '", u, "' refers to unknown group(s): ",
           paste(unknown, collapse = ", "), ".", call. = FALSE)
    acc <- Reduce(`+`, Map(function(g, w) w * st$arrs[[g]], cg, coef))
    dimnames(acc) <- list(NULL, st$options, st$outcomes)
    if (st$was_matrix) {
      matrix(acc[, , 1L], nrow = st$S, dimnames = list(NULL, st$options))
    } else {
      acc
    }
  })
  stats::setNames(out, un)
}
